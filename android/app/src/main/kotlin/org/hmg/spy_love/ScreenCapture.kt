package org.hmg.spy_love

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.Base64
import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Consent-scoped live screen capture for the monitored device.
 *
 * This path is deliberately NOT covert:
 *  - Capture can only begin after the OS MediaProjection consent dialog
 *    ([Activity.startActivityForResult] with [MediaProjectionManager]), which
 *    the user must approve every session.
 *  - It runs inside a foreground [ScreenCaptureService] with an ongoing
 *    notification, so Android shows the system screen-cast indicator the whole
 *    time (in addition to the app's own in-app "screen is being shared" banner).
 *  - Frames are streamed live over the Flutter EventChannel and never stored.
 *
 * iOS is a follow-up: live screen capture there requires a ReplayKit broadcast
 * upload extension (a separate app target) and is intentionally not implemented
 * here. [MonitoringPlugin] reports isScreenCaptureSupported=false off Android.
 */
object ScreenFrameEventSink {
    @Volatile
    var sink: EventChannel.EventSink? = null
}

data class CaptureParams(
    val fps: Int,
    val maxWidth: Int,
    val jpegQuality: Int,
)

/**
 * Bridges Flutter's startScreenCapture call to the Activity-scoped OS consent
 * dialog, then launches the foreground capture service.
 */
object ScreenCaptureController {
    const val REQUEST_CODE = 0xC0DE
    const val EXTRA_RESULT_CODE = "result_code"
    const val EXTRA_RESULT_DATA = "result_data"
    const val EXTRA_FPS = "fps"
    const val EXTRA_MAX_WIDTH = "max_width"
    const val EXTRA_JPEG_QUALITY = "jpeg_quality"

    @Volatile
    private var activityRef: Activity? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingParams: CaptureParams = CaptureParams(8, 720, 40)

    fun attachActivity(activity: Activity) {
        activityRef = activity
    }

    fun detachActivity(activity: Activity) {
        if (activityRef === activity) activityRef = null
    }

    fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    /** Returns via [result] (true if the OS grant succeeded) asynchronously. */
    fun requestCapture(
        result: MethodChannel.Result,
        fps: Int,
        maxWidth: Int,
        jpegQuality: Int,
    ) {
        val activity = activityRef
        if (!isSupported() || activity == null) {
            result.success(false)
            return
        }
        // Only one pending request at a time.
        pendingResult?.success(false)
        pendingResult = result
        pendingParams = CaptureParams(
            fps = fps.coerceIn(1, 30),
            maxWidth = maxWidth.coerceIn(240, 1920),
            jpegQuality = jpegQuality.coerceIn(10, 90),
        )
        val manager =
            activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        activity.startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_CODE)
    }

    /** Called from MainActivity.onActivityResult. */
    fun onActivityResult(context: Context, requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_CODE) return
        val result = pendingResult
        pendingResult = null
        if (resultCode == Activity.RESULT_OK && data != null) {
            val intent = Intent(context, ScreenCaptureService::class.java).apply {
                putExtra(EXTRA_RESULT_CODE, resultCode)
                putExtra(EXTRA_RESULT_DATA, data)
                putExtra(EXTRA_FPS, pendingParams.fps)
                putExtra(EXTRA_MAX_WIDTH, pendingParams.maxWidth)
                putExtra(EXTRA_JPEG_QUALITY, pendingParams.jpegQuality)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            result?.success(true)
        } else {
            result?.success(false)
        }
    }

    fun stopCapture(context: Context) {
        context.stopService(Intent(context, ScreenCaptureService::class.java))
    }
}

class ScreenCaptureService : Service() {

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var handlerThread: HandlerThread? = null
    private var handler: Handler? = null
    private var lastFrameAt = 0L
    private var frameIntervalMs = 125L
    private var jpegQuality = 40

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            stopSelf()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForegroundWithNotification()

        val resultCode = intent.getIntExtra(ScreenCaptureController.EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
        @Suppress("DEPRECATION")
        val data: Intent? = intent.getParcelableExtra(ScreenCaptureController.EXTRA_RESULT_DATA)
        val fps = intent.getIntExtra(ScreenCaptureController.EXTRA_FPS, 8).coerceIn(1, 30)
        val maxWidth = intent.getIntExtra(ScreenCaptureController.EXTRA_MAX_WIDTH, 720).coerceIn(240, 1920)
        jpegQuality = intent.getIntExtra(ScreenCaptureController.EXTRA_JPEG_QUALITY, 40).coerceIn(10, 90)
        frameIntervalMs = (1000L / fps)

        if (data == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val projection = manager.getMediaProjection(resultCode, data)
        if (projection == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        mediaProjection = projection

        handlerThread = HandlerThread("screen-capture").also { it.start() }
        handler = Handler(handlerThread!!.looper)
        projection.registerCallback(projectionCallback, handler)

        startCapture(maxWidth)
        return START_NOT_STICKY
    }

    private fun startCapture(maxWidth: Int) {
        val metrics = DisplayMetrics()
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getRealMetrics(metrics)

        val scale = (maxWidth.toFloat() / metrics.widthPixels.toFloat()).coerceAtMost(1f)
        val width = (metrics.widthPixels * scale).toInt().coerceAtLeast(2)
        val height = (metrics.heightPixels * scale).toInt().coerceAtLeast(2)
        val density = metrics.densityDpi

        val reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        imageReader = reader

        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "spy-love-screen",
            width,
            height,
            density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            reader.surface,
            null,
            handler,
        )

        reader.setOnImageAvailableListener({ r ->
            val image = r.acquireLatestImage() ?: return@setOnImageAvailableListener
            try {
                val now = System.currentTimeMillis()
                if (now - lastFrameAt < frameIntervalMs) {
                    return@setOnImageAvailableListener
                }
                lastFrameAt = now

                val plane = image.planes[0]
                val buffer = plane.buffer
                val pixelStride = plane.pixelStride
                val rowStride = plane.rowStride
                val rowPadding = rowStride - pixelStride * width

                val bitmap = Bitmap.createBitmap(
                    width + rowPadding / pixelStride,
                    height,
                    Bitmap.Config.ARGB_8888,
                )
                bitmap.copyPixelsFromBuffer(buffer)
                val cropped = if (rowPadding == 0) {
                    bitmap
                } else {
                    Bitmap.createBitmap(bitmap, 0, 0, width, height)
                }

                val stream = ByteArrayOutputStream()
                cropped.compress(Bitmap.CompressFormat.JPEG, jpegQuality, stream)
                val b64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)

                if (cropped !== bitmap) cropped.recycle()
                bitmap.recycle()

                Handler(Looper.getMainLooper()).post {
                    ScreenFrameEventSink.sink?.success(
                        hashMapOf(
                            "image" to b64,
                            "w" to width,
                            "h" to height,
                        ),
                    )
                }
            } catch (_: Throwable) {
                // Drop bad frame; keep streaming.
            } finally {
                image.close()
            }
        }, handler)
    }

    private fun startForegroundWithNotification() {
        val channelId = "spy_love_screen_share"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                channelId,
                "Live screen sharing",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.description = "Shown while your screen is shared live with a consented monitor."
            nm.createNotificationChannel(channel)
        }

        val notification: Notification = Notification.Builder(
            this,
            channelId,
        )
            .setContentTitle("Your screen is being shared")
            .setContentText("A consented monitor can see your screen live. Stop anytime in the app.")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onDestroy() {
        try {
            virtualDisplay?.release()
            imageReader?.close()
            mediaProjection?.unregisterCallback(projectionCallback)
            mediaProjection?.stop()
        } catch (_: Throwable) {
            // best-effort teardown
        }
        virtualDisplay = null
        imageReader = null
        mediaProjection = null
        handlerThread?.quitSafely()
        handlerThread = null
        handler = null
        ScreenFrameEventSink.sink?.endOfStream()
        super.onDestroy()
    }

    companion object {
        private const val NOTIFICATION_ID = 0x5C1E
    }
}

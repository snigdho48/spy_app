package org.hmg.spy_love

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
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
import android.util.Log
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream

/**
 * Consent-scoped live screen capture for the monitored device.
 *
 * Critical Android 10/14+ rules this implementation follows:
 *  - Never parcel the MediaProjection result [Intent] through a Service intent —
 *    the binder token is lost on modern Android. Keep it in-process instead.
 *  - Call [Service.startForeground] with
 *    [ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION] *before*
 *    [MediaProjectionManager.getMediaProjection].
 *  - Register a [MediaProjection.Callback] before creating the VirtualDisplay.
 *  - Deliver the OS consent dialog result via
 *    [PluginRegistry.ActivityResultListener] (reliable with FlutterActivity),
 *    not only deprecated [Activity.onActivityResult].
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

object ScreenCaptureController : PluginRegistry.ActivityResultListener {
    const val REQUEST_CODE = 0xC0DE
    const val EXTRA_FPS = "fps"
    const val EXTRA_MAX_WIDTH = "max_width"
    const val EXTRA_JPEG_QUALITY = "jpeg_quality"
    private const val TAG = "SpyLoveScreenCapture"

    /**
     * Holds the OS grant between the Activity result and the service start.
     * Must NOT be put into an Intent extra — that drops the MediaProjection
     * IBinder on Android 14+.
     */
    @Volatile
    var grantedResultCode: Int = Activity.RESULT_CANCELED
        private set

    @Volatile
    var grantedResultData: Intent? = null
        private set

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

    fun consumeGrant(): Pair<Int, Intent>? {
        val data = grantedResultData ?: return null
        val code = grantedResultCode
        grantedResultData = null
        grantedResultCode = Activity.RESULT_CANCELED
        return code to data
    }

    fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP

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
        if (pendingResult != null) {
            // A consent dialog is already showing — do not complete the original.
            result.success(false)
            return
        }
        pendingResult = result
        pendingParams = CaptureParams(
            fps = fps.coerceIn(1, 30),
            maxWidth = maxWidth.coerceIn(240, 1920),
            jpegQuality = jpegQuality.coerceIn(10, 90),
        )

        // Android 13+: a foreground service notification is mandatory. Ask for
        // POST_NOTIFICATIONS first so startForeground is not rejected.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                activity,
                android.Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_CODE + 1,
                )
                // Continue anyway — the OS dialog for MediaProjection is still required.
            }
        }

        val manager =
            activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        try {
            activity.startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_CODE)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to launch MediaProjection consent", t)
            completePending(false)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        handleActivityResult(activityRef ?: return true, resultCode, data)
        return true
    }

    /** Also called from MainActivity.onActivityResult as a fallback. */
    fun onActivityResult(context: Context, requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_CODE) return
        handleActivityResult(context, resultCode, data)
    }

    private fun handleActivityResult(context: Context, resultCode: Int, data: Intent?) {
        if (pendingResult == null) {
            // Already handled by the other listener path.
            return
        }
        if (resultCode == Activity.RESULT_OK && data != null) {
            grantedResultCode = resultCode
            grantedResultData = data
            val intent = Intent(context, ScreenCaptureService::class.java).apply {
                putExtra(EXTRA_FPS, pendingParams.fps)
                putExtra(EXTRA_MAX_WIDTH, pendingParams.maxWidth)
                putExtra(EXTRA_JPEG_QUALITY, pendingParams.jpegQuality)
            }
            try {
                ContextCompat.startForegroundService(context, intent)
                // Success is confirmed by the service via [onServiceReady].
                // Keep pendingResult until then (or a short timeout).
                Handler(Looper.getMainLooper()).postDelayed({
                    if (pendingResult != null) {
                        Log.w(TAG, "Capture service did not confirm in time")
                        completePending(false)
                        stopCapture(context)
                    }
                }, 8_000L)
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to start capture service", t)
                grantedResultData = null
                completePending(false)
            }
        } else {
            completePending(false)
        }
    }

    fun onServiceReady(ok: Boolean) {
        completePending(ok)
    }

    private fun completePending(ok: Boolean) {
        val result = pendingResult ?: return
        pendingResult = null
        try {
            result.success(ok)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to complete Flutter result", t)
        }
    }

    fun stopCapture(context: Context) {
        grantedResultData = null
        grantedResultCode = Activity.RESULT_CANCELED
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
    private var reportedReady = false

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            stopSelf()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            failAndStop("null intent")
            return START_NOT_STICKY
        }

        try {
            startForegroundWithNotification()
        } catch (t: Throwable) {
            Log.e(TAG, "startForeground failed", t)
            failAndStop("startForeground: ${t.message}")
            return START_NOT_STICKY
        }

        val grant = ScreenCaptureController.consumeGrant()
        if (grant == null) {
            failAndStop("missing MediaProjection grant")
            return START_NOT_STICKY
        }
        val (resultCode, data) = grant

        val fps = intent.getIntExtra(ScreenCaptureController.EXTRA_FPS, 8).coerceIn(1, 30)
        val maxWidth = intent.getIntExtra(ScreenCaptureController.EXTRA_MAX_WIDTH, 720).coerceIn(240, 1920)
        jpegQuality = intent.getIntExtra(ScreenCaptureController.EXTRA_JPEG_QUALITY, 40).coerceIn(10, 90)
        frameIntervalMs = 1000L / fps

        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val projection = try {
            manager.getMediaProjection(resultCode, data)
        } catch (t: Throwable) {
            Log.e(TAG, "getMediaProjection failed", t)
            failAndStop("getMediaProjection: ${t.message}")
            return START_NOT_STICKY
        }
        if (projection == null) {
            failAndStop("getMediaProjection returned null")
            return START_NOT_STICKY
        }
        mediaProjection = projection

        handlerThread = HandlerThread("screen-capture").also { it.start() }
        handler = Handler(handlerThread!!.looper)
        // Android 14+: callback MUST be registered before createVirtualDisplay.
        projection.registerCallback(projectionCallback, handler)

        try {
            startCapture(maxWidth)
            reportReady(true)
        } catch (t: Throwable) {
            Log.e(TAG, "startCapture failed", t)
            failAndStop("startCapture: ${t.message}")
            return START_NOT_STICKY
        }
        return START_NOT_STICKY
    }

    private fun failAndStop(reason: String) {
        Log.w(TAG, "Capture service aborting: $reason")
        reportReady(false)
        stopSelf()
    }

    private fun reportReady(ok: Boolean) {
        if (reportedReady) return
        reportedReady = true
        Handler(Looper.getMainLooper()).post {
            ScreenCaptureController.onServiceReady(ok)
        }
    }

    private fun startCapture(maxWidth: Int) {
        val metrics = DisplayMetrics()
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getRealMetrics(metrics)

        val scale = (maxWidth.toFloat() / metrics.widthPixels.toFloat()).coerceAtMost(1f)
        val width = (metrics.widthPixels * scale).toInt().coerceAtLeast(2) and 1.inv()
        val height = (metrics.heightPixels * scale).toInt().coerceAtLeast(2) and 1.inv()
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
        ) ?: throw IllegalStateException("createVirtualDisplay returned null")

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
            channel.setShowBadge(false)
            nm.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Your screen is being shared")
            .setContentText("A consented monitor can see your screen live. Stop anytime in the app.")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
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
        super.onDestroy()
    }

    companion object {
        private const val NOTIFICATION_ID = 0x5C1E
        private const val TAG = "SpyLoveScreenCapture"
    }
}

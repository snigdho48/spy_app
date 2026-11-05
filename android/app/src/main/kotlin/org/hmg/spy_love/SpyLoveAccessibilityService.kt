package org.hmg.spy_love

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

/**
 * Declared AccessibilityService so Spy Love appears under
 * Settings → Accessibility and can be enabled by the device owner.
 *
 * After the owner explicitly approves a remote-control request, this service
 * injects consented taps, swipes, and Back/Home/Recents. Event handling stays
 * a no-op: we do not record keystrokes, typed text, passwords, or clipboard.
 */
class SpyLoveAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile
        var instance: SpyLoveAccessibilityService? = null

        fun inject(raw: Map<*, *>?): Boolean {
            val service = instance ?: return false
            val data = raw ?: return false
            return service.enqueueControl(data)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        // Keep the XML config as source of truth; refresh flags defensively.
        serviceInfo = serviceInfo?.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = flags or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        }
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        if (instance === this) instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Intentionally empty: do not record keystrokes, text, or window content.
    }

    override fun onInterrupt() {
        // Required by AccessibilityService.
    }

    private fun enqueueControl(data: Map<*, *>): Boolean {
        val action = data["action"]?.toString() ?: return false
        mainHandler.post { dispatch(action, data) }
        return true
    }

    private fun dispatch(action: String, data: Map<*, *>) {
        when (action) {
            "tap" -> gestureTap(
                norm(data["x"]),
                norm(data["y"]),
                duration(data["duration_ms"], 50L),
            )
            "long_press" -> gestureTap(
                norm(data["x"]),
                norm(data["y"]),
                duration(data["duration_ms"], 600L),
            )
            "swipe" -> gestureSwipe(
                norm(data["x"]),
                norm(data["y"]),
                norm(data["x2"]),
                norm(data["y2"]),
                duration(data["duration_ms"], 250L),
            )
            "back" -> performGlobalAction(GLOBAL_ACTION_BACK)
            "home" -> performGlobalAction(GLOBAL_ACTION_HOME)
            "recents" -> performGlobalAction(GLOBAL_ACTION_RECENTS)
            else -> Unit
        }
    }

    private fun norm(value: Any?): Float {
        val number = (value as? Number)?.toFloat() ?: return -1f
        return if (number in 0f..1f) number else -1f
    }

    private fun duration(value: Any?, default: Long): Long {
        val raw = (value as? Number)?.toLong() ?: default
        return raw.coerceIn(20L, 1500L)
    }

    private fun gestureTap(nx: Float, ny: Float, durationMs: Long) {
        if (nx < 0f || ny < 0f) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val metrics = resources.displayMetrics
        val x = nx * metrics.widthPixels
        val y = ny * metrics.heightPixels
        val path = Path().apply { moveTo(x, y) }
        val stroke = GestureDescription.StrokeDescription(path, 0, durationMs)
        dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
    }

    private fun gestureSwipe(
        nx: Float,
        ny: Float,
        nx2: Float,
        ny2: Float,
        durationMs: Long,
    ) {
        if (nx < 0f || ny < 0f || nx2 < 0f || ny2 < 0f) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val metrics = resources.displayMetrics
        val path = Path().apply {
            moveTo(nx * metrics.widthPixels, ny * metrics.heightPixels)
            lineTo(nx2 * metrics.widthPixels, ny2 * metrics.heightPixels)
        }
        val stroke = GestureDescription.StrokeDescription(path, 0, durationMs)
        dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
    }
}

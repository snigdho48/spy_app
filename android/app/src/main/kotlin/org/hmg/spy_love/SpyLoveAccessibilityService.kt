package org.hmg.spy_love

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent

/**
 * Declared AccessibilityService so Spy Love appears under
 * Settings → Accessibility and can be enabled by the device owner.
 *
 * Event handling is intentionally minimal for now: enabling the service is
 * what unblocks consented monitoring features that require accessibility.
 * Expand handlers when a specific feature needs window/content events.
 */
class SpyLoveAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
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

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // No-op stub: listing + enablement is the goal of this pass.
    }

    override fun onInterrupt() {
        // Required by AccessibilityService.
    }
}

package org.hmg.spy_love

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * FlutterPlugin wrapper so MediaProjection activity results are delivered via
 * [ActivityPluginBinding.addActivityResultListener] (reliable with FlutterActivity).
 */
class MonitoringFlutterPlugin : FlutterPlugin, ActivityAware {
    private var binding: ActivityPluginBinding? = null
    private var registered = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        MonitoringPlugin.register(binding.binaryMessenger, binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Channels are process-scoped; leave sinks alone.
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        ScreenCaptureController.attachActivity(binding.activity)
        if (!registered) {
            binding.addActivityResultListener(ScreenCaptureController)
            registered = true
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        val activity = binding?.activity
        if (activity != null) ScreenCaptureController.detachActivity(activity)
        binding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        val activity = binding?.activity
        if (activity != null) ScreenCaptureController.detachActivity(activity)
        if (registered) {
            this.binding?.removeActivityResultListener(ScreenCaptureController)
            registered = false
        }
        binding = null
    }
}

package org.hmg.spy_love

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MonitoringPlugin.register(flutterEngine, applicationContext)
    }

    override fun onResume() {
        super.onResume()
        // Needed so consent-scoped screen capture can launch the OS
        // MediaProjection permission dialog from a live Activity.
        ScreenCaptureController.attachActivity(this)
    }

    override fun onDestroy() {
        ScreenCaptureController.detachActivity(this)
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        ScreenCaptureController.onActivityResult(applicationContext, requestCode, resultCode, data)
    }
}

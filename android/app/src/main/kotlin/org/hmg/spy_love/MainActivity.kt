package org.hmg.spy_love

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // ActivityAware plugin receives activity-result callbacks reliably.
        flutterEngine.plugins.add(MonitoringFlutterPlugin())
    }

    override fun onResume() {
        super.onResume()
        ScreenCaptureController.attachActivity(this)
    }

    override fun onDestroy() {
        ScreenCaptureController.detachActivity(this)
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // Belt-and-suspenders alongside ActivityAware listener.
        ScreenCaptureController.onActivityResult(applicationContext, requestCode, resultCode, data)
    }
}

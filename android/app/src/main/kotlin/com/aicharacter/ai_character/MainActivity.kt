package com.aicharacter.ai_character

import android.Manifest
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.*
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.view.WindowManager
import android.app.KeyguardManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.aicharacter.ai_character/usage_stats"
    private val AUDIO_CHANNEL = "com.aicharacter.ai_character/audio"
    private val SPEECH_CHANNEL = "com.aicharacter.ai_character/speech"
    private val EVENT_CHANNEL = "com.aicharacter.ai_character/distraction_events"
    private val NAVER_CHANNEL = "com.aicharacter.ai_character/naver_reservation"
    private val NAVER_EVENT_CHANNEL = "com.aicharacter.ai_character/naver_events"
    private var eventSink: EventChannel.EventSink? = null
    private var naverEventSink: EventChannel.EventSink? = null
    private var mediaPlayer: MediaPlayer? = null
    private var alarmPlayer: MediaPlayer? = null
    private var alarmRingtone: android.media.Ringtone? = null
    private var fallbackTone: android.media.ToneGenerator? = null
    private var ambientGenerator: AmbientSoundGenerator? = null
    private var speechResult: MethodChannel.Result? = null
    private var naverResult: MethodChannel.Result? = null
    private var pickImageResult: MethodChannel.Result? = null
    private val PICK_IMAGE_REQUEST = 2001

    // Shake detection
    private var sensorManager: SensorManager? = null
    private var shakeListener: SensorEventListener? = null
    private var audioChannel: MethodChannel? = null
    private var lastShakeTime: Long = 0
    private val SHAKE_THRESHOLD = 12.0
    private val SHAKE_DEBOUNCE_MS = 300L

    // Alarm: pending alarm data from fullScreenIntent
    private var usageStatsChannel: MethodChannel? = null
    private var pendingAlarmData: Map<String, String>? = null

    private val distractionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.aicharacter.DISTRACTION_DETECTED") {
                val data = mapOf(
                    "app_package" to (intent.getStringExtra("app_package") ?: ""),
                    "app_label" to (intent.getStringExtra("app_label") ?: ""),
                    "routine_name" to (intent.getStringExtra("routine_name") ?: "")
                )
                eventSink?.success(data)
            }
        }
    }

    private val naverReservationReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == NaverNotificationService.ACTION_RESERVATION_DETECTED) {
                val data = mapOf(
                    "title" to (intent.getStringExtra("title") ?: ""),
                    "text" to (intent.getStringExtra("text") ?: ""),
                    "bigText" to (intent.getStringExtra("bigText") ?: ""),
                    "timestamp" to (intent.getLongExtra("timestamp", 0L).toString())
                )
                naverEventSink?.success(data)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        usageStatsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        usageStatsChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageStatsPermission" -> result.success(hasUsageStatsPermission())
                "requestUsageStatsPermission" -> {
                    requestUsageStatsPermission()
                    result.success(null)
                }
                "hasOverlayPermission" -> result.success(hasOverlayPermission())
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success(null)
                }
                "getForegroundApp" -> result.success(getForegroundApp())
                "getAppLabel" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    result.success(getAppLabel(pkg))
                }
                "getInstalledApps" -> result.success(getInstalledApps())
                "queryDailyUsageStats" -> {
                    val date = call.argument<String>("date") ?: ""
                    result.success(queryDailyUsageStats(date))
                }
                "getUnlockCount" -> {
                    val date = call.argument<String>("date") ?: ""
                    result.success(getUnlockCount(date))
                }
                "getHourlyUsage" -> {
                    val date = call.argument<String>("date") ?: ""
                    result.success(getHourlyUsage(date))
                }
                "startActivityRecognition" -> {
                    startActivityRecognition(result)
                }
                "stopActivityRecognition" -> {
                    stopActivityRecognition()
                    result.success(true)
                }
                "getActivityLog" -> {
                    val date = call.argument<String>("date") ?: ""
                    result.success(getActivityLog(date))
                }
                "startMonitorService" -> {
                    startMonitorService()
                    result.success(true)
                }
                "stopMonitorService" -> {
                    stopMonitorService()
                    result.success(true)
                }
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                    }
                    startActivity(Intent.createChooser(intent, "공유"))
                    result.success(true)
                }
                "shareFile" -> {
                    val path = call.argument<String>("path") ?: ""
                    val mimeType = call.argument<String>("mimeType") ?: "image/png"
                    val file = java.io.File(path)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "File not found: $path", null)
                    } else {
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            this, "$packageName.fileprovider", file
                        )
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = mimeType
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(intent, "공유"))
                        result.success(true)
                    }
                }
                "shareFiles" -> {
                    val paths = call.argument<List<String>>("paths") ?: emptyList()
                    val uris = ArrayList<Uri>()
                    for (p in paths) {
                        val f = java.io.File(p)
                        if (f.exists()) {
                            uris.add(androidx.core.content.FileProvider.getUriForFile(
                                this, "$packageName.fileprovider", f
                            ))
                        }
                    }
                    if (uris.isEmpty()) {
                        result.error("NO_FILES", "No valid files", null)
                    } else {
                        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                            type = "*/*"
                            putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(intent, "명함 공유"))
                        result.success(true)
                    }
                }
                "getCacheDir" -> {
                    result.success(cacheDir.absolutePath)
                }
                "pickImage" -> {
                    pickImageResult = result
                    val intent = Intent(Intent.ACTION_PICK).apply {
                        type = "image/*"
                    }
                    startActivityForResult(intent, PICK_IMAGE_REQUEST)
                }
                "openUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    try {
                        openUrlPreferApp(url)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_URL_ERROR", e.message, null)
                    }
                }
                "scheduleNativeAlarm" -> {
                    val requestCode = call.argument<Int>("requestCode")!!
                    val timeMillis = call.argument<Number>("timeMillis")!!.toLong()
                    val alarmId = call.argument<String>("alarmId") ?: ""
                    val label = call.argument<String>("label") ?: "알람"
                    val repeating = call.argument<Boolean>("repeating") ?: false
                    AlarmReceiver.scheduleAlarm(this, requestCode, timeMillis, alarmId, label, repeating)
                    result.success(true)
                }
                "cancelNativeAlarm" -> {
                    val requestCode = call.argument<Int>("requestCode")!!
                    AlarmReceiver.cancelAlarm(this, requestCode)
                    result.success(true)
                }
                "stopAlarmRing" -> {
                    stopService(Intent(this, AlarmRingService::class.java))
                    disableAlarmScreenFlags()
                    result.success(true)
                }
                "checkPendingAlarm" -> {
                    val data = pendingAlarmData ?: consumeAlarmIntent(intent)
                    pendingAlarmData = null
                    if (data != null) {
                        enableAlarmScreenFlags()
                    }
                    result.success(data)
                }
                "debugWidgetData" -> {
                    val dump = WidgetDataHelper.debugDumpKeys(this)
                    println(dump)
                    result.success(dump)
                }
                "testDetection" -> {
                    val fg = getForegroundApp()
                    val label = if (fg.isNotEmpty()) getAppLabel(fg) else "없음"
                    result.success(mapOf(
                        "foreground_app" to fg,
                        "app_label" to label,
                        "has_usage_permission" to hasUsageStatsPermission(),
                        "has_overlay_permission" to hasOverlayPermission()
                    ))
                }
                else -> result.notImplemented()
            }
        }

        audioChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
        audioChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "playFile" -> {
                    val path = call.argument<String>("path") ?: ""
                    playAudioFile(path, result)
                }
                "stop" -> {
                    stopAudio()
                    result.success(null)
                }
                "playAlarm" -> {
                    playAlarmSound()
                    result.success(null)
                }
                "stopAlarm" -> {
                    stopAlarmSound()
                    result.success(null)
                }
                "startAmbient" -> {
                    val type = call.argument<String>("type") ?: "white"
                    val vol = call.argument<Double>("volume") ?: 0.5
                    if (ambientGenerator == null) {
                        ambientGenerator = AmbientSoundGenerator()
                    }
                    ambientGenerator?.start(type, vol)
                    result.success(null)
                }
                "stopAmbient" -> {
                    ambientGenerator?.stop()
                    result.success(null)
                }
                "setAmbientVolume" -> {
                    val vol = call.argument<Double>("volume") ?: 0.5
                    ambientGenerator?.setVolume(vol)
                    result.success(null)
                }
                "setAmbientType" -> {
                    val type = call.argument<String>("type") ?: "white"
                    ambientGenerator?.setType(type)
                    result.success(null)
                }
                "startShakeDetection" -> {
                    startShakeDetection()
                    result.success(null)
                }
                "stopShakeDetection" -> {
                    stopShakeDetection()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> startSpeechRecognition(result)
                else -> result.notImplemented()
            }
        }

        // Naver reservation channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "fetchReservations" -> fetchNaverReservations(result)
                "hasNotificationListenerPermission" -> {
                    result.success(hasNotificationListenerPermission())
                }
                "requestNotificationListenerPermission" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    } catch (_: Exception) {}
                    result.success(null)
                }
                "getPendingNotifications" -> {
                    result.success(getAndClearPendingNotifications())
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        // Naver reservation event channel (real-time notification delivery)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NAVER_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    naverEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    naverEventSink = null
                }
            }
        )

        val filter = IntentFilter("com.aicharacter.DISTRACTION_DETECTED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(distractionReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(distractionReceiver, filter)
        }

        // Naver reservation broadcast receiver
        val naverFilter = IntentFilter(NaverNotificationService.ACTION_RESERVATION_DETECTED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(naverReservationReceiver, naverFilter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(naverReservationReceiver, naverFilter)
        }
    }

    override fun onResume() {
        super.onResume()
        refreshAllWidgets()
    }

    private fun refreshAllWidgets() {
        RoutineWidgetProvider.updateAllWidgets(this)
        BookmarkWidgetProvider.updateAllWidgets(this)
        TodoWidgetProvider.updateAllWidgets(this)
        MemoWidgetProvider.updateAllWidgets(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent) // Update so getIntent() returns latest alarm intent
        val data = consumeAlarmIntent(intent)
        if (data != null) {
            enableAlarmScreenFlags()
            // Store as pending in case Flutter channel isn't ready yet
            pendingAlarmData = data
            // Flutter is already running, send via MethodChannel
            usageStatsChannel?.invokeMethod("onAlarmRing", data)
        }
    }

    private fun enableAlarmScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            km.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }

    private fun disableAlarmScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
        } else {
            @Suppress("DEPRECATION")
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }

    private fun consumeAlarmIntent(intent: Intent?): Map<String, String>? {
        if (intent?.getBooleanExtra("from_alarm", false) != true) return null
        val alarmId = intent.getStringExtra("alarm_id") ?: ""
        val label = intent.getStringExtra("alarm_label") ?: "알람"
        intent.removeExtra("from_alarm") // consume
        return mapOf("alarmId" to alarmId, "label" to label)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_IMAGE_REQUEST) {
            if (resultCode == RESULT_OK && data?.data != null) {
                try {
                    val uri = data.data!!
                    val dest = java.io.File(filesDir, "card_photo.jpg")
                    contentResolver.openInputStream(uri)?.use { input ->
                        dest.outputStream().use { output -> input.copyTo(output) }
                    }
                    pickImageResult?.success(dest.absolutePath)
                } catch (e: Exception) {
                    pickImageResult?.error("PICK_ERROR", e.message, null)
                }
            } else {
                pickImageResult?.success(null)
            }
            pickImageResult = null
        }
    }

    override fun onDestroy() {
        stopShakeDetection()
        ambientGenerator?.stop()
        ambientGenerator = null
        try { unregisterReceiver(distractionReceiver) } catch (_: Exception) {}
        try { unregisterReceiver(naverReservationReceiver) } catch (_: Exception) {}
        super.onDestroy()
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    1001
                )
            }
        }
    }

    private fun startMonitorService() {
        val intent = Intent(this, MonitorService::class.java).apply {
            action = MonitorService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopMonitorService() {
        val intent = Intent(this, MonitorService::class.java).apply {
            action = MonitorService.ACTION_STOP
        }
        startService(intent)
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun requestUsageStatsPermission() {
        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else true
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            startActivity(Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            ))
        }
    }

    private fun getForegroundApp(): String {
        if (!hasUsageStatsPermission()) return ""
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, end - 5000, end)
        if (stats.isNullOrEmpty()) return ""
        var app = ""
        var time = 0L
        for (s in stats) {
            if (s.lastTimeUsed > time) { time = s.lastTimeUsed; app = s.packageName }
        }
        return app
    }

    private fun getAppLabel(pkg: String): String {
        return try {
            val pm = applicationContext.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (_: PackageManager.NameNotFoundException) { pkg }
    }

    private fun queryDailyUsageStats(date: String): List<Map<String, Any>> {
        if (!hasUsageStatsPermission()) return emptyList()

        val parts = date.split("-")
        if (parts.size != 3) return emptyList()

        val year = parts[0].toIntOrNull() ?: return emptyList()
        val month = parts[1].toIntOrNull() ?: return emptyList()
        val day = parts[2].toIntOrNull() ?: return emptyList()

        val cal = java.util.Calendar.getInstance().apply {
            set(year, month - 1, day, 0, 0, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val rangeStart = cal.timeInMillis
        cal.add(java.util.Calendar.DAY_OF_MONTH, 1)
        val rangeEnd = Math.min(cal.timeInMillis, System.currentTimeMillis())

        if (rangeEnd <= rangeStart) return emptyList()

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(rangeStart, rangeEnd)

        val foregroundStarts = mutableMapOf<String, Long>()
        val totalTimes = mutableMapOf<String, Long>()

        val event = android.app.usage.UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue

            when (event.eventType) {
                1, 7 -> { // MOVE_TO_FOREGROUND, ACTIVITY_RESUMED
                    foregroundStarts[pkg] = event.timeStamp
                }
                2, 8 -> { // MOVE_TO_BACKGROUND, ACTIVITY_PAUSED
                    val start = foregroundStarts.remove(pkg) ?: continue
                    val duration = event.timeStamp - start
                    if (duration > 0) {
                        totalTimes[pkg] = (totalTimes[pkg] ?: 0L) + duration
                    }
                }
            }
        }

        // Apps still in foreground: count time up to rangeEnd
        for ((pkg, start) in foregroundStarts) {
            val duration = rangeEnd - start
            if (duration > 0) {
                totalTimes[pkg] = (totalTimes[pkg] ?: 0L) + duration
            }
        }

        val myPackage = packageName
        val excludePrefixes = listOf(
            "com.android.launcher",
            "com.android.systemui",
            "com.android.inputmethod",
            "com.google.android.inputmethod",
            "com.samsung.android.honeyboard",
            "com.sec.android.inputmethod"
        )

        return totalTimes.entries
            .filter { (pkg, time) ->
                time > 0 &&
                pkg != myPackage &&
                excludePrefixes.none { prefix -> pkg.startsWith(prefix) }
            }
            .map { (pkg, time) ->
                mapOf<String, Any>(
                    "appPackage" to pkg,
                    "appLabel" to getAppLabel(pkg),
                    "totalTime" to time
                )
            }
    }

    private fun getUnlockCount(date: String): Int {
        if (!hasUsageStatsPermission()) return 0
        val parts = date.split("-")
        if (parts.size != 3) return 0
        val year = parts[0].toIntOrNull() ?: return 0
        val month = parts[1].toIntOrNull() ?: return 0
        val day = parts[2].toIntOrNull() ?: return 0

        val cal = java.util.Calendar.getInstance().apply {
            set(year, month - 1, day, 0, 0, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val rangeStart = cal.timeInMillis
        cal.add(java.util.Calendar.DAY_OF_MONTH, 1)
        val rangeEnd = Math.min(cal.timeInMillis, System.currentTimeMillis())
        if (rangeEnd <= rangeStart) return 0

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(rangeStart, rangeEnd)
        var count = 0
        val event = android.app.usage.UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            // KEYGUARD_HIDDEN = 18
            if (event.eventType == 18) count++
        }
        return count
    }

    private fun getHourlyUsage(date: String): List<Long> {
        val hourly = MutableList(24) { 0L }
        if (!hasUsageStatsPermission()) return hourly
        val parts = date.split("-")
        if (parts.size != 3) return hourly
        val year = parts[0].toIntOrNull() ?: return hourly
        val month = parts[1].toIntOrNull() ?: return hourly
        val day = parts[2].toIntOrNull() ?: return hourly

        val cal = java.util.Calendar.getInstance().apply {
            set(year, month - 1, day, 0, 0, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val rangeStart = cal.timeInMillis
        cal.add(java.util.Calendar.DAY_OF_MONTH, 1)
        val rangeEnd = Math.min(cal.timeInMillis, System.currentTimeMillis())
        if (rangeEnd <= rangeStart) return hourly

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(rangeStart, rangeEnd)

        val foregroundStarts = mutableMapOf<String, Long>()
        val myPackage = packageName
        val excludePrefixes = listOf(
            "com.android.launcher", "com.android.systemui",
            "com.android.inputmethod", "com.google.android.inputmethod",
            "com.samsung.android.honeyboard", "com.sec.android.inputmethod"
        )

        val event = android.app.usage.UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            if (pkg == myPackage || excludePrefixes.any { pkg.startsWith(it) }) continue

            when (event.eventType) {
                1, 7 -> foregroundStarts[pkg] = event.timeStamp
                2, 8 -> {
                    val start = foregroundStarts.remove(pkg) ?: continue
                    if (event.timeStamp > start) {
                        addToHourlyBuckets(hourly, start, event.timeStamp, rangeStart)
                    }
                }
            }
        }
        // Still-in-foreground apps
        for ((_, start) in foregroundStarts) {
            if (rangeEnd > start) {
                addToHourlyBuckets(hourly, start, rangeEnd, rangeStart)
            }
        }
        return hourly
    }

    private fun addToHourlyBuckets(hourly: MutableList<Long>, start: Long, end: Long, dayStart: Long) {
        val msPerHour = 3600_000L
        val startHour = ((start - dayStart) / msPerHour).toInt().coerceIn(0, 23)
        val endHour = ((end - dayStart - 1) / msPerHour).toInt().coerceIn(0, 23)
        if (startHour == endHour) {
            hourly[startHour] += end - start
        } else {
            // First hour partial
            val firstHourEnd = dayStart + (startHour + 1) * msPerHour
            hourly[startHour] += firstHourEnd - start
            // Full hours in between
            for (h in (startHour + 1) until endHour) {
                hourly[h] += msPerHour
            }
            // Last hour partial
            val lastHourStart = dayStart + endHour * msPerHour
            hourly[endHour] += end - lastHourStart
        }
    }

    // ─── Activity Recognition ───
    private var activityPendingIntent: android.app.PendingIntent? = null

    private fun startActivityRecognition(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION)
                != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this,
                    arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), 3001)
                result.success(false)
                return
            }
        }

        val intent = Intent(this, ActivityRecognitionReceiver::class.java)
        activityPendingIntent = android.app.PendingIntent.getBroadcast(
            this, 0, intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
        )

        val transitions = mutableListOf<com.google.android.gms.location.ActivityTransition>()
        val types = listOf(
            com.google.android.gms.location.DetectedActivity.WALKING,
            com.google.android.gms.location.DetectedActivity.RUNNING,
            com.google.android.gms.location.DetectedActivity.ON_BICYCLE,
            com.google.android.gms.location.DetectedActivity.IN_VEHICLE,
            com.google.android.gms.location.DetectedActivity.STILL,
        )
        for (type in types) {
            transitions.add(com.google.android.gms.location.ActivityTransition.Builder()
                .setActivityType(type)
                .setActivityTransition(com.google.android.gms.location.ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                .build())
            transitions.add(com.google.android.gms.location.ActivityTransition.Builder()
                .setActivityType(type)
                .setActivityTransition(com.google.android.gms.location.ActivityTransition.ACTIVITY_TRANSITION_EXIT)
                .build())
        }

        val request = com.google.android.gms.location.ActivityTransitionRequest(transitions)
        com.google.android.gms.location.ActivityRecognition.getClient(this)
            .requestActivityTransitionUpdates(request, activityPendingIntent!!)
            .addOnSuccessListener { result.success(true) }
            .addOnFailureListener { result.success(false) }
    }

    private fun stopActivityRecognition() {
        val pi = activityPendingIntent ?: return
        com.google.android.gms.location.ActivityRecognition.getClient(this)
            .removeActivityTransitionUpdates(pi)
        activityPendingIntent = null
    }

    private fun getActivityLog(date: String): List<Map<String, Any>> {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.activity_log", "[]") ?: "[]"
        val arr = try { org.json.JSONArray(raw) } catch (_: Exception) { return emptyList() }

        // Parse date range
        val parts = date.split("-")
        if (parts.size != 3) return emptyList()
        val year = parts[0].toIntOrNull() ?: return emptyList()
        val month = parts[1].toIntOrNull() ?: return emptyList()
        val day = parts[2].toIntOrNull() ?: return emptyList()

        val cal = java.util.Calendar.getInstance().apply {
            set(year, month - 1, day, 0, 0, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val rangeStart = cal.timeInMillis
        cal.add(java.util.Calendar.DAY_OF_MONTH, 1)
        val rangeEnd = cal.timeInMillis

        val result = mutableListOf<Map<String, Any>>()
        for (i in 0 until arr.length()) {
            val obj = arr.optJSONObject(i) ?: continue
            val ts = obj.optLong("timestamp", 0)
            if (ts in rangeStart until rangeEnd) {
                result.add(mapOf(
                    "type" to (obj.optString("type", "unknown")),
                    "transition" to (obj.optString("transition", "")),
                    "timestamp" to ts,
                ))
            }
        }
        return result
    }

    private fun getInstalledApps(): Map<String, String> {
        val pm = applicationContext.packageManager
        val apps = mutableMapOf<String, String>()
        for (info in pm.getInstalledApplications(PackageManager.GET_META_DATA)) {
            if (pm.getLaunchIntentForPackage(info.packageName) != null) {
                apps[info.packageName] = pm.getApplicationLabel(info).toString()
            }
        }
        return apps
    }

    // ─── Naver Reservation Helpers ─────────────────────────

    private fun fetchNaverReservations(result: MethodChannel.Result) {
        naverResult?.success(mapOf("status" to "cancelled", "text" to ""))
        naverResult = result

        NaverWebViewActivity.onResult = { text ->
            naverResult?.success(mapOf("status" to "ok", "text" to text))
            naverResult = null
        }
        NaverWebViewActivity.onError = { err ->
            naverResult?.success(mapOf("status" to "error", "text" to "", "error" to err))
            naverResult = null
        }

        try {
            val intent = Intent(this, NaverWebViewActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            naverResult?.error("NAVER_ERROR", e.message, null)
            naverResult = null
        }
    }

    private fun hasNotificationListenerPermission(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: ""
        return flat.split(":").any { it.contains(pkgName) }
    }

    private fun getAndClearPendingNotifications(): List<Map<String, Any>> {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val raw = prefs.getString("flutter.naver_pending_notifications", "[]") ?: "[]"
        val arr = try { org.json.JSONArray(raw) } catch (_: Exception) { org.json.JSONArray() }

        val result = mutableListOf<Map<String, Any>>()
        for (i in 0 until arr.length()) {
            val obj = arr.optJSONObject(i) ?: continue
            result.add(mapOf(
                "title" to (obj.optString("title", "")),
                "text" to (obj.optString("text", "")),
                "bigText" to (obj.optString("bigText", "")),
                "timestamp" to obj.optLong("timestamp", 0L),
            ))
        }
        // Clear pending
        prefs.edit().putString("flutter.naver_pending_notifications", "[]").apply()
        return result
    }

    // ─── Speech Recognition ─────────────────────────────────

    private fun startSpeechRecognition(result: MethodChannel.Result) {
        // Cancel any previous pending result
        speechResult?.success(null)
        speechResult = result

        SpeechListenerActivity.onResult = { text ->
            speechResult?.success(text)
            speechResult = null
        }
        SpeechListenerActivity.onError = { _ ->
            speechResult?.success(null)
            speechResult = null
        }
        SpeechListenerActivity.onListening = {}
        SpeechListenerActivity.onPartial = {}

        try {
            val intent = Intent(this, SpeechListenerActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            speechResult?.error("SPEECH_ERROR", e.message, null)
            speechResult = null
        }
    }

    private fun playAudioFile(path: String, result: MethodChannel.Result) {
        try {
            stopAudio()
            mediaPlayer = MediaPlayer().apply {
                setDataSource(path)
                setOnCompletionListener {
                    it.release()
                    mediaPlayer = null
                }
                setOnErrorListener { mp, _, _ ->
                    mp.release()
                    mediaPlayer = null
                    true
                }
                prepare()
                start()
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("PLAY_ERROR", e.message, null)
        }
    }

    private fun playAlarmSound() {
        stopAlarmSound()

        // 1차: Ringtone API (가장 안정적)
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            if (uri != null) {
                val rt = RingtoneManager.getRingtone(this, uri)
                if (rt != null) {
                    rt.audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        rt.isLooping = true
                    }
                    rt.play()
                    alarmRingtone = rt
                    println("[MainActivity] playAlarmSound: Ringtone OK")
                    return
                }
            }
        } catch (e: Exception) {
            println("[MainActivity] Ringtone failed: ${e.message}")
        }

        // 2차: MediaPlayer
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            if (uri != null) {
                alarmPlayer = MediaPlayer().apply {
                    setDataSource(this@MainActivity, uri)
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    isLooping = true
                    prepare()
                    start()
                }
                println("[MainActivity] playAlarmSound: MediaPlayer OK")
                return
            }
        } catch (e: Exception) {
            println("[MainActivity] MediaPlayer failed: ${e.message}")
        }

        // 3차: ToneGenerator (최후 수단)
        playFallbackTone()
    }

    private fun playFallbackTone() {
        try {
            val toneGen = android.media.ToneGenerator(
                android.media.AudioManager.STREAM_ALARM, 100
            )
            toneGen.startTone(android.media.ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 5000)
            fallbackTone = toneGen
            println("[MainActivity] playAlarmSound: ToneGenerator fallback")
        } catch (e: Exception) {
            println("[MainActivity] fallbackTone error: ${e.message}")
        }
    }

    private fun stopAlarmSound() {
        try {
            alarmRingtone?.stop()
        } catch (_: Exception) {}
        alarmRingtone = null
        try {
            alarmPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {}
        alarmPlayer = null
        try {
            fallbackTone?.release()
        } catch (_: Exception) {}
        fallbackTone = null
    }

    private fun stopAudio() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {}
        mediaPlayer = null
    }

    private fun startShakeDetection() {
        stopShakeDetection()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return

        shakeListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent?) {
                if (event == null) return
                val x = event.values[0]
                val y = event.values[1]
                val z = event.values[2]
                val gX = x / SensorManager.GRAVITY_EARTH
                val gY = y / SensorManager.GRAVITY_EARTH
                val gZ = z / SensorManager.GRAVITY_EARTH
                val gForce = Math.sqrt((gX * gX + gY * gY + gZ * gZ).toDouble())

                if (gForce > SHAKE_THRESHOLD / SensorManager.GRAVITY_EARTH) {
                    val now = System.currentTimeMillis()
                    if (now - lastShakeTime > SHAKE_DEBOUNCE_MS) {
                        lastShakeTime = now
                        runOnUiThread {
                            audioChannel?.invokeMethod("onShake", null)
                        }
                    }
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        sensorManager?.registerListener(
            shakeListener, accelerometer, SensorManager.SENSOR_DELAY_UI
        )
        println("[MainActivity] startShakeDetection: registered")
    }

    private fun stopShakeDetection() {
        shakeListener?.let { sensorManager?.unregisterListener(it) }
        shakeListener = null
        sensorManager = null
        println("[MainActivity] stopShakeDetection: unregistered")
    }

    /** Known browser packages — used to filter out browsers when preferring native apps */
    private val BROWSER_PACKAGES = setOf(
        "com.android.chrome",
        "com.chrome.beta", "com.chrome.dev", "com.chrome.canary",
        "org.mozilla.firefox", "org.mozilla.firefox_beta",
        "com.opera.browser", "com.opera.mini.native",
        "com.microsoft.emmx",
        "com.brave.browser",
        "com.sec.android.app.sbrowser", "com.sec.android.app.sbrowser.lite",
        "com.naver.whale",
        "com.vivaldi.browser",
        "mark.via.gp",
        "com.kiwibrowser.browser",
        "com.duckduckgo.mobile.android",
        "org.chromium.webview_shell",
        "com.UCMobile.intl",
        "com.mi.globalbrowser",
    )

    /**
     * Open a URL, preferring native apps over browsers.
     *
     * Strategy:
     * 1. Query all apps that can handle this URL via ACTION_VIEW
     * 2. If a non-browser app claims to handle it → use that app
     * 3. Else, check hardcoded urlToPackage map → try ACTION_VIEW with package → try just launching the app
     * 4. Final fallback → open in default browser
     */
    private fun openUrlPreferApp(url: String) {
        val viewIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        // Step 1: Query all apps that can handle this URL
        val resolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                viewIntent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(viewIntent, PackageManager.MATCH_DEFAULT_ONLY)
        }

        // Step 2: Find non-browser apps (exclude our own app too)
        val nonBrowserApps = resolved.filter { ri ->
            val pkg = ri.activityInfo.packageName
            pkg != packageName && !BROWSER_PACKAGES.contains(pkg)
        }

        if (nonBrowserApps.isNotEmpty()) {
            val target = nonBrowserApps[0].activityInfo
            val appIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                component = ComponentName(target.packageName, target.name)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                startActivity(appIntent)
                return
            } catch (_: Exception) {}
        }

        // Step 3: Hardcoded fallback — try launching the mapped app
        val pkg = urlToPackage(url)
        if (pkg != null) {
            // 3a: Check if app is installed → launch it directly
            try {
                val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(launchIntent)
                    return
                }
            } catch (_: Exception) {}
        }

        // Step 4: Final fallback — open in browser
        startActivity(viewIntent)
    }

    private fun urlToPackage(url: String): String? {
        val host = Uri.parse(url).host?.lowercase() ?: return null
        return when {
            // Korean apps (specific subdomains first!)
            host.contains("webtoon") || host.contains("comic.naver") -> "com.nhn.android.webtoon"
            host.contains("band.us") || host.contains("band.naver") -> "com.nhn.android.band"
            host.contains("naver.com") || host.contains("naver") -> "com.nhn.android.search"
            host.contains("kakaotalk") || host.contains("kakao.com") || host.contains("kakaocorp.com") -> "com.kakao.talk"
            host.contains("daum.net") -> "net.daum.android.daum"
            host.contains("coupang.com") -> "com.coupang.mobile"
            host.contains("baemin") || host.contains("woowahan") -> "com.baemin"
            host.contains("toss") && !host.contains("github") -> "viva.republica.toss"
            host.contains("danggeun") || host.contains("karrotmarket") || host.contains("daangn") -> "com.towneers.www"
            host.contains("zigbang.com") -> "com.chbreeze.jikbang4a"
            host.contains("melon.com") -> "com.iloen.melon"
            host.contains("bugs.co.kr") -> "com.neowiz.android.bugs"
            host.contains("genie.co.kr") -> "com.ktmusic.geniemusic"
            host.contains("watcha.com") -> "com.frograms.watcha"
            host.contains("wavve.com") -> "com.pooq.player"
            host.contains("tving.com") -> "net.cj.cjhv.gs.tving"
            // Global apps
            host.contains("youtube.com") || host.contains("youtu.be") -> "com.google.android.youtube"
            host.contains("instagram.com") -> "com.instagram.android"
            host.contains("threads.net") -> "com.instagram.barcelona"
            host.contains("twitter.com") || host.contains("x.com") -> "com.twitter.android"
            host.contains("facebook.com") || host.contains("fb.com") -> "com.facebook.katana"
            host.contains("tiktok.com") -> "com.zhiliaoapp.musically"
            host.contains("reddit.com") -> "com.reddit.frontpage"
            host.contains("twitch.tv") -> "tv.twitch.android.app"
            host.contains("discord.com") || host.contains("discord.gg") -> "com.discord"
            host.contains("spotify.com") -> "com.spotify.music"
            host.contains("netflix.com") -> "com.netflix.mediaclient"
            host.contains("whatsapp.com") -> "com.whatsapp"
            host.contains("telegram.org") || host.contains("t.me") -> "org.telegram.messenger"
            host.contains("pinterest.com") || host.contains("pin.it") -> "com.pinterest"
            host.contains("linkedin.com") -> "com.linkedin.android"
            host.contains("google.com") -> "com.google.android.googlequicksearchbox"
            host.contains("github.com") -> "com.github.android"
            else -> null
        }
    }
}

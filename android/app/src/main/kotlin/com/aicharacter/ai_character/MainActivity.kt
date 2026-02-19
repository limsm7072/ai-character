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
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.aicharacter.ai_character/usage_stats"
    private val AUDIO_CHANNEL = "com.aicharacter.ai_character/audio"
    private val SPEECH_CHANNEL = "com.aicharacter.ai_character/speech"
    private val EVENT_CHANNEL = "com.aicharacter.ai_character/distraction_events"
    private var eventSink: EventChannel.EventSink? = null
    private var mediaPlayer: MediaPlayer? = null
    private var alarmPlayer: MediaPlayer? = null
    private var alarmRingtone: android.media.Ringtone? = null
    private var fallbackTone: android.media.ToneGenerator? = null
    private var ambientGenerator: AmbientSoundGenerator? = null
    private var speechResult: MethodChannel.Result? = null
    private var pickImageResult: MethodChannel.Result? = null
    private val PICK_IMAGE_REQUEST = 2001

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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_URL_ERROR", e.message, null)
                    }
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, result ->
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
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> startSpeechRecognition(result)
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

        val filter = IntentFilter("com.aicharacter.DISTRACTION_DETECTED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(distractionReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(distractionReceiver, filter)
        }
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
        ambientGenerator?.stop()
        ambientGenerator = null
        try { unregisterReceiver(distractionReceiver) } catch (_: Exception) {}
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
}

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
import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aicharacter.ai_character/usage_stats"
    private val AUDIO_CHANNEL = "com.aicharacter.ai_character/audio"
    private val SPEECH_CHANNEL = "com.aicharacter.ai_character/speech"
    private val EVENT_CHANNEL = "com.aicharacter.ai_character/distraction_events"
    private var eventSink: EventChannel.EventSink? = null
    private var mediaPlayer: MediaPlayer? = null
    private var speechResult: MethodChannel.Result? = null

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
                "startMonitorService" -> {
                    startMonitorService()
                    result.success(true)
                }
                "stopMonitorService" -> {
                    stopMonitorService()
                    result.success(true)
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

    override fun onDestroy() {
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

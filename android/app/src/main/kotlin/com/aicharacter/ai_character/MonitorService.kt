package com.aicharacter.ai_character

import android.app.*
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class MonitorService : Service() {
    companion object {
        const val CHANNEL_ID = "monitor_channel"
        const val NOTIFICATION_ID = 1
        const val ACTION_START = "START"
        const val ACTION_STOP = "STOP"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var isRunning = false
    private var lastDetectedApp = ""
    private var lastNagTime = 0L
    private var nagOverlay: NagOverlay? = null

    // Distraction tracking
    private var currentDistractionStart = 0L
    private var currentDistractionApp = ""
    private var currentDistractionAppLabel = ""
    private var currentRoutineId = ""
    private var currentRoutineName = ""

    private val checkRunnable = object : Runnable {
        override fun run() {
            if (isRunning) {
                checkForegroundApp()
                val interval = getCheckInterval()
                handler.postDelayed(this, interval)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        nagOverlay = NagOverlay(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                endCurrentDistraction()
                stopSelf()
                return START_NOT_STICKY
            }
        }

        val notification = buildNotification("루틴 모니터링 중...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        isRunning = true
        handler.post(checkRunnable)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacks(checkRunnable)
        endCurrentDistraction()
        nagOverlay?.dismiss()
        super.onDestroy()
    }

    private fun getNagCooldownMs(): Long {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val seconds = try { prefs.getLong("flutter.nag_frequency", 30L) } catch (_: Exception) { 30L }
        return seconds * 1000L
    }

    private fun getNagIntensity(): Int {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val intensity = try { prefs.getLong("flutter.nag_intensity", 1L).toInt() } catch (e: Exception) {
            android.util.Log.w("MonitorService", "getNagIntensity getLong failed: $e, trying getInt")
            try { prefs.getInt("flutter.nag_intensity", 1) } catch (_: Exception) { 1 }
        }
        android.util.Log.d("MonitorService", "getNagIntensity=$intensity")
        return intensity
    }

    private fun getCheckInterval(): Long {
        val cooldown = getNagCooldownMs()
        return if (cooldown < 3000) 1500L else 3000L
    }

    private fun getApiKey(): String {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getString("flutter.gemini_api_key", "") ?: ""
    }

    private fun checkForegroundApp() {
        // If overlay is showing (voice conversation active), skip detection
        // Speech recognizer changes foreground app to Google, which would falsely dismiss
        if (nagOverlay?.isShowing == true) return

        val foregroundApp = getForegroundApp()
        if (foregroundApp.isEmpty() || foregroundApp == packageName) {
            endCurrentDistraction()
            lastDetectedApp = ""
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) return

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val routinesJson = prefs.getString("flutter.routines", null) ?: run {
            endCurrentDistraction()
            return
        }

        val activeRoutine = findActiveRoutine(routinesJson) ?: run {
            endCurrentDistraction()
            return
        }

        val routineId = activeRoutine.optString("id", "")
        val routineName = activeRoutine.optString("name", "루틴")

        val blockedApps = activeRoutine.optJSONArray("blockedApps") ?: JSONArray()
        val isBlocked = if (blockedApps.length() == 0) {
            true
        } else {
            (0 until blockedApps.length()).any { blockedApps.getString(it) == foregroundApp }
        }

        if (isBlocked) {
            val appLabel = getAppLabel(foregroundApp)

            // Distraction tracking
            if (foregroundApp != currentDistractionApp || currentDistractionStart == 0L) {
                if (currentDistractionStart > 0 && foregroundApp != currentDistractionApp) {
                    endCurrentDistraction()
                }
                if (currentDistractionStart == 0L) {
                    currentDistractionStart = System.currentTimeMillis()
                    currentDistractionApp = foregroundApp
                    currentDistractionAppLabel = appLabel
                    currentRoutineId = routineId
                    currentRoutineName = routineName
                }
            }

            // Show nag with cooldown
            if (foregroundApp != lastDetectedApp) {
                val now = System.currentTimeMillis()
                val cooldown = getNagCooldownMs()
                if (now - lastNagTime >= cooldown) {
                    lastNagTime = now
                    lastDetectedApp = foregroundApp

                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    nm.notify(NOTIFICATION_ID, buildNotification("$appLabel 감지! 잔소리 중..."))

                    val apiKey = getApiKey()
                    val intensity = getNagIntensity()
                    nagOverlay?.show(appLabel, routineName, apiKey, intensity)
                }
            }
        } else {
            endCurrentDistraction()
            lastDetectedApp = ""
        }
    }

    private fun endCurrentDistraction() {
        if (currentDistractionStart > 0 && currentDistractionApp.isNotEmpty()) {
            val endTime = System.currentTimeMillis()
            val duration = endTime - currentDistractionStart
            if (duration > 3000) {
                saveDistractionLog(
                    routineId = currentRoutineId,
                    routineName = currentRoutineName,
                    appPackage = currentDistractionApp,
                    appLabel = currentDistractionAppLabel,
                    startTime = currentDistractionStart,
                    endTime = endTime
                )
            }
            currentDistractionStart = 0L
            currentDistractionApp = ""
            currentDistractionAppLabel = ""
            currentRoutineId = ""
            currentRoutineName = ""
        }
    }

    private fun saveDistractionLog(
        routineId: String, routineName: String,
        appPackage: String, appLabel: String,
        startTime: Long, endTime: Long
    ) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val existingJson = prefs.getString("flutter.distraction_logs", null)
            val logs = if (existingJson != null) JSONArray(existingJson) else JSONArray()
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())

            logs.put(JSONObject().apply {
                put("routineId", routineId)
                put("routineName", routineName)
                put("appPackage", appPackage)
                put("appLabel", appLabel)
                put("startTime", startTime)
                put("endTime", endTime)
                put("date", dateFormat.format(Date(startTime)))
            })
            prefs.edit().putString("flutter.distraction_logs", logs.toString()).apply()
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun findActiveRoutine(routinesJson: String): JSONObject? {
        try {
            val routines = JSONArray(routinesJson)
            val now = Calendar.getInstance()
            val dayIndex = (now.get(Calendar.DAY_OF_WEEK) + 5) % 7
            val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)

            for (i in 0 until routines.length()) {
                val routine = routines.getJSONObject(i)
                if (!routine.optBoolean("isEnabled", true)) continue
                val activeDays = routine.optJSONArray("activeDays")
                if (activeDays != null && !activeDays.optBoolean(dayIndex, true)) continue
                val startMinutes = routine.optInt("startHour", 0) * 60 + routine.optInt("startMinute", 0)
                val endMinutes = routine.optInt("endHour", 0) * 60 + routine.optInt("endMinute", 0)
                val isActive = if (startMinutes <= endMinutes) {
                    nowMinutes in startMinutes..endMinutes
                } else {
                    nowMinutes >= startMinutes || nowMinutes <= endMinutes
                }
                if (isActive) return routine
            }
        } catch (e: Exception) { e.printStackTrace() }
        return null
    }

    private fun getForegroundApp(): String {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return ""
        val end = System.currentTimeMillis()
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, end - 5000, end)
        if (stats.isNullOrEmpty()) return ""
        var app = ""; var time = 0L
        for (s in stats) { if (s.lastTimeUsed > time) { time = s.lastTimeUsed; app = s.packageName } }
        return app
    }

    private fun getAppLabel(pkg: String): String {
        return try {
            val pm = applicationContext.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (_: PackageManager.NameNotFoundException) { pkg }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "루틴 모니터링", NotificationManager.IMPORTANCE_LOW).apply {
                description = "루틴 시간 앱 사용 감시"
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val pi = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AI 루틴 잔소리")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }
}

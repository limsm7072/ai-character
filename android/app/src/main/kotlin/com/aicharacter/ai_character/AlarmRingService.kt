package com.aicharacter.ai_character

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.*
import androidx.core.app.NotificationCompat

class AlarmRingService : Service() {
    companion object {
        const val CHANNEL_ID = "alarm_ring_channel"
        const val NOTIFICATION_ID = 9999
        private const val MAX_RING_MS = 5 * 60 * 1000L // 5 minutes
    }

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val alarmId = intent?.getStringExtra(AlarmReceiver.EXTRA_ALARM_ID) ?: ""
        val label = intent?.getStringExtra(AlarmReceiver.EXTRA_ALARM_LABEL) ?: "알람"

        // Full-screen intent to bring app to foreground
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("from_alarm", true)
            putExtra("alarm_id", alarmId)
            putExtra("alarm_label", label)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val fullScreenPi = PendingIntent.getActivity(
            this, 0, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Dismiss action
        val dismissIntent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_DISMISS
        }
        val dismissPi = PendingIntent.getBroadcast(
            this, 1, dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("알람")
            .setContentText(label)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(fullScreenPi, true)
            .setContentIntent(fullScreenPi)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "끄기", dismissPi)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        playAlarmSound()
        startVibration()

        // Auto-stop after 5 minutes
        handler.postDelayed({ stopSelf() }, MAX_RING_MS)

        println("[AlarmRingService] started: alarmId=$alarmId label=$label")
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "알람 울림",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "알람이 울릴 때 표시됩니다"
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null) // We play sound via MediaPlayer
                enableVibration(false) // We handle vibration ourselves
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun playAlarmSound() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

            mediaPlayer = MediaPlayer().apply {
                setDataSource(this@AlarmRingService, uri!!)
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
            println("[AlarmRingService] playAlarmSound: OK")
        } catch (e: Exception) {
            println("[AlarmRingService] playAlarmSound error: $e")
        }
    }

    private fun startVibration() {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = longArrayOf(0, 500, 300, 500)
        vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {}
        mediaPlayer = null
        vibrator?.cancel()
        vibrator = null
        println("[AlarmRingService] destroyed")
        super.onDestroy()
    }
}

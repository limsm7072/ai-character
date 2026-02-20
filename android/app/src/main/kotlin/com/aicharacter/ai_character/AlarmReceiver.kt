package com.aicharacter.ai_character

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_RING = "com.aicharacter.ALARM_RING"
        const val ACTION_DISMISS = "com.aicharacter.ALARM_DISMISS"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_ALARM_LABEL = "alarm_label"
        const val EXTRA_REQUEST_CODE = "request_code"
        const val EXTRA_REPEATING = "repeating"
        private const val PREFS_NAME = "native_alarm_schedules"

        fun scheduleAlarm(context: Context, requestCode: Int, timeMillis: Long, alarmId: String, label: String, repeating: Boolean) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_RING
                putExtra(EXTRA_ALARM_ID, alarmId)
                putExtra(EXTRA_ALARM_LABEL, label)
                putExtra(EXTRA_REQUEST_CODE, requestCode)
                putExtra(EXTRA_REPEATING, repeating)
            }
            val pi = PendingIntent.getBroadcast(
                context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(timeMillis, pi),
                pi
            )
            storeAlarm(context, requestCode, timeMillis, alarmId, label, repeating)
            println("[AlarmReceiver] scheduled: code=$requestCode time=$timeMillis label=$label repeating=$repeating")
        }

        fun cancelAlarm(context: Context, requestCode: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_RING
            }
            val pi = PendingIntent.getBroadcast(
                context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pi)
            removeStoredAlarm(context, requestCode)
            println("[AlarmReceiver] cancelled: code=$requestCode")
        }

        private fun storeAlarm(context: Context, requestCode: Int, timeMillis: Long, alarmId: String, label: String, repeating: Boolean) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val allData = prefs.getString("alarms", null)
            val json = if (allData != null) JSONObject(allData) else JSONObject()
            json.put(requestCode.toString(), JSONObject().apply {
                put("timeMillis", timeMillis)
                put("alarmId", alarmId)
                put("label", label)
                put("repeating", repeating)
            })
            prefs.edit().putString("alarms", json.toString()).apply()
        }

        fun removeStoredAlarm(context: Context, requestCode: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val allData = prefs.getString("alarms", null) ?: return
            try {
                val json = JSONObject(allData)
                json.remove(requestCode.toString())
                prefs.edit().putString("alarms", json.toString()).apply()
            } catch (_: Exception) {}
        }

        fun rescheduleAll(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val allData = prefs.getString("alarms", null) ?: return
            try {
                val json = JSONObject(allData)
                val keys = json.keys()
                val now = System.currentTimeMillis()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val obj = json.getJSONObject(key)
                    val requestCode = key.toIntOrNull() ?: continue
                    var timeMillis = obj.getLong("timeMillis")
                    val alarmId = obj.getString("alarmId")
                    val label = obj.getString("label")
                    val repeating = obj.optBoolean("repeating", false)
                    if (timeMillis <= now) {
                        if (repeating) {
                            while (timeMillis <= now) {
                                timeMillis += 7 * 24 * 60 * 60 * 1000L
                            }
                        } else {
                            continue
                        }
                    }
                    scheduleAlarm(context, requestCode, timeMillis, alarmId, label, repeating)
                }
                println("[AlarmReceiver] rescheduleAll: done")
            } catch (e: Exception) {
                println("[AlarmReceiver] rescheduleAll error: $e")
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_DISMISS -> {
                context.stopService(Intent(context, AlarmRingService::class.java))
            }
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "android.intent.action.MY_PACKAGE_REPLACED" -> {
                rescheduleAll(context)
            }
            ACTION_RING -> {
                val alarmId = intent.getStringExtra(EXTRA_ALARM_ID) ?: return
                val label = intent.getStringExtra(EXTRA_ALARM_LABEL) ?: "알람"
                val requestCode = intent.getIntExtra(EXTRA_REQUEST_CODE, 0)
                val repeating = intent.getBooleanExtra(EXTRA_REPEATING, false)

                // Start alarm ringing service (sound + vibration + notification)
                val serviceIntent = Intent(context, AlarmRingService::class.java).apply {
                    putExtra(EXTRA_ALARM_ID, alarmId)
                    putExtra(EXTRA_ALARM_LABEL, label)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }

                // Directly launch MainActivity to show alarm screen
                // (fullScreenIntent on notification may not launch activity on Android 10+)
                try {
                    val launchIntent = Intent(context, MainActivity::class.java).apply {
                        putExtra("from_alarm", true)
                        putExtra("alarm_id", alarmId)
                        putExtra("alarm_label", label)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                    context.startActivity(launchIntent)
                } catch (e: Exception) {
                    println("[AlarmReceiver] failed to launch activity: $e")
                }

                // Reschedule for next week if repeating
                if (repeating) {
                    val nextWeekMillis = System.currentTimeMillis() + 7 * 24 * 60 * 60 * 1000L
                    scheduleAlarm(context, requestCode, nextWeekMillis, alarmId, label, true)
                } else {
                    removeStoredAlarm(context, requestCode)
                }
            }
        }
    }
}

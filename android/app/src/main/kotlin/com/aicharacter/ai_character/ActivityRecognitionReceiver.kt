package com.aicharacter.ai_character

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import com.google.android.gms.location.ActivityTransitionResult
import org.json.JSONArray
import org.json.JSONObject

class ActivityRecognitionReceiver : BroadcastReceiver() {
    companion object {
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val KEY = "flutter.activity_log"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (!ActivityTransitionResult.hasResult(intent)) return
        val result = ActivityTransitionResult.extractResult(intent) ?: return

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = try {
            JSONArray(prefs.getString(KEY, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }

        for (event in result.transitionEvents) {
            val entry = JSONObject().apply {
                put("type", activityTypeToString(event.activityType))
                put("transition", if (event.transitionType == 0) "ENTER" else "EXIT")
                put("timestamp", System.currentTimeMillis())
            }
            existing.put(entry)
        }

        // Trim to 7 days
        val cutoff = System.currentTimeMillis() - 7 * 24 * 3600 * 1000L
        val trimmed = JSONArray()
        for (i in 0 until existing.length()) {
            val obj = existing.optJSONObject(i) ?: continue
            if (obj.optLong("timestamp", 0) >= cutoff) {
                trimmed.put(obj)
            }
        }

        prefs.edit().putString(KEY, trimmed.toString()).apply()
    }

    private fun activityTypeToString(type: Int): String {
        return when (type) {
            0 -> "vehicle"   // IN_VEHICLE
            1 -> "cycling"   // ON_BICYCLE
            2 -> "still"     // ON_FOOT (treat as still/walking)
            3 -> "still"     // STILL
            5 -> "still"     // TILTING
            7 -> "walking"   // WALKING
            8 -> "running"   // RUNNING
            else -> "unknown"
        }
    }
}

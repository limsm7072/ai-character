package com.aicharacter.ai_character

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Listens for Naver app notifications related to reservations.
 * When a reservation notification is detected:
 * 1. Saves to SharedPreferences (for Flutter to poll)
 * 2. Sends a broadcast (for real-time EventChannel delivery)
 */
class NaverNotificationService : NotificationListenerService() {

    companion object {
        private const val TAG = "NaverNotifService"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PENDING_KEY = "flutter.naver_pending_notifications"
        const val ACTION_RESERVATION_DETECTED = "com.aicharacter.NAVER_RESERVATION_DETECTED"

        val NAVER_PACKAGES = setOf(
            "com.nhn.android.search",   // 네이버 앱
            "com.nhn.android.nmap",     // 네이버 지도
        )

        private val RESERVATION_KEYWORDS = listOf(
            "예약", "예약 확정", "예약 완료", "예약 접수",
            "예약이 취소", "방문 예정", "체크인", "숙박",
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val pkg = sbn.packageName ?: return
        if (pkg !in NAVER_PACKAGES) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getString("android.title") ?: ""
        val text = extras.getString("android.text") ?: ""
        val bigText = extras.getString("android.bigText") ?: ""

        val combined = "$title $text $bigText"
        if (!isReservationRelated(combined)) return

        Log.d(TAG, "Reservation notification detected: title=$title, text=$text")

        // 1. Save to SharedPreferences for Flutter polling
        savePending(title, text, bigText)

        // 2. Send broadcast for real-time delivery
        val intent = Intent(ACTION_RESERVATION_DETECTED).apply {
            setPackage(packageName)
            putExtra("title", title)
            putExtra("text", text)
            putExtra("bigText", bigText)
            putExtra("timestamp", System.currentTimeMillis())
        }
        sendBroadcast(intent)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // No action needed
    }

    private fun isReservationRelated(text: String): Boolean {
        return RESERVATION_KEYWORDS.any { text.contains(it) }
    }

    private fun savePending(title: String, text: String, bigText: String) {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            val raw = prefs.getString(PENDING_KEY, "[]") ?: "[]"
            val arr = try { JSONArray(raw) } catch (_: Exception) { JSONArray() }

            arr.put(JSONObject().apply {
                put("title", title)
                put("text", text)
                put("bigText", bigText)
                put("timestamp", System.currentTimeMillis())
            })

            prefs.edit().putString(PENDING_KEY, arr.toString()).apply()
            Log.d(TAG, "Saved pending notification (total: ${arr.length()})")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save pending notification", e)
        }
    }
}

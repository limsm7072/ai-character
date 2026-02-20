package com.aicharacter.ai_character

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

object WidgetDataHelper {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"

    /**
     * Try multiple SharedPreferences files to find where Flutter stores data.
     * Returns the first one that contains any "flutter." keys.
     */
    private fun getPrefs(context: Context): SharedPreferences {
        val ctx = context.applicationContext

        // 1st: Standard Flutter SharedPreferences file
        val flutterPrefs = ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        if (flutterPrefs.all.any { it.key.startsWith("flutter.") }) {
            return flutterPrefs
        }

        // 2nd: Default Android SharedPreferences (package_name_preferences)
        val defaultPrefs = ctx.getSharedPreferences("${ctx.packageName}_preferences", Context.MODE_PRIVATE)
        if (defaultPrefs.all.any { it.key.startsWith("flutter.") }) {
            println("[WidgetDataHelper] found flutter keys in DEFAULT prefs!")
            return defaultPrefs
        }

        // 3rd: Try app-specific named SharedPreferences
        val pkgPrefs = ctx.getSharedPreferences("${ctx.packageName}_preferences", Context.MODE_PRIVATE)
        if (pkgPrefs.all.any { it.key.startsWith("flutter.") }) {
            println("[WidgetDataHelper] found flutter keys in package-named prefs!")
            return pkgPrefs
        }

        // Fallback: return the standard file even if empty
        println("[WidgetDataHelper] WARNING: no flutter keys found in any SharedPreferences!")
        return flutterPrefs
    }

    /** Debug: dump all SharedPreferences info */
    fun debugDumpKeys(context: Context): String {
        val ctx = context.applicationContext
        val sb = StringBuilder()

        val files = listOf(
            FLUTTER_PREFS to ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE),
            "${ctx.packageName}_preferences" to ctx.getSharedPreferences("${ctx.packageName}_preferences", Context.MODE_PRIVATE),
        )

        for ((name, prefs) in files) {
            val all = prefs.all
            sb.append("[$name] ${all.size} keys")
            val flutterKeys = all.keys.filter { it.startsWith("flutter.") }
            sb.append(", flutter keys: ${flutterKeys.size}\n")
            for (key in flutterKeys.take(10)) {
                val v = all[key]?.toString() ?: "null"
                val preview = if (v.length > 80) v.substring(0, 80) + "..." else v
                sb.append("  $key: $preview\n")
            }
        }

        return sb.toString()
    }

    // ─── Routine ────────────────────────────────

    data class RoutineItem(
        val id: String,
        val name: String,
        val startHour: Int,
        val startMinute: Int,
        val endHour: Int,
        val endMinute: Int,
        val isAllDay: Boolean,
        val isCompleted: Boolean
    ) {
        val timeText: String
            get() = if (isAllDay) "종일"
            else "${startHour.toString().padStart(2, '0')}:${startMinute.toString().padStart(2, '0')} - ${endHour.toString().padStart(2, '0')}:${endMinute.toString().padStart(2, '0')}"
    }

    fun getTodayRoutines(context: Context): List<RoutineItem> {
        try {
            val prefs = getPrefs(context)
            val routinesJson = prefs.getString("flutter.routines", null)
            if (routinesJson == null) {
                println("[WidgetDataHelper] getTodayRoutines: routines is NULL")
                return emptyList()
            }

            val completionsJson = prefs.getString("flutter.routine_completions", null)
            val today = todayString()
            val dayIndex = todayDayIndex()

            val completedIds = mutableSetOf<String>()
            if (completionsJson != null) {
                val arr = JSONArray(completionsJson)
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    if (obj.optString("date") == today && obj.optString("status") == "completed") {
                        completedIds.add(obj.optString("routineId"))
                    }
                }
            }

            val arr = JSONArray(routinesJson)
            val result = mutableListOf<RoutineItem>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (!obj.optBoolean("isEnabled", true)) continue

                val activeDaysArr = obj.optJSONArray("activeDays")
                if (activeDaysArr != null && !activeDaysArr.optBoolean(dayIndex, true)) continue

                val startDate = obj.optString("startDate", "")
                if (startDate.isNotEmpty() && startDate != "null" && startDate > today) continue

                val id = obj.optString("id")
                result.add(
                    RoutineItem(
                        id = id,
                        name = obj.optString("name"),
                        startHour = obj.optInt("startHour"),
                        startMinute = obj.optInt("startMinute"),
                        endHour = obj.optInt("endHour"),
                        endMinute = obj.optInt("endMinute"),
                        isAllDay = obj.optBoolean("isAllDay", false),
                        isCompleted = completedIds.contains(id)
                    )
                )
            }
            println("[WidgetDataHelper] getTodayRoutines: ${result.size} items")
            return result
        } catch (e: Exception) {
            println("[WidgetDataHelper] getTodayRoutines ERROR: $e")
            return emptyList()
        }
    }

    fun toggleRoutineCompletion(context: Context, routineId: String) {
        try {
            val prefs = getPrefs(context)
            val today = todayString()
            val raw = prefs.getString("flutter.routine_completions", null)
            val arr = if (raw != null) JSONArray(raw) else JSONArray()

            var foundIdx = -1
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optString("routineId") == routineId &&
                    obj.optString("date") == today &&
                    obj.optString("status") == "completed"
                ) {
                    foundIdx = i
                    break
                }
            }

            if (foundIdx >= 0) {
                arr.remove(foundIdx)
            } else {
                arr.put(JSONObject().apply {
                    put("routineId", routineId)
                    put("date", today)
                    put("completedAt", System.currentTimeMillis())
                    put("status", "completed")
                })
            }

            prefs.edit().putString("flutter.routine_completions", arr.toString()).apply()
        } catch (e: Exception) {
            println("[WidgetDataHelper] toggleRoutineCompletion ERROR: $e")
        }
    }

    // ─── Bookmark ───────────────────────────────

    data class BookmarkItem(
        val id: String,
        val name: String,
        val url: String,
        val faviconUrl: String?,
        val order: Int
    )

    fun getBookmarks(context: Context): List<BookmarkItem> {
        try {
            val prefs = getPrefs(context)
            val raw = prefs.getString("flutter.bookmarks", null)
            if (raw == null) {
                println("[WidgetDataHelper] getBookmarks: NULL")
                return emptyList()
            }

            val arr = JSONArray(raw)
            val result = mutableListOf<BookmarkItem>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val favicon = obj.optString("faviconUrl", "")
                result.add(
                    BookmarkItem(
                        id = obj.optString("id"),
                        name = obj.optString("name"),
                        url = obj.optString("url"),
                        faviconUrl = if (favicon.isEmpty() || favicon == "null") null else favicon,
                        order = obj.optInt("order", i)
                    )
                )
            }
            println("[WidgetDataHelper] getBookmarks: ${result.size} items")
            return result.sortedBy { it.order }
        } catch (e: Exception) {
            println("[WidgetDataHelper] getBookmarks ERROR: $e")
            return emptyList()
        }
    }

    // ─── Todo ───────────────────────────────────

    data class TodoItem(
        val id: String,
        val title: String,
        val isCompleted: Boolean,
        val dueDate: String?
    )

    fun getIncompleteTodos(context: Context): List<TodoItem> {
        try {
            val prefs = getPrefs(context)
            val raw = prefs.getString("flutter.todos", null)
            if (raw == null) {
                println("[WidgetDataHelper] getIncompleteTodos: NULL")
                return emptyList()
            }

            val arr = JSONArray(raw)
            val result = mutableListOf<TodoItem>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optBoolean("isCompleted", false)) continue
                val dueDate = obj.optString("dueDate", "")
                result.add(
                    TodoItem(
                        id = obj.optString("id"),
                        title = obj.optString("title"),
                        isCompleted = false,
                        dueDate = if (dueDate.isEmpty() || dueDate == "null") null else dueDate
                    )
                )
            }
            println("[WidgetDataHelper] getIncompleteTodos: ${result.size} items")
            return result
        } catch (e: Exception) {
            println("[WidgetDataHelper] getIncompleteTodos ERROR: $e")
            return emptyList()
        }
    }

    fun toggleTodoCompletion(context: Context, todoId: String) {
        try {
            val prefs = getPrefs(context)
            val raw = prefs.getString("flutter.todos", null) ?: return
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optString("id") == todoId) {
                    val wasCompleted = obj.optBoolean("isCompleted", false)
                    obj.put("isCompleted", !wasCompleted)
                    if (!wasCompleted) {
                        obj.put("completedAt", System.currentTimeMillis())
                    } else {
                        obj.remove("completedAt")
                    }
                    break
                }
            }
            prefs.edit().putString("flutter.todos", arr.toString()).apply()
        } catch (e: Exception) {
            println("[WidgetDataHelper] toggleTodoCompletion ERROR: $e")
        }
    }

    // ─── Memo ───────────────────────────────────

    data class MemoItem(
        val id: String,
        val title: String,
        val content: String,
        val updatedAt: Long
    ) {
        val preview: String
            get() {
                val text = content.replace("\n", " ").trim()
                return if (text.length > 80) text.substring(0, 80) + "..." else text
            }
    }

    fun getRecentMemos(context: Context, limit: Int = 10): List<MemoItem> {
        try {
            val prefs = getPrefs(context)
            val raw = prefs.getString("flutter.memos", null)
            if (raw == null) {
                println("[WidgetDataHelper] getRecentMemos: NULL")
                return emptyList()
            }

            val arr = JSONArray(raw)
            val result = mutableListOf<MemoItem>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                result.add(
                    MemoItem(
                        id = obj.optString("id"),
                        title = obj.optString("title"),
                        content = obj.optString("content", ""),
                        updatedAt = obj.optLong("updatedAt", 0)
                    )
                )
            }
            println("[WidgetDataHelper] getRecentMemos: ${result.size} items")
            return result.sortedByDescending { it.updatedAt }.take(limit)
        } catch (e: Exception) {
            println("[WidgetDataHelper] getRecentMemos ERROR: $e")
            return emptyList()
        }
    }

    // ─── Helpers ────────────────────────────────

    private fun todayString(): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        return sdf.format(Date())
    }

    private fun todayDayIndex(): Int {
        val cal = Calendar.getInstance()
        return when (cal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 0
            Calendar.TUESDAY -> 1
            Calendar.WEDNESDAY -> 2
            Calendar.THURSDAY -> 3
            Calendar.FRIDAY -> 4
            Calendar.SATURDAY -> 5
            Calendar.SUNDAY -> 6
            else -> 0
        }
    }
}

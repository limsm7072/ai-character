package com.aicharacter.ai_character

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class RoutineWidgetProvider : AppWidgetProvider() {
    companion object {
        const val ACTION_TOGGLE = "com.aicharacter.WIDGET_ROUTINE_TOGGLE"
        const val EXTRA_ROUTINE_ID = "routine_id"

        fun updateAllWidgets(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, RoutineWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                val intent = Intent(context, RoutineWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                context.sendBroadcast(intent)
            }
        }
    }

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            updateWidget(context, mgr, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TOGGLE) {
            val routineId = intent.getStringExtra(EXTRA_ROUTINE_ID) ?: return
            WidgetDataHelper.toggleRoutineCompletion(context, routineId)
            updateAllWidgets(context)
        }
    }

    private fun updateWidget(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        println("[RoutineWidget] updateWidget id=$widgetId")
        println(WidgetDataHelper.debugDumpKeys(context))
        val views = RemoteViews(context.packageName, R.layout.widget_routine)

        // ListView adapter
        val serviceIntent = Intent(context, RoutineWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.routine_list, serviceIntent)
        views.setEmptyView(R.id.routine_list, R.id.routine_empty)

        // Count text
        val routines = WidgetDataHelper.getTodayRoutines(context)
        val doneCount = routines.count { it.isCompleted }
        views.setTextViewText(R.id.routine_count, "$doneCount/${routines.size}")

        // Template for list item clicks
        val toggleIntent = Intent(context, RoutineWidgetProvider::class.java).apply {
            action = ACTION_TOGGLE
        }
        val togglePI = PendingIntent.getBroadcast(
            context, 0, toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        views.setPendingIntentTemplate(R.id.routine_list, togglePI)

        // Header opens app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            val launchPI = PendingIntent.getActivity(
                context, 100, launchIntent, PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_header, launchPI)
        }

        mgr.updateAppWidget(widgetId, views)
        mgr.notifyAppWidgetViewDataChanged(widgetId, R.id.routine_list)
    }
}

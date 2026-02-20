package com.aicharacter.ai_character

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class TodoWidgetProvider : AppWidgetProvider() {
    companion object {
        const val ACTION_TOGGLE = "com.aicharacter.WIDGET_TODO_TOGGLE"
        const val EXTRA_TODO_ID = "todo_id"

        fun updateAllWidgets(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, TodoWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                val intent = Intent(context, TodoWidgetProvider::class.java).apply {
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
            val todoId = intent.getStringExtra(EXTRA_TODO_ID) ?: return
            WidgetDataHelper.toggleTodoCompletion(context, todoId)
            updateAllWidgets(context)
        }
    }

    private fun updateWidget(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_todo)

        // ListView adapter
        val serviceIntent = Intent(context, TodoWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.todo_list, serviceIntent)
        views.setEmptyView(R.id.todo_list, R.id.todo_empty)

        // Count text
        val todos = WidgetDataHelper.getIncompleteTodos(context)
        views.setTextViewText(R.id.todo_count, "${todos.size}개")

        // Template for list item clicks
        val toggleIntent = Intent(context, TodoWidgetProvider::class.java).apply {
            action = ACTION_TOGGLE
        }
        val togglePI = PendingIntent.getBroadcast(
            context, 0, toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        views.setPendingIntentTemplate(R.id.todo_list, togglePI)

        // Header opens app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            val launchPI = PendingIntent.getActivity(
                context, 102, launchIntent, PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_header, launchPI)
        }

        mgr.updateAppWidget(widgetId, views)
        mgr.notifyAppWidgetViewDataChanged(widgetId, R.id.todo_list)
    }
}

package com.aicharacter.ai_character

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class MemoWidgetProvider : AppWidgetProvider() {
    companion object {
        fun updateAllWidgets(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, MemoWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                val intent = Intent(context, MemoWidgetProvider::class.java).apply {
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

    private fun updateWidget(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_memo)

        // ListView adapter
        val serviceIntent = Intent(context, MemoWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.memo_list, serviceIntent)
        views.setEmptyView(R.id.memo_list, R.id.memo_empty)

        // Count
        val memos = WidgetDataHelper.getRecentMemos(context)
        views.setTextViewText(R.id.memo_count, "${memos.size}개")

        // List item click opens app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            val launchPI = PendingIntent.getActivity(
                context, 103, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.memo_list, launchPI)
            views.setOnClickPendingIntent(R.id.widget_header, launchPI)
        }

        mgr.updateAppWidget(widgetId, views)
        mgr.notifyAppWidgetViewDataChanged(widgetId, R.id.memo_list)
    }
}

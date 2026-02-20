package com.aicharacter.ai_character

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class RoutineWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return RoutineRemoteViewsFactory(applicationContext)
    }
}

class RoutineRemoteViewsFactory(
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<WidgetDataHelper.RoutineItem> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items = WidgetDataHelper.getTodayRoutines(context)
    }

    override fun onDestroy() {}
    override fun getCount() = items.size
    override fun getViewTypeCount() = 1
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = false
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_routine_item)
        if (position >= items.size) return views

        val item = items[position]
        views.setTextViewText(R.id.routine_name, item.name)
        views.setTextViewText(R.id.routine_time, item.timeText)

        val checkboxRes = if (item.isCompleted) R.drawable.widget_checkbox_checked
        else R.drawable.widget_checkbox_unchecked
        views.setImageViewResource(R.id.routine_checkbox, checkboxRes)

        val alpha = if (item.isCompleted) 0.5f else 1.0f
        views.setFloat(R.id.routine_name, "setAlpha", alpha)
        views.setFloat(R.id.routine_time, "setAlpha", alpha)

        val fillIntent = Intent().apply {
            putExtra(RoutineWidgetProvider.EXTRA_ROUTINE_ID, item.id)
        }
        views.setOnClickFillInIntent(R.id.routine_item_root, fillIntent)

        return views
    }
}

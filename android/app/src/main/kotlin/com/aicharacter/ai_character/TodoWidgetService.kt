package com.aicharacter.ai_character

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class TodoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TodoRemoteViewsFactory(applicationContext)
    }
}

class TodoRemoteViewsFactory(
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<WidgetDataHelper.TodoItem> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items = WidgetDataHelper.getIncompleteTodos(context)
    }

    override fun onDestroy() {}
    override fun getCount() = items.size
    override fun getViewTypeCount() = 1
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = false
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_todo_item)
        if (position >= items.size) return views

        val item = items[position]
        views.setTextViewText(R.id.todo_title, item.title)
        views.setImageViewResource(R.id.todo_checkbox, R.drawable.widget_checkbox_unchecked)

        // Show due date if present
        if (item.dueDate != null) {
            val parts = item.dueDate.split("-")
            if (parts.size == 3) {
                val display = "${parts[1].toInt()}/${parts[2].toInt()}"
                views.setTextViewText(R.id.todo_due, display)
                views.setViewVisibility(R.id.todo_due, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.todo_due, android.view.View.GONE)
            }
        } else {
            views.setViewVisibility(R.id.todo_due, android.view.View.GONE)
        }

        val fillIntent = Intent().apply {
            putExtra(TodoWidgetProvider.EXTRA_TODO_ID, item.id)
        }
        views.setOnClickFillInIntent(R.id.todo_item_root, fillIntent)

        return views
    }
}

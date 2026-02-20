package com.aicharacter.ai_character

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class MemoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MemoRemoteViewsFactory(applicationContext)
    }
}

class MemoRemoteViewsFactory(
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<WidgetDataHelper.MemoItem> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items = WidgetDataHelper.getRecentMemos(context)
    }

    override fun onDestroy() {}
    override fun getCount() = items.size
    override fun getViewTypeCount() = 1
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = false
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_memo_item)
        if (position >= items.size) return views

        val item = items[position]
        views.setTextViewText(R.id.memo_title, item.title)
        views.setTextViewText(R.id.memo_preview, item.preview)

        // Click opens app
        val fillIntent = Intent()
        views.setOnClickFillInIntent(R.id.memo_item_root, fillIntent)

        return views
    }
}

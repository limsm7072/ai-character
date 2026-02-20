package com.aicharacter.ai_character

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews

class BookmarkWidgetProvider : AppWidgetProvider() {
    companion object {
        const val ACTION_OPEN_URL = "com.aicharacter.WIDGET_BOOKMARK_OPEN"
        const val EXTRA_URL = "bookmark_url"

        fun updateAllWidgets(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, BookmarkWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                val intent = Intent(context, BookmarkWidgetProvider::class.java).apply {
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
        if (intent.action == ACTION_OPEN_URL) {
            val url = intent.getStringExtra(EXTRA_URL) ?: return
            openUrlWithApp(context, url)
        }
    }

    private fun openUrlWithApp(context: Context, url: String) {
        val viewIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        // Step 1: Find non-browser apps that can handle this URL
        val resolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.queryIntentActivities(
                viewIntent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.queryIntentActivities(viewIntent, PackageManager.MATCH_DEFAULT_ONLY)
        }

        val browsers = setOf(
            "com.android.chrome", "com.chrome.beta", "com.chrome.dev",
            "org.mozilla.firefox", "com.opera.browser", "com.opera.mini.native",
            "com.microsoft.emmx", "com.brave.browser",
            "com.sec.android.app.sbrowser", "com.sec.android.app.sbrowser.lite",
            "com.naver.whale", "com.vivaldi.browser", "mark.via.gp",
            "com.kiwibrowser.browser", "com.duckduckgo.mobile.android",
        )
        val nonBrowser = resolved.filter { ri ->
            val pkg = ri.activityInfo.packageName
            pkg != context.packageName && !browsers.contains(pkg)
        }

        if (nonBrowser.isNotEmpty()) {
            try {
                val target = nonBrowser[0].activityInfo
                val appIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                    component = android.content.ComponentName(target.packageName, target.name)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(appIntent)
                return
            } catch (_: Exception) {}
        }

        // Step 2: Hardcoded fallback
        val host = Uri.parse(url).host?.lowercase()
        val pkg = if (host != null) urlToPackage(host) else null
        if (pkg != null) {
            try {
                val pkgIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                    setPackage(pkg)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(pkgIntent)
                return
            } catch (_: Exception) {}
            try {
                val launchIntent = context.packageManager.getLaunchIntentForPackage(pkg)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(launchIntent)
                    return
                }
            } catch (_: Exception) {}
        }

        // Step 3: Browser fallback
        try {
            context.startActivity(viewIntent)
        } catch (_: Exception) {}
    }

    private fun urlToPackage(host: String): String? {
        return when {
            host.contains("naver.com") || host.contains("naver") -> "com.nhn.android.search"
            host.contains("kakaotalk") || host.contains("kakao.com") || host.contains("kakaocorp.com") -> "com.kakao.talk"
            host.contains("daum.net") -> "net.daum.android.daum"
            host.contains("coupang.com") -> "com.coupang.mobile"
            host.contains("baemin") || host.contains("woowahan") -> "com.baemin"
            host.contains("toss") && !host.contains("github") -> "viva.republica.toss"
            host.contains("danggeun") || host.contains("karrotmarket") || host.contains("daangn") -> "com.towneers.www"
            host.contains("youtube.com") || host.contains("youtu.be") -> "com.google.android.youtube"
            host.contains("instagram.com") -> "com.instagram.android"
            host.contains("threads.net") -> "com.instagram.barcelona"
            host.contains("twitter.com") || host.contains("x.com") -> "com.twitter.android"
            host.contains("facebook.com") || host.contains("fb.com") -> "com.facebook.katana"
            host.contains("tiktok.com") -> "com.zhiliaoapp.musically"
            host.contains("reddit.com") -> "com.reddit.frontpage"
            host.contains("twitch.tv") -> "tv.twitch.android.app"
            host.contains("discord.com") || host.contains("discord.gg") -> "com.discord"
            host.contains("spotify.com") -> "com.spotify.music"
            host.contains("netflix.com") -> "com.netflix.mediaclient"
            host.contains("google.com") -> "com.google.android.googlequicksearchbox"
            host.contains("github.com") -> "com.github.android"
            else -> null
        }
    }

    private fun updateWidget(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val bookmarks = WidgetDataHelper.getBookmarks(context)
        val views = RemoteViews(context.packageName, R.layout.widget_bookmark)

        // Clear grid
        views.removeAllViews(R.id.bookmark_grid)

        if (bookmarks.isEmpty()) {
            views.setViewVisibility(R.id.bookmark_grid, android.view.View.GONE)
            views.setViewVisibility(R.id.bookmark_empty, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.bookmark_grid, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.bookmark_empty, android.view.View.GONE)

            // Build rows of 4 items
            val items = bookmarks.take(8)
            val rows = items.chunked(4)
            for (row in rows) {
                val rowView = RemoteViews(context.packageName, R.layout.widget_bookmark_row)
                rowView.removeAllViews(R.id.bookmark_row)

                for (bookmark in row) {
                    val itemView = RemoteViews(context.packageName, R.layout.widget_bookmark_item)
                    val initial = bookmark.name.firstOrNull()?.toString() ?: "?"
                    itemView.setTextViewText(R.id.bookmark_initial, initial)
                    itemView.setTextViewText(R.id.bookmark_name, bookmark.name)

                    val openIntent = Intent(context, BookmarkWidgetProvider::class.java).apply {
                        action = ACTION_OPEN_URL
                        putExtra(EXTRA_URL, bookmark.url)
                        data = Uri.parse(bookmark.url)
                    }
                    val openPI = PendingIntent.getBroadcast(
                        context, bookmark.id.hashCode(), openIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    itemView.setOnClickPendingIntent(R.id.bookmark_item_root, openPI)
                    rowView.addView(R.id.bookmark_row, itemView)
                }

                // Fill remaining slots with invisible spacers
                for (i in row.size until 4) {
                    val spacer = RemoteViews(context.packageName, R.layout.widget_bookmark_item)
                    spacer.setFloat(R.id.bookmark_item_root, "setAlpha", 0f)
                    rowView.addView(R.id.bookmark_row, spacer)
                }

                views.addView(R.id.bookmark_grid, rowView)
            }
        }

        // Header opens app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            val launchPI = PendingIntent.getActivity(
                context, 101, launchIntent, PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_header, launchPI)
        }

        mgr.updateAppWidget(widgetId, views)
    }
}

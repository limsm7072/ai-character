package com.aicharacter.ai_character

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class ModelWebViewFactory(private val messenger: BinaryMessenger)
    : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return ModelWebView(context, viewId, params, messenger)
    }
}

class ModelWebView(
    context: Context,
    private val viewId: Int,
    params: Map<*, *>,
    messenger: BinaryMessenger
) : PlatformView {

    private val container = FrameLayout(context)
    private val webView = WebView(context)
    private val channel = MethodChannel(messenger, "model_webview_$viewId")
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        val url = params["url"] as? String ?: ""
        val bgColor = params["bgColor"] as? String ?: "#1a1a2e"

        setupWebView(bgColor)
        setupChannel()
        setupBridge()

        if (url.isNotEmpty()) {
            webView.loadUrl(url)
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun setupWebView(bgColor: String) {
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            loadWithOverviewMode = true
            useWideViewPort = true
            mediaPlaybackRequiresUserGesture = false
            allowFileAccess = true
            @SuppressLint("AllowFileAccessFromFileURLs")
            allowFileAccessFromFileURLs = true
            @SuppressLint("AllowUniversalAccessFromFileURLs")
            allowUniversalAccessFromFileURLs = true
            setSupportZoom(true)
            builtInZoomControls = true
            displayZoomControls = false
            mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        }

        try {
            webView.setBackgroundColor(Color.parseColor(bgColor))
        } catch (_: Exception) {
            webView.setBackgroundColor(Color.parseColor("#1a1a2e"))
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                channel.invokeMethod("onLoaded", null)
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                channel.invokeMethod("onProgress", newProgress)
            }
        }

        container.addView(webView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))
    }

    private fun setupChannel() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "loadUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    webView.loadUrl(url)
                    result.success(null)
                }
                "reload" -> {
                    webView.reload()
                    result.success(null)
                }
                "evaluateJavascript" -> {
                    val script = call.argument<String>("script") ?: ""
                    webView.evaluateJavascript(script) { value ->
                        result.success(value)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @SuppressLint("JavascriptInterface")
    private fun setupBridge() {
        webView.addJavascriptInterface(object {
            @JavascriptInterface
            fun onModelTapped(modelId: String, modelName: String) {
                mainHandler.post {
                    channel.invokeMethod("onModelTapped", mapOf("id" to modelId, "name" to modelName))
                }
            }

            @JavascriptInterface
            fun onSceneReady() {
                mainHandler.post {
                    channel.invokeMethod("onSceneReady", null)
                }
            }
        }, "RoomBridge")
    }

    override fun getView(): View = container

    override fun dispose() {
        webView.stopLoading()
        webView.destroy()
        channel.setMethodCallHandler(null)
    }
}

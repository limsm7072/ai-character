package com.aicharacter.ai_character

import android.app.Activity
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.ViewGroup
import android.webkit.*
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView

/**
 * Native WebView Activity for Naver login + reservation page scraping.
 * Uses companion object callback pattern (same as SpeechListenerActivity).
 *
 * Flow:
 * 1. Load Naver login page (with redirect to reservation list)
 * 2. User logs in manually (cookies persist for next time)
 * 3. After login, auto-navigate to reservation page
 * 4. Wait for React SPA to render, then extract innerText via JS
 * 5. Return text via onResult callback
 */
class NaverWebViewActivity : Activity() {

    companion object {
        private const val TAG = "NaverWebView"
        const val RESERVATION_URL = "https://m.place.naver.com/my/timeline?tab=RESERVATION"
        private val LOGIN_HOST = "nid.naver.com"

        var onResult: ((String) -> Unit)? = null
        var onError: ((String) -> Unit)? = null
    }

    private lateinit var webView: WebView
    private lateinit var statusText: TextView
    private lateinit var progressBar: ProgressBar
    private val handler = Handler(Looper.getMainLooper())
    private var hasResult = false
    private var extractionScheduled = false

    // Safety timeout (60s - user needs time to login)
    private val timeoutRunnable = Runnable {
        if (!isFinishing && !hasResult) {
            Log.w(TAG, "Timeout - finishing")
            onError?.invoke("TIMEOUT")
            safeFinish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "NaverWebViewActivity created")

        setupUI()
        setupWebView()

        handler.postDelayed(timeoutRunnable, 60_000)

        // Check if cookies exist (already logged in)
        val cookieManager = CookieManager.getInstance()
        val cookies = cookieManager.getCookie("https://nid.naver.com") ?: ""
        val isLoggedIn = cookies.contains("NID_AUT") && cookies.contains("NID_SES")

        if (isLoggedIn) {
            statusText.text = "예약 내역을 불러오는 중..."
            webView.loadUrl(RESERVATION_URL)
        } else {
            statusText.text = "네이버 로그인이 필요합니다"
            val encodedUrl = Uri.encode(RESERVATION_URL)
            webView.loadUrl("https://nid.naver.com/nidlogin.login?mode=form&url=$encodedUrl")
        }
    }

    private fun setupUI() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.WHITE)
        }

        // Top bar
        val topBar = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#03C75A")) // Naver green
            setPadding(dp(16), dp(12), dp(16), dp(12))
        }

        val title = TextView(this).apply {
            text = "네이버 예약 연동"
            setTextColor(Color.WHITE)
            textSize = 16f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        topBar.addView(title, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.START or Gravity.CENTER_VERTICAL
        ))

        val closeBtn = TextView(this).apply {
            text = "닫기"
            setTextColor(Color.WHITE)
            textSize = 14f
            setPadding(dp(12), dp(8), dp(12), dp(8))
            setOnClickListener {
                onError?.invoke("USER_CANCELLED")
                safeFinish()
            }
        }
        topBar.addView(closeBtn, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.END or Gravity.CENTER_VERTICAL
        ))

        root.addView(topBar, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        // Status text
        statusText = TextView(this).apply {
            text = "로딩 중..."
            setTextColor(Color.parseColor("#666666"))
            textSize = 13f
            setPadding(dp(16), dp(8), dp(16), dp(4))
        }
        root.addView(statusText, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        // Progress bar
        progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            isIndeterminate = true
            setPadding(0, 0, 0, 0)
        }
        root.addView(progressBar, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(3)
        ))

        // WebView
        webView = WebView(this)
        root.addView(webView, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            0,
            1f
        ))

        setContentView(root, ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ))
    }

    @android.annotation.SuppressLint("SetJavaScriptEnabled")
    private fun setupWebView() {
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        cookieManager.setAcceptThirdPartyCookies(webView, true)

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            userAgentString = "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
            setSupportMultipleWindows(false)
            loadWithOverviewMode = true
            useWideViewPort = true
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                Log.d(TAG, "Page finished: $url")

                if (url == null) return

                // Login page - waiting for user input
                if (url.contains(LOGIN_HOST) && url.contains("nidlogin")) {
                    statusText.text = "네이버 계정으로 로그인해주세요"
                    progressBar.visibility = android.view.View.GONE
                    return
                }

                // Reservation page reached
                if (url.contains("place.naver.com") && url.contains("timeline")) {
                    statusText.text = "예약 내역을 읽는 중..."
                    progressBar.visibility = android.view.View.VISIBLE
                    scheduleExtraction()
                    return
                }

                // Login completed - redirect to reservation page
                if (!url.contains(LOGIN_HOST) && !extractionScheduled) {
                    val cookies = cookieManager.getCookie(url) ?: ""
                    if (cookies.contains("NID_AUT") || cookies.contains("NID_SES")) {
                        Log.d(TAG, "Login detected, navigating to reservations")
                        statusText.text = "로그인 완료! 예약 내역으로 이동 중..."
                        webView.loadUrl(RESERVATION_URL)
                    }
                }
            }

            override fun onReceivedError(
                view: WebView?, request: android.webkit.WebResourceRequest?,
                error: android.webkit.WebResourceError?
            ) {
                // Only handle main frame errors
                if (request?.isForMainFrame == true) {
                    Log.e(TAG, "WebView error: ${error?.description}")
                    onError?.invoke("NETWORK_ERROR")
                    safeFinish()
                }
            }
        }
    }

    private fun scheduleExtraction() {
        if (extractionScheduled) return
        extractionScheduled = true

        // Wait for React SPA to render (3 seconds)
        handler.postDelayed({
            extractPageText()
        }, 3000)
    }

    private fun extractPageText() {
        if (hasResult || isFinishing) return

        Log.d(TAG, "Extracting page text via JS")
        webView.evaluateJavascript(
            "(function() { return document.body.innerText; })()"
        ) { rawValue ->
            // JS returns a JSON-encoded string (with quotes and escapes)
            val text = try {
                // Remove surrounding quotes and unescape
                if (rawValue != null && rawValue != "null") {
                    org.json.JSONObject("{\"t\":$rawValue}").getString("t")
                } else ""
            } catch (e: Exception) {
                rawValue?.trim('"') ?: ""
            }

            Log.d(TAG, "Extracted text length: ${text.length}")

            if (text.length > 50) {
                hasResult = true
                onResult?.invoke(text)
                // Small delay to ensure callback is processed
                handler.postDelayed({ safeFinish() }, 300)
            } else {
                // Text too short, might not be fully loaded. Retry once after 3 more seconds.
                Log.w(TAG, "Text too short (${text.length}), retrying...")
                extractionScheduled = false
                handler.postDelayed({
                    extractionScheduled = true
                    retryExtraction()
                }, 3000)
            }
        }
    }

    private fun retryExtraction() {
        if (hasResult || isFinishing) return

        webView.evaluateJavascript(
            "(function() { return document.body.innerText; })()"
        ) { rawValue ->
            val text = try {
                if (rawValue != null && rawValue != "null") {
                    org.json.JSONObject("{\"t\":$rawValue}").getString("t")
                } else ""
            } catch (e: Exception) {
                rawValue?.trim('"') ?: ""
            }

            hasResult = true
            if (text.length > 20) {
                onResult?.invoke(text)
            } else {
                onError?.invoke("EMPTY_PAGE")
            }
            handler.postDelayed({ safeFinish() }, 300)
        }
    }

    private fun safeFinish() {
        handler.removeCallbacks(timeoutRunnable)
        if (!isFinishing) finish()
    }

    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            onError?.invoke("USER_CANCELLED")
            safeFinish()
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        try {
            webView.stopLoading()
            webView.destroy()
        } catch (_: Exception) {}
        super.onDestroy()
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}

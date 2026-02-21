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

        handler.postDelayed(timeoutRunnable, 90_000)

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

        statusText.text = "예약 내역 불러오는 중..."

        // Wait for initial render, then start incremental scrolling
        handler.postDelayed({
            incrementalScroll(0)
        }, 3000)
    }

    /**
     * Scroll incrementally like a real user to trigger lazy loading.
     * Naver SPA may use IntersectionObserver or scroll event listeners
     * that only fire on gradual scrolling, not instant scrollTo(0, max).
     */
    private fun incrementalScroll(step: Int) {
        if (hasResult || isFinishing) return

        // Scroll down by ~1 viewport height each step, also try scrollable containers
        val js = """
            (function() {
                var vh = window.innerHeight || 800;

                // 1. Try scrolling the window
                window.scrollBy(0, vh);

                // 2. Also find and scroll any overflow containers (React SPA pattern)
                var containers = document.querySelectorAll('[class*="scroll"], [class*="list"], [class*="content"], [class*="timeline"], [style*="overflow"]');
                for (var i = 0; i < containers.length; i++) {
                    var c = containers[i];
                    if (c.scrollHeight > c.clientHeight + 10) {
                        c.scrollBy(0, vh);
                    }
                }

                // 3. Dispatch scroll event (some frameworks listen for this)
                window.dispatchEvent(new Event('scroll'));
                document.dispatchEvent(new Event('scroll'));

                var scrollY = window.pageYOffset || document.documentElement.scrollTop;
                var maxScroll = document.body.scrollHeight - window.innerHeight;
                var textLen = document.body.innerText.length;

                return JSON.stringify({y: scrollY, max: maxScroll, len: textLen});
            })()
        """.trimIndent()

        webView.evaluateJavascript(js) { rawResult ->
            val json = try {
                val str = if (rawResult != null && rawResult != "null") {
                    org.json.JSONObject("{\"t\":$rawResult}").getString("t")
                } else "{}"
                org.json.JSONObject(str)
            } catch (e: Exception) {
                Log.w(TAG, "Scroll parse error: $rawResult")
                org.json.JSONObject()
            }

            val scrollY = json.optInt("y", 0)
            val maxScroll = json.optInt("max", 0)
            val textLen = json.optInt("len", 0)
            Log.d(TAG, "Scroll step #$step: y=$scrollY, max=$maxScroll, textLen=$textLen")

            statusText.text = "예약 내역 불러오는 중... (${step + 1})"

            // Keep scrolling if not at bottom yet, or up to 20 steps
            if (step < 20 && (scrollY < maxScroll - 100 || step < 3)) {
                handler.postDelayed({
                    incrementalScroll(step + 1)
                }, 800)
            } else {
                // Done scrolling, wait a moment for final lazy content, then extract
                Log.d(TAG, "Scroll done at step $step, waiting for final render...")
                statusText.text = "내용 추출 중..."
                handler.postDelayed({
                    extractFullPage()
                }, 2000)
            }
        }
    }

    /**
     * Extract the entire page text (includes both upcoming and past reservations).
     */
    private fun extractFullPage() {
        if (hasResult || isFinishing) return

        // Don't scroll back to top — just extract all text from wherever we are
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

            Log.d(TAG, "Extracted full page: ${text.length} chars")

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

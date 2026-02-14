package com.aicharacter.ai_character

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.*
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

class NagOverlay(private val context: Context) {

    companion object {
        private const val TAG = "NagOverlay"
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private val handler = Handler(Looper.getMainLooper())
    var isShowing = false; private set

    private var tts: TextToSpeech? = null
    private var ttsReady = false

    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    private var apiKey = ""
    private val history = mutableListOf<Pair<String, String>>()
    private var charView: CharacterCanvasView? = null
    private var noSpeechCount = 0
    private var layoutParams: WindowManager.LayoutParams? = null

    private val nagMessages = listOf(
        "야! 지금 뭐하는 거야!",
        "루틴 시간이잖아! 집중해!",
        "또 딴짓이야? 진짜 화난다...",
        "폰 내려놓고 루틴 해!",
        "내가 보고 있다... 딴짓 그만!",
        "이러면 안 되는 거 알지?!",
        "에이~ 다시 집중하자!",
        "지금 이게 중요해? 루틴이 중요하지!",
        "한 번만 더 딴짓하면 진짜 화낸다!",
        "루틴 끝나면 하자, 응?",
    )

    private val systemPrompt = """너는 "루나"라는 잔소리 캐릭터야. 사용자가 루틴 시간에 딴짓(다른 앱)을 해서 네가 나타났어.
규칙:
- 반말, 짧게 1-2문장
- 변명하면 더 잔소리
- 미안하다/돌아가겠다 하면 칭찬
- 시끄럽다/화내면 삐진 척 하면서 잔소리
- JSON으로 대답: {"text":"대사","emotion":"angry"}
- emotion: angry, annoyed, sad, happy, disappointed, scolding, proud, surprised"""

    init {
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        initTts()
    }

    private fun initTts() {
        tts = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.setLanguage(Locale.KOREAN)
                tts?.setSpeechRate(1.1f)
                tts?.setPitch(1.3f)
                ttsReady = true
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(id: String?) {
                        handler.post { charView?.isSpeaking = true }
                    }
                    override fun onDone(id: String?) {
                        handler.post {
                            charView?.isSpeaking = false
                            if (isShowing) handler.postDelayed({ if (isShowing) startListening() }, 500)
                        }
                    }
                    override fun onError(id: String?) {
                        handler.post {
                            charView?.isSpeaking = false
                            if (isShowing) handler.postDelayed({ if (isShowing) startListening() }, 1000)
                        }
                    }
                })
            }
        }
    }

    private fun requestAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANT)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                    .build()
                audioManager?.requestAudioFocus(audioFocusRequest!!)
            } else {
                @Suppress("DEPRECATION")
                audioManager?.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            }
        } catch (_: Exception) {}
    }

    private fun abandonAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
        } catch (_: Exception) {}
    }

    fun show(appLabel: String, routineName: String, key: String) {
        if (isShowing) return
        apiKey = key; noSpeechCount = 0; history.clear()
        history.add("user" to systemPrompt)
        history.add("model" to """{"text":"야! 딴짓하지 마!","emotion":"angry"}""")

        handler.post {
            try {
                requestAudioFocus()
                windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                overlayView = createOverlayView()

                val dm = context.resources.displayMetrics
                val screenW = dm.widthPixels
                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                    PixelFormat.TRANSLUCENT
                )
                params.gravity = Gravity.TOP or Gravity.LEFT
                params.x = (screenW - 240) / 2
                params.y = 160
                layoutParams = params

                windowManager?.addView(overlayView, params)
                isShowing = true

                overlayView?.translationY = -800f
                overlayView?.animate()
                    ?.translationY(0f)
                    ?.setDuration(600)
                    ?.setInterpolator(OvershootInterpolator(1.2f))
                    ?.withEndAction {
                        charView?.startHeadShake()
                        speak(nagMessages.random(), "angry")
                    }?.start()
            } catch (e: Exception) { Log.e(TAG, "show fail", e) }
        }
    }

    fun dismiss() {
        if (!isShowing) return
        handler.post {
            try {
                tts?.stop(); charView?.cleanup(); abandonAudioFocus()
                overlayView?.animate()
                    ?.alpha(0f)?.scaleX(0.3f)?.scaleY(0.3f)
                    ?.setDuration(250)
                    ?.withEndAction {
                        try { windowManager?.removeView(overlayView) } catch (_: Exception) {}
                        overlayView = null; charView = null; isShowing = false
                    }?.start()
            } catch (_: Exception) { isShowing = false }
        }
    }

    private fun speak(text: String, emotion: String) {
        handler.post {
            charView?.emotion = emotion
            when (emotion) {
                "angry", "scolding" -> {
                    charView?.gesture = listOf("arms_crossed", "pointing").random()
                    charView?.startHeadShake()
                }
                "annoyed", "disappointed" -> charView?.gesture = "arms_crossed"
                "happy", "proud" -> charView?.gesture = "waving"
                else -> charView?.gesture = "idle"
            }

            if (ttsReady) {
                charView?.isSpeaking = true
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "nag_${System.currentTimeMillis()}")
            } else {
                charView?.isSpeaking = true
                handler.postDelayed({
                    charView?.isSpeaking = false
                    if (isShowing) startListening()
                }, 2500)
            }
        }
    }

    private fun startListening() {
        if (!isShowing) return
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) return
        if (apiKey.isEmpty()) return

        handler.post {
            charView?.isListeningAnim = true
            charView?.emotion = "neutral"

            SpeechListenerActivity.onListening = {
                handler.post { charView?.isListeningAnim = true }
            }
            SpeechListenerActivity.onPartial = { /* character stays in listening mode */ }
            SpeechListenerActivity.onResult = { text ->
                handler.post {
                    charView?.isListeningAnim = false
                    noSpeechCount = 0
                    charView?.emotion = "annoyed"
                    processUserSpeech(text)
                }
            }
            SpeechListenerActivity.onError = { _ ->
                handler.post {
                    charView?.isListeningAnim = false
                    noSpeechCount++
                    if (noSpeechCount < 5 && isShowing) {
                        handler.postDelayed({ if (isShowing) startListening() }, 1000)
                    } else {
                        charView?.emotion = "annoyed"
                        charView?.gesture = "idle"
                    }
                }
            }

            try {
                val intent = Intent(context, SpeechListenerActivity::class.java)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "SpeechActivity launch fail", e)
                charView?.isListeningAnim = false
            }
        }
    }

    private fun processUserSpeech(userText: String) {
        history.add("user" to userText)
        handler.post { charView?.emotion = "annoyed"; charView?.gesture = "idle" }

        Thread {
            try {
                val resp = callApi()
                handler.post {
                    try {
                        val clean = resp.trim()
                            .removePrefix("```json").removePrefix("```").removeSuffix("```").trim()
                        val json = JSONObject(clean)
                        val text = json.optString("text", resp)
                        val emo = json.optString("emotion", "angry")
                        history.add("model" to clean)
                        speak(text, emo)
                    } catch (_: Exception) {
                        val cleaned = resp.trim().take(100)
                        history.add("model" to """{"text":"$cleaned","emotion":"angry"}""")
                        speak(cleaned, "angry")
                    }
                }
            } catch (_: Exception) {
                handler.post {
                    speak(listOf("야! 변명하지 마!", "에이~ 그래도 안 돼!", "다시 집중해!", "루틴부터 끝내!").random(), "angry")
                }
            }
        }.start()
    }

    private fun callApi(): String {
        val url = URL("https://generativelanguage.googleapis.com/v1beta/models/gemma-3-4b-it:generateContent?key=$apiKey")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.doOutput = true; conn.connectTimeout = 10000; conn.readTimeout = 10000

        val contents = JSONArray()
        for ((role, text) in history) {
            contents.put(JSONObject().apply {
                put("role", role)
                put("parts", JSONArray().put(JSONObject().put("text", text)))
            })
        }
        val body = JSONObject().apply {
            put("contents", contents)
            put("generationConfig", JSONObject().apply { put("temperature", 0.9); put("maxOutputTokens", 100) })
        }
        conn.outputStream.write(body.toString().toByteArray())

        if (conn.responseCode != 200) throw Exception("API ${conn.responseCode}")
        val resp = conn.inputStream.bufferedReader().readText()
        return JSONObject(resp)
            .getJSONArray("candidates").getJSONObject(0)
            .getJSONObject("content").getJSONArray("parts")
            .getJSONObject(0).getString("text")
    }

    private fun createOverlayView(): View {
        val container = FrameLayout(context)

        charView = CharacterCanvasView(context).apply {
            emotion = "angry"; gesture = "arms_crossed"
        }

        var downX = 0f; var downY = 0f
        var downParamX = 0; var downParamY = 0
        var dragged = false

        charView?.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX; downY = event.rawY
                    downParamX = layoutParams?.x ?: 0
                    downParamY = layoutParams?.y ?: 0
                    dragged = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downX
                    val dy = event.rawY - downY
                    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) dragged = true
                    if (dragged) {
                        layoutParams?.x = downParamX + dx.toInt()
                        layoutParams?.y = downParamY + dy.toInt()
                        try { windowManager?.updateViewLayout(overlayView, layoutParams) } catch (_: Exception) {}
                    }
                }
                MotionEvent.ACTION_UP -> {
                    if (!dragged) dismiss()
                }
            }
            true
        }

        container.addView(charView, FrameLayout.LayoutParams(240, 300).apply {
            gravity = Gravity.CENTER
        })

        return container
    }
}

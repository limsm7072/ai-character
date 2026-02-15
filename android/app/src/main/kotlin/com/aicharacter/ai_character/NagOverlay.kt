package com.aicharacter.ai_character

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.*
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import android.view.Gravity
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

class NagOverlay(private val context: Context) {

    companion object {
        private const val TAG = "NagOverlay"
        private const val PREFS_NAME = "FlutterSharedPreferences"
    }

    private val handler = Handler(Looper.getMainLooper())
    var isShowing = false; private set

    // Periodically check if Flutter overlay was dismissed by user tap
    private val overlayWatchdog = object : Runnable {
        override fun run() {
            if (isShowing && !isFlutterOverlayRunning()) {
                Log.d(TAG, "Overlay dismissed by user")
                tts?.stop()
                abandonAudioFocus()
                isShowing = false
            }
            if (isShowing) {
                handler.postDelayed(this, 500)
            }
        }
    }

    private fun isFlutterOverlayRunning(): Boolean {
        return try {
            val serviceClass = Class.forName("flutter.overlay.window.flutter_overlay_window.OverlayService")
            val field = serviceClass.getDeclaredField("isRunning")
            field.isAccessible = true
            field.getBoolean(null)
        } catch (_: Exception) { false }
    }

    private var tts: TextToSpeech? = null
    private var ttsReady = false

    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    private var apiKey = ""
    private val history = mutableListOf<Pair<String, String>>()
    private var noSpeechCount = 0

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
                        handler.post { updateOverlayState(isSpeaking = true) }
                    }
                    override fun onDone(id: String?) {
                        handler.post {
                            updateOverlayState(isSpeaking = false)
                            // Auto-dismiss after speaking
                            if (isShowing) handler.postDelayed({ dismiss() }, 2000)
                        }
                    }
                    override fun onError(id: String?) {
                        handler.post {
                            updateOverlayState(isSpeaking = false)
                            if (isShowing) handler.postDelayed({ dismiss() }, 1500)
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

    // ── Read selected character from SharedPreferences ──
    private fun getSelectedCharacter(): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString("flutter.selected_character", "chibi-stickers") ?: "chibi-stickers"
    }

    // ── Write nag state to SharedPreferences (Flutter overlay reads this) ──
    private var currentEmotion = "angry"
    private var currentText = ""

    private fun writeNagState(emotion: String, text: String, gesture: String = "idle") {
        currentEmotion = emotion
        currentText = text
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val json = JSONObject().apply {
                put("emotion", emotion)
                put("gesture", gesture)
                put("text", text)
                put("characterId", getSelectedCharacter())
            }
            prefs.edit().putString("flutter.nag_state", json.toString()).apply()
        } catch (e: Exception) { Log.e(TAG, "writeNagState fail", e) }
    }

    // ── Send data to Flutter overlay via BasicMessageChannel (reflection) ──
    private fun sendToFlutterOverlay(emotion: String, text: String, gesture: String = "idle") {
        try {
            val data = JSONObject().apply {
                put("emotion", emotion)
                put("gesture", gesture)
                put("text", text)
                put("characterId", getSelectedCharacter())
            }
            val wsClass = Class.forName("flutter.overlay.window.flutter_overlay_window.WindowSetup")
            val messengerField = wsClass.getDeclaredField("messenger")
            messengerField.isAccessible = true
            val messenger = messengerField.get(null)
            if (messenger != null) {
                // BasicMessageChannel<Object>.send(Object)
                val sendMethod = messenger.javaClass.getMethod("send", Any::class.java)
                sendMethod.invoke(messenger, data.toString())
            }
        } catch (e: Exception) { Log.d(TAG, "sendToFlutterOverlay: ${e.message}") }
    }

    private fun updateOverlayState(isSpeaking: Boolean? = null) {
        // Just re-send current state (emotion unchanged)
        sendToFlutterOverlay(currentEmotion, currentText)
    }

    // ── Start/stop Flutter overlay via flutter_overlay_window ──
    private fun startFlutterOverlay() {
        try {
            val wsClass = Class.forName("flutter.overlay.window.flutter_overlay_window.WindowSetup")

            fun setField(name: String, value: Any) {
                val f = wsClass.getDeclaredField(name)
                f.isAccessible = true
                f.set(null, value)
            }

            setField("width", 300)
            setField("height", 450)
            setField("enableDrag", true)
            setField("overlayTitle", "AI Character")
            setField("overlayContent", "")
            setField("positionGravity", "auto")
            setField("gravity", Gravity.CENTER)

            val overlayServiceClass = Class.forName("flutter.overlay.window.flutter_overlay_window.OverlayService")
            val intent = Intent(context, overlayServiceClass)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.d(TAG, "Flutter overlay started")
        } catch (e: Exception) { Log.e(TAG, "startFlutterOverlay fail", e) }
    }

    private fun stopFlutterOverlay() {
        try {
            val overlayServiceClass = Class.forName("flutter.overlay.window.flutter_overlay_window.OverlayService")
            val intent = Intent(context, overlayServiceClass)
            context.stopService(intent)
            Log.d(TAG, "Flutter overlay stopped")
        } catch (e: Exception) { Log.e(TAG, "stopFlutterOverlay fail", e) }
    }

    // ── Show / Dismiss ──
    fun show(appLabel: String, routineName: String, key: String) {
        if (isShowing) return
        apiKey = key; noSpeechCount = 0; history.clear()
        history.add("user" to systemPrompt)
        history.add("model" to """{"text":"야! 딴짓하지 마!","emotion":"angry"}""")

        handler.post {
            try {
                requestAudioFocus()

                val initialText = nagMessages.random()
                writeNagState("angry", initialText)
                startFlutterOverlay()
                isShowing = true

                // Start watchdog to detect user dismissal
                handler.postDelayed(overlayWatchdog, 1000)

                // Wait for Flutter engine to initialize, then send data + speak
                handler.postDelayed({
                    sendToFlutterOverlay("angry", initialText)
                    speak(initialText, "angry")
                }, 800)
            } catch (e: Exception) { Log.e(TAG, "show fail", e) }
        }
    }

    fun dismiss() {
        if (!isShowing) return
        handler.post {
            try {
                handler.removeCallbacks(overlayWatchdog)
                tts?.stop()
                abandonAudioFocus()
                stopFlutterOverlay()
                isShowing = false
                Log.d(TAG, "Overlay dismissed")
            } catch (_: Exception) { isShowing = false }
        }
    }

    // ── Speak + update overlay ──
    private fun speak(text: String, emotion: String) {
        handler.post {
            writeNagState(emotion, text)
            sendToFlutterOverlay(emotion, text)

            if (ttsReady) {
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "nag_${System.currentTimeMillis()}")
            } else {
                handler.postDelayed({
                    if (isShowing) startListening()
                }, 2500)
            }
        }
    }

    // ── Speech recognition ──
    private fun startListening() {
        if (!isShowing) return
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) return
        if (apiKey.isEmpty()) return

        handler.post {
            writeNagState("neutral", "...")
            sendToFlutterOverlay("neutral", "...")

            SpeechListenerActivity.onListening = {}
            SpeechListenerActivity.onPartial = {}
            SpeechListenerActivity.onResult = { text ->
                handler.post {
                    noSpeechCount = 0
                    writeNagState("annoyed", "...")
                    sendToFlutterOverlay("annoyed", "...")
                    processUserSpeech(text)
                }
            }
            SpeechListenerActivity.onError = { _ ->
                handler.post {
                    noSpeechCount++
                    if (noSpeechCount < 5 && isShowing) {
                        handler.postDelayed({ if (isShowing) startListening() }, 1000)
                    }
                }
            }

            try {
                val intent = Intent(context, SpeechListenerActivity::class.java)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "SpeechActivity launch fail", e)
            }
        }
    }

    private fun processUserSpeech(userText: String) {
        history.add("user" to userText)

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
}

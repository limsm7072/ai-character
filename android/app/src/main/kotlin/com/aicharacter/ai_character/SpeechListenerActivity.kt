package com.aicharacter.ai_character

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log

/**
 * Transparent Activity solely for speech recognition.
 * SpeechRecognizer requires Activity context on many devices.
 * This activity is invisible - overlay stays on top.
 */
class SpeechListenerActivity : Activity() {

    companion object {
        private const val TAG = "SpeechListener"
        var onResult: ((String) -> Unit)? = null
        var onPartial: ((String) -> Unit)? = null
        var onError: ((String) -> Unit)? = null
        var onListening: (() -> Unit)? = null
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var hasResult = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "SpeechListenerActivity created")

        // Auto-finish safety net (15 seconds max)
        handler.postDelayed({ if (!isFinishing) { Log.d(TAG, "Timeout finish"); safeFinish() } }, 15000)

        startRecognition()
    }

    private fun startRecognition() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            Log.e(TAG, "Speech recognition not available")
            onError?.invoke("음성인식을 사용할 수 없어요")
            safeFinish()
            return
        }

        try {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
            speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(p: Bundle?) {
                    Log.d(TAG, "Ready for speech")
                    onListening?.invoke()
                }

                override fun onBeginningOfSpeech() {
                    Log.d(TAG, "Speech started")
                }

                override fun onRmsChanged(v: Float) {}
                override fun onBufferReceived(b: ByteArray?) {}

                override fun onEndOfSpeech() {
                    Log.d(TAG, "Speech ended")
                }

                override fun onError(err: Int) {
                    val msg = when (err) {
                        SpeechRecognizer.ERROR_AUDIO -> "오디오 에러"
                        SpeechRecognizer.ERROR_CLIENT -> "클라이언트 에러"
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "마이크 권한 없음"
                        SpeechRecognizer.ERROR_NETWORK -> "네트워크 에러"
                        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "네트워크 시간초과"
                        SpeechRecognizer.ERROR_NO_MATCH -> "인식 못함"
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "인식기 사용중"
                        SpeechRecognizer.ERROR_SERVER -> "서버 에러"
                        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "말 안 함"
                        else -> "에러($err)"
                    }
                    Log.w(TAG, "Error: $msg ($err)")
                    if (!hasResult) {
                        onError?.invoke(msg)
                    }
                    safeFinish()
                }

                override fun onResults(results: Bundle?) {
                    val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()
                    Log.d(TAG, "Final result: $text")
                    if (!text.isNullOrBlank()) {
                        hasResult = true
                        onResult?.invoke(text)
                    } else {
                        onError?.invoke("빈 결과")
                    }
                    safeFinish()
                }

                override fun onPartialResults(p: Bundle?) {
                    val partial = p?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()
                    if (!partial.isNullOrBlank()) {
                        Log.d(TAG, "Partial: $partial")
                        onPartial?.invoke(partial)
                    }
                }

                override fun onEvent(t: Int, p: Bundle?) {}
            })

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ko-KR")
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "ko-KR")
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            }
            speechRecognizer?.startListening(intent)
            Log.d(TAG, "Listening started")
        } catch (e: Exception) {
            Log.e(TAG, "Start failed", e)
            onError?.invoke("시작 실패: ${e.message}")
            safeFinish()
        }
    }

    private fun safeFinish() {
        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.destroy()
            speechRecognizer = null
        } catch (_: Exception) {}
        if (!isFinishing) finish()
    }

    override fun onDestroy() {
        try { speechRecognizer?.destroy() } catch (_: Exception) {}
        // Don't clear callbacks here - they might still be needed for the result
        super.onDestroy()
    }
}

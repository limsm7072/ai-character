package com.aicharacter.ai_character

import android.util.Log
import okhttp3.*
import okio.ByteString
import java.io.File
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Native Edge TTS client using OkHttp WebSocket.
 * Matches the Python edge-tts library's authentication protocol.
 */
class EdgeTtsNative {
    companion object {
        private const val TAG = "EdgeTtsNative"
        private const val TRUSTED_CLIENT_TOKEN = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
        private const val WS_BASE = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1"
        private const val OUTPUT_FORMAT = "audio-24khz-48kbitrate-mono-mp3"
        private const val CHROMIUM_FULL_VERSION = "143.0.3650.75"
        private const val CHROMIUM_MAJOR_VERSION = "143"
        private const val WIN_EPOCH = 11644473600L

        /** Voice preset ID → Edge TTS voice name */
        val voiceMap = mapOf(
            "sunhi" to "ko-KR-SunHiNeural",
            "sunhi_gentle" to "ko-KR-SunHiNeural",
            "sunhi_bright" to "ko-KR-SunHiNeural",
            "injoon" to "ko-KR-InJoonNeural",
            "injoon_energetic" to "ko-KR-InJoonNeural",
            "hyunsu" to "ko-KR-HyunsuMultilingualNeural",
            "hyunsu_deep" to "ko-KR-HyunsuMultilingualNeural",
        )

        /** Voice preset ID → SSML rate */
        val rateMap = mapOf(
            "sunhi" to "+0%",
            "sunhi_gentle" to "-15%",
            "sunhi_bright" to "+10%",
            "injoon" to "+0%",
            "injoon_energetic" to "+10%",
            "hyunsu" to "+0%",
            "hyunsu_deep" to "-10%",
        )

        /** Voice preset ID → SSML pitch */
        val pitchMap = mapOf(
            "sunhi" to "+0Hz",
            "sunhi_gentle" to "-10Hz",
            "sunhi_bright" to "+15Hz",
            "injoon" to "+0Hz",
            "injoon_energetic" to "+10Hz",
            "hyunsu" to "+0Hz",
            "hyunsu_deep" to "-15Hz",
        )
    }

    private val client = OkHttpClient.Builder()
        .readTimeout(15, TimeUnit.SECONDS)
        .writeTimeout(5, TimeUnit.SECONDS)
        .build()

    var lastError: String? = null

    /**
     * Synthesize text to MP3 file. Returns the file path, or null on failure.
     * Must be called on a background thread.
     */
    fun synthesize(text: String, presetId: String, outputFile: File): Boolean {
        if (text.isBlank()) return false
        lastError = null

        val voice = voiceMap[presetId] ?: voiceMap["sunhi"]!!
        val rate = rateMap[presetId] ?: "+0%"
        val pitch = pitchMap[presetId] ?: "+0Hz"

        val connId = UUID.randomUUID().toString().replace("-", "")
        val secMsGec = generateSecMsGec()
        val muid = generateMuid()

        val wsUrl = "$WS_BASE" +
                "?TrustedClientToken=$TRUSTED_CLIENT_TOKEN" +
                "&ConnectionId=$connId" +
                "&Sec-MS-GEC=$secMsGec" +
                "&Sec-MS-GEC-Version=1-$CHROMIUM_FULL_VERSION"

        val request = Request.Builder()
            .url(wsUrl)
            .header("User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" +
                " (KHTML, like Gecko) Chrome/$CHROMIUM_MAJOR_VERSION.0.0.0 Safari/537.36" +
                " Edg/$CHROMIUM_MAJOR_VERSION.0.0.0")
            .header("Accept-Encoding", "gzip, deflate, br, zstd")
            .header("Accept-Language", "en-US,en;q=0.9")
            .header("Pragma", "no-cache")
            .header("Cache-Control", "no-cache")
            .header("Origin", "chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold")
            .header("Cookie", "muid=$muid;")
            .build()

        val audioChunks = mutableListOf<ByteArray>()
        val latch = CountDownLatch(1)
        var error: String? = null

        val ws = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket connected")

                // Send speech.config
                val timestamp = rfc1123Timestamp()
                webSocket.send(
                    "X-Timestamp:$timestamp\r\n" +
                    "Content-Type:application/json; charset=utf-8\r\n" +
                    "Path:speech.config\r\n\r\n" +
                    """{"context":{"synthesis":{"audio":{"metadataoptions":""" +
                    """{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"true"},""" +
                    """"outputFormat":"$OUTPUT_FORMAT"}}}}"""
                )

                // Send SSML
                val requestId = UUID.randomUUID().toString().replace("-", "")
                val escapedText = escapeXml(text)
                webSocket.send(
                    "X-RequestId:$requestId\r\n" +
                    "Content-Type:application/ssml+xml\r\n" +
                    "X-Timestamp:${timestamp}Z\r\n" +
                    "Path:ssml\r\n\r\n" +
                    """<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="ko-KR">""" +
                    """<voice name="$voice">""" +
                    """<prosody pitch="$pitch" rate="$rate" volume="+0%">""" +
                    escapedText +
                    "</prosody></voice></speak>"
                )
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                if (text.contains("Path:turn.end")) {
                    webSocket.close(1000, null)
                    latch.countDown()
                }
            }

            override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                val data = bytes.toByteArray()
                if (data.size > 2) {
                    val headerLen = ((data[0].toInt() and 0xFF) shl 8) or (data[1].toInt() and 0xFF)
                    val audioStart = 2 + headerLen
                    if (audioStart <= data.size) {
                        val header = String(data, 2, headerLen, Charsets.UTF_8)
                        if (header.contains("Path:audio")) {
                            audioChunks.add(data.copyOfRange(audioStart, data.size))
                        }
                    }
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                error = "WebSocket error: ${t.message}"
                Log.e(TAG, "WebSocket failure: ${t.message}")
                latch.countDown()
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                latch.countDown()
            }
        })

        // Wait for completion (max 15 seconds)
        val completed = latch.await(15, TimeUnit.SECONDS)
        if (!completed) {
            ws.cancel()
            lastError = "Timeout"
            return false
        }

        if (error != null) {
            lastError = error
            return false
        }

        if (audioChunks.isEmpty()) {
            lastError = "No audio data received"
            return false
        }

        // Write audio to file
        try {
            val totalSize = audioChunks.sumOf { it.size }
            outputFile.outputStream().use { out ->
                for (chunk in audioChunks) {
                    out.write(chunk)
                }
            }
            Log.d(TAG, "Synthesized ${audioChunks.size} chunks, $totalSize bytes → ${outputFile.path}")
            return true
        } catch (e: Exception) {
            lastError = "File write error: ${e.message}"
            return false
        }
    }

    private fun generateSecMsGec(): String {
        val nowSec = System.currentTimeMillis() / 1000.0
        var ticks = nowSec + WIN_EPOCH
        ticks -= ticks % 300
        ticks *= 1e7
        val strToHash = "${ticks.toLong()}$TRUSTED_CLIENT_TOKEN"
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(strToHash.toByteArray(Charsets.US_ASCII))
        return hash.joinToString("") { "%02X".format(it) }
    }

    private fun generateMuid(): String {
        val bytes = ByteArray(16)
        java.security.SecureRandom().nextBytes(bytes)
        return bytes.joinToString("") { "%02X".format(it) }
    }

    private fun rfc1123Timestamp(): String {
        val cal = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC"))
        val days = arrayOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
        val months = arrayOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
        return "${days[cal.get(java.util.Calendar.DAY_OF_WEEK) - 1]}, " +
                "%02d".format(cal.get(java.util.Calendar.DAY_OF_MONTH)) + " " +
                "${months[cal.get(java.util.Calendar.MONTH)]} ${cal.get(java.util.Calendar.YEAR)} " +
                "%02d:%02d:%02d GMT".format(
                    cal.get(java.util.Calendar.HOUR_OF_DAY),
                    cal.get(java.util.Calendar.MINUTE),
                    cal.get(java.util.Calendar.SECOND))
    }

    private fun escapeXml(text: String): String {
        return text
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
            .replace("'", "&apos;")
    }
}

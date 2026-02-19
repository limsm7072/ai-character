package com.aicharacter.ai_character

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.math.sin
import kotlin.math.PI
import kotlin.random.Random

class AmbientSoundGenerator {
    companion object {
        const val SAMPLE_RATE = 44100
        const val BUFFER_SAMPLES = 4096
    }

    private var audioTrack: AudioTrack? = null
    private var thread: Thread? = null
    @Volatile private var isPlaying = false
    @Volatile private var currentType = "white"
    @Volatile private var volume = 0.5f

    fun start(type: String, vol: Double) {
        stop()
        currentType = type
        volume = vol.coerceIn(0.0, 1.0).toFloat()

        val minBuf = AudioTrack.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(maxOf(minBuf, BUFFER_SAMPLES * 2) * 2)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        isPlaying = true
        audioTrack?.play()
        thread = Thread(::generateLoop, "AmbientSoundThread").apply { start() }
    }

    fun stop() {
        isPlaying = false
        thread?.join(500)
        thread = null
        try {
            audioTrack?.stop()
            audioTrack?.release()
        } catch (_: Exception) {}
        audioTrack = null
    }

    fun setVolume(vol: Double) {
        volume = vol.coerceIn(0.0, 1.0).toFloat()
    }

    fun setType(type: String) {
        currentType = type
    }

    // --- Main generation loop ---

    private fun generateLoop() {
        val buffer = ShortArray(BUFFER_SAMPLES)
        val raw = FloatArray(BUFFER_SAMPLES)
        var sampleIndex = 0L

        // Brown noise state
        var brownValue = 0.0

        // Pink noise state (Voss-McCartney)
        val pinkRows = DoubleArray(12)
        var pinkRunningSum = 0.0
        var pinkIndex = 0

        // Rain state
        var rainLpValue = 0.0
        var dropTimer = 0
        var dropAmplitude = 0.0

        // Ocean state
        var oceanBrown = 0.0

        while (isPlaying) {
            val type = currentType
            val vol = volume

            when (type) {
                "white" -> {
                    for (i in raw.indices) {
                        raw[i] = (Random.nextFloat() * 2f - 1f) * 0.3f
                    }
                }
                "pink" -> {
                    for (i in raw.indices) {
                        pinkIndex++
                        var newRandom = 0.0
                        // Voss-McCartney: update rows based on trailing zeros
                        for (k in pinkRows.indices) {
                            if (pinkIndex and (1 shl k) == 0) {
                                pinkRunningSum -= pinkRows[k]
                                pinkRows[k] = Random.nextDouble() * 2.0 - 1.0
                                pinkRunningSum += pinkRows[k]
                                break
                            }
                        }
                        newRandom = Random.nextDouble() * 2.0 - 1.0
                        raw[i] = ((pinkRunningSum + newRandom) / (pinkRows.size + 1)).toFloat() * 0.5f
                    }
                }
                "brown" -> {
                    for (i in raw.indices) {
                        brownValue += (Random.nextDouble() * 2.0 - 1.0) * 0.02
                        brownValue = brownValue.coerceIn(-1.0, 1.0)
                        raw[i] = brownValue.toFloat() * 0.5f
                    }
                }
                "rain" -> {
                    for (i in raw.indices) {
                        // Base: filtered noise
                        val white = Random.nextDouble() * 2.0 - 1.0
                        rainLpValue = rainLpValue * 0.7 + white * 0.3
                        var sample = rainLpValue * 0.3

                        // Random droplet bursts
                        dropTimer--
                        if (dropTimer <= 0) {
                            dropTimer = Random.nextInt(200, 2000)
                            dropAmplitude = Random.nextDouble() * 0.4 + 0.2
                        }
                        if (dropTimer > dropTimer.coerceAtMost(100)) {
                            // During droplet
                        } else if (dropTimer > 0) {
                            sample += (Random.nextDouble() * 2.0 - 1.0) * dropAmplitude * (dropTimer / 100.0)
                        }

                        raw[i] = sample.toFloat()
                    }
                }
                "ocean" -> {
                    for (i in raw.indices) {
                        // Brown noise base
                        oceanBrown += (Random.nextDouble() * 2.0 - 1.0) * 0.015
                        oceanBrown = oceanBrown.coerceIn(-1.0, 1.0)

                        // Slow wave modulation (period ~12 seconds)
                        val idx = sampleIndex + i
                        val wavePeriod = SAMPLE_RATE * 12.0
                        val mod = 0.3 + 0.7 * ((sin(2.0 * PI * idx / wavePeriod) + 1.0) / 2.0)

                        raw[i] = (oceanBrown * mod * 0.5).toFloat()
                    }
                }
                else -> {
                    for (i in raw.indices) raw[i] = 0f
                }
            }

            // Apply volume and convert to short
            for (i in raw.indices) {
                val s = (raw[i] * vol * Short.MAX_VALUE).toInt()
                buffer[i] = s.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
            }

            try {
                audioTrack?.write(buffer, 0, buffer.size)
            } catch (_: Exception) {
                break
            }
            sampleIndex += buffer.size
        }
    }
}

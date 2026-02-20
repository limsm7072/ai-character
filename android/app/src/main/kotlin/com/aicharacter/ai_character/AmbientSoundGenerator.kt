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

        // Stream state
        var streamLpValue = 0.0
        var streamDropTimer = 0
        var streamDropAmp = 0.0

        // Forest state
        var forestPinkSum = 0.0
        val forestPinkRows = DoubleArray(12)
        var forestPinkIdx = 0
        var forestBirdTimer = 0
        var forestBirdFreq = 3000.0
        var forestBirdDuration = 0
        var forestBirdPhase = 0.0

        // Fire state
        var fireBrown = 0.0
        var fireCrackleTimer = 0
        var fireCrackleAmp = 0.0
        var fireCrackleDuration = 0

        // Wind state
        var windBrown = 0.0

        // Night state
        var nightChirpFreq = 4000.0
        var nightChirpOn = false
        var nightChirpTimer = 0
        var nightChirpPhase = 0.0
        var nightBgLp = 0.0

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
                "stream" -> {
                    for (i in raw.indices) {
                        // High-pass filtered noise (LP coeff 0.85 = softer, more watery)
                        val white = Random.nextDouble() * 2.0 - 1.0
                        streamLpValue = streamLpValue * 0.85 + white * 0.15
                        var sample = streamLpValue * 0.25

                        // Irregular water droplet bursts
                        streamDropTimer--
                        if (streamDropTimer <= 0) {
                            streamDropTimer = Random.nextInt(500, 4000)
                            streamDropAmp = Random.nextDouble() * 0.3 + 0.1
                        }
                        if (streamDropTimer < 80) {
                            val env = streamDropTimer / 80.0
                            sample += (Random.nextDouble() * 2.0 - 1.0) * streamDropAmp * env
                        }

                        raw[i] = sample.toFloat()
                    }
                }
                "forest" -> {
                    for (i in raw.indices) {
                        // Very soft pink noise background
                        forestPinkIdx++
                        for (k in forestPinkRows.indices) {
                            if (forestPinkIdx and (1 shl k) == 0) {
                                forestPinkSum -= forestPinkRows[k]
                                forestPinkRows[k] = Random.nextDouble() * 2.0 - 1.0
                                forestPinkSum += forestPinkRows[k]
                                break
                            }
                        }
                        val rnd = Random.nextDouble() * 2.0 - 1.0
                        var sample = ((forestPinkSum + rnd) / (forestPinkRows.size + 1)) * 0.15

                        // Random short sine bursts (bird chirps)
                        if (forestBirdDuration > 0) {
                            forestBirdPhase += 2.0 * PI * forestBirdFreq / SAMPLE_RATE
                            val env = forestBirdDuration / 800.0
                            sample += sin(forestBirdPhase) * 0.12 * env
                            forestBirdDuration--
                        } else {
                            forestBirdTimer--
                            if (forestBirdTimer <= 0) {
                                forestBirdTimer = Random.nextInt(8000, 40000)
                                forestBirdFreq = Random.nextDouble() * 2000.0 + 2500.0
                                forestBirdDuration = Random.nextInt(300, 800)
                                forestBirdPhase = 0.0
                            }
                        }

                        raw[i] = sample.toFloat()
                    }
                }
                "fire" -> {
                    for (i in raw.indices) {
                        // Low-frequency brown noise base
                        fireBrown += (Random.nextDouble() * 2.0 - 1.0) * 0.01
                        fireBrown = fireBrown.coerceIn(-1.0, 1.0)
                        var sample = fireBrown * 0.3

                        // Random crackle bursts
                        if (fireCrackleDuration > 0) {
                            sample += (Random.nextDouble() * 2.0 - 1.0) * fireCrackleAmp * (fireCrackleDuration / 200.0)
                            fireCrackleDuration--
                        } else {
                            fireCrackleTimer--
                            if (fireCrackleTimer <= 0) {
                                fireCrackleTimer = Random.nextInt(100, 3000)
                                fireCrackleAmp = Random.nextDouble() * 0.5 + 0.2
                                fireCrackleDuration = Random.nextInt(50, 200)
                            }
                        }

                        raw[i] = sample.toFloat()
                    }
                }
                "wind" -> {
                    for (i in raw.indices) {
                        // Brown noise base
                        windBrown += (Random.nextDouble() * 2.0 - 1.0) * 0.018
                        windBrown = windBrown.coerceIn(-1.0, 1.0)

                        // Slow sinusoidal amplitude modulation (20-second period)
                        val idx = sampleIndex + i
                        val period = SAMPLE_RATE * 20.0
                        val mod = 0.2 + 0.8 * ((sin(2.0 * PI * idx / period) + 1.0) / 2.0)

                        raw[i] = (windBrown * mod * 0.4).toFloat()
                    }
                }
                "night" -> {
                    for (i in raw.indices) {
                        // Soft background noise
                        val white = Random.nextDouble() * 2.0 - 1.0
                        nightBgLp = nightBgLp * 0.95 + white * 0.05
                        var sample = nightBgLp * 0.1

                        // Cricket chirps: high-freq sine tones (3500-5000Hz) with intermittent on/off
                        nightChirpTimer--
                        if (nightChirpTimer <= 0) {
                            nightChirpOn = !nightChirpOn
                            nightChirpTimer = if (nightChirpOn) {
                                Random.nextInt(2000, 8000)
                            } else {
                                Random.nextInt(4000, 20000)
                            }
                            if (nightChirpOn) {
                                nightChirpFreq = Random.nextDouble() * 1500.0 + 3500.0
                                nightChirpPhase = 0.0
                            }
                        }
                        if (nightChirpOn) {
                            nightChirpPhase += 2.0 * PI * nightChirpFreq / SAMPLE_RATE
                            // Pulsing envelope for cricket-like rhythm
                            val pulseFreq = 15.0
                            val pulse = (sin(2.0 * PI * pulseFreq * (sampleIndex + i) / SAMPLE_RATE) + 1.0) / 2.0
                            sample += sin(nightChirpPhase) * 0.06 * pulse
                        }

                        raw[i] = sample.toFloat()
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

package com.aicharacter.ai_character

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator

class CharacterCanvasView(context: Context) : View(context) {

    private val skinPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#FFE0BD") }
    private val hairPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#3D2314") }
    private val eyePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#1A1A1A") }
    private val whitePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private val mouthPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#D94040")
        style = Paint.Style.STROKE; strokeWidth = 3f; strokeCap = Paint.Cap.ROUND
    }
    private val mouthFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#C0392B") }
    private val blushPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#50FF8888") }
    private val outfitPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#5B86E5") }
    private val limbPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#FFE0BD"); style = Paint.Style.STROKE; strokeWidth = 8f; strokeCap = Paint.Cap.ROUND
    }
    private val browPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#3D2314"); style = Paint.Style.STROKE; strokeWidth = 3.5f; strokeCap = Paint.Cap.ROUND
    }
    private val listenPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#E74C3C") }
    private val listenRingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#60E74C3C"); style = Paint.Style.STROKE; strokeWidth = 2f
    }

    // Animated values
    private var bounceY = 0f
    private var headRot = 0f
    private var mouthOpen = 0f
    private var leftArmAngle = 20f
    private var rightArmAngle = -20f
    private var eyeScaleY = 1f
    private var listenPulse = 0f

    var emotion = "angry"; set(v) { field = v; invalidate() }
    var gesture = "idle"; set(v) { field = v; animateGesture() }
    var isSpeaking = false; set(v) { field = v; if (v) startMouth() else stopMouth() }
    var isListeningAnim = false; set(v) { field = v; if (v) startListenPulse() else stopListenPulse(); invalidate() }

    private var bounceAnim: ValueAnimator? = null
    private var blinkAnim: ValueAnimator? = null
    private var mouthAnim: ValueAnimator? = null
    private var headShakeAnim: ValueAnimator? = null
    private var armAnim: ValueAnimator? = null
    private var listenAnim: ValueAnimator? = null

    init {
        bounceAnim = ValueAnimator.ofFloat(0f, -10f).apply {
            duration = 700; repeatMode = ValueAnimator.REVERSE; repeatCount = ValueAnimator.INFINITE
            interpolator = AccelerateDecelerateInterpolator()
            addUpdateListener { bounceY = it.animatedValue as Float; invalidate() }
            start()
        }
        blinkAnim = ValueAnimator.ofFloat(1f, 0.05f, 1f).apply {
            duration = 120; startDelay = 2500; repeatCount = ValueAnimator.INFINITE
            addUpdateListener { eyeScaleY = it.animatedValue as Float; invalidate() }
            start()
        }
    }

    private fun startMouth() {
        mouthAnim?.cancel()
        mouthAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 180; repeatMode = ValueAnimator.REVERSE; repeatCount = ValueAnimator.INFINITE
            addUpdateListener { mouthOpen = it.animatedValue as Float; invalidate() }
            start()
        }
    }
    private fun stopMouth() { mouthAnim?.cancel(); mouthOpen = 0f; invalidate() }

    fun startHeadShake() {
        headShakeAnim?.cancel()
        headShakeAnim = ValueAnimator.ofFloat(0f, -12f, 12f, -8f, 8f, -4f, 0f).apply {
            duration = 500; addUpdateListener { headRot = it.animatedValue as Float; invalidate() }
            start()
        }
    }

    private fun animateGesture() {
        armAnim?.cancel()
        val (targetL, targetR) = when (gesture) {
            "arms_crossed" -> -50f to 50f
            "pointing" -> 20f to -100f
            "waving" -> 20f to -80f
            else -> 20f to -20f
        }
        armAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 300
            addUpdateListener {
                val p = it.animatedValue as Float
                leftArmAngle = leftArmAngle + (targetL - leftArmAngle) * p
                rightArmAngle = rightArmAngle + (targetR - rightArmAngle) * p
                invalidate()
            }
            start()
        }
        if (gesture == "waving") {
            armAnim?.addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(a: android.animation.Animator) {
                    ValueAnimator.ofFloat(-80f, -50f).apply {
                        duration = 250; repeatMode = ValueAnimator.REVERSE; repeatCount = 5
                        addUpdateListener { rightArmAngle = it.animatedValue as Float; invalidate() }
                        start()
                    }
                }
            })
        }
    }

    private fun startListenPulse() {
        listenAnim?.cancel()
        listenAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 800; repeatMode = ValueAnimator.REVERSE; repeatCount = ValueAnimator.INFINITE
            addUpdateListener { listenPulse = it.animatedValue as Float; invalidate() }
            start()
        }
    }
    private fun stopListenPulse() { listenAnim?.cancel(); listenPulse = 0f }

    fun cleanup() {
        bounceAnim?.cancel(); blinkAnim?.cancel(); mouthAnim?.cancel()
        headShakeAnim?.cancel(); armAnim?.cancel(); listenAnim?.cancel()
    }

    override fun onMeasure(w: Int, h: Int) { setMeasuredDimension(220, 280) }

    override fun onDraw(c: Canvas) {
        super.onDraw(c)
        val cx = width / 2f
        val headY = 80f + bounceY
        val hr = 50f

        c.save()
        c.rotate(headRot, cx, headY)

        // Legs
        val legTop = headY + hr + 68f
        c.drawLine(cx - 10f, legTop, cx - 15f, legTop + 30f, limbPaint)
        c.drawLine(cx + 10f, legTop, cx + 15f, legTop + 30f, limbPaint)

        // Body
        c.drawRoundRect(RectF(cx - 22f, headY + hr + 5f, cx + 22f, headY + hr + 55f), 8f, 8f, outfitPaint)

        // Arms
        c.save(); c.rotate(leftArmAngle, cx - 22f, headY + hr + 15f)
        c.drawLine(cx - 22f, headY + hr + 15f, cx - 48f, headY + hr + 45f, limbPaint)
        c.restore()
        c.save(); c.rotate(rightArmAngle, cx + 22f, headY + hr + 15f)
        c.drawLine(cx + 22f, headY + hr + 15f, cx + 48f, headY + hr + 45f, limbPaint)
        c.restore()

        // Head
        c.drawCircle(cx, headY, hr, skinPaint)

        // Hair top
        val hp = Path().apply {
            moveTo(cx - hr * 0.8f, headY - hr * 0.3f)
            quadTo(cx - hr * 0.2f, headY - hr * 1.4f, cx + hr * 0.1f, headY - hr * 0.9f)
            quadTo(cx + hr * 0.4f, headY - hr * 1.3f, cx + hr * 0.8f, headY - hr * 0.3f)
            quadTo(cx + hr * 0.5f, headY - hr * 0.7f, cx, headY - hr * 1.05f)
            quadTo(cx - hr * 0.5f, headY - hr * 0.7f, cx - hr * 0.8f, headY - hr * 0.3f)
            close()
        }
        c.drawPath(hp, hairPaint)

        // Side hair
        c.drawArc(RectF(cx - hr - 4f, headY - hr, cx - hr + 14f, headY + hr * 0.3f), 180f, 90f, false,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { color = hairPaint.color; style = Paint.Style.STROKE; strokeWidth = 10f })
        c.drawArc(RectF(cx + hr - 14f, headY - hr, cx + hr + 4f, headY + hr * 0.3f), 270f, 90f, false,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { color = hairPaint.color; style = Paint.Style.STROKE; strokeWidth = 10f })

        // Eyes
        val eyeY = headY + 2f
        val es = hr * 0.32f
        drawEyes(c, cx - es, cx + es, eyeY)

        // Eyebrows
        drawBrows(c, cx - es, cx + es, eyeY - 16f)

        // Mouth
        drawMouth(c, cx, headY + hr * 0.38f)

        // Blush
        if (emotion in listOf("angry", "annoyed", "scolding")) {
            c.drawOval(RectF(cx - es - 14f, eyeY + 6f, cx - es + 2f, eyeY + 16f), blushPaint)
            c.drawOval(RectF(cx + es - 2f, eyeY + 6f, cx + es + 14f, eyeY + 16f), blushPaint)
        }

        c.restore()

        // Listen indicator
        if (isListeningAnim) {
            val iy = height - 15f
            c.drawCircle(cx, iy, 5f + listenPulse * 3f, listenPaint)
            c.drawCircle(cx, iy, 10f + listenPulse * 8f, listenRingPaint)
            c.drawCircle(cx, iy, 16f + listenPulse * 12f, listenRingPaint)
        }
    }

    private fun drawEyes(c: Canvas, lx: Float, rx: Float, y: Float) {
        when (emotion) {
            "angry", "scolding" -> {
                val ew = 10f; val eh = 5f * eyeScaleY
                c.drawOval(RectF(lx - ew, y - eh, lx + ew, y + eh), whitePaint)
                c.drawOval(RectF(rx - ew, y - eh, rx + ew, y + eh), whitePaint)
                c.drawCircle(lx, y, 3.5f * eyeScaleY, eyePaint)
                c.drawCircle(rx, y, 3.5f * eyeScaleY, eyePaint)
            }
            "happy", "proud" -> {
                val ap = Paint(eyePaint).apply { style = Paint.Style.STROKE; strokeWidth = 2.5f; strokeCap = Paint.Cap.ROUND }
                c.drawArc(RectF(lx - 7f, y - 5f, lx + 7f, y + 5f), 0f, -180f, false, ap)
                c.drawArc(RectF(rx - 7f, y - 5f, rx + 7f, y + 5f), 0f, -180f, false, ap)
            }
            "surprised" -> {
                c.drawCircle(lx, y, 9f * eyeScaleY, whitePaint); c.drawCircle(rx, y, 9f * eyeScaleY, whitePaint)
                c.drawCircle(lx, y, 4.5f, eyePaint); c.drawCircle(rx, y, 4.5f, eyePaint)
                c.drawCircle(lx - 2f, y - 2f, 1.5f, whitePaint); c.drawCircle(rx - 2f, y - 2f, 1.5f, whitePaint)
            }
            else -> {
                c.drawCircle(lx, y, 7f * eyeScaleY, whitePaint); c.drawCircle(rx, y, 7f * eyeScaleY, whitePaint)
                c.drawCircle(lx, y, 3.5f, eyePaint); c.drawCircle(rx, y, 3.5f, eyePaint)
                c.drawCircle(lx - 1.5f, y - 1.5f, 1.2f, whitePaint); c.drawCircle(rx - 1.5f, y - 1.5f, 1.2f, whitePaint)
            }
        }
    }

    private fun drawBrows(c: Canvas, lx: Float, rx: Float, y: Float) {
        when (emotion) {
            "angry", "scolding" -> {
                c.drawLine(lx - 10f, y - 4f, lx + 8f, y + 4f, browPaint)
                c.drawLine(rx + 10f, y - 4f, rx - 8f, y + 4f, browPaint)
            }
            "sad", "disappointed" -> {
                c.drawLine(lx - 8f, y + 3f, lx + 8f, y - 2f, browPaint)
                c.drawLine(rx + 8f, y + 3f, rx - 8f, y - 2f, browPaint)
            }
            "annoyed" -> {
                c.drawLine(lx - 8f, y, lx + 8f, y + 4f, browPaint)
                c.drawLine(rx + 8f, y - 4f, rx - 8f, y + 1f, browPaint)
            }
            "surprised" -> {
                c.drawLine(lx - 8f, y - 4f, lx + 8f, y - 4f, browPaint)
                c.drawLine(rx - 8f, y - 4f, rx + 8f, y - 4f, browPaint)
            }
            else -> {
                c.drawLine(lx - 7f, y, lx + 7f, y, browPaint)
                c.drawLine(rx - 7f, y, rx + 7f, y, browPaint)
            }
        }
    }

    private fun drawMouth(c: Canvas, cx: Float, y: Float) {
        if (mouthOpen > 0.3f) {
            c.drawOval(RectF(cx - 7f, y - mouthOpen * 6f, cx + 7f, y + mouthOpen * 6f), mouthFillPaint)
        } else {
            val path = Path()
            when (emotion) {
                "happy", "proud" -> {
                    path.moveTo(cx - 10f, y - 2f); path.quadTo(cx, y + 9f, cx + 10f, y - 2f)
                }
                "angry", "scolding", "annoyed" -> {
                    path.moveTo(cx - 9f, y + 3f); path.quadTo(cx, y - 5f, cx + 9f, y + 3f)
                }
                "sad", "disappointed" -> {
                    path.moveTo(cx - 7f, y + 2f); path.quadTo(cx, y - 4f, cx + 7f, y + 2f)
                }
                "surprised" -> { c.drawCircle(cx, y, 5f, mouthFillPaint); return }
                else -> { c.drawLine(cx - 7f, y, cx + 7f, y, mouthPaint); return }
            }
            c.drawPath(path, mouthPaint)
        }
    }
}

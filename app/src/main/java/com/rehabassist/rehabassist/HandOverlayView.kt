package com.rehabassist.rehabassist

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.util.AttributeSet
import android.view.View
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import android.graphics.DashPathEffect
import android.graphics.RadialGradient
import android.graphics.Shader

class HandOverlayView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null
) : View(context, attrs) {

    private var results: HandLandmarkerResult? = null
    private var imageWidth = 1
    private var imageHeight = 1
    private var rotation = 0

    // 狀態變數
    private var showStickGuide = false // 翻掌準備階段
    private var showPinchGuide = false // ✨ 新增：側捏階段開關
    private var currentProgress = 0f  // 通用進度 (0.0~1.0)
    private var currentSpeedState = 0 // 0:正常, 1:太快

    // --- 畫筆設定區 ---

    // 1. 通用文字 (陰影色)
    private val textPaint = Paint().apply {
        color = Color.WHITE
        textSize = 60f
        typeface = Typeface.DEFAULT_BOLD
        setShadowLayer(8f, 0f, 0f, Color.BLACK)
        textAlign = Paint.Align.CENTER
    }

    // 2. 翻掌專用：動態紅綠線
    private val badStickPaint = Paint().apply { color = Color.parseColor("#CCFF4B4B"); strokeWidth = 12f; style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
    private val goodStickPaint = Paint().apply { color = Color.parseColor("#CC4CAF50"); strokeWidth = 12f; style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }

    // 3. 翻掌專用：半圓進度條
    private val progressBgPaint = Paint().apply { color = Color.parseColor("#33FFFFFF"); style = Paint.Style.STROKE; strokeWidth = 20f; strokeCap = Paint.Cap.ROUND }
    private val progressFillPaint = Paint().apply { color = Color.GREEN; style = Paint.Style.STROKE; strokeWidth = 22f; strokeCap = Paint.Cap.ROUND }

    // 4. ✨ 側捏專用：指尖金色雷射線 (帶虛線效果)
    private val pinchLinePaint = Paint().apply {
        color = Color.parseColor("#FFD700") // 金色
        strokeWidth = 8f
        style = Paint.Style.STROKE
        pathEffect = DashPathEffect(floatArrayOf(15f, 10f), 0f)
        strokeCap = Paint.Cap.ROUND
        setShadowLayer(15f, 0f, 0f, Color.parseColor("#FFD700")) // 金色光暈
    }

    // 5. ✨ 側捏專用：捏緊時的綠色爆裂光圈 (Shader會在onDraw動態設定)
    private val pinchFillPaint = Paint().apply {
        style = Paint.Style.FILL
        isAntiAlias = true
    }

    // 6. 基礎骨架
    private val pointPaint = Paint().apply { color = Color.RED; strokeWidth = 12f; style = Paint.Style.FILL }
    private val linePaint = Paint().apply { color = Color.GREEN; strokeWidth = 5f; style = Paint.Style.STROKE }

    private val connections = listOf(
        0 to 1, 1 to 2, 2 to 3, 3 to 4, 0 to 5, 5 to 6, 6 to 7, 7 to 8,
        0 to 9, 9 to 10, 10 to 11, 11 to 12, 0 to 13, 13 to 14, 14 to 15, 15 to 16,
        0 to 17, 17 to 18, 18 to 19, 19 to 20
    )

    // --- 外部控制介面 ---

    // 翻掌準備階段
    fun setStickGuideEnabled(enabled: Boolean) {
        showStickGuide = enabled
        showPinchGuide = false
        postInvalidate()
    }

    // ✨ 側捏階段
    fun setPinchGuideEnabled(enabled: Boolean) {
        showPinchGuide = enabled
        showStickGuide = false
        currentProgress = 0f
        postInvalidate()
    }

    // 更新進度與狀態
    fun setProgress(progress: Float, speedState: Int) {
        this.currentProgress = progress
        this.currentSpeedState = speedState

        // 根據狀態調整畫筆顏色
        if (showPinchGuide) {
            // 側捏模式下，progress接近1代表捏緊，顏色變綠；接近0代表張開，顏色變金
            val red = (255 * (1 - progress)).toInt()
            val green = (215 + (40 * progress)).toInt()
            val blue = (0 * (1 - progress)).toInt()
            pinchLinePaint.color = Color.rgb(red, green, blue)
            pinchLinePaint.setShadowLayer(15f + 20f * progress, 0f, 0f, pinchLinePaint.color)
        } else {
            // 翻掌模式
            progressFillPaint.color = if (speedState == 1) Color.parseColor("#FF9800") else Color.GREEN
        }
        postInvalidate()
    }

    fun setResults(result: HandLandmarkerResult, imgWidth: Int, imgHeight: Int, rotation: Int = 0) {
        results = result
        imageWidth = imgWidth
        imageHeight = imgHeight
        this.rotation = rotation
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val result = results ?: return
        if (result.landmarks().isEmpty()) return
        val landmarks = result.landmarks()[0]

        // 1. 畫基礎手部骨架 (略透明，突出特效)
        linePaint.alpha = 100
        pointPaint.alpha = 100
        for ((start, end) in connections) {
            val s = landmarks[start]; val e = landmarks[end]
            val sx = if (rotation == 90 || rotation == 270) s.y() * width else s.x() * width
            val sy = if (rotation == 90 || rotation == 270) s.x() * height else s.y() * height
            val ex = if (rotation == 90 || rotation == 270) e.y() * width else e.x() * width
            val ey = if (rotation == 90 || rotation == 270) e.x() * height else e.y() * height
            canvas.drawLine(sx, sy, ex, ey, linePaint)
        }
        for (lm in landmarks) {
            val px = if (rotation == 90 || rotation == 270) lm.y() * width else lm.x() * width
            val py = if (rotation == 90 || rotation == 270) lm.x() * height else lm.y() * height
            canvas.drawCircle(px, py, 8f, pointPaint)
        }
        linePaint.alpha = 255
        pointPaint.alpha = 255

        val wrist = landmarks[0]
        val wx = if (rotation == 90 || rotation == 270) wrist.y() * width else wrist.x() * width
        val wy = if (rotation == 90 || rotation == 270) wrist.x() * height else wrist.y() * height

        // --- 翻掌特效區 ---

        // 階段一：動態紅綠線
        if (showStickGuide && landmarks.size >= 18) {
            val indexMcp = landmarks[5]; val pinkyMcp = landmarks[17]
            val ix = if (rotation == 90 || rotation == 270) indexMcp.y() * width else indexMcp.x() * width
            val iy = if (rotation == 90 || rotation == 270) indexMcp.x() * height else indexMcp.y() * height
            val px = if (rotation == 90 || rotation == 270) pinkyMcp.y() * width else pinkyMcp.x() * width
            val py = if (rotation == 90 || rotation == 270) pinkyMcp.x() * height else pinkyMcp.y() * height
            val dx = ix - px; val dy = iy - py
            val cx = (ix + px) / 2f; val cy = (iy + py) / 2f
            val angle = Math.toDegrees(Math.atan2(dy.toDouble(), dx.toDouble()))
            val deviation = Math.abs(angle - (-90.0))
            val displayAngle = (if (deviation > 180) 360 - deviation else deviation).toInt()
            val isStable = displayAngle <= 25
            val currentPaint = if (isStable) goodStickPaint else badStickPaint
            val lengthFactor = 4f
            canvas.drawLine(cx - dx * lengthFactor, cy - dy * lengthFactor, cx + dx * lengthFactor, cy + dy * lengthFactor, currentPaint)
            textPaint.color = if (isStable) Color.GREEN else Color.RED
            canvas.drawText(if (isStable) "完美對齊" else "偏差: $displayAngle°", cx, cy - 50f, textPaint)
        }

        // 階段二：半圓進度條
        if (!showStickGuide && !showPinchGuide && currentProgress > 0f) {
            val radius = 150f
            val oval = android.graphics.RectF(wx - radius, wy - radius - 100f, wx + radius, wy + radius - 100f)
            canvas.drawArc(oval, 180f, 180f, false, progressBgPaint)
            canvas.drawArc(oval, 180f, 180f * currentProgress, false, progressFillPaint)
            if (currentSpeedState == 1) {
                textPaint.color = Color.parseColor("#FF9800")
                canvas.drawText("⚠️ 慢一點！", wx, wy - radius - 150f, textPaint)
            }
        }

        // --- ✨ 側捏特效區 ✨ ---
        if (showPinchGuide && landmarks.size >= 9) {
            val thumbTip = landmarks[4] // 大拇指指尖
            val indexPip = landmarks[6] // 食指第二關節 (側捏接觸點)

            val tx = if (rotation == 90 || rotation == 270) thumbTip.y() * width else thumbTip.x() * width
            val ty = if (rotation == 90 || rotation == 270) thumbTip.x() * height else thumbTip.y() * height
            val idx = if (rotation == 90 || rotation == 270) indexPip.y() * width else indexPip.x() * width
            val idy = if (rotation == 90 || rotation == 270) indexPip.x() * height else indexPip.y() * height

            // 1. 畫指尖之間的「金色雷射連線」
            canvas.drawLine(tx, ty, idx, idy, pinchLinePaint)

            // 2. 當捏緊時 (progress > 0.9)，在接觸點畫出「綠色爆裂光圈」
            if (currentProgress > 0.9f) {
                val centerX = (tx + idx) / 2f
                val centerY = (ty + idy) / 2f

                // 動態縮放光圈，做出呼吸感
                val pulse = (Math.sin(System.currentTimeMillis() / 100.0) * 10f).toFloat()
                val radius = 60f + pulse

                // 設置徑向漸變 (中心綠色 -> 外圈透明)
                val gradient = RadialGradient(
                    centerX, centerY, radius,
                    intArrayOf(Color.parseColor("#00FF00"), Color.parseColor("#8000FF00"), Color.TRANSPARENT),
                    floatArrayOf(0f, 0.5f, 1f),
                    Shader.TileMode.CLAMP
                )
                pinchFillPaint.shader = gradient
                canvas.drawCircle(centerX, centerY, radius, pinchFillPaint)

                textPaint.color = Color.GREEN
                canvas.drawText("✨ 捏緊了！", centerX, centerY - radius - 30f, textPaint)
            } else if (currentProgress < 0.1f) {
                // 完全張開時提示
                val centerX = (tx + idx) / 2f
                val centerY = (ty + idy) / 2f
                textPaint.color = Color.parseColor("#FFD700") // 金色
                canvas.drawText("👐 請張開", centerX, centerY - 50f, textPaint)
            }
        }
    }
}
package com.rehabassist.rehabassist

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult

class HandOverlayView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null
) : View(context, attrs) {

    private var results: HandLandmarkerResult? = null
    private var imageWidth = 1
    private var imageHeight = 1

    private val pointPaint = Paint().apply {
        color = Color.RED
        strokeWidth = 12f
        style = Paint.Style.FILL
    }

    private val linePaint = Paint().apply {
        color = Color.GREEN
        strokeWidth = 5f
        style = Paint.Style.STROKE
    }

    // MediaPipe Hand 連線定義
    private val connections = listOf(
        0 to 1, 1 to 2, 2 to 3, 3 to 4,       // 拇指
        0 to 5, 5 to 6, 6 to 7, 7 to 8,       // 食指
        0 to 9, 9 to 10, 10 to 11, 11 to 12,  // 中指
        0 to 13, 13 to 14, 14 to 15, 15 to 16, // 無名指
        0 to 17, 17 to 18, 18 to 19, 19 to 20  // 小指
    )

    private var isFrontCamera = false
    private var rotation = 0

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

        for ((start, end) in connections) {
            val s = landmarks[start]
            val e = landmarks[end]
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
    }
}
package com.rehabassist.rehabassist

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import androidx.camera.core.CameraSelector
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult

// 🌟 全身骨架專屬畫筆 (修正鏡像版)
class PoseOverlayView(context: Context?, attrs: AttributeSet?) : View(context, attrs) {

    private var results: PoseLandmarkerResult? = null

    // ✨ 新增：記錄目前是否為鏡像模式 (前鏡頭)
    private var isMirrored = false

    // 🎨 畫筆樣式
    private val landmarkPaint = Paint().apply {
        color = Color.RED
        style = Paint.Style.FILL
        strokeWidth = 12f
        isAntiAlias = true
    }
    private val linePaint = Paint().apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 6f
        isAntiAlias = true
    }

    // ✨ 修改：setResults 增加傳入鏡頭方向
    fun setResults(
        poseLandmarkerResult: PoseLandmarkerResult,
        lensFacing: Int // 傳入 CameraSelector.LENS_FACING_FRONT/BACK
    ) {
        this.results = poseLandmarkerResult
        // 如果是前鏡頭，就開啟鏡像修正
        this.isMirrored = (lensFacing == CameraSelector.LENS_FACING_FRONT)
        postInvalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        results?.let { poseLandmarkerResult ->
            for (landmarks in poseLandmarkerResult.landmarks()) {

                // 1. 畫全身的 33 個紅點 (修正座標)
                for (landmark in landmarks) {
                    val correctedX = if (isMirrored) {
                        // ✨ 鏡像魔法：1.0 - 原本的X，就把左變右、右變左了！
                        (1.0f - landmark.x()) * width
                    } else {
                        landmark.x() * width
                    }
                    val py = landmark.y() * height
                    canvas.drawPoint(correctedX, py, landmarkPaint)
                }

                // 2. 畫出身體的連線 (修正座標)
                // 肩膀(11-12), 軀幹(11-23, 12-24, 23-24)
                drawLine(canvas, landmarks[11], landmarks[12])
                drawLine(canvas, landmarks[11], landmarks[23])
                drawLine(canvas, landmarks[12], landmarks[24])
                drawLine(canvas, landmarks[23], landmarks[24])

                // 左手臂：肩膀-手肘(11-13), 手肘-手腕(13-15)
                drawLine(canvas, landmarks[11], landmarks[13])
                drawLine(canvas, landmarks[13], landmarks[15])

                // 右手臂：肩膀-手肘(12-14), 手肘-手腕(14-16)
                drawLine(canvas, landmarks[12], landmarks[14])
                drawLine(canvas, landmarks[14], landmarks[16])
            }
        }
    }

    // ✨ 修改 drawLine 工具函式，套用鏡像邏輯
    private fun drawLine(
        canvas: Canvas,
        start: com.google.mediapipe.tasks.components.containers.NormalizedLandmark,
        end: com.google.mediapipe.tasks.components.containers.NormalizedLandmark
    ) {
        val startX = if (isMirrored) (1.0f - start.x()) * width else start.x() * width
        val endX = if (isMirrored) (1.0f - end.x()) * width else end.x() * width

        canvas.drawLine(
            startX, start.y() * height,
            endX, end.y() * height,
            linePaint
        )
    }
}
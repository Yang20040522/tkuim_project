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

    // ✨ 新增：目前的骨架顯示模式，預設為全身
    private var currentMode: String = "FULL_BODY"

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

    // ==========================================
    // ✨ 定義各種部位的連線與點位
    // ==========================================

    // 1. 僅手臂與肩膀 (適合畫圓、側捏代償偵測)
    private val armConnections = listOf(
        11 to 13, 13 to 15, 15 to 17, 15 to 19, 15 to 21, // 左手臂與手掌
        12 to 14, 14 to 16, 16 to 18, 16 to 20, 16 to 22, // 右手臂與手掌
        11 to 12 // 肩膀連線
    )
    private val armPoints = (11..22).toList()

    // 2. 上半身 (適合擦拭、穿衣訓練)
    private val upperBodyConnections = armConnections + listOf(
        11 to 23, 12 to 24, 23 to 24, // 身體軀幹
        0 to 1, 1 to 2, 2 to 3, 3 to 7, // 臉部左
        0 to 4, 4 to 5, 5 to 6, 6 to 8  // 臉部右
    )
    private val upperBodyPoints = (0..24).toList()

    // 3. 全身 (適合深蹲、站立平衡)
    private val fullBodyConnections = upperBodyConnections + listOf(
        23 to 25, 25 to 27, 27 to 29, 27 to 31, 29 to 31, // 左腳
        24 to 26, 26 to 28, 28 to 30, 28 to 32, 30 to 32  // 右腳
    )
    private val fullBodyPoints = (0..32).toList()

    // ==========================================

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

    // ✨ 讓外部決定要畫哪種骨架
    fun setSkeletonMode(mode: String) {
        currentMode = mode
        postInvalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        results?.let { poseLandmarkerResult ->
            for (landmarks in poseLandmarkerResult.landmarks()) {

                // ✨ 根據目前模式，選擇要畫的連線和點位
                val (activeConnections, activePoints) = when (currentMode) {
                    "ARMS_ONLY" -> armConnections to armPoints
                    "UPPER_BODY" -> upperBodyConnections to upperBodyPoints
                    else -> fullBodyConnections to fullBodyPoints
                }

                // 1. 畫關節點 (取代原本寫死的 33 個點，只畫有需要的)
                for (index in activePoints) {
                    val landmark = landmarks[index]
                    val correctedX = if (isMirrored) {
                        // ✨ 鏡像魔法：1.0 - 原本的X，就把左變右、右變左了！
                        (1.0f - landmark.x()) * width
                    } else {
                        landmark.x() * width
                    }
                    val py = landmark.y() * height
                    canvas.drawPoint(correctedX, py, landmarkPaint)
                }

                // 2. 畫出身體的連線 (取代原本寫死的連線)
                for ((start, end) in activeConnections) {
                    drawLine(canvas, landmarks[start], landmarks[end])
                }
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
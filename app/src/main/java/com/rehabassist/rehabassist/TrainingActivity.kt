package com.rehabassist.rehabassist

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.SystemClock
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class TrainingActivity : AppCompatActivity() {

    // UI 元件
    private lateinit var previewView: PreviewView
    private lateinit var overlayView: HandOverlayView
    private lateinit var btnStop: Button

    // 文字顯示元件
    private lateinit var tvTitle: TextView
    private lateinit var tvFeedback: TextView
    private lateinit var tvInstruction: TextView
    private lateinit var tvRepCount: TextView
    private lateinit var tvAccuracy: TextView

    // MediaPipe 與相機
    private lateinit var cameraExecutor: ExecutorService
    private var handLandmarker: HandLandmarker? = null

    // 動作類型管理
    private var currentActionType = "TURN_PALM"

    // 通用狀態管理
    private var currentStage = 1
    private var lastImageWidth = 1
    private var lastImageHeight = 1
    private var lastRotation = 0
    private var repCount = 0
    private val smoothingFactor = 0.2

    // 翻掌 (動作1) 專用變數
    private var smoothedAngleStage1 = 0.0
    private var smoothedAngleStage2 = 0.0
    private var holdStartTime: Long = 0L
    private var isCurrentlyStable = false
    private var palmStateBuffer = mutableListOf<String>()
    private var lastConfirmedState = ""

    // --- 側捏 (動作2) 專用變數 (新增) ---
    private var pinchStateBuffer = mutableListOf<String>()
    private var lastConfirmedPinchState = ""
    private var smoothedPinchDistance = 0.0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_training)

        previewView = findViewById(R.id.previewView)
        overlayView = findViewById(R.id.overlayView)
        btnStop = findViewById(R.id.btnStop)

        tvTitle = findViewById(R.id.tvTitle)
        tvFeedback = findViewById(R.id.tvFeedback)
        tvInstruction = findViewById(R.id.tvInstruction)
        tvRepCount = findViewById(R.id.tvRepCount)
        tvAccuracy = findViewById(R.id.tvAccuracy)

        // 接收首頁傳來的選擇
        currentActionType = intent.getStringExtra("ACTION_TYPE") ?: "TURN_PALM"

        // 根據選擇設定初始標題與文字
        if (currentActionType == "TURN_PALM") {
            tvTitle.text = "初階翻掌訓練 - 階段一：穩定度"
            tvInstruction.text = "請握住棍子保持直立"
        } else if (currentActionType == "SECOND_ACTION") {
            tvTitle.text = "手部精細動作 - 側捏訓練"
            tvInstruction.text = "請用大拇指與食指側邊進行捏合"
        }

        tvRepCount.text = "0 / 10"

        cameraExecutor = Executors.newSingleThreadExecutor()
        btnStop.setOnClickListener { finish() }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED) {
            setupMediaPipe()
            startCamera()
        } else {
            ActivityCompat.requestPermissions(this,
                arrayOf(Manifest.permission.CAMERA), 100)
        }
    }

    private fun setupMediaPipe() {
        try {
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath("hand_landmarker.task")
                .build()
            val options = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setNumHands(1)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener { result, _ -> processResult(result) }
                .setErrorListener { error ->
                    runOnUiThread {
                        tvFeedback.text = "系統錯誤"
                        tvInstruction.text = error.message
                    }
                }
                .build()
            handLandmarker = HandLandmarker.createFromOptions(this, options)
        } catch (e: Exception) {
            runOnUiThread {
                tvFeedback.text = "初始化失敗"
                tvInstruction.text = e.message
            }
        }
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()
            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }
            val imageAnalyzer = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .build()
                .also {
                    it.setAnalyzer(cameraExecutor) { imageProxy ->
                        val rotation = imageProxy.imageInfo.rotationDegrees
                        val bitmap = imageProxy.toBitmap()
                        val rotatedBitmap = rotateBitmap(bitmap, rotation)
                        lastImageWidth = rotatedBitmap.width
                        lastImageHeight = rotatedBitmap.height
                        lastRotation = 0
                        val mpImage = BitmapImageBuilder(rotatedBitmap).build()
                        handLandmarker?.detectAsync(mpImage, SystemClock.uptimeMillis())
                        imageProxy.close()
                    }
                }
            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(
                this, CameraSelector.DEFAULT_BACK_CAMERA, preview, imageAnalyzer)
        }, ContextCompat.getMainExecutor(this))
    }

    private fun processResult(result: HandLandmarkerResult) {
        runOnUiThread {
            overlayView.setResults(result, lastImageWidth, lastImageHeight, lastRotation)

            if (result.landmarks().isEmpty()) {
                tvFeedback.text = "請將手放入鏡頭範圍內"
                tvInstruction.text = "等待偵測中..."
                tvAccuracy.text = "--"
                return@runOnUiThread
            }

            val landmarks = result.landmarks()[0]

            // 核心分流：根據選單選擇，執行對應的動作邏輯
            when (currentActionType) {
                "TURN_PALM" -> processTurnPalm(landmarks)
                "SECOND_ACTION" -> processSecondAction(landmarks) // 進入側捏邏輯
            }
        }
    }

    // ==========================================
    // 動作 1：初階翻掌訓練
    // ==========================================
    private fun processTurnPalm(landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>) {
        when (currentStage) {
            1 -> detectStage1(landmarks)
            2 -> detectStage2(landmarks)
        }
    }

    // ==========================================
    // 動作 2：側捏訓練 (精準觀測與自訂數值版)
    // ==========================================
    private fun processSecondAction(landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>) {
        // 1. 換回最準確的側捏接觸點：大拇指尖 (4) vs 食指第二關節 (6)
        val thumbTip = landmarks[4]
        val indexPip = landmarks[6]

        val wrist = landmarks[0]
        val middleMcp = landmarks[9]

        // 2. 動態比例尺 (手掌長度)
        val palmDx = (middleMcp.x() - wrist.x()).toDouble()
        val palmDy = (middleMcp.y() - wrist.y()).toDouble()
        val palmLength = Math.sqrt(palmDx * palmDx + palmDy * palmDy)

        // 3. 計算距離並轉換為比例 (乘以 100)
        val pinchDx = (thumbTip.x() - indexPip.x()).toDouble()
        val pinchDy = (thumbTip.y() - indexPip.y()).toDouble()
        val rawPinchDistance = Math.sqrt(pinchDx * pinchDx + pinchDy * pinchDy)

        val pinchRatio = (rawPinchDistance / palmLength) * 100
        smoothedPinchDistance = (smoothingFactor * pinchRatio) + ((1 - smoothingFactor) * smoothedPinchDistance)

        // 🌟 核心關鍵：請在測試時，死死盯著畫面上這個數字！ 🌟
        tvAccuracy.text = "捏合度: ${String.format("%.1f", smoothedPinchDistance)}"

        // =========================================================
        // 🛠️ 工程師調校區 🛠️
        // 下面這兩個數字，請根據你「畫面上看到的捏合度」來修改！
        // =========================================================
        val pinchThreshold = 45.0 // 當數字【小於】多少時，算「捏緊」？ (可微調)
        val openThreshold = 65.0  // 當數字【大於】多少時，算「打開」？ (可微調)

        val currentState = when {
            smoothedPinchDistance < pinchThreshold -> "PINCHED"
            smoothedPinchDistance > openThreshold -> "OPENED"
            else -> "MID"
        }

        // 防抖邏輯
        pinchStateBuffer.add(currentState)
        if (pinchStateBuffer.size > 8) pinchStateBuffer.removeAt(0)

        val pinchCount = pinchStateBuffer.count { it == "PINCHED" }
        val openCount = pinchStateBuffer.count { it == "OPENED" }

        val isStablePinch = pinchCount >= 5
        val isStableOpen = openCount >= 5

        // 狀態切換與計次
        if (isStablePinch && lastConfirmedPinchState != "PINCHED") {
            lastConfirmedPinchState = "PINCHED"
            tvFeedback.text = "✅ 捏住了！"
            tvInstruction.text = "很好，請接著把手指打開"
        } else if (isStableOpen && lastConfirmedPinchState != "OPENED") {
            if (lastConfirmedPinchState == "PINCHED") {
                repCount++
            }
            lastConfirmedPinchState = "OPENED"
            tvFeedback.text = "✅ 打開了！"
            tvInstruction.text = "很好，請試著往下捏"
        } else if (!isStablePinch && !isStableOpen) {
            tvFeedback.text = "動作中..."
            tvInstruction.text = "請確實捏緊與打開"
        }

        tvRepCount.text = "$repCount / 10"

        if (repCount >= 10) {
            tvFeedback.text = "🎉 訓練圓滿結束！"
            tvInstruction.text = "請按下停止按鈕"
        }
    }

    // --- 下方的 detectStage1, detectStage2, rotateBitmap 保持不變 ---
    private fun detectStage1(landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>) {
        val wrist = landmarks[0]
        val middleMcp = landmarks[9]

        val deltaX = (middleMcp.x() - wrist.x()).toDouble()
        val deltaY = (middleMcp.y() - wrist.y()).toDouble()
        val angle = Math.toDegrees(Math.atan2(deltaY, deltaX))
        val tiltDeviation = Math.abs(angle - (-90.0))
        val rawDeviation = if (tiltDeviation > 180) 360 - tiltDeviation else tiltDeviation

        smoothedAngleStage1 = (smoothingFactor * rawDeviation) + ((1 - smoothingFactor) * smoothedAngleStage1)
        val displayAngle = smoothedAngleStage1.toInt()

        tvAccuracy.text = "${displayAngle}°"
        tvRepCount.text = "$repCount / 10"

        val toleranceAngle = 20.0

        if (displayAngle < toleranceAngle) {
            if (!isCurrentlyStable) {
                isCurrentlyStable = true
                holdStartTime = SystemClock.uptimeMillis()
                tvFeedback.text = "✅ 很好！保持住"
            } else {
                val holdDuration = SystemClock.uptimeMillis() - holdStartTime

                if (holdDuration >= 2000L) {
                    repCount++
                    isCurrentlyStable = false
                    holdStartTime = SystemClock.uptimeMillis()
                } else {
                    tvInstruction.text = "已維持: ${String.format("%.1f", holdDuration / 1000.0)}s / 2.0s"
                }
            }
        } else {
            isCurrentlyStable = false
            tvFeedback.text = if (deltaX > 0) "⚠️ 往右倒了" else "⚠️ 往左倒了"
            tvInstruction.text = "請拉正以恢復計時"
        }

        if (repCount >= 10) {
            currentStage = 2
            repCount = 0
            palmStateBuffer.clear()
            tvTitle.text = "初階翻掌訓練 - 階段二：翻掌"
            tvFeedback.text = "🎉 階段一完成！"
        }
    }

    private fun detectStage2(landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>) {
        val indexMcp = landmarks[5]
        val pinkyMcp = landmarks[17]

        val deltaY = (pinkyMcp.y() - indexMcp.y()).toDouble()
        val deltaX = (pinkyMcp.x() - indexMcp.x()).toDouble()
        val rawAngle = Math.toDegrees(Math.atan2(deltaY, deltaX))

        smoothedAngleStage2 = (smoothingFactor * rawAngle) + ((1 - smoothingFactor) * smoothedAngleStage2)
        val displayAngle = smoothedAngleStage2.toInt()

        val normalizedDisplayAngle = if (displayAngle < 0) displayAngle + 360 else displayAngle
        tvAccuracy.text = "${normalizedDisplayAngle}°"

        val currentState = when {
            normalizedDisplayAngle > 140 && normalizedDisplayAngle < 220 -> "UP"
            normalizedDisplayAngle < 40 || normalizedDisplayAngle > 320 -> "DOWN"
            else -> "MID"
        }

        palmStateBuffer.add(currentState)
        if (palmStateBuffer.size > 8) palmStateBuffer.removeAt(0)

        val upCount = palmStateBuffer.count { it == "UP" }
        val downCount = palmStateBuffer.count { it == "DOWN" }

        val isStableUP = upCount >= 6
        val isStableDOWN = downCount >= 6

        if (isStableUP && lastConfirmedState != "UP") {
            if (lastConfirmedState == "DOWN") repCount++
            lastConfirmedState = "UP"
            tvFeedback.text = "✅ 掌心朝上！"
            tvInstruction.text = "很好，請接著往下翻轉"
        } else if (isStableDOWN && lastConfirmedState != "DOWN") {
            if (lastConfirmedState == "UP") repCount++
            lastConfirmedState = "DOWN"
            tvFeedback.text = "✅ 掌心朝下！"
            tvInstruction.text = "很好，請接著往上翻轉"
        } else if (!isStableUP && !isStableDOWN){
            tvFeedback.text = "翻掌中..."
            tvInstruction.text = "請動作確實，轉到極限"
        }

        tvRepCount.text = "$repCount / 10"

        if (repCount >= 10) {
            tvFeedback.text = "🎉 訓練圓滿結束！"
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 100 && grantResults.isNotEmpty()
            && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            setupMediaPipe()
            startCamera()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
        handLandmarker?.close()
    }

    private fun rotateBitmap(bitmap: android.graphics.Bitmap, degrees: Int): android.graphics.Bitmap {
        if (degrees == 0) return bitmap
        val matrix = android.graphics.Matrix()
        matrix.postRotate(degrees.toFloat())
        return android.graphics.Bitmap.createBitmap(
            bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
}
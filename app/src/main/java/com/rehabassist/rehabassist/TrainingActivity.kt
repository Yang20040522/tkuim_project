package com.rehabassist.rehabassist

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.SystemClock
import android.speech.tts.TextToSpeech
import android.util.Log
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
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class TrainingActivity : AppCompatActivity() {

    // UI 元件
    private lateinit var previewView: PreviewView
    private lateinit var overlayView: HandOverlayView
    private lateinit var btnStop: Button
    private lateinit var tvTitle: TextView
    private lateinit var tvFeedback: TextView
    private lateinit var tvInstruction: TextView
    private lateinit var tvRepCount: TextView
    private lateinit var tvAccuracy: TextView

    // MediaPipe 與相機
    private lateinit var cameraExecutor: ExecutorService
    private var handLandmarker: HandLandmarker? = null

    // 語音回饋 (TTS) 與冷卻邏輯
    private var textToSpeech: TextToSpeech? = null
    private var lastSpeakTime = 0L
    private val speakCooldown = 1500L

    // 動作與狀態管理
    private var currentActionType = "TURN_PALM"
    private var currentStage = 1
    private var lastImageWidth = 1
    private var lastImageHeight = 1
    private var lastRotation = 0
    private var repCount = 0
    private val smoothingFactor = 0.2

    // 轉場與配速控制
    private var lastRepTime = 0L
    private var isTransitioning = false
    private var transitionStartTime = 0L
    private var lastCountdownSec = -1

    // 終極防護鎖
    private var isTrainingComplete = false

    // 翻掌 (動作1) 專用變數
    private var smoothedAngleStage1 = 0.0
    private var smoothedAngleStage2 = 0.0
    private var holdStartTime: Long = 0L
    private var isCurrentlyStable = false
    private var palmStateBuffer = mutableListOf<String>()
    private var lastConfirmedState = ""

    // 側捏 (動作2) 專用變數
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

        textToSpeech = TextToSpeech(this, { status ->
            if (status == TextToSpeech.SUCCESS) {
                val locale = Locale.TAIWAN
                textToSpeech?.language = locale
                textToSpeech?.setSpeechRate(0.95f)
                textToSpeech?.setPitch(1.1f)
            }
        }, "com.google.android.tts")

        currentActionType = intent.getStringExtra("ACTION_TYPE") ?: "TURN_PALM"
        setupInitialUI()

        cameraExecutor = Executors.newSingleThreadExecutor()
        btnStop.setOnClickListener { finish() }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            setupMediaPipe()
            startCamera()
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), 100)
        }
    }

    private fun speakSafe(text: String, isUrgent: Boolean = false) {
        if (isTrainingComplete && !text.contains("完成")) return
        val currentTime = SystemClock.uptimeMillis()

        if (isUrgent) {
            textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, null)
            lastSpeakTime = currentTime
            return
        }
        if (currentTime - lastSpeakTime > speakCooldown) {
            textToSpeech?.speak(text, TextToSpeech.QUEUE_ADD, null, null)
            lastSpeakTime = currentTime
        }
    }

    // 🌟 徹底修復的計數語音 (轉成中文字，保證不被吞音)
    private fun speakCount() {
        if (repCount <= 0 || repCount > 10) return

        val numWords = arrayOf("零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十")
        when (repCount) {
            1 -> speakSafe("第一下，很好", isUrgent = true) // 強制唸出第一下
            5 -> speakSafe("五下，堅持住", isUrgent = true)
            8 -> speakSafe("八，快完成了", isUrgent = true)
            10 -> return
            else -> speakSafe(numWords[repCount], isUrgent = true)
        }
    }

    private fun setupInitialUI() {
        if (currentActionType == "TURN_PALM") {
            tvTitle.text = "初階翻掌訓練 - 階段一：穩定度"
            tvInstruction.text = "請握住棍子保持直立 5 秒"
            tvRepCount.text = "0.0s / 5.0s"
        } else if (currentActionType == "SECOND_ACTION") {
            tvTitle.text = "手部精細動作 - 側捏訓練"
            tvInstruction.text = "請先將手指完全打開" // 明確起始動作
            tvRepCount.text = "0 / 10"
        }
    }

    private fun setupMediaPipe() {
        try {
            val baseOptions = BaseOptions.builder().setModelAssetPath("hand_landmarker.task").build()
            val options = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setNumHands(1)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener { result, _ -> processResult(result) }
                .build()
            handLandmarker = HandLandmarker.createFromOptions(this, options)
        } catch (e: Exception) {
            runOnUiThread { tvFeedback.text = "初始化失敗" }
        }
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()
            val preview = Preview.Builder().build().also { it.setSurfaceProvider(previewView.surfaceProvider) }
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
                        val mpImage = BitmapImageBuilder(rotatedBitmap).build()
                        handLandmarker?.detectAsync(mpImage, SystemClock.uptimeMillis())
                        imageProxy.close()
                    }
                }
            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, preview, imageAnalyzer)
        }, ContextCompat.getMainExecutor(this))
    }

    private fun processResult(result: HandLandmarkerResult) {
        runOnUiThread {
            if (isTrainingComplete) return@runOnUiThread

            overlayView.setResults(result, lastImageWidth, lastImageHeight, 0)
            if (result.landmarks().isEmpty()) {
                if (!isTransitioning) {
                    tvFeedback.text = "請將手放入鏡頭範圍內"
                    tvInstruction.text = "等待偵測中..."
                }
                tvAccuracy.text = "--"
                return@runOnUiThread
            }

            val landmarks = result.landmarks()[0]

            if (isTransitioning) {
                handleTransition()
                return@runOnUiThread
            }

            when (currentActionType) {
                "TURN_PALM" -> processTurnPalm(landmarks)
                "SECOND_ACTION" -> processSecondAction(landmarks)
            }
        }
    }

    private fun handleTransition() {
        val elapsed = SystemClock.uptimeMillis() - transitionStartTime
        if (elapsed < 3000L) {
            val remain = 3 - (elapsed / 1000).toInt()
            tvFeedback.text = "⏳ 準備進入階段二"
            tvInstruction.text = "請在 $remain 秒後開始上下翻掌"

            if (remain != lastCountdownSec && remain > 0) {
                speakSafe(remain.toString(), isUrgent = true)
                lastCountdownSec = remain
            }
        } else {
            isTransitioning = false
            currentStage = 2
            repCount = 0
            lastRepTime = SystemClock.uptimeMillis()
            palmStateBuffer.clear()
            lastConfirmedState = ""
            lastCountdownSec = -1

            tvTitle.text = "初階翻掌訓練 - 階段二：翻掌"
            tvRepCount.text = "0 / 10"
            tvInstruction.text = "請將掌心朝上作為起點"
            speakSafe("開始翻掌", isUrgent = true)
        }
    }

    private fun processTurnPalm(landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>) {
        when (currentStage) {
            1 -> detectStage1(landmarks)
            2 -> detectStage2(landmarks)
        }
    }

    // 🌟 重新設計的側捏邏輯 (完整循環制 + 文字清晰化)
    private fun processSecondAction(landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>) {
        val thumbTip = landmarks[4]
        val indexPip = landmarks[6]
        val wrist = landmarks[0]
        val middleMcp = landmarks[9]

        val palmLen = Math.sqrt(Math.pow((middleMcp.x() - wrist.x()).toDouble(), 2.0) + Math.pow((middleMcp.y() - wrist.y()).toDouble(), 2.0))
        val pinchDist = Math.sqrt(Math.pow((thumbTip.x() - indexPip.x()).toDouble(), 2.0) + Math.pow((thumbTip.y() - indexPip.y()).toDouble(), 2.0))
        val ratio = (pinchDist / palmLen) * 100
        smoothedPinchDistance = (smoothingFactor * ratio) + ((1 - smoothingFactor) * smoothedPinchDistance)

        tvAccuracy.text = "捏合度: ${String.format("%.1f", smoothedPinchDistance)}"

        val pinchThreshold = 45.0
        val openThreshold = 65.0
        val currentState = when {
            smoothedPinchDistance < pinchThreshold -> "PINCHED"
            smoothedPinchDistance > openThreshold -> "OPENED"
            else -> "MID"
        }

        pinchStateBuffer.add(currentState)
        if (pinchStateBuffer.size > 8) pinchStateBuffer.removeAt(0)

        val isStablePinch = pinchStateBuffer.count { it == "PINCHED" } >= 5
        val isStableOpen = pinchStateBuffer.count { it == "OPENED" } >= 5

        if (isStablePinch && lastConfirmedPinchState != "PINCHED") {
            lastConfirmedPinchState = "PINCHED"
            tvFeedback.text = "✅ 捏緊了！"
            tvInstruction.text = "很好，請將手指完全打開" // 明確指示下一步

        } else if (isStableOpen && lastConfirmedPinchState != "OPENED") {
            if (lastConfirmedPinchState == "PINCHED") {
                // 從捏緊到打開，算完成 1 個完整循環
                val now = SystemClock.uptimeMillis()
                if (now - lastRepTime > 1200L) {
                    repCount++
                    lastRepTime = now
                    speakCount()
                    tvFeedback.text = "✅ 完成一次！"
                    tvInstruction.text = "請再次將手指捏緊"
                } else {
                    lastRepTime = now
                    speakSafe("太快了", isUrgent = true)
                    tvFeedback.text = "⚠️ 動作太快"
                    tvInstruction.text = "請放慢速度，重新捏合"
                }
            } else {
                // 剛啟動，第一次把手打開
                tvFeedback.text = "✅ 起始動作完成"
                tvInstruction.text = "請開始將手指捏緊"
            }
            lastConfirmedPinchState = "OPENED"

        } else if (!isStablePinch && !isStableOpen) {
            // 過渡狀態中的文字變化
            if (lastConfirmedPinchState == "OPENED") tvInstruction.text = "捏合中..."
            else if (lastConfirmedPinchState == "PINCHED") tvInstruction.text = "打開中..."
        }

        tvRepCount.text = "$repCount / 10"
        checkCompletion()
    }

    private fun detectStage1(landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>) {
        val wrist = landmarks[0]
        val middleMcp = landmarks[9]
        val dx = (middleMcp.x() - wrist.x()).toDouble()
        val dy = (middleMcp.y() - wrist.y()).toDouble()
        val angle = Math.toDegrees(Math.atan2(dy, dx))
        val deviation = Math.abs(angle - (-90.0))
        val rawDev = if (deviation > 180) 360 - deviation else deviation

        smoothedAngleStage1 = (smoothingFactor * rawDev) + ((1 - smoothingFactor) * smoothedAngleStage1)
        val displayAngle = smoothedAngleStage1.toInt()
        tvAccuracy.text = "${displayAngle}°"

        val targetHoldTime = 5000L

        if (displayAngle < 20) {
            if (!isCurrentlyStable) {
                isCurrentlyStable = true
                holdStartTime = SystemClock.uptimeMillis()
                tvFeedback.text = "✅ 很好！保持住"
            } else {
                val duration = SystemClock.uptimeMillis() - holdStartTime
                val seconds = duration / 1000.0
                tvInstruction.text = "請保持直立不要晃動"
                tvRepCount.text = String.format("%.1fs / 5.0s", seconds)

                if (duration >= targetHoldTime) {
                    isCurrentlyStable = false
                    isTransitioning = true
                    transitionStartTime = SystemClock.uptimeMillis()

                    tvTitle.text = "初階翻掌訓練 - 階段一完成"
                    tvFeedback.text = "🎉 穩定度測試通過！"
                    tvRepCount.text = ""
                    speakSafe("穩定度通過，準備轉場", isUrgent = true)
                }
            }
        } else {
            isCurrentlyStable = false
            val direction = if (dx > 0) "往右倒了" else "往左倒了"
            tvFeedback.text = "⚠️ $direction"
            tvInstruction.text = "請拉正以恢復計時"
            tvRepCount.text = "0.0s / 5.0s"
            speakSafe("請拿正", isUrgent = true)
        }
    }

    // 🌟 重新設計的翻掌邏輯 (完整循環制)
    private fun detectStage2(landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>) {
        val indexMcp = landmarks[5]
        val pinkyMcp = landmarks[17]
        val dx = (pinkyMcp.x() - indexMcp.x()).toDouble()
        val dy = (pinkyMcp.y() - indexMcp.y()).toDouble()
        val rawAngle = Math.toDegrees(Math.atan2(dy, dx))
        val normAngle = (rawAngle + 360) % 360

        smoothedAngleStage2 = (smoothingFactor * normAngle) + ((1 - smoothingFactor) * smoothedAngleStage2)
        tvAccuracy.text = "${smoothedAngleStage2.toInt()}°"

        val state = when {
            smoothedAngleStage2 in 140.0..220.0 -> "UP"
            smoothedAngleStage2 < 40.0 || smoothedAngleStage2 > 320.0 -> "DOWN"
            else -> "MID"
        }

        palmStateBuffer.add(state)
        if (palmStateBuffer.size > 8) palmStateBuffer.removeAt(0)

        // 規則：以「掌心朝上 (UP)」作為計數的結算點。
        // DOWN -> UP 算 1 個循環。
        if (palmStateBuffer.count { it == "UP" } >= 6 && lastConfirmedState != "UP") {
            if (lastConfirmedState == "DOWN") {
                val now = SystemClock.uptimeMillis()
                if (now - lastRepTime > 1200L) { // 放寬一點時間要求
                    repCount++
                    lastRepTime = now
                    speakCount()
                    tvFeedback.text = "✅ 完成一次！"
                } else {
                    lastRepTime = now
                    speakSafe("太快了", isUrgent = true)
                    tvFeedback.text = "⚠️ 動作太快"
                }
            } else {
                tvFeedback.text = "✅ 掌心朝上"
            }
            lastConfirmedState = "UP"
            tvInstruction.text = "請將掌心往下翻"

        } else if (palmStateBuffer.count { it == "DOWN" } >= 6 && lastConfirmedState != "DOWN") {
            // 翻到一半，不計數，但給予正向回饋
            tvFeedback.text = "✅ 掌心朝下"
            lastConfirmedState = "DOWN"
            tvInstruction.text = "很好，請將掌心往上翻"

        } else if (state == "MID") {
            // 過渡狀態的文字提示
            if (lastConfirmedState == "UP") tvInstruction.text = "往下翻轉中..."
            else if (lastConfirmedState == "DOWN") tvInstruction.text = "往上翻轉中..."
        }

        tvRepCount.text = "$repCount / 10"
        checkCompletion()
    }

    private fun checkCompletion() {
        if (repCount >= 10 && !isTrainingComplete) {
            isTrainingComplete = true
            tvFeedback.text = "🎉 訓練圓滿結束！"
            tvInstruction.text = "辛苦了，請按下停止按鈕休息"
            speakSafe("十次動作全部完成，您做得非常棒", isUrgent = true)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
        handLandmarker?.close()
        textToSpeech?.stop()
        textToSpeech?.shutdown()
    }

    private fun rotateBitmap(bitmap: android.graphics.Bitmap, degrees: Int): android.graphics.Bitmap {
        if (degrees == 0) return bitmap
        val matrix = android.graphics.Matrix()
        matrix.postRotate(degrees.toFloat())
        return android.graphics.Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
}
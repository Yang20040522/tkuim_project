package com.rehabassist.rehabassist

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.SystemClock
import android.speech.tts.TextToSpeech
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
import com.rehabassist.rehabassist.actions.* // 🌟 匯入你的卡匣包！
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

// 🌟 繼承 RehabActionCallback，讓這台主機可以接收卡匣的指令
class TrainingActivity : AppCompatActivity(), RehabActionCallback {

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

    // 語音回饋 (TTS)
    private var textToSpeech: TextToSpeech? = null
    private var lastSpeakTime = 0L
    private val speakCooldown = 1500L

    // 基礎狀態變數
    private var currentActionType = "TURN_PALM"
    private var lastImageWidth = 1
    private var lastImageHeight = 1
    private var isTrainingComplete = false

    // 🌟 核心引擎：目前插在主機上的卡匣！
    private var currentExercise: BaseRehabAction? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_training)

        // 綁定 UI
        previewView = findViewById(R.id.previewView)
        overlayView = findViewById(R.id.overlayView)
        btnStop = findViewById(R.id.btnStop)
        tvTitle = findViewById(R.id.tvTitle)
        tvFeedback = findViewById(R.id.tvFeedback)
        tvInstruction = findViewById(R.id.tvInstruction)
        tvRepCount = findViewById(R.id.tvRepCount)
        tvAccuracy = findViewById(R.id.tvAccuracy)

        // 設定 TTS
        textToSpeech = TextToSpeech(this, { status ->
            if (status == TextToSpeech.SUCCESS) {
                textToSpeech?.language = Locale.TAIWAN
                textToSpeech?.setSpeechRate(0.95f)
                textToSpeech?.setPitch(1.1f)
            }
        }, "com.google.android.tts")

        // 取得 Intent 傳來的動作類型 (從上一個畫面傳過來的)
        currentActionType = intent.getStringExtra("ACTION_TYPE") ?: "TURN_PALM"

        // ✨ 新增：取得 Intent 傳來的難度等級 (若沒傳，預設為 1)
        val difficultyLevel = intent.getIntExtra("DIFFICULTY_LEVEL", 1)

        // 🌟 終極大解脫：主機不用管邏輯了，直接根據字串插入對應的卡匣！
        currentExercise = when (currentActionType) {
            "TURN_PALM" -> TurnPalmAction(this, difficultyLevel) // 🌟 把難度傳給翻掌卡匣
            "SECOND_ACTION" -> SidePinchAction(this)             // 側捏卡匣維持原樣
            else -> null
        }

        cameraExecutor = Executors.newSingleThreadExecutor()
        btnStop.setOnClickListener { finish() }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            setupMediaPipe()
            startCamera()
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), 100)
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
                // 如果畫面沒抓到手，給予基本提示
                tvFeedback.text = "請將手放入鏡頭範圍內"
                tvInstruction.text = "等待偵測中..."
                tvAccuracy.text = "--"
                return@runOnUiThread
            }

            // 🌟 這裡就是見證奇蹟的時刻：直接把骨架資料丟給目前插著的卡匣去算數學！
            currentExercise?.processLandmarks(result.landmarks()[0])
        }
    }

    // =========================================================
    // 以下四個方法，是主機開放給「卡匣」使用的遙控器功能 (Callback)
    // =========================================================

    override fun updateUI(title: String?, instruction: String?, feedback: String?, repCount: String?, accuracy: String?) {
        title?.let { tvTitle.text = it }
        instruction?.let { tvInstruction.text = it }
        feedback?.let { tvFeedback.text = it }
        repCount?.let { tvRepCount.text = it }
        accuracy?.let { tvAccuracy.text = it }
    }

    override fun speak(text: String, isUrgent: Boolean) {
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

    override fun speakCount(count: Int) {
        if (count <= 0 || count > 10) return
        val numWords = arrayOf("零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十")
        when (count) {
            1 -> speak("第一下，很好", isUrgent = true)
            5 -> speak("五下，堅持住", isUrgent = true)
            8 -> speak("八，快完成了", isUrgent = true)
            10 -> return
            else -> speak(numWords[count], isUrgent = true)
        }
    }

    override fun onTrainingComplete() {
        isTrainingComplete = true
        tvFeedback.text = "🎉 訓練圓滿結束！"
        tvInstruction.text = "辛苦了，請按下停止按鈕休息"
        speak("十次動作全部完成，您做得非常棒", isUrgent = true)
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
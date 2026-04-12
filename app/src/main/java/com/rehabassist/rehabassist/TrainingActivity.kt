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
// ✨ 雙引擎改造 1：引入全身骨架套件
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import com.rehabassist.rehabassist.actions.* // 🌟 匯入你的卡匣包！
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

// 🌟 繼承 RehabActionCallback，讓這台主機可以接收卡匣的指令
class TrainingActivity : AppCompatActivity(), RehabActionCallback {

    // UI 元件
    private lateinit var previewView: PreviewView
    private lateinit var overlayView: HandOverlayView
    private lateinit var poseOverlayView: PoseOverlayView // ✨ 新增：全身畫筆變數
    private lateinit var btnStop: Button
    // private lateinit var btnFlipCamera: Button // ✨ 新增：翻轉鏡頭按鈕
    private lateinit var tvTitle: TextView
    private lateinit var tvFeedback: TextView
    private lateinit var tvInstruction: TextView
    private lateinit var tvRepCount: TextView
    private lateinit var tvAccuracy: TextView

    // MediaPipe 與相機
    private lateinit var cameraExecutor: ExecutorService
    private var handLandmarker: HandLandmarker? = null
    // ✨ 雙引擎改造 2：宣告全身骨架引擎變數
    private var poseLandmarker: PoseLandmarker? = null

    // ✨ 新增：記錄現在是用哪顆鏡頭 (預設後置)
    private var cameraLensFacing = CameraSelector.LENS_FACING_BACK

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
        poseOverlayView = findViewById(R.id.poseOverlayView)
        btnStop = findViewById(R.id.btnStop)
        // btnFlipCamera = findViewById(R.id.btnFlipCamera) // ✨ 綁定翻轉按鈕
        tvTitle = findViewById(R.id.tvTitle)
        tvFeedback = findViewById(R.id.tvFeedback)
        tvInstruction = findViewById(R.id.tvInstruction)
        tvRepCount = findViewById(R.id.tvRepCount)
        tvAccuracy = findViewById(R.id.tvAccuracy)

        // 設定 TTS
        /*
        textToSpeech = TextToSpeech(this, { status ->
            if (status == TextToSpeech.SUCCESS) {
                textToSpeech?.language = Locale.TAIWAN
                textToSpeech?.setSpeechRate(0.95f)
                textToSpeech?.setPitch(1.1f)
            }
        }, "com.google.android.tts")
         */

        // 設定 TTS
        textToSpeech = TextToSpeech(this, { status ->
            if (status == TextToSpeech.SUCCESS) {
                textToSpeech?.language = Locale.TAIWAN

                // 💡 換了新聲音後，建議先將速度和音調調回預設的 1.0f 聽聽看原音
                textToSpeech?.setSpeechRate(1.0f)
                textToSpeech?.setPitch(1.0f)

                // ✨ 召喚「網路高品質」真人語音魔法
                try {
                    val voices = textToSpeech?.voices
                    if (voices != null) {
                        // 在系統的所有聲音中，尋找台灣口音 (TW) 且帶有 "network" (網路高品質) 的模型
                        val highQualityVoice = voices.firstOrNull {
                            it.locale.country == "TW" && it.name.contains("network", ignoreCase = true)
                        }

                        // 如果有找到高品質的，就幫治療師換上這個新嗓音！
                        if (highQualityVoice != null) {
                            textToSpeech?.voice = highQualityVoice
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace() // 萬一找不到，就會默默用原本的機器音，不會當機
                }
            }
        }, "com.google.android.tts")

        currentActionType = intent.getStringExtra("ACTION_TYPE") ?: "TURN_PALM"
        val difficultyLevel = intent.getIntExtra("DIFFICULTY_LEVEL", 1)

        // 🌟 核心引擎：根據選擇的動作載入對應的卡匣，並打開對應的視覺特效
        currentExercise = when (currentActionType) {
            "TURN_PALM" -> {
                overlayView.setStickGuideEnabled(true)
                overlayView.setPinchGuideEnabled(false)
                TurnPalmAction(this, difficultyLevel)
            }
            "SECOND_ACTION" -> {
                overlayView.setStickGuideEnabled(false)
                overlayView.setPinchGuideEnabled(true) // ✨ 打開側捏專屬特效
                SidePinchAction(this, difficultyLevel)
            }
            "WIPE_ACTION" -> {
                overlayView.setStickGuideEnabled(false)
                overlayView.setPinchGuideEnabled(false)
                WipeAction(this, difficultyLevel)
            }
            "DRAW_CIRCLE" -> {
                overlayView.setStickGuideEnabled(false)
                overlayView.setPinchGuideEnabled(false)
                DrawCircleAction(this, difficultyLevel)
            }
            "REACH_ACTION" -> { // ✨ 裝上第五個卡匣：手臂上舉
                overlayView.setStickGuideEnabled(false)
                overlayView.setPinchGuideEnabled(false)
                ReachAction(this, difficultyLevel)
            }
            else -> null
        }

        cameraExecutor = Executors.newSingleThreadExecutor()

        btnStop.setOnClickListener { finish() }

        // ✨ 方案 B：點擊整個相機預覽畫面，就會自動翻轉鏡頭！
        previewView.setOnClickListener {
            cameraLensFacing = if (cameraLensFacing == CameraSelector.LENS_FACING_BACK) {
                CameraSelector.LENS_FACING_FRONT
            } else {
                CameraSelector.LENS_FACING_BACK
            }
            startCamera() // 重新啟動相機
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            setupMediaPipe()
            startCamera()
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), 100)
        }
    }

    // ✨ 雙引擎改造 3：根據動作切換引擎
    private fun setupMediaPipe() {
        try {
            // ✨ 讓擦拭動作、畫圓動作和上舉動作都使用全身骨架引擎
            if (currentActionType == "WIPE_ACTION" || currentActionType == "DRAW_CIRCLE" || currentActionType == "REACH_ACTION") {
                // 啟動全身骨架引擎
                val baseOptions = BaseOptions.builder().setModelAssetPath("pose_landmarker_lite.task").build()
                val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                    .setBaseOptions(baseOptions)
                    .setRunningMode(RunningMode.LIVE_STREAM)
                    .setResultListener { result, _ -> processPoseResult(result) }
                    .build()
                poseLandmarker = PoseLandmarker.createFromOptions(this, options)
            } else {
                // 啟動原本的手部引擎
                val baseOptions = BaseOptions.builder().setModelAssetPath("hand_landmarker.task").build()
                val options = HandLandmarker.HandLandmarkerOptions.builder()
                    .setBaseOptions(baseOptions)
                    .setNumHands(1)
                    .setRunningMode(RunningMode.LIVE_STREAM)
                    .setResultListener { result, _ -> processResult(result) }
                    .build()
                handLandmarker = HandLandmarker.createFromOptions(this, options)
            }
        } catch (e: Exception) {
            runOnUiThread { tvFeedback.text = "初始化失敗" }
            e.printStackTrace()
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

                        // ✨ 雙引擎改造 4：影像分流
                        if (currentActionType == "WIPE_ACTION" || currentActionType == "DRAW_CIRCLE" || currentActionType == "REACH_ACTION") {
                            poseLandmarker?.detectAsync(mpImage, SystemClock.uptimeMillis())
                        } else {
                            handLandmarker?.detectAsync(mpImage, SystemClock.uptimeMillis())
                        }

                        imageProxy.close()
                    }
                }
            cameraProvider.unbindAll()

            // ✨ 把原本寫死的 DEFAULT_BACK_CAMERA 換成我們動態控制的 cameraLensFacing
            val cameraSelector = CameraSelector.Builder().requireLensFacing(cameraLensFacing).build()
            cameraProvider.bindToLifecycle(this, cameraSelector, preview, imageAnalyzer)

        }, ContextCompat.getMainExecutor(this))
    }

    private fun processResult(result: HandLandmarkerResult) {
        runOnUiThread {
            if (isTrainingComplete) return@runOnUiThread

            // ✨ 正統做法：判斷現在是不是前鏡頭，然後傳給畫筆
            val isFront = cameraLensFacing == CameraSelector.LENS_FACING_FRONT
            overlayView.setResults(result, lastImageWidth, lastImageHeight, 0, isFront)

            if (result.landmarks().isEmpty()) {
                tvFeedback.text = "請將手放入鏡頭範圍內"
                tvInstruction.text = "等待偵測中..."
                tvAccuracy.text = "--"
                return@runOnUiThread
            }
            currentExercise?.processLandmarks(result.landmarks()[0])
        }
    }

    // ✨ 雙引擎改造 5：全身骨架專屬的資料接收器
    // ✨ 全身骨架專屬的資料接收器 (修正版)
    private fun processPoseResult(result: PoseLandmarkerResult) {
        runOnUiThread {
            if (isTrainingComplete) return@runOnUiThread

            // ✨ 將全身骨架資料 AND 鏡頭方向 交給畫筆！
            poseOverlayView.setResults(result, cameraLensFacing) // 👈 改這一行

            if (result.landmarks().isEmpty()) {
                tvFeedback.text = "請將上半身放入鏡頭範圍內"
                tvInstruction.text = "等待偵測中..."
                tvAccuracy.text = "--"
                return@runOnUiThread
            }
            // 把全身的 33 個點傳給卡匣！
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

    override fun onTrainingComplete(report: TrainingReport) {
        isTrainingComplete = true
        tvFeedback.text = "🎉 訓練圓滿結束！"
        tvInstruction.text = "辛苦了，請按下停止按鈕休息"
        speak("十次動作全部完成，您做得非常棒", isUrgent = true)

        try {
            val sharedPref = getSharedPreferences("RehabRecords", android.content.Context.MODE_PRIVATE)
            val historyJson = sharedPref.getString("history", "[]")
            val jsonArray = org.json.JSONArray(historyJson)
            val newRecord = org.json.JSONObject()
            val sdf = java.text.SimpleDateFormat("MM/dd HH:mm", java.util.Locale.getDefault())
            val timestamp = sdf.format(java.util.Date())

            newRecord.put("timestamp", timestamp)
            newRecord.put("actionName", report.actionName)
            newRecord.put("difficulty", report.difficulty)
            newRecord.put("durationSeconds", report.durationSeconds)

            val mistakesArray = org.json.JSONArray()
            report.mistakeLogs.forEach { mistakesArray.put(it) }
            newRecord.put("mistakeLogs", mistakesArray)

            jsonArray.put(newRecord)
            sharedPref.edit().putString("history", jsonArray.toString()).apply()

        } catch (e: Exception) {
            e.printStackTrace()
        }

        showCompletionDialog()
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
        handLandmarker?.close()
        poseLandmarker?.close() // ✨ 雙引擎改造 6：關閉全身引擎避免漏水
        textToSpeech?.stop()
        textToSpeech?.shutdown()
    }

    private fun rotateBitmap(bitmap: android.graphics.Bitmap, degrees: Int): android.graphics.Bitmap {
        if (degrees == 0) return bitmap
        val matrix = android.graphics.Matrix()
        matrix.postRotate(degrees.toFloat())
        return android.graphics.Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun showCompletionDialog() {
        runOnUiThread {
            // ✨ 選單加上畫圓動作和上舉動作
            val actionOptions = arrayOf(
                "🔄 再來一組 (維持現狀)",
                "🖐️ 切換：翻掌訓練",
                "🤏 切換：手部精細動作 - 側捏",
                "🧽 切換：功能性擦拭訓練",
                "🚗 切換：方向盤畫圓訓練",
                "💪 切換：手臂上舉訓練", // ✨ 加入第五個選單
                "🏠 結束今日訓練 (回到首頁)"
            )

            val builder = android.app.AlertDialog.Builder(this)
            builder.setTitle("🎉 訓練完成！請選擇下一個項目")
            builder.setCancelable(false)

            builder.setItems(actionOptions) { _, which ->
                when (which) {
                    0 -> recreate()
                    1 -> showDifficultyDialog("TURN_PALM")
                    2 -> showDifficultyDialog("SECOND_ACTION")
                    3 -> showDifficultyDialog("WIPE_ACTION")
                    4 -> showDifficultyDialog("DRAW_CIRCLE") // ✨ 呼叫畫圓動作
                    5 -> showDifficultyDialog("REACH_ACTION") // ✨ 呼叫上舉動作
                    6 -> finish()
                }
            }
            builder.show()
        }
    }

    private fun showDifficultyDialog(actionType: String) {
        runOnUiThread {
            // ✨ 難度選單加上畫圓動作和上舉動作
            val difficultyOptions = when (actionType) {
                "TURN_PALM" -> arrayOf("Level 1 (初階 - 容錯較高)", "Level 2 (中階 - 要求嚴格)")
                "SECOND_ACTION" -> arrayOf("Level 1 (初階微幅)", "Level 2 (中階標準)", "Level 3 (進階連擊)")
                "WIPE_ACTION" -> arrayOf("Level 1 (微幅擦拭)", "Level 2 (標準來回)", "Level 3 (抗重力穩定)")
                "DRAW_CIRCLE" -> arrayOf("Level 1 (小方向盤)", "Level 2 (大方向盤)")
                "REACH_ACTION" -> arrayOf("Level 1 (輕度抬起)", "Level 2 (舉高至頭部)", "Level 3 (空中定格)") // ✨ 加上上舉的難度選單
                else -> arrayOf("Level 1")
            }

            val builder = android.app.AlertDialog.Builder(this)
            builder.setTitle("請選擇難度等級")
            builder.setCancelable(false)

            builder.setItems(difficultyOptions) { _, which ->
                val selectedDifficulty = which + 1
                startNewTraining(actionType, selectedDifficulty)
            }

            builder.setNegativeButton("返回上一步") { _, _ ->
                showCompletionDialog()
            }

            builder.show()
        }
    }

    private fun startNewTraining(actionType: String, difficulty: Int) {
        val intent = android.content.Intent(this, TrainingActivity::class.java)
        intent.putExtra("ACTION_TYPE", actionType)
        intent.putExtra("DIFFICULTY_LEVEL", difficulty)
        startActivity(intent)
        finish()
    }

    // =========================================================
    // ✨ 實作介面：控制畫面的輔助線與進度條
    // =========================================================
    override fun setGuideLineVisible(visible: Boolean) {
        runOnUiThread {
            overlayView.setStickGuideEnabled(visible)
        }
    }

    // ✨ 接收卡匣傳來的側捏視覺開關
    override fun setPinchGuideEnabled(visible: Boolean) {
        runOnUiThread {
            overlayView.setPinchGuideEnabled(visible)
        }
    }

    override fun updateProgress(progress: Float, speedState: Int) {
        runOnUiThread {
            overlayView.setProgress(progress, speedState)
        }
    }

    // ✨ 新增這段：接收卡匣的訊號，並轉達給全身畫筆
    override fun setSkeletonMode(mode: String) {
        runOnUiThread {
            poseOverlayView.setSkeletonMode(mode)
        }
    }
}
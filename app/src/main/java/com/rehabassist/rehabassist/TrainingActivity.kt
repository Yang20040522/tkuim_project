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

    // ✨ 升級版：接收來自 AI 卡匣的成績單！
    // ✨ 接收來自 AI 卡匣的成績單，並且把它「存檔」！
    override fun onTrainingComplete(report: TrainingReport) {
        isTrainingComplete = true
        tvFeedback.text = "🎉 訓練圓滿結束！"
        tvInstruction.text = "辛苦了，請按下停止按鈕休息"
        speak("十次動作全部完成，您做得非常棒", isUrgent = true)

        // ==========================================
        // 💾 ✨ 核心新增：把成績單存進手機的 SharedPreferences
        // ==========================================
        try {
            // 1. 取得儲存庫
            val sharedPref = getSharedPreferences("RehabRecords", android.content.Context.MODE_PRIVATE)
            val historyJson = sharedPref.getString("history", "[]") // 拿出舊紀錄，如果沒有就是空陣列 "[]"
            val jsonArray = org.json.JSONArray(historyJson)

            // 2. 建立這次的新紀錄 (使用內建的 JSONObject)
            val newRecord = org.json.JSONObject()

            // 產生現在的時間 (例如：03/23 10:50)
            val sdf = java.text.SimpleDateFormat("MM/dd HH:mm", java.util.Locale.getDefault())
            val timestamp = sdf.format(java.util.Date())

            newRecord.put("timestamp", timestamp)
            newRecord.put("actionName", report.actionName)
            newRecord.put("difficulty", report.difficulty)
            newRecord.put("durationSeconds", report.durationSeconds)

            // 處理失誤清單
            val mistakesArray = org.json.JSONArray()
            report.mistakeLogs.forEach { mistakesArray.put(it) }
            newRecord.put("mistakeLogs", mistakesArray)

            // 3. 把新紀錄塞進陣列，然後存回手機裡！
            jsonArray.put(newRecord)
            sharedPref.edit().putString("history", jsonArray.toString()).apply()

            println("💾 存檔成功！目前共有 ${jsonArray.length()} 筆紀錄")
        } catch (e: Exception) {
            e.printStackTrace()
            println("❌ 存檔失敗")
        }
        // ==========================================

        // 顯示完成選單
        showCompletionDialog()
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
    // ✨ 新增：完成後的「選單列表」邏輯
    // ✨ 新增：包含「難易度」的完整選單邏輯
    // ✨ 第一層選單：選擇復健動作
    private fun showCompletionDialog() {
        runOnUiThread {
            val actionOptions = arrayOf(
                "🔄 再來一組 (維持現狀)",
                "🖐️ 切換：翻掌訓練",
                "🤏 切換：手部精細動作 - 側捏",
                "🏠 結束今日訓練 (回到首頁)"
            )

            val builder = android.app.AlertDialog.Builder(this)
            builder.setTitle("🎉 訓練完成！請選擇下一個項目")
            builder.setCancelable(false) // 防止點擊背景關閉

            builder.setItems(actionOptions) { _, which ->
                when (which) {
                    0 -> recreate() // 維持現狀重新開始
                    1 -> showDifficultyDialog("TURN_PALM")    // 呼叫第二層選單，傳入翻掌暗號
                    2 -> showDifficultyDialog("SECOND_ACTION") // 呼叫第二層選單，傳入側捏暗號
                    3 -> finish() // 回到首頁
                }
            }
            builder.show()
        }
    }

    // ✨ 第二層選單：選擇對應的難度
    private fun showDifficultyDialog(actionType: String) {
        runOnUiThread {
            // 根據傳進來的動作，決定要顯示哪些難度 (呼應你 MainActivity 的設定)
            val difficultyOptions = if (actionType == "TURN_PALM") {
                arrayOf("Level 1 (初階 - 容錯較高)", "Level 2 (中階 - 要求嚴格)")
            } else {
                arrayOf("Level 1 (標準側捏)") // 側捏目前只有一個選項
            }

            val builder = android.app.AlertDialog.Builder(this)
            builder.setTitle("請選擇難度等級")
            builder.setCancelable(false)

            // 選擇難度後，正式啟動新的訓練
            builder.setItems(difficultyOptions) { _, which ->
                val selectedDifficulty = which + 1 // 因為陣列從 0 開始，+1 就會變成 Level 1, Level 2
                startNewTraining(actionType, selectedDifficulty)
            }

            // 加入「返回」按鈕，防呆設計
            builder.setNegativeButton("返回上一步") { _, _ ->
                showCompletionDialog() // 重新呼叫第一層選單
            }

            builder.show()
        }
    }

    // ✨ 負責執行跳轉的工具函式
    private fun startNewTraining(actionType: String, difficulty: Int) {
        val intent = android.content.Intent(this, TrainingActivity::class.java)
        intent.putExtra("ACTION_TYPE", actionType)
        intent.putExtra("DIFFICULTY_LEVEL", difficulty) // 把難度傳遞給下一個訓練
        startActivity(intent)
        finish() // 關掉目前的畫面
    }
}
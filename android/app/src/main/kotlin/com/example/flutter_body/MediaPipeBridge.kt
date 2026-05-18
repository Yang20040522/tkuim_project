package com.example.flutter_body

import android.content.Context
import android.os.SystemClock
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import com.example.flutter_body.actions.*
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MediaPipeBridge(
    private val context: Context,
    private val actionType: String,
    private val difficulty: Int,
    private var useFrontCamera: Boolean,
    private val previewView: PreviewView?
) : RehabActionCallback {

    var landmarkEventSink: EventChannel.EventSink? = null
    var trainingEventSink: EventChannel.EventSink? = null

    private var handLandmarker: HandLandmarker? = null
    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var cameraProvider: ProcessCameraProvider? = null
    private var currentExercise: BaseRehabAction? = null

    // ⚡ 優化 1：防止幀堆積，避免分析執行緒被塞爆
    private var isProcessing = false

    // ⚡ 優化 2：平滑濾波，消除骨架抖動
    private var smoothedLandmarks = Array(21) { FloatArray(3) }
    private var isFirstFrame = true
    private val SMOOTHING_FACTOR = 0.65f

    // ⚡ 優化 3：節流閥，限制傳送給 Flutter 的頻率，避免 UI 通道塞車
    private var lastEventSendTime = 0L

    // ⚡ 優化 4：重複使用 Matrix，減少 GC 壓力避免卡頓
    private val reusableMatrix = android.graphics.Matrix()

    fun start() {
        setupMediaPipe()
        startCamera()
    }

    fun stop() {
        cameraProvider?.unbindAll()
        handLandmarker?.close()
        cameraExecutor.shutdown()
    }

    fun flipCamera() {
        useFrontCamera = !useFrontCamera
        isFirstFrame = true  // ⚡ 優化 6：翻鏡頭時重置平滑狀態，防止畫面閃爍
        startCamera()
    }

    private fun setupMediaPipe() {
        try {
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath("hand_landmarker.task")
                .build()
            val options = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setNumHands(1)
                // ⚡ 優化 7：設定信心度門檻，讓偵測更穩定
                .setMinHandDetectionConfidence(0.5f)
                .setMinHandPresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener { result, _ ->
                    processResult(result)
                    isProcessing = false  // ⚡ 優化 1：分析完成才釋放旗標
                }
                .setErrorListener { _ ->
                    isProcessing = false  // ⚡ 優化 8：錯誤時也要釋放，防止死鎖
                }
                .build()
            handLandmarker = HandLandmarker.createFromOptions(context, options)

            currentExercise = when (actionType) {
                "TURN_PALM" -> TurnPalmAction(this, difficulty)
                "SECOND_ACTION" -> SidePinchAction(this, difficulty)
                else -> TurnPalmAction(this, difficulty)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()

            // ⚡ 優化 5a：預覽不裁切畫面，確保顯示完整
            previewView?.scaleType = PreviewView.ScaleType.FIT_CENTER

            // ⚡ 優化 5b：強制 4:3 比例，讓預覽與 Flutter UI 對齊
            val preview = Preview.Builder()
                .setTargetAspectRatio(AspectRatio.RATIO_4_3)
                .build().also {
                    it.setSurfaceProvider(previewView?.surfaceProvider)
                }

            val imageAnalyzer = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                // ⚡ 優化 5c：AI 分析也用 4:3，確保座標比例不偏移
                .setTargetAspectRatio(AspectRatio.RATIO_4_3)
                .build()
                .also { analysis ->
                    analysis.setAnalyzer(cameraExecutor) { imageProxy ->
                        // ⚡ 優化 1：若上一幀還在處理中，直接跳過此幀
                        if (isProcessing) {
                            imageProxy.close()
                            return@setAnalyzer
                        }

                        isProcessing = true
                        val rotation = imageProxy.imageInfo.rotationDegrees
                        val bitmap = imageProxy.toBitmap()
                        val rotated = rotateBitmap(bitmap, rotation)
                        val mpImage = BitmapImageBuilder(rotated).build()
                        handLandmarker?.detectAsync(mpImage, SystemClock.uptimeMillis())
                        imageProxy.close()
                    }
                }

            val lensFacing = if (useFrontCamera)
                CameraSelector.LENS_FACING_FRONT
            else
                CameraSelector.LENS_FACING_BACK

            val cameraSelector = CameraSelector.Builder()
                .requireLensFacing(lensFacing)
                .build()

            cameraProvider?.unbindAll()
            cameraProvider?.bindToLifecycle(
                context as LifecycleOwner,
                cameraSelector,
                preview,
                imageAnalyzer
            )
        }, ContextCompat.getMainExecutor(context))
    }

    private fun rotateBitmap(bitmap: android.graphics.Bitmap, degrees: Int): android.graphics.Bitmap {
        if (degrees == 0) return bitmap
        // ⚡ 優化 4：重複使用 Matrix，不每次都 new 新物件
        reusableMatrix.reset()
        reusableMatrix.postRotate(degrees.toFloat())
        return android.graphics.Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, reusableMatrix, true)
    }

    private fun processResult(result: HandLandmarkerResult) {
        val isFront = useFrontCamera
        val landmarks = if (result.landmarks().isNotEmpty()) result.landmarks()[0] else null

        if (landmarks == null) {
            // 偵測不到手時重置平滑狀態
            isFirstFrame = true
            val now = SystemClock.uptimeMillis()
            // ⚡ 優化 3：沒有手時也節流，每 32ms 最多送一次
            if (now - lastEventSendTime > 32) {
                lastEventSendTime = now
                (context as? android.app.Activity)?.runOnUiThread {
                    landmarkEventSink?.success(mapOf(
                        "landmarks" to emptyList<Map<String, Float>>(),
                        "handDetected" to false
                    ))
                }
            }
            return
        }

        val landmarkList = mutableListOf<Map<String, Float>>()
        for (i in landmarks.indices) {
            val lm = landmarks[i]
            // 前鏡頭鏡像反轉
            val rawX = if (isFront) 1f - lm.x() else lm.x()
            val rawY = lm.y()
            val rawZ = lm.z()

            // ⚡ 優化 2：平滑濾波，第一幀直接採用，之後做指數加權平均
            if (isFirstFrame) {
                smoothedLandmarks[i][0] = rawX
                smoothedLandmarks[i][1] = rawY
                smoothedLandmarks[i][2] = rawZ
            } else {
                smoothedLandmarks[i][0] = (SMOOTHING_FACTOR * rawX) + ((1 - SMOOTHING_FACTOR) * smoothedLandmarks[i][0])
                smoothedLandmarks[i][1] = (SMOOTHING_FACTOR * rawY) + ((1 - SMOOTHING_FACTOR) * smoothedLandmarks[i][1])
                smoothedLandmarks[i][2] = (SMOOTHING_FACTOR * rawZ) + ((1 - SMOOTHING_FACTOR) * smoothedLandmarks[i][2])
            }

            landmarkList.add(mapOf(
                "x" to smoothedLandmarks[i][0],
                "y" to smoothedLandmarks[i][1],
                "z" to smoothedLandmarks[i][2]
            ))
        }
        isFirstFrame = false

        // ⚡ 優化 3：節流閥核心，限制約 25fps 傳送給 Flutter，解決 UI 渲染卡頓
        val now = SystemClock.uptimeMillis()
        if (now - lastEventSendTime > 40) {
            lastEventSendTime = now
            (context as? android.app.Activity)?.runOnUiThread {
                landmarkEventSink?.success(mapOf(
                    "landmarks" to landmarkList,
                    "handDetected" to true
                ))
            }
        }

        // 注意：運動邏輯仍使用原始（未節流）的 landmarks，保持準確性
        currentExercise?.processLandmarks(landmarks)
    }

    override fun updateUI(
        title: String?, instruction: String?,
        feedback: String?, repCount: String?, accuracy: String?
    ) {
        val repNum = repCount?.trim()?.split("/")?.firstOrNull()
            ?.trim()?.toIntOrNull() ?: -1
        val accNum = accuracy?.replace(Regex("[^0-9.]"), "")
            ?.toDoubleOrNull() ?: 0.0

        (context as? android.app.Activity)?.runOnUiThread {
            trainingEventSink?.success(mapOf(
                "feedback" to (feedback ?: ""),
                "instruction" to (instruction ?: ""),
                "repCount" to repNum,
                "accuracy" to accNum,
                "progress" to 0.0,
                "speedState" to 0,
                "isComplete" to false,
                "mistakeLogs" to emptyList<String>(),
                "durationSeconds" to 0
            ))
        }
    }

    override fun speak(text: String, isUrgent: Boolean) {}

    override fun speakCount(count: Int) {}

    override fun onTrainingComplete(report: TrainingReport) {
        (context as? android.app.Activity)?.runOnUiThread {
            trainingEventSink?.success(mapOf(
                "feedback" to "🎉 訓練完成！",
                "instruction" to "辛苦了",
                "repCount" to 10,
                "accuracy" to 0.0,
                "progress" to 1.0,
                "speedState" to 0,
                "isComplete" to true,
                "mistakeLogs" to report.mistakeLogs,
                "durationSeconds" to report.durationSeconds
            ))
        }
    }

    override fun setGuideLineVisible(visible: Boolean) {}

    override fun setPinchGuideEnabled(visible: Boolean) {}

    override fun updateProgress(progress: Float, speedState: Int) {
        (context as? android.app.Activity)?.runOnUiThread {
            trainingEventSink?.success(mapOf(
                "feedback" to "",
                "instruction" to "",
                "repCount" to -1,
                "accuracy" to 0.0,
                "progress" to progress.toDouble(),
                "speedState" to speedState,
                "isComplete" to false,
                "mistakeLogs" to emptyList<String>(),
                "durationSeconds" to 0
            ))
        }
    }

    override fun setSkeletonMode(mode: String) {}
}
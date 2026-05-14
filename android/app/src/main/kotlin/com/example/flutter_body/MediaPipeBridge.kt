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
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener { result, _ -> processResult(result) }
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

            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView?.surfaceProvider)
            }

            val imageAnalyzer = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .build()
                .also { analysis ->
                    analysis.setAnalyzer(cameraExecutor) { imageProxy ->
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

    private fun processResult(result: HandLandmarkerResult) {
        val isFront = useFrontCamera
        val landmarks = if (result.landmarks().isNotEmpty()) result.landmarks()[0] else null

        val landmarkList = landmarks?.map { lm ->
            mapOf(
                "x" to if (isFront) 1f - lm.x() else lm.x(),
                "y" to lm.y(),
                "z" to lm.z()
            )
        } ?: emptyList()

        (context as? android.app.Activity)?.runOnUiThread {
            landmarkEventSink?.success(mapOf(
                "landmarks" to landmarkList,
                "handDetected" to (landmarks != null)
            ))
        }

        if (landmarks != null) {
            currentExercise?.processLandmarks(landmarks)
        }
    }

    private fun rotateBitmap(
        bitmap: android.graphics.Bitmap,
        degrees: Int
    ): android.graphics.Bitmap {
        if (degrees == 0) return bitmap
        val matrix = android.graphics.Matrix()
        matrix.postRotate(degrees.toFloat())
        return android.graphics.Bitmap.createBitmap(
            bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true
        )
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
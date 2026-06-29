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
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MediaPipeBridge(
    private val context: Context,
    private var useFrontCamera: Boolean,
    private val previewView: PreviewView?
) {
    var landmarkEventSink: EventChannel.EventSink? = null

    private var handLandmarker: HandLandmarker? = null
    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var cameraProvider: ProcessCameraProvider? = null

    private var isProcessing = false
    private var smoothedLandmarks = Array(21) { FloatArray(3) }
    private var isFirstFrame = true
    private val SMOOTHING_FACTOR = 0.65f
    private var lastEventSendTime = 0L
    private val reusableMatrix = android.graphics.Matrix()

    // 收尾旗標:設為 true 後相機幀不再送入 MediaPipe,避免 race condition
    @Volatile
    private var isClosing = false

    fun start() {
        setupMediaPipe()
        startCamera()
    }

    fun stop() {
        // 1. 先設旗標,讓背景執行緒看到後立刻跳過
        isClosing = true
        // 2. 解綁相機
        cameraProvider?.unbindAll()
        // 3. 關閉並清空 MediaPipe
        handLandmarker?.close()
        handLandmarker = null
        // 4. 關閉執行緒池
        cameraExecutor.shutdown()
    }

    fun flipCamera() {
        useFrontCamera = !useFrontCamera
        isFirstFrame = true
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
                .setMinHandDetectionConfidence(0.5f)
                .setMinHandPresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener { result, _ ->
                    processResult(result)
                    isProcessing = false
                }
                .setErrorListener { _ ->
                    isProcessing = false
                }
                .build()
            handLandmarker = HandLandmarker.createFromOptions(context, options)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            previewView?.scaleType = PreviewView.ScaleType.FIT_CENTER

            val preview = Preview.Builder()
                .setTargetAspectRatio(AspectRatio.RATIO_4_3)
                .build().also {
                    it.setSurfaceProvider(previewView?.surfaceProvider)
                }

            val imageAnalyzer = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setTargetAspectRatio(AspectRatio.RATIO_4_3)
                .build()
                .also { analysis ->
                    analysis.setAnalyzer(cameraExecutor) { imageProxy ->
                        // 收尾期間直接跳過,不送入 MediaPipe
                        if (isClosing) {
                            imageProxy.close()
                            return@setAnalyzer
                        }
                        if (isProcessing) {
                            imageProxy.close()
                            return@setAnalyzer
                        }
                        isProcessing = true
                        try {
                            val rotation = imageProxy.imageInfo.rotationDegrees
                            val bitmap = imageProxy.toBitmap()
                            val rotated = rotateBitmap(bitmap, rotation)
                            val mpImage = BitmapImageBuilder(rotated).build()
                            // 再次檢查 + 包 try-catch,雙重保險
                            if (!isClosing) {
                                handLandmarker?.detectAsync(mpImage, SystemClock.uptimeMillis())
                            }
                        } catch (e: Exception) {
                            // 收尾期間殘留幀引發的例外,忽略即可
                            isProcessing = false
                        } finally {
                            imageProxy.close()
                        }
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
        reusableMatrix.reset()
        reusableMatrix.postRotate(degrees.toFloat())
        return android.graphics.Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, reusableMatrix, true)
    }

    private fun processResult(result: HandLandmarkerResult) {
        // 收尾期間不再回傳結果
        if (isClosing) return

        val isFront = useFrontCamera
        val landmarks = if (result.landmarks().isNotEmpty()) result.landmarks()[0] else null

        if (landmarks == null) {
            isFirstFrame = true
            val now = SystemClock.uptimeMillis()
            if (now - lastEventSendTime > 32) {
                lastEventSendTime = now
                (context as? android.app.Activity)?.runOnUiThread {
                    if (!isClosing) {
                        landmarkEventSink?.success(mapOf(
                            "landmarks" to emptyList<Map<String, Float>>(),
                            "handDetected" to false
                        ))
                    }
                }
            }
            return
        }

        val landmarkList = mutableListOf<Map<String, Float>>()
        for (i in landmarks.indices) {
            val lm = landmarks[i]
            val rawX = if (isFront) 1f - lm.x() else lm.x()
            val rawY = lm.y()
            val rawZ = lm.z()

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

        val now = SystemClock.uptimeMillis()
        if (now - lastEventSendTime > 40) {
            lastEventSendTime = now
            (context as? android.app.Activity)?.runOnUiThread {
                if (!isClosing) {
                    landmarkEventSink?.success(mapOf(
                        "landmarks" to landmarkList,
                        "handDetected" to true
                    ))
                }
            }
        }
    }
}
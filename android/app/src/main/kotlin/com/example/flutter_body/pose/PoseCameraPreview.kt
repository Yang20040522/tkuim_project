package com.example.flutter_body.pose

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Matrix
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Size
import android.view.Surface
import android.view.View
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.CameraState
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.UseCaseGroup
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.camera.view.TransformExperimental
import androidx.camera.view.transform.ImageProxyTransformFactory
import androidx.camera.view.transform.OutputTransform
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.Observer
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/** An isolated camera owner; it never starts Flutter camera or touches legacy hand channels. */
@androidx.annotation.OptIn(TransformExperimental::class)
internal class PoseCameraPreview(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    messenger: BinaryMessenger,
    viewId: Int,
) : PlatformView, DefaultLifecycleObserver {
    private val main = Handler(Looper.getMainLooper())
    // Serializes detector creation, input ownership, inference dispatch and detector closure.
    private val worker = Executors.newSingleThreadExecutor()
    private val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val previewView = PreviewView(context).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FILL_CENTER
    }
    private val channelPrefix = "com.rehabassist/pose_measurement/$viewId"
    private val control = MethodChannel(messenger, "$channelPrefix/control")
    private val events = EventChannel(messenger, "$channelPrefix/events")
    private var eventSink: EventChannel.EventSink? = null
    private var lastState: Map<String, Any> = stateEvent("initializing", "正在初始化相機")
    private var requested = false
    @Volatile private var disposed = false
    @Volatile private var currentSession: CameraSession? = null
    private var revision = 0
    private var provider: ProcessCameraProvider? = null
    private var boundWidth = 0
    private var boundHeight = 0
    private var boundRotation = Surface.ROTATION_0

    private class CameraSession(val revision: Int) {
        @Volatile var closing = false
        val gate = PoseFrameGate()
        var detector: PoseLandmarker? = null // worker only
        var pending: PendingFrame? = null // worker only
        var preview: Preview? = null // main only
        var analysis: ImageAnalysis? = null // main only
        var cameraInfo: CameraInfo? = null
        var cameraObserver: Observer<CameraState>? = null
        var deliveredFrame = false // main only
        var startupTimeout: Runnable? = null
    }

    private class PendingFrame(
        val timestampMs: Long,
        val input: MPImage,
        val source: OutputTransform,
        val rawWidth: Int,
        val rawHeight: Int,
        val uprightWidth: Int,
        val uprightHeight: Int,
        val rotationDegrees: Int,
        val cropRect: Rect,
    ) {
        var geometry: Map<String, Any>? = null
        var timeout: Runnable? = null
    }

    private val layoutListener = View.OnLayoutChangeListener { _, l, t, r, b, _, _, _, _ ->
        if (r - l != boundWidth || b - t != boundHeight) restartForGeometry()
    }
    private val attachListener = object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(view: View) = ensureStarted()
        override fun onViewDetachedFromWindow(view: View) = stopSession()
    }
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = Unit
        override fun onDisplayRemoved(displayId: Int) = Unit
        override fun onDisplayChanged(displayId: Int) {
            if (cameraDisplay()?.displayId == displayId &&
                cameraDisplay()?.rotation != boundRotation
            ) restartForGeometry()
        }
    }

    init {
        control.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    if (disposed) {
                        result.error("POSE_DISPOSED", "姿勢量測已關閉，請重新進入", null)
                    } else {
                        requested = true
                        ensureStarted()
                        result.success(null)
                    }
                }
                "stop" -> {
                    requested = false
                    stopSession { result.success(null) }
                }
                else -> result.notImplemented()
            }
        }
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                eventSink = sink
                if (currentSession == null) {
                    lastState = stateEvent("initializing", "正在初始化相機")
                }
                sink.success(lastState)
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
                requested = false
                stopSession()
            }
        })
        previewView.addOnLayoutChangeListener(layoutListener)
        previewView.addOnAttachStateChangeListener(attachListener)
        displayManager.registerDisplayListener(displayListener, main)
        lifecycleOwner.lifecycle.addObserver(this)
    }

    override fun getView(): View = previewView

    override fun onResume(owner: LifecycleOwner) = ensureStarted()

    override fun onPause(owner: LifecycleOwner) {
        // Lifecycle enforcement also works if Flutter has not yet delivered its stop call.
        stopSession()
        emitState("unavailable", "已暫停姿勢量測")
    }

    override fun onDestroy(owner: LifecycleOwner) = dispose()

    override fun dispose() {
        if (disposed) return
        disposed = true
        requested = false
        stopSession()
        control.setMethodCallHandler(null)
        events.setStreamHandler(null)
        eventSink = null
        previewView.removeOnLayoutChangeListener(layoutListener)
        previewView.removeOnAttachStateChangeListener(attachListener)
        displayManager.unregisterDisplayListener(displayListener)
        lifecycleOwner.lifecycle.removeObserver(this)
        // Already queued teardown finishes; no abrupt shutdown while native owns a bitmap.
        worker.shutdown()
    }

    private fun isActive(session: CameraSession): Boolean =
        !disposed && !session.closing && currentSession === session

    @Suppress("DEPRECATION")
    private fun cameraDisplay() = (lifecycleOwner as? Activity)?.windowManager?.defaultDisplay
        ?: previewView.display

    private fun restartForGeometry() {
        if (!requested || disposed) return
        stopSession() // invalidate outstanding coordinates before rebinding a new ViewPort
        ensureStarted()
    }

    private fun ensureStarted() {
        if (disposed || !requested || currentSession != null ||
            !lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED) ||
            !previewView.isAttachedToWindow || previewView.width <= 0 || previewView.height <= 0
        ) return
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requested = false
            emitState("unavailable", "尚未取得相機權限，請允許相機存取後重試")
            return
        }
        boundWidth = previewView.width
        boundHeight = previewView.height
        // A PlatformView's virtual display can remain ROTATION_0 after the device rotates.
        // CameraX target rotation must use the Activity's physical display instead.
        boundRotation = cameraDisplay()?.rotation ?: Surface.ROTATION_0
        val session = CameraSession(++revision)
        currentSession = session
        emitState("initializing", "正在初始化相機")
        emitState("loadingModel", "正在載入人體姿勢模型")
        executeWorker {
            try {
                if (!isActive(session)) return@executeWorker
                val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                    .setBaseOptions(BaseOptions.builder()
                        .setModelAssetPath("pose_landmarker_lite.task")
                        .setDelegate(Delegate.CPU)
                        .build())
                    .setRunningMode(RunningMode.LIVE_STREAM)
                    .setNumPoses(1)
                    .setMinPoseDetectionConfidence(0.5f)
                    .setMinPosePresenceConfidence(0.5f)
                    .setMinTrackingConfidence(0.5f)
                    .setOutputSegmentationMasks(false)
                    .setResultListener { result, outputImage ->
                        // MediaPipe produces a separate callback image; no image crosses channels.
                        try {
                            executeWorker { finishResult(session, result) }
                        } finally {
                            outputImage.close()
                        }
                    }
                    .setErrorListener {
                        fail(session, "人體姿勢偵測發生錯誤，請重新進入量測")
                    }
                    .build()
                session.detector = PoseLandmarker.createFromOptions(context, options)
                main.post { if (isActive(session)) bindCamera(session) }
            } catch (_: Exception) {
                fail(session, "無法載入人體姿勢模型，請確認安裝完整後重試")
            } catch (_: LinkageError) {
                fail(session, "此裝置無法啟動人體姿勢模型")
            }
        }
    }

    private fun bindCamera(session: CameraSession) {
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            if (!isActive(session)) return@addListener
            try {
                val cameraProvider = future.get()
                provider = cameraProvider
                if (!cameraProvider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)) {
                    fail(session, "此裝置沒有可用的前鏡頭")
                    return@addListener
                }
                val viewport = previewView.getViewPort(boundRotation) ?: run {
                    fail(session, "相機顯示區尚未就緒，請重新進入量測")
                    return@addListener
                }
                val preview = Preview.Builder().setTargetRotation(boundRotation).build()
                val analysis = ImageAnalysis.Builder()
                    .setTargetRotation(boundRotation)
                    .setTargetResolution(Size(640, 480))
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                session.preview = preview
                session.analysis = analysis
                preview.setSurfaceProvider(previewView.surfaceProvider)
                analysis.setAnalyzer(worker) { image -> analyze(session, image) }
                // This shared CameraX ViewPort is essential: not merely matching aspect ratios.
                val useCases = UseCaseGroup.Builder().setViewPort(viewport)
                    .addUseCase(preview).addUseCase(analysis).build()
                val camera = cameraProvider.bindToLifecycle(
                    lifecycleOwner, CameraSelector.DEFAULT_FRONT_CAMERA, useCases)
                val observer = Observer<CameraState> { state ->
                    if (state.error != null) {
                        fail(session, "無法開啟前鏡頭，請關閉其他相機功能後再試")
                    }
                }
                session.cameraInfo = camera.cameraInfo
                session.cameraObserver = observer
                camera.cameraInfo.cameraState.observe(lifecycleOwner, observer)
                session.startupTimeout = Runnable {
                    if (isActive(session) && !session.deliveredFrame) {
                        fail(session, "相機影像或顯示座標尚未就緒，請重新進入量測")
                    }
                }.also { main.postDelayed(it, 10000L) }
            } catch (_: Exception) {
                fail(session, "無法啟動前鏡頭，請確認權限並重新進入量測")
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun analyze(session: CameraSession, image: ImageProxy) {
        val timestamp = SystemClock.uptimeMillis()
        if (!isActive(session) || !session.gate.acquire(timestamp)) {
            image.close()
            return
        }
        var raw: Bitmap? = null
        var upright: Bitmap? = null
        var input: MPImage? = null
        try {
            val rotation = image.imageInfo.rotationDegrees
            val source = ImageProxyTransformFactory().apply {
                isUsingCropRect = false
                isUsingRotationDegrees = false
            }.getOutputTransform(image)
            raw = image.toBitmap() // full unrotated buffer; crop is retained in source transform
            upright = if (rotation == 0) raw else Bitmap.createBitmap(
                raw, 0, 0, raw.width, raw.height,
                Matrix().apply { setRotate(rotation.toFloat()) }, true)
            if (upright !== raw) raw.recycle()
            input = BitmapImageBuilder(upright).build()
            val frame = PendingFrame(timestamp, input, source, image.width, image.height,
                upright.width, upright.height, rotation, Rect(image.cropRect))
            session.pending = frame
            // Ownership moved to pending; close only after result or detector.close().
            input = null
            upright = null
            raw = null
            main.post { preparePreviewTransform(session, frame) }
        } catch (_: Exception) {
            input?.close()
            if (upright?.isRecycled == false) upright.recycle()
            if (raw?.isRecycled == false) raw.recycle()
            session.gate.release(timestamp)
            fail(session, "無法處理相機影像，請重新進入量測")
        } finally {
            image.close()
        }
    }

    private fun preparePreviewTransform(session: CameraSession, frame: PendingFrame) {
        if (!isActive(session)) return
        // PreviewView.outputTransform is authoritative and must be queried on the main thread.
        val target = previewView.outputTransform
        val geometry = if (target == null) null else PosePreviewGeometry.create(
            frame.source, target, frame.rawWidth, frame.rawHeight,
            frame.uprightWidth, frame.uprightHeight, frame.rotationDegrees, frame.cropRect,
            previewView.width, previewView.height, session.revision)
        executeWorker {
            if (!isActive(session) || session.pending !== frame) return@executeWorker
            if (geometry == null) {
                releaseFrame(session, frame) // wait for CameraX transform; do not guess a fit
                return@executeWorker
            }
            frame.geometry = geometry
            try {
                session.detector?.detectAsync(frame.input, frame.timestampMs)
                frame.timeout = Runnable {
                    if (isActive(session)) executeWorker {
                        if (isActive(session) && session.pending === frame) {
                            fail(session, "人體姿勢偵測未回應，請重新進入量測")
                        }
                    }
                }.also { main.postDelayed(it, 5000L) }
            } catch (_: Exception) {
                // The detector may still own input; close the session before releasing it.
                fail(session, "人體姿勢偵測失敗，請重新進入量測")
            }
        }
    }

    private fun finishResult(session: CameraSession, result: PoseLandmarkerResult) {
        val frame = session.pending ?: return
        if (!isActive(session) || result.timestampMs() != frame.timestampMs) return
        val landmarks = result.landmarks().firstOrNull()?.map { landmark ->
            mapOf("x" to landmark.x().toDouble(), "y" to landmark.y().toDouble(),
                "z" to landmark.z().toDouble(),
                "visibility" to landmark.visibility().orElse(null)?.toDouble(),
                "presence" to landmark.presence().orElse(null)?.toDouble())
        } ?: emptyList()
        val world = result.worldLandmarks().firstOrNull()?.map { landmark ->
            mapOf("x" to landmark.x().toDouble(), "y" to landmark.y().toDouble(),
                "z" to landmark.z().toDouble(),
                "visibility" to landmark.visibility().orElse(null)?.toDouble(),
                "presence" to landmark.presence().orElse(null)?.toDouble())
        } ?: emptyList()
        val payload = mapOf("type" to "frame", "timestampMs" to frame.timestampMs,
            "landmarks" to landmarks, "worldLandmarks" to world,
            "geometry" to frame.geometry,
            "inferenceMs" to (SystemClock.uptimeMillis() - frame.timestampMs).toDouble())
        releaseFrame(session, frame)
        main.post {
            if (isActive(session)) {
                session.deliveredFrame = true
                session.startupTimeout?.let { main.removeCallbacks(it) }
                session.startupTimeout = null
                if (lastState["state"] != "ready") emitState("ready", "相機與人體姿勢模型已就緒")
                eventSink?.success(payload)
            }
        }
    }

    private fun releaseFrame(session: CameraSession, frame: PendingFrame) {
        if (session.pending !== frame) return
        session.pending = null
        frame.timeout?.let { main.removeCallbacks(it) }
        frame.timeout = null
        frame.input.close() // BitmapImageBuilder owns and recycles its bitmap on close.
        session.gate.release(frame.timestampMs)
    }

    private fun stopSession(onStopped: (() -> Unit)? = null) {
        val session = currentSession
        if (session == null) {
            // Also waits for an earlier background/detach teardown already in the serial queue.
            if (onStopped != null) executeWorker { main.post { onStopped() } }
            return
        }
        session.closing = true
        session.gate.close()
        currentSession = null
        session.startupTimeout?.let { main.removeCallbacks(it) }
        session.startupTimeout = null
        session.analysis?.clearAnalyzer()
        session.cameraObserver?.let { session.cameraInfo?.cameraState?.removeObserver(it) }
        // Never unbindAll(): ownership is restricted to this PlatformView's two use cases.
        val owned = listOfNotNull(session.preview, session.analysis)
        if (owned.isNotEmpty()) provider?.unbind(*owned.toTypedArray())
        session.preview?.setSurfaceProvider(null)
        executeWorker {
            try {
                session.detector?.close()
            } catch (_: Exception) {
                // Still release per-session inputs; never close a newer session's detector.
            } finally {
                session.detector = null
                session.pending?.let { releaseFrame(session, it) }
                if (onStopped != null) main.post { onStopped() }
            }
        }
    }

    private fun fail(session: CameraSession, message: String) {
        main.post {
            if (!isActive(session)) return@post
            requested = false
            stopSession()
            emitState("error", message)
        }
    }

    private fun executeWorker(block: () -> Unit) {
        try {
            worker.execute(block)
        } catch (_: RejectedExecutionException) {
            // Disposed views cannot schedule work; teardown was queued before shutdown.
        }
    }

    private fun emitState(state: String, message: String) {
        if (disposed) return
        lastState = stateEvent(state, message)
        eventSink?.success(lastState)
    }

    private fun stateEvent(state: String, message: String): Map<String, Any> =
        mapOf("type" to "state", "state" to state, "message" to message)
}

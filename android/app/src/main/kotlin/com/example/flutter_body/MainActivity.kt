package com.example.flutter_body

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.platform.PlatformView

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.rehabassist/mediapipe"
    private val LANDMARK_CHANNEL = "com.rehabassist/landmarks"

    private var mediaPipeBridge: MediaPipeBridge? = null
    private var cameraPreviewView: CameraPreviewView? = null
    private var landmarkEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.rehabassist/camera_preview",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(
                    ctx: android.content.Context?,
                    viewId: Int,
                    args: Any?
                ): PlatformView {
                    cameraPreviewView = CameraPreviewView(this@MainActivity)
                    return cameraPreviewView!!
                }
            }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, LANDMARK_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    landmarkEventSink = events
                    mediaPipeBridge?.landmarkEventSink = events
                }
                override fun onCancel(args: Any?) {
                    landmarkEventSink = null
                    mediaPipeBridge?.landmarkEventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startDetection" -> {
                        val useFront = call.argument<Boolean>("useFrontCamera") ?: false
                        mediaPipeBridge = MediaPipeBridge(
                            context = this,
                            useFrontCamera = useFront,
                            previewView = cameraPreviewView?.previewView
                        )
                        mediaPipeBridge?.landmarkEventSink = landmarkEventSink
                        mediaPipeBridge?.start()
                        result.success(null)
                    }
                    "stopDetection" -> {
                        mediaPipeBridge?.stop()
                        mediaPipeBridge = null
                        result.success(null)
                    }
                    "flipCamera" -> {
                        mediaPipeBridge?.flipCamera()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
// lib/services/body_pose_engine.dart
//
// ══════════════════════════════════════════════════════════════════
//  全身姿勢偵測引擎 (RTMPose 133 點)
//
//  ⚠️ 全 App 唯一含 ONNX 推論的檔案。
//     要換模型 / 改推論邏輯,只改這一個檔案。
//
//  邏輯來源:原封不動搬自 body_test_screen.dart 那套已驗證成功的方案。
//  (convertYUV / ONNX 推論 / EMA 平滑,參數完全相同)
//
//  用法:
//    final engine = BodyPoseEngine();
//    await engine.init();
//    // 監聽骨架更新 → 畫骨架
//    engine.poseNotifier.addListener(...)
//    // 啟動相機串流
//    engine.startCamera();
//    // 結束
//    engine.dispose();
// ══════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import '../models/pose_data.dart';

// ── 推論輸入封裝 ──────────────────────────────────────────────────
class InferenceInput {
  final Uint8List yPlane;
  final Uint8List uPlane;
  final Uint8List vPlane;
  final int imgW;
  final int imgH;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
  final bool isFrontCamera;

  InferenceInput({
    required this.yPlane,
    required this.uPlane,
    required this.vPlane,
    required this.imgW,
    required this.imgH,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.isFrontCamera,
  });
}

// ── YUV → Float32 轉換 (搬自 body_test_screen,參數完全相同) ───────
final Float32List _sharedYuvBuffer = Float32List(3 * 256 * 192);

Float32List convertYUV(InferenceInput input) {
  const int inputH = 256;
  const int inputW = 192;
  const int area = inputH * inputW;

  final double ratioX = input.imgW / inputH;
  final double ratioY = input.imgH / inputW;

  int idx = 0;
  for (int y = 0; y < inputH; y++) {
    final int srcX =
        ((inputH - 1 - y) * ratioX).toInt().clamp(0, input.imgW - 1);
    final int halfSrcX = srcX >> 1;

    for (int x = 0; x < inputW; x++) {
      final int srcY = (x * ratioY).toInt().clamp(0, input.imgH - 1);

      final int yIdx = srcY * input.yRowStride + srcX;
      final int uvIdx =
          (srcY >> 1) * input.uvRowStride + halfSrcX * input.uvPixelStride;

      final int yVal = input.yPlane[yIdx];
      final int uVal = input.uPlane[uvIdx] - 128;
      final int vVal = input.vPlane[uvIdx] - 128;

      final double r = yVal + 1.402 * vVal;
      final double g = yVal - 0.344 * uVal - 0.714 * vVal;
      final double b = yVal + 1.772 * uVal;

      _sharedYuvBuffer[idx] = (r - 123.675) / 58.395;
      _sharedYuvBuffer[area + idx] = (g - 116.28) / 57.12;
      _sharedYuvBuffer[2 * area + idx] = (b - 103.53) / 57.375;
      idx++;
    }
  }
  return _sharedYuvBuffer;
}

// ══════════════════════════════════════════════════════════════════
//  BodyPoseEngine — 相機 + ONNX + 133 點,全包
// ══════════════════════════════════════════════════════════════════
class BodyPoseEngine {
  static const int numKpts = 133;
  static const double scoreThreshold = 0.3;

  CameraController? _cam;
  OrtSession? _poseSession;
  OrtRunOptions? _runOpts;
  bool _processing = false;
  bool _isFrontCamera = true;

  List<Offset> _smoothedKeypoints = [];

  // 對外:骨架資料 (畫骨架的人監聽這個)
  final ValueNotifier<PoseData> poseNotifier =
      ValueNotifier(PoseData.empty());

  // 對外:相機是否就緒
  final ValueNotifier<bool> cameraReady = ValueNotifier(false);

  CameraController? get cameraController => _cam;
  bool get isFrontCamera => _isFrontCamera;

  // ── 初始化:相機 + 模型 ──────────────────────────────────────────
  Future<void> init() async {
    await _initCamera();
    await _initOnnx();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final cam = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _isFrontCamera = cam.lensDirection == CameraLensDirection.front;

    final ctrl = CameraController(
      cam,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await ctrl.initialize();
    _cam = ctrl;
  }

  Future<void> _initOnnx() async {
    final opts = OrtSessionOptions()
      ..setIntraOpNumThreads(4)
      ..setInterOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);

    try {
      opts.appendXnnpackProvider();
    } catch (_) {
      debugPrint('XNNPACK 啟動失敗,退回預設 CPU 模式');
    }

    final bytes = (await rootBundle.load('assets/rtmpose_wholebody.onnx'))
        .buffer
        .asUint8List();
    _poseSession = OrtSession.fromBuffer(bytes, opts);
    _runOpts = OrtRunOptions();

    cameraReady.value = true;
  }

  // ── 啟動相機串流 ──────────────────────────────────────────────────
  Future<void> startCamera() async {
    if (_cam == null) return;
    await _cam!.startImageStream(_onFrame);
  }

  // ── 切換鏡頭 ──────────────────────────────────────────────────────
  Future<void> switchCamera() async {
    if (_cam == null) return;
    await _cam!.stopImageStream();
    await _cam!.dispose();

    final cameras = await availableCameras();
    final next = cameras.firstWhere(
      (c) =>
          c.lensDirection !=
          (_isFrontCamera
              ? CameraLensDirection.front
              : CameraLensDirection.back),
      orElse: () => cameras.first,
    );
    _isFrontCamera = next.lensDirection == CameraLensDirection.front;

    final ctrl = CameraController(
      next,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await ctrl.initialize();
    _cam = ctrl;
    await _cam!.startImageStream(_onFrame);
  }

  // ── 每幀進入點 ────────────────────────────────────────────────────
  void _onFrame(CameraImage image) {
    if (_processing || _poseSession == null) return;
    _processing = true;

    final input = InferenceInput(
      yPlane: image.planes[0].bytes,
      uPlane: image.planes[1].bytes,
      vPlane: image.planes[2].bytes,
      imgW: image.width,
      imgH: image.height,
      yRowStride: image.planes[0].bytesPerRow,
      uvRowStride: image.planes[1].bytesPerRow,
      uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
      isFrontCamera: _isFrontCamera,
    );

    final converted = convertYUV(input);
    _runInference(converted);
  }

  // ── ONNX 推論 + 解碼 + EMA (搬自 body_test_screen,邏輯相同) ──────
  Future<void> _runInference(Float32List converted) async {
    OrtValueTensor? tensor;
    List<OrtValue?>? outputs;

    try {
      const inputH = 256, inputW = 192;
      tensor = OrtValueTensor.createTensorWithDataList(
          converted, [1, 3, inputH, inputW]);

      outputs = await _poseSession!.runAsync(_runOpts!, {'input': tensor});
      if (outputs == null || outputs.length < 2) return;

      final xBatch = (outputs[0]!.value as List)[0] as List;
      final yBatch = (outputs[1]!.value as List)[0] as List;

      final keypoints = <Offset>[];
      final scores = <double>[];

      for (int i = 0; i < numKpts; i++) {
        final xArr = xBatch[i] as List;
        final yArr = yBatch[i] as List;
        if (xArr.isEmpty || yArr.isEmpty) continue;

        double maxX = -double.infinity, maxY = -double.infinity;
        int xi = 0, yi = 0;
        for (int j = 0; j < xArr.length; j++) {
          final v = (xArr[j] as num).toDouble();
          if (v > maxX) {
            maxX = v;
            xi = j;
          }
        }
        for (int j = 0; j < yArr.length; j++) {
          final v = (yArr[j] as num).toDouble();
          if (v > maxY) {
            maxY = v;
            yi = j;
          }
        }

        scores.add((maxX + maxY) / 2);
        final rawX = xi / xArr.length.toDouble();
        final rawY = yi / yArr.length.toDouble();

        if (_isFrontCamera) {
          keypoints.add(Offset(1.0 - rawX, rawY));
        } else {
          keypoints.add(Offset(1.0 - rawX, 1.0 - rawY));
        }
      }

      // EMA 動態平滑 (參數與 body_test_screen 相同:dist*40, clamp 0.15~1.0)
      if (_smoothedKeypoints.isEmpty ||
          _smoothedKeypoints.length != keypoints.length) {
        _smoothedKeypoints = List.from(keypoints);
      } else {
        for (int i = 0; i < keypoints.length; i++) {
          if (i >= scores.length || scores[i] < scoreThreshold) continue;
          final cur = keypoints[i];
          final prev = _smoothedKeypoints[i];
          final dx = cur.dx - prev.dx;
          final dy = cur.dy - prev.dy;
          final dist = math.sqrt(dx * dx + dy * dy);
          final alpha = (dist * 40).clamp(0.15, 1.0);
          _smoothedKeypoints[i] = Offset(
            alpha * cur.dx + (1 - alpha) * prev.dx,
            alpha * cur.dy + (1 - alpha) * prev.dy,
          );
        }
      }

      poseNotifier.value =
          PoseData(List.from(_smoothedKeypoints), scores);
    } catch (e) {
      debugPrint('BodyPoseEngine 推論錯誤: $e');
    } finally {
      tensor?.release();
      if (outputs != null) {
        for (final out in outputs) {
          out?.release();
        }
      }
      // 散熱節能鎖 (與 body_test_screen 相同:休息 20ms)
      Future.delayed(const Duration(milliseconds: 20), () {
        _processing = false;
      });
    }
  }

  // ── 釋放 ──────────────────────────────────────────────────────────
  Future<void> dispose() async {
    await _cam?.stopImageStream();
    await _cam?.dispose();
    _runOpts?.release();
    _poseSession?.release();
    poseNotifier.dispose();
    cameraReady.dispose();
  }
}
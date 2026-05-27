// lib/services/body_pose_service.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import '../models/pose_data.dart';

// ── InferenceInput（定義在這裡，不依賴外部檔案）─────────────────────
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

// ── YUV → Float32 轉換（top-level，供 compute() 使用）──────────────
Float32List convertYUV(InferenceInput input) {
  const inputH = 256;
  const inputW = 192;
  final result = Float32List(3 * inputH * inputW);

  final ratioX = input.imgW / inputH;
  final ratioY = input.imgH / inputW;

  for (int y = 0; y < inputH; y++) {
    final int srcX =
        ((inputH - 1 - y) * ratioX).toInt().clamp(0, input.imgW - 1);
    final int halfSrcX = srcX ~/ 2;

    for (int x = 0; x < inputW; x++) {
      final int srcY =
          (x * ratioY).toInt().clamp(0, input.imgH - 1);

      final yIdx = srcY * input.yRowStride + srcX;
      final uvIdx =
          (srcY ~/ 2) * input.uvRowStride + halfSrcX * input.uvPixelStride;

      final yVal = input.yPlane[yIdx].toDouble();
      final uVal = input.uPlane[uvIdx].toDouble() - 128.0;
      final vVal = input.vPlane[uvIdx].toDouble() - 128.0;

      final r = (yVal + 1.402 * vVal).clamp(0, 255);
      final g = (yVal - 0.344 * uVal - 0.714 * vVal).clamp(0, 255);
      final b = (yVal + 1.772 * uVal).clamp(0, 255);

      final idx = y * inputW + x;
      result[idx] = (r - 123.675) / 58.395;
      result[inputH * inputW + idx] = (g - 116.28) / 57.12;
      result[2 * inputH * inputW + idx] = (b - 103.53) / 57.375;
    }
  }
  return result;
}

// ── BodyPoseService ──────────────────────────────────────────────────
class BodyPoseService {
  OrtSession? _poseSession;
  OrtSession? _detSession;
  bool _processing = false;
  bool _isFrontCamera = true;

  final ValueNotifier<PoseData> poseNotifier =
      ValueNotifier(PoseData.empty());

  List<Offset> _smoothedKeypoints = [];
  static const double _scoreThreshold = 0.3;
  static const int _numKpts = 133;

  // ── 初始化 ────────────────────────────────────────────────────────
  Future<void> init({required bool isFrontCamera}) async {
    _isFrontCamera = isFrontCamera;

    final sessionOptions = OrtSessionOptions()
      ..setIntraOpNumThreads(4)
      ..setInterOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(
          GraphOptimizationLevel.ortEnableAll);

    try {
      sessionOptions.appendNnapiProvider(NnapiFlags.useNone);
    } catch (_) {}

    final poseBytes =
        (await rootBundle.load('assets/rtmpose_wholebody.onnx'))
            .buffer
            .asUint8List();
    _poseSession = OrtSession.fromBuffer(poseBytes, sessionOptions);

    final detBytes =
        (await rootBundle.load('assets/rtmdet.onnx'))
            .buffer
            .asUint8List();
    _detSession = OrtSession.fromBuffer(detBytes, sessionOptions);
  }

  // ── 鏡頭切換時同步方向 ────────────────────────────────────────────
  void updateCameraDirection({required bool isFrontCamera}) {
    _isFrontCamera = isFrontCamera;
  }

  // ── 每幀進入點 ────────────────────────────────────────────────────
  void onFrame(CameraImage image) {
    if (_processing || _poseSession == null) return;
    _processing = true;
    _runPipeline(image).then((data) {
      _applyEMA(data);
      _processing = false;
    });
  }

  // ── EMA 平滑 ──────────────────────────────────────────────────────
  void _applyEMA(PoseData newData) {
    if (newData.keypoints.isEmpty) return;
    if (_smoothedKeypoints.isEmpty ||
        _smoothedKeypoints.length != newData.keypoints.length) {
      _smoothedKeypoints = List.from(newData.keypoints);
    } else {
      for (int i = 0; i < newData.keypoints.length; i++) {
        if (i >= newData.scores.length ||
            newData.scores[i] < _scoreThreshold) {
          continue;
        }
        final cur = newData.keypoints[i];
        final prev = _smoothedKeypoints[i];
        final dx = cur.dx - prev.dx;
        final dy = cur.dy - prev.dy;
        final dist = math.sqrt(dx * dx + dy * dy);
        final alpha = (dist * 25).clamp(0.05, 1.0);
        _smoothedKeypoints[i] = Offset(
          alpha * cur.dx + (1 - alpha) * prev.dx,
          alpha * cur.dy + (1 - alpha) * prev.dy,
        );
      }
    }
    poseNotifier.value =
        PoseData(List.from(_smoothedKeypoints), newData.scores);
  }

  // ── ONNX 推論 ─────────────────────────────────────────────────────
  Future<PoseData> _runPipeline(CameraImage image) async {
    try {
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

      final converted = await compute(convertYUV, input);

      const inputH = 256, inputW = 192;
      final tensor = OrtValueTensor.createTensorWithDataList(
          converted, [1, 3, inputH, inputW]);
      final runOpts = OrtRunOptions();
      final outputs = _poseSession!.run(runOpts, {'input': tensor});
      tensor.release();
      runOpts.release();

      if (outputs.length < 2) return PoseData.empty();

      // outputs[0] / [1] 不會是 null（長度已確認 >= 2）
      final xOut = outputs[0]!;
      final yOut = outputs[1]!;
      final xBatch = (xOut.value as List)[0] as List;
      final yBatch = (yOut.value as List)[0] as List;

      final keypoints = <Offset>[];
      final scores = <double>[];

      for (int i = 0; i < _numKpts; i++) {
        final xArr = xBatch[i] as List;
        final yArr = yBatch[i] as List;
        if (xArr.isEmpty || yArr.isEmpty) continue;

        double maxX = -double.infinity, maxY = -double.infinity;
        int xi = 0, yi = 0;
        for (int j = 0; j < xArr.length; j++) {
          final v = (xArr[j] as num).toDouble();
          if (v > maxX) { maxX = v; xi = j; }
        }
        for (int j = 0; j < yArr.length; j++) {
          final v = (yArr[j] as num).toDouble();
          if (v > maxY) { maxY = v; yi = j; }
        }

        scores.add((maxX + maxY) / 2);
        final rawX = xi / xArr.length.toDouble();
        keypoints.add(Offset(
          _isFrontCamera ? 1.0 - rawX : rawX,
          yi / yArr.length.toDouble(),
        ));
      }

      xOut.release();
      yOut.release();
      return PoseData(keypoints, scores);
    } catch (e) {
      debugPrint('BodyPoseService 推論錯誤: $e');
      return PoseData.empty();
    }
  }

  // ── 釋放資源 ──────────────────────────────────────────────────────
  void dispose() {
    poseNotifier.dispose();
    _poseSession?.release();
    _detSession?.release();
  }
}
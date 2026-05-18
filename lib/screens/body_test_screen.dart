// lib/screens/body_test_screen.dart
//
// 全身骨架測試頁面
// 完全獨立：使用 Flutter Camera + ONNX RTMPose
// 與手部的 TrainingScreen / MediaPipe 完全無關

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

import '../models/pose_data.dart';
import '../services/body_pose_service.dart';

// ── 骨骼連線定義 ─────────────────────────────────────────────────────
const _skeletonConnections = [
  // 臉部
  [0, 1], [0, 2], [1, 3], [2, 4],
  // 上半身
  [5, 6], [5, 7], [7, 9], [6, 8], [8, 10],
  [5, 11], [6, 12], [11, 12],
  // 下半身
  [11, 13], [13, 15], [12, 14], [14, 16],
  // 左手指
  [91, 92], [92, 93], [93, 94], [94, 95],
  [91, 96], [96, 97], [97, 98], [98, 99],
  [91, 100], [100, 101], [101, 102], [102, 103],
  [91, 104], [104, 105], [105, 106], [106, 107],
  [91, 108], [108, 109], [109, 110], [110, 111],
  // 右手指
  [112, 113], [113, 114], [114, 115], [115, 116],
  [112, 117], [117, 118], [118, 119], [119, 120],
  [112, 121], [121, 122], [122, 123], [123, 124],
  [112, 125], [125, 126], [126, 127], [127, 128],
  [112, 129], [129, 130], [130, 131], [131, 132],
];

class BodyTestScreen extends StatefulWidget {
  const BodyTestScreen({super.key});

  @override
  State<BodyTestScreen> createState() => _BodyTestScreenState();
}

class _BodyTestScreenState extends State<BodyTestScreen> {
  // ── 相機 ─────────────────────────────────────────────────────────
  CameraController? _cam;
  bool _camReady = false;
  bool _isFrontCamera = true;

  // ── ONNX ─────────────────────────────────────────────────────────
  OrtSession? _poseSession;
  bool _processing = false;

  // ── 骨架資料 ─────────────────────────────────────────────────────
  final ValueNotifier<PoseData> _poseNotifier =
      ValueNotifier(PoseData.empty());
  List<Offset> _smoothedKeypoints = [];
  static const double _scoreThreshold = 0.3;

  // ── 狀態顯示 ─────────────────────────────────────────────────────
  int _detectedPoints = 0;
  double _avgScore = 0;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
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
      opts.appendNnapiProvider(NnapiFlags.useNone);
    } catch (_) {}

    final bytes =
        (await rootBundle.load('assets/rtmpose_wholebody.onnx'))
            .buffer
            .asUint8List();
    _poseSession = OrtSession.fromBuffer(bytes, opts);

    if (mounted) {
      setState(() => _camReady = true);
      await _cam!.startImageStream(_onFrame);
    }
  }

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

    compute(convertYUV, input).then((converted) {
      _runInference(converted);
    });
  }

  Future<void> _runInference(Float32List converted) async {
    try {
      const inputH = 256, inputW = 192, numKpts = 133;

      final tensor = OrtValueTensor.createTensorWithDataList(
          converted, [1, 3, inputH, inputW]);
      final runOpts = OrtRunOptions();
      final outputs = _poseSession!.run(runOpts, {'input': tensor});
      tensor.release();
      runOpts.release();

      if (outputs == null || outputs.length < 2) {
        _processing = false;
        return;
      }

      final xOut = outputs[0]!;
      final yOut = outputs[1]!;
      final xBatch = (xOut.value as List)[0] as List;
      final yBatch = (yOut.value as List)[0] as List;

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
          if (v > maxX) { maxX = v; xi = j; }
        }
        for (int j = 0; j < yArr.length; j++) {
          final v = (yArr[j] as num).toDouble();
          if (v > maxY) { maxY = v; yi = j; }
        }

        scores.add((maxX + maxY) / 2);
        
        // ── 座標歸一化 ───────────────────────────────────────────────────
        final rawX = xi / xArr.length.toDouble();
        final rawY = yi / yArr.length.toDouble();

        // ── 前後鏡頭座標映射邏輯修正 ─────────────────────────────────────────
        if (_isFrontCamera) {
          // 前鏡頭（自拍）：左右鏡像 (1.0 - rawX)，上下不變。
          keypoints.add(Offset(1.0 - rawX, rawY));
        } else {
          // 後鏡頭（主鏡頭）：原先發生上下左右相反，上一步修正了上下，
          // 這裡將 rawX 也改為 1.0 - rawX，成功解決左右相反的問題！
          keypoints.add(Offset(1.0 - rawX, 1.0 - rawY)); 
        }
      }

      xOut.release();
      yOut.release();

      // EMA 平滑
      if (_smoothedKeypoints.isEmpty ||
          _smoothedKeypoints.length != keypoints.length) {
        _smoothedKeypoints = List.from(keypoints);
      } else {
        for (int i = 0; i < keypoints.length; i++) {
          if (i >= scores.length || scores[i] < _scoreThreshold) continue;
          final cur = keypoints[i];
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

      // 統計有效點數與平均分
      final validScores =
          scores.where((s) => s > _scoreThreshold).toList();

      if (mounted) {
        _poseNotifier.value =
            PoseData(List.from(_smoothedKeypoints), scores);
        setState(() {
          _detectedPoints = validScores.length;
          _avgScore = validScores.isEmpty
              ? 0
              : validScores.reduce((a, b) => a + b) / validScores.length;
        });
      }
    } catch (e) {
      debugPrint('BodyTestScreen 推論錯誤: $e');
    } finally {
      _processing = false;
    }
  }

  Future<void> _switchCamera() async {
    if (_cam == null) return;
    await _cam!.stopImageStream();
    await _cam!.dispose();

    final cameras = await availableCameras();
    final next = cameras.firstWhere(
      (c) => c.lensDirection !=
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

    if (mounted) setState(() {});
    await _cam!.startImageStream(_onFrame);
  }

  @override
  void dispose() {
    _cam?.stopImageStream();
    _cam?.dispose();
    _poseSession?.release();
    _poseNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildBody()),
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF161824),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF252738)),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '全身骨架偵測',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 8),
                    _TopBarBetaBadge(),
                  ],
                ),
                Text(
                  'RTMPose Wholebody · 133 關鍵點',
                  style:
                      TextStyle(color: Color(0xFF8A8D9F), fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _switchCamera,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF161824),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF252738)),
              ),
              child: const Icon(Icons.flip_camera_ios,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_camReady || _cam == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                color: Color(0xFF00BCD4), strokeWidth: 3),
            SizedBox(height: 16),
            Text('載入模型中...',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_cam!),

            // 骨架 Overlay
            ValueListenableBuilder<PoseData>(
              valueListenable: _poseNotifier,
              builder: (_, data, __) => CustomPaint(
                painter: _BodySkeletonPainter(data, _scoreThreshold),
              ),
            ),

            // 沒有偵測到時的提示
            if (_detectedPoints < 5)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: Text(
                    '請站入鏡頭範圍內',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161824),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF252738)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(
            icon: Icons.location_on,
            label: '偵測點數',
            value: '$_detectedPoints / 133',
            color: _detectedPoints > 50
                ? const Color(0xFF4CAF50)
                : const Color(0xFFFF9800),
          ),
          Container(width: 1, height: 32, color: const Color(0xFF252738)),
          _buildStat(
            icon: Icons.analytics,
            label: '平均信心度',
            value: _avgScore > 0
                ? _avgScore.toStringAsFixed(2)
                : '--',
            color: const Color(0xFF00BCD4),
          ),
          Container(width: 1, height: 32, color: const Color(0xFF252738)),
          _buildStat(
            icon: Icons.camera_alt,
            label: '鏡頭',
            value: _isFrontCamera ? '前鏡頭' : '後鏡頭',
            color: const Color(0xFF8A8D9F),
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8A8D9F), fontSize: 10),
        ),
      ],
    );
  }
}

// ── TopBar Beta 標籤 ──────────────────────────────────────────────────
class _TopBarBetaBadge extends StatelessWidget {
  const _TopBarBetaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF00BCD4).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: const Color(0xFF00BCD4).withOpacity(0.4), width: 1),
      ),
      child: const Text(
        'Beta',
        style: TextStyle(
          color: Color(0xFF00BCD4),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── 骨架繪製器 ────────────────────────────────────────────────────────
class _BodySkeletonPainter extends CustomPainter {
  final PoseData data;
  final double threshold;

  _BodySkeletonPainter(this.data, this.threshold);

  bool _valid(Offset p) =>
      p.dx > 0.02 && p.dx < 0.98 && p.dy > 0.02 && p.dy < 0.98;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.keypoints.isEmpty || data.scores.isEmpty) return;

    final bodyVisible = List.generate(17, (i) => i)
        .where((i) =>
            i < data.scores.length &&
            data.scores[i] > threshold &&
            i < data.keypoints.length &&
            _valid(data.keypoints[i]))
        .length;
    if (bodyVisible < 3) return;

    final bonePaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    for (final conn in _skeletonConnections) {
      final a = conn[0], b = conn[1];
      if (a >= data.keypoints.length || b >= data.keypoints.length) continue;
      if (a >= data.scores.length || b >= data.scores.length) continue;
      if (data.scores[a] < threshold || data.scores[b] < threshold) continue;

      final pa = data.keypoints[a];
      final pb = data.keypoints[b];
      if (!_valid(pa) || !_valid(pb)) continue;

      final dx = (pa.dx - pb.dx) * size.width;
      final dy = (pa.dy - pb.dy) * size.height;
      if ((dx * dx + dy * dy) > size.width * size.width * 0.5) continue;

      canvas.drawLine(
        Offset(pa.dx * size.width, pa.dy * size.height),
        Offset(pb.dx * size.width, pb.dy * size.height),
        bonePaint,
      );
    }

    for (int i = 0; i < data.keypoints.length; i++) {
      if (i >= data.scores.length || data.scores[i] < threshold) continue;
      final p = data.keypoints[i];
      if (!_valid(p)) continue;
      canvas.drawCircle(
        Offset(p.dx * size.width, p.dy * size.height),
        i < 17 ? 5 : 3,
        jointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_BodySkeletonPainter old) => true;
}
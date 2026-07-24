// lib/features/demo/standard_analysis_screen.dart
//
// ══════════════════════════════════════════════════════════════════
//  動作標準分析
//
//  功能:
//    ✅ 內建預設影片 + 使用者自選影片
//    ✅ 逐幀骨架偵測(RTMPose 全身 133 點)
//    ✅ 多維度特徵萃取(主要關節、對稱性、穩定性、動作次數)
//    ✅ 儲存為 JSON 模板(給未來病人動作比對用)
// ══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img_lib;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../models/pose_data.dart';
import '../../services/body_pose_engine.dart';

class StandardAnalysisScreen extends StatefulWidget {
  const StandardAnalysisScreen({super.key});

  @override
  State<StandardAnalysisScreen> createState() =>
      _StandardAnalysisScreenState();
}

class _StandardAnalysisScreenState extends State<StandardAnalysisScreen> {
  // ── 預設影片清單 ──
  static const List<Map<String, String>> _presetVideos = [
    {
      'name': '站姿抬腳(示範)',
      'actionType': '站姿抬腳',
      'assetPath': 'assets/preset_videos/standing_knee_raise_demo.mp4',
    },
    // 未來擴充加在這裡
  ];

  // ── 選擇狀態 ──
  String? _selectedVideoPath;
  String _currentActionType = '';
  bool _isPreset = false;   // 是否為內建影片
  bool _isAnalyzing = false;

  // ── 使用者輸入動作名稱 ──
  final TextEditingController _actionNameController = TextEditingController();

  // ── 分析進度 ──
  int _totalFrames = 0;
  int _processedFrames = 0;
  int _framesWithPose = 0;

  // ── 多維度分析資料 ──
  final List<List<Offset>> _framePoses = [];
  final List<List<double>> _frameScores = [];
  final List<PoseData> _collectedPoses = [];

  // ── 分析結果 ──
  List<int> _mainJointIndices = [];
  Map<int, double> _jointTotalMovement = {};
  List<double> _actionIntensity = [];
  int _estimatedReps = 0;
  double _symmetryScore = 0;
  double _stabilityScore = 0;

  // ── 引擎 ──
  BodyPoseEngine? _engine;

  @override
  void dispose() {
    _engine?.dispose();
    _actionNameController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  1. 選影片來源
  // ═══════════════════════════════════════════════════════════════

  void _showVideoSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '選擇影片來源',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D2E),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading:
                    const Icon(Icons.video_library, color: Color(0xFF4A65FF)),
                title: const Text('內建示範影片'),
                subtitle: Text('${_presetVideos.length} 支可選'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPresetVideoPicker();
                },
              ),
              const Divider(),
              ListTile(
                leading:
                    const Icon(Icons.folder_open, color: Color(0xFF4CAF50)),
                title: const Text('選我的影片'),
                subtitle: const Text('從相簿選擇 + 手動輸入動作名稱'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCustomVideo();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPresetVideoPicker() async {
    final picked = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('選內建示範影片',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ..._presetVideos.map((v) => ListTile(
                    leading:
                        const Icon(Icons.movie, color: Color(0xFF4A65FF)),
                    title: Text(v['name']!),
                    subtitle: Text('動作類型:${v['actionType']}'),
                    onTap: () => Navigator.pop(ctx, v),
                  )),
            ],
          ),
        ),
      ),
    );

    if (picked == null) return;
    final tempPath = await _copyAssetToTemp(picked['assetPath']!);

    setState(() {
      _selectedVideoPath = tempPath;
      _currentActionType = picked['actionType']!;
      _isPreset = true;
      _resetAnalysisState();
    });
  }

  Future<void> _pickCustomVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.isEmpty) return;

    final actionName = await _askActionName();
    if (actionName == null || actionName.isEmpty) return;

    setState(() {
      _selectedVideoPath = result.files.single.path;
      _currentActionType = actionName;
      _isPreset = false;
      _resetAnalysisState();
    });
  }

  Future<String?> _askActionName() async {
    _actionNameController.text = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('這是什麼動作?'),
        content: TextField(
          controller: _actionNameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '例如:站姿抬腳、翻掌、側捏',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(
                ctx, _actionNameController.text.trim()),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  void _resetAnalysisState() {
    _totalFrames = 0;
    _processedFrames = 0;
    _framesWithPose = 0;
    _collectedPoses.clear();
    _framePoses.clear();
    _frameScores.clear();
    _mainJointIndices = [];
    _jointTotalMovement = {};
    _actionIntensity = [];
    _estimatedReps = 0;
    _symmetryScore = 0;
    _stabilityScore = 0;
  }

  Future<String> _copyAssetToTemp(String assetPath) async {
    final bytes = await DefaultAssetBundle.of(context).load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final fileName = assetPath.split('/').last;
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file.path;
  }

  // ═══════════════════════════════════════════════════════════════
  //  2. 開始分析
  // ═══════════════════════════════════════════════════════════════

  Future<void> _startAnalysis() async {
    if (_selectedVideoPath == null) return;

    setState(() {
      _isAnalyzing = true;
      _processedFrames = 0;
      _framesWithPose = 0;
      _collectedPoses.clear();
      _framePoses.clear();
      _frameScores.clear();
    });

    try {
      _engine ??= BodyPoseEngine();
      await _engine!.init();

      // 讀影片實際長度
      final videoCtrl = VideoPlayerController.file(File(_selectedVideoPath!));
      await videoCtrl.initialize();
      final double videoDurationSec =
          videoCtrl.value.duration.inMilliseconds / 1000.0;
      await videoCtrl.dispose();

      // 逐幀設定
      const int fps = 2;
      const int maxAnalyzeSec = 60;
      final double actualAnalyzeSec =
          math.min(videoDurationSec, maxAnalyzeSec.toDouble());
      final int totalFrames = (fps * actualAnalyzeSec).ceil();

      debugPrint('📹 影片長度: ${videoDurationSec.toStringAsFixed(1)} 秒, '
          '將分析前 ${actualAnalyzeSec.toStringAsFixed(1)} 秒 = $totalFrames 幀');

      setState(() => _totalFrames = totalFrames);

      for (int i = 0; i < totalFrames; i++) {
        if (!mounted) return;
        final int timeMs = i * (1000 ~/ fps);

        final Uint8List? jpegBytes = await VideoThumbnail.thumbnailData(
          video: _selectedVideoPath!,
          timeMs: timeMs,
          imageFormat: ImageFormat.JPEG,
          quality: 75,
        );

        if (jpegBytes == null) {
          setState(() => _processedFrames = i + 1);
          continue;
        }

        final img_lib.Image? decoded = img_lib.decodeJpg(jpegBytes);
        if (decoded == null) {
          setState(() => _processedFrames = i + 1);
          continue;
        }

        final Uint8List rgbBytes = _imageToRgbBytes(decoded);

        await _engine!.processExternalFrame(
          rgbBytes,
          decoded.width,
          decoded.height,
          isMirror: false,
        );

        final PoseData pose = _engine!.poseNotifier.value;
        if (pose.keypoints.isNotEmpty) {
          _collectedPoses.add(pose);
          _framePoses.add(List<Offset>.from(pose.keypoints));
          _frameScores.add(List<double>.from(pose.scores));
          setState(() => _framesWithPose++);
        }

        setState(() => _processedFrames = i + 1);
      }

      // 多維度分析
      if (_framePoses.length >= 3) {
        _analyzeMultiDimensional();
        if (mounted) setState(() {});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '分析完成:$_processedFrames 幀,成功偵測 $_framesWithPose 幀'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析錯誤:$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Uint8List _imageToRgbBytes(img_lib.Image img) {
    final int w = img.width;
    final int h = img.height;
    final Uint8List rgb = Uint8List(w * h * 3);
    int idx = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final pixel = img.getPixel(x, y);
        rgb[idx++] = pixel.r.toInt();
        rgb[idx++] = pixel.g.toInt();
        rgb[idx++] = pixel.b.toInt();
      }
    }
    return rgb;
  }

  // ═══════════════════════════════════════════════════════════════
  //  3. 多維度特徵萃取
  // ═══════════════════════════════════════════════════════════════

  void _analyzeMultiDimensional() {
    final int numFrames = _framePoses.length;
    if (numFrames < 3) return;

    const double scoreThreshold = 0.3;
    const int bodyJointStart = 0;
    const int bodyJointEnd = 16;

    // 1. 每個關節總位移
    final Map<int, double> totalMovement = {};
    for (int j = bodyJointStart; j <= bodyJointEnd; j++) {
      double sum = 0;
      int validPairs = 0;
      for (int f = 1; f < numFrames; f++) {
        if (_frameScores[f][j] < scoreThreshold ||
            _frameScores[f - 1][j] < scoreThreshold) continue;
        final prev = _framePoses[f - 1][j];
        final curr = _framePoses[f][j];
        final dx = curr.dx - prev.dx;
        final dy = curr.dy - prev.dy;
        sum += math.sqrt(dx * dx + dy * dy);
        validPairs++;
      }
      if (validPairs > 0) totalMovement[j] = sum;
    }
    _jointTotalMovement = totalMovement;

    // 2. 主要活動關節(前 5)
    final sorted = totalMovement.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _mainJointIndices = sorted.take(5).map((e) => e.key).toList();

    // 3. 動作強度曲線
    final List<double> intensity = [];
    for (int f = 1; f < numFrames; f++) {
      double sum = 0;
      for (final j in _mainJointIndices) {
        if (_frameScores[f][j] < scoreThreshold ||
            _frameScores[f - 1][j] < scoreThreshold) continue;
        final prev = _framePoses[f - 1][j];
        final curr = _framePoses[f][j];
        final dx = curr.dx - prev.dx;
        final dy = curr.dy - prev.dy;
        sum += math.sqrt(dx * dx + dy * dy);
      }
      intensity.add(sum);
    }
    _actionIntensity = intensity;

    // 4-6. 次數 / 對稱 / 穩定
    _estimatedReps = _countPeaks(intensity);
    _symmetryScore = _computeSymmetry(totalMovement);
    _stabilityScore = _computeStability();
  }

  int _countPeaks(List<double> intensity) {
    if (intensity.length < 3) return 0;
    final mean = intensity.reduce((a, b) => a + b) / intensity.length;
    final variance = intensity
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        intensity.length;
    final std = math.sqrt(variance);
    final threshold = mean + std * 0.3;

    int peaks = 0;
    bool inPeak = false;
    for (final v in intensity) {
      if (v > threshold && !inPeak) {
        peaks++;
        inPeak = true;
      } else if (v <= threshold * 0.7 && inPeak) {
        inPeak = false;
      }
    }
    return peaks;
  }

  double _computeSymmetry(Map<int, double> movement) {
    const pairs = [
      [5, 6], [7, 8], [9, 10], [11, 12], [13, 14], [15, 16],
    ];
    double total = 0;
    int valid = 0;
    for (final pair in pairs) {
      final l = movement[pair[0]];
      final r = movement[pair[1]];
      if (l == null || r == null) continue;
      final maxV = math.max(l, r);
      if (maxV < 1e-6) continue;
      total += math.min(l, r) / maxV;
      valid++;
    }
    return valid == 0 ? 0 : total / valid;
  }

  double _computeStability() {
    const trunkJoints = [5, 6, 11, 12];
    double totalVariance = 0;
    int count = 0;
    for (final j in trunkJoints) {
      final List<double> xs = [];
      final List<double> ys = [];
      for (int f = 0; f < _framePoses.length; f++) {
        if (_frameScores[f][j] < 0.3) continue;
        xs.add(_framePoses[f][j].dx);
        ys.add(_framePoses[f][j].dy);
      }
      if (xs.length < 3) continue;
      final meanX = xs.reduce((a, b) => a + b) / xs.length;
      final meanY = ys.reduce((a, b) => a + b) / ys.length;
      final varX = xs
              .map((v) => (v - meanX) * (v - meanX))
              .reduce((a, b) => a + b) /
          xs.length;
      final varY = ys
              .map((v) => (v - meanY) * (v - meanY))
              .reduce((a, b) => a + b) /
          ys.length;
      totalVariance += (varX + varY);
      count++;
    }
    if (count == 0) return 0;
    final avgVariance = totalVariance / count;
    return (1 - avgVariance * 20).clamp(0.0, 1.0);
  }

  String _jointName(int index) {
    const names = {
      0: '鼻',
      5: '左肩', 6: '右肩',
      7: '左肘', 8: '右肘',
      9: '左腕', 10: '右腕',
      11: '左髖', 12: '右髖',
      13: '左膝', 14: '右膝',
      15: '左踝', 16: '右踝',
    };
    return names[index] ?? '關節$index';
  }

  // ═══════════════════════════════════════════════════════════════
  //  4. 儲存 JSON 模板
  // ═══════════════════════════════════════════════════════════════

  Future<void> _saveAsTemplate() async {
    if (_mainJointIndices.isEmpty) return;

    // 讓使用者輸入模板名稱
    final nameCtrl =
        TextEditingController(text: '$_currentActionType 標準模板');
    final saveName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('儲存為模板'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '模板名稱'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('儲存'),
          ),
        ],
      ),
    );

    if (saveName == null || saveName.isEmpty) return;

    try {
      // 組 JSON 資料
      final Map<String, dynamic> data = {
        'templateName': saveName,
        'actionType': _currentActionType,
        'createdAt': DateTime.now().toIso8601String(),
        'totalFrames': _framePoses.length,
        'estimatedReps': _estimatedReps,
        'symmetryScore': _symmetryScore,
        'stabilityScore': _stabilityScore,
        'mainJoints': _mainJointIndices
            .map((idx) => {
                  'index': idx,
                  'name': _jointName(idx),
                  'movement': _jointTotalMovement[idx] ?? 0,
                })
            .toList(),
        'actionIntensity': _actionIntensity,
        'framePoses': _framePoses
            .map((frame) => frame
                .map((offset) => {'x': offset.dx, 'y': offset.dy})
                .toList())
            .toList(),
        'frameScores': _frameScores,
      };

      // 存到手機內部目錄
      final dir = await getApplicationDocumentsDirectory();
      final templatesDir = Directory('${dir.path}/templates');
      if (!await templatesDir.exists()) {
        await templatesDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${templatesDir.path}/template_$timestamp.json');
      await file.writeAsString(jsonEncode(data));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('模板已儲存:${file.path.split('/').last}'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗:$e')),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  UI
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bool hasVideo = _selectedVideoPath != null;
    final String fileName =
        hasVideo ? _selectedVideoPath!.split('/').last : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('動作標準分析'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '從治療師示範影片,建立動作標準模板',
              style: TextStyle(
                  color: Color(0xFF1A1D2E),
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '選內建影片 or 自己的影片 → AI 逐幀分析 → 儲存為模板(供病人比對)',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 24),

            // 選影片區塊
            GestureDetector(
              onTap: _isAnalyzing ? null : _showVideoSourcePicker,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasVideo
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFDDE0F0),
                    width: hasVideo ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      hasVideo
                          ? Icons.check_circle
                          : Icons.video_call_outlined,
                      color: hasVideo
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF9CA3AF),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasVideo ? fileName : '點擊選擇影片',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: hasVideo
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasVideo) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isPreset
                              ? const Color(0xFFE0E7FF)
                              : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_isPreset ? "內建" : "自選"} · $_currentActionType',
                          style: TextStyle(
                            color: _isPreset
                                ? const Color(0xFF4A65FF)
                                : const Color(0xFF2E7D32),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 分析按鈕
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                    !hasVideo || _isAnalyzing ? null : _startAnalysis,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A65FF),
                  disabledBackgroundColor: const Color(0xFFEDEFF7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isAnalyzing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('開始分析',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
              ),
            ),

            const SizedBox(height: 20),

            // 進度
            if (_isAnalyzing || _processedFrames > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDE0F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('進度:$_processedFrames / $_totalFrames 幀',
                        style: const TextStyle(
                            color: Color(0xFF1A1D2E),
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('成功偵測到骨架:$_framesWithPose 幀',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _totalFrames == 0
                          ? 0
                          : _processedFrames / _totalFrames,
                      backgroundColor: const Color(0xFFEDEFF7),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4A65FF)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 多維度分析結果
            if (_mainJointIndices.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF4A65FF), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.analytics,
                            color: Color(0xFF4A65FF), size: 18),
                        SizedBox(width: 6),
                        Text('動作特徵分析',
                            style: TextStyle(
                                color: Color(0xFF1A1D2E),
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('AI 偵測的主要活動關節',
                        style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _mainJointIndices.map((idx) {
                        final movement = _jointTotalMovement[idx] ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            '${_jointName(idx)} (${movement.toStringAsFixed(2)})',
                            style: const TextStyle(
                                color: Color(0xFF4A65FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 24),
                    _buildAngleStat('估算動作次數', '$_estimatedReps 次',
                        const Color(0xFF4CAF50)),
                    const SizedBox(height: 8),
                    _buildAngleStat(
                      '左右對稱性',
                      '${(_symmetryScore * 100).toStringAsFixed(0)}%',
                      _symmetryScore > 0.7
                          ? const Color(0xFF4CAF50)
                          : _symmetryScore > 0.4
                              ? const Color(0xFFFF9800)
                              : const Color(0xFFF44336),
                    ),
                    const SizedBox(height: 8),
                    _buildAngleStat(
                      '軀幹穩定性',
                      '${(_stabilityScore * 100).toStringAsFixed(0)}%',
                      _stabilityScore > 0.7
                          ? const Color(0xFF4CAF50)
                          : _stabilityScore > 0.4
                              ? const Color(0xFFFF9800)
                              : const Color(0xFFF44336),
                    ),
                    const SizedBox(height: 8),
                    _buildAngleStat('分析資料點', '${_framePoses.length} 幀',
                        const Color(0xFF6B7280)),
                    const SizedBox(height: 16),

                    // ── 儲存為模板按鈕 ──
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _saveAsTemplate,
                        icon: const Icon(Icons.save_alt, size: 18),
                        label: const Text('儲存為模板',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '💡 儲存後可作為病人動作比對的參考模板',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAngleStat(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        ),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
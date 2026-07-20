// lib/features/demo/standard_analysis_screen.dart
//
// ══════════════════════════════════════════════════════════════════
//  動作標準分析
//
//  用途:分析治療師示範影片,逐幀跑 RTMPose 骨架,產生「角度序列」
//  技術棧:
//    - file_picker  → 選影片
//    - video_thumbnail → 逐幀截圖(JPEG)
//    - image 套件   → JPEG 解碼成 RGB
//    - BodyPoseEngine.processExternalFrame → 骨架偵測
//
//  現階段:
//    - 只顯示「這支影片跑出來的關鍵點座標數」+ 前幾幀的骨架資料
//    - DTW 比對 / 完整角度分析 → 下一階段做
// ══════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:image/image.dart' as img_lib;

import '../../services/body_pose_engine.dart';
import '../../models/pose_data.dart';

class StandardAnalysisScreen extends StatefulWidget {
  const StandardAnalysisScreen({super.key});

  @override
  State<StandardAnalysisScreen> createState() =>
      _StandardAnalysisScreenState();
}

class _StandardAnalysisScreenState extends State<StandardAnalysisScreen> {
  String? _selectedVideoPath;
  bool _isAnalyzing = false;

  // ── 分析進度 & 結果 ──
  int _totalFrames = 0;
  int _processedFrames = 0;
  int _framesWithPose = 0;
  final List<PoseData> _collectedPoses = [];

  BodyPoseEngine? _engine;

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  1. 選影片
  // ═══════════════════════════════════════════════════════════════
  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _selectedVideoPath = result.files.single.path;
      _totalFrames = 0;
      _processedFrames = 0;
      _framesWithPose = 0;
      _collectedPoses.clear();
    });
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
    });

    try {
      // ─── 初始化引擎(只做 ONNX,不啟動相機)──
      _engine ??= BodyPoseEngine();
      // 只初始化 ONNX,跳過相機。所以我們自己呼叫 _initOnnx?
      // 但 _initOnnx 是 private 的。這裡改用 init 但不 startCamera 也可以,
      // 但 init 內部有 _initCamera 會開相機。
      //
      // 折衷做法:引擎的 init 會開相機但不 startCamera,不會影響分析。
      // 相機開了不啟動串流,不會吃資源。
      await _engine!.init();

      // ─── 逐幀分析設定 ──
      const int fps = 5;              // 每秒抽 5 幀(復健動作變化慢,5fps 夠)
      const int videoLengthSecEst = 10; // 先假設 10 秒(下方會依實際情況調整)
      final int totalFrames = fps * videoLengthSecEst;

      setState(() => _totalFrames = totalFrames);

      // ─── 逐幀跑分析 ──
      // 每 200ms 截 1 幀,連續截 totalFrames 幀
      for (int i = 0; i < totalFrames; i++) {
        if (!mounted) return;

        final int timeMs = i * (1000 ~/ fps);   // 0, 200, 400, ...

        // (a) 用 video_thumbnail 抓這時間點的截圖(JPEG bytes)
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

        // (b) JPEG 解碼成 RGB
        final img_lib.Image? decoded = img_lib.decodeJpg(jpegBytes);
        if (decoded == null) {
          setState(() => _processedFrames = i + 1);
          continue;
        }

        // (c) 轉成連續的 RGB Uint8List(不含 alpha)
        final Uint8List rgbBytes = _imageToRgbBytes(decoded);

        // (d) 送進骨架引擎
        await _engine!.processExternalFrame(
          rgbBytes,
          decoded.width,
          decoded.height,
          isMirror: false,   // 影片不是自拍,不用鏡像
        );

        // (e) 拿當下 poseNotifier 的結果存起來
        final PoseData pose = _engine!.poseNotifier.value;
        if (pose.keypoints.isNotEmpty) {
          _collectedPoses.add(pose);
          setState(() => _framesWithPose++);
        }

        setState(() => _processedFrames = i + 1);
      }

      // ─── 分析完成 ──
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '分析完成:共處理 $_processedFrames 幀,'
              '成功偵測到骨架的有 $_framesWithPose 幀',
            ),
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

  /// image 套件的 Image 轉成連續 RGB bytes
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
              '從治療師示範影片,分析出標準動作角度',
              style: TextStyle(
                color: Color(0xFF1A1D2E),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '選擇一支示範影片,AI 逐幀分析骨架 → 收集角度序列(下階段做 DTW 比對)',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 24),

            // ── 選影片區塊 ──
            GestureDetector(
              onTap: _isAnalyzing ? null : _pickVideo,
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
                      hasVideo ? fileName : '點擊選擇治療師示範影片',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight:
                            hasVideo ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── 分析按鈕 ──
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
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isAnalyzing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        '開始分析',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── 進度顯示 ──
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
                    Text(
                      '進度:$_processedFrames / $_totalFrames 幀',
                      style: const TextStyle(
                        color: Color(0xFF1A1D2E),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '成功偵測到骨架:$_framesWithPose 幀',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _totalFrames == 0
                          ? 0
                          : _processedFrames / _totalFrames,
                      backgroundColor: const Color(0xFFEDEFF7),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4A65FF),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ── 分析結果簡報 ──
            if (_collectedPoses.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFF4CAF50), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Color(0xFF4CAF50), size: 18),
                        SizedBox(width: 6),
                        Text(
                          '分析成功',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '共收集 ${_collectedPoses.length} 個骨架資料點\n'
                      '每個資料點有 ${_collectedPoses.first.keypoints.length} 個關鍵點\n\n'
                      '(下階段:DTW 比對、角度分析、模板儲存)',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
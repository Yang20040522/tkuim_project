// lib/features/analysis/video_analysis_service.dart
//
// ══════════════════════════════════════════════════════════════════
//  影片分析服務(共用)
//
//  用途:對任意 mp4 影片跑「骨架偵測 + 多維度特徵萃取」
//
//  誰在用:
//    - standard_analysis_screen.dart(治療師建立模板時)
//    - history_screen.dart(病人歷史錄影分析時)
//    - 未來的 body_training_screen(訓練完自動分析)
// ══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img_lib;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../services/body_pose_engine.dart';
import 'models/video_segment.dart';
import 'motion_feature_extractor.dart';

class BodyVideoFrameSample {
  BodyVideoFrameSample({
    required this.timestampMs,
    List<Offset>? landmarks,
    List<double>? scores,
  })  : landmarks =
            landmarks == null ? null : List<Offset>.unmodifiable(landmarks),
        scores = scores == null ? null : List<double>.unmodifiable(scores);

  final int timestampMs;
  final List<Offset>? landmarks;
  final List<double>? scores;

  bool get isValid =>
      landmarks != null && landmarks!.isNotEmpty && scores != null;
}

class BodyVideoAnalysisResult {
  BodyVideoAnalysisResult({
    required this.segment,
    required List<BodyVideoFrameSample> attemptedFrames,
    required this.summary,
  }) : attemptedFrames =
            List<BodyVideoFrameSample>.unmodifiable(attemptedFrames);

  final VideoSegment segment;
  final List<BodyVideoFrameSample> attemptedFrames;
  final MotionAnalysisResult? summary;

  int get attemptedFrameCount => attemptedFrames.length;
  int get validFrameCount =>
      attemptedFrames.where((frame) => frame.isValid).length;
  double get validRatio =>
      attemptedFrameCount == 0 ? 0 : validFrameCount / attemptedFrameCount;
}

class VideoAnalysisService {
  /// 對影片跑逐幀骨架偵測 + 多維度分析
  ///
  /// 回傳完整分析結果(如果偵測不到骨架則回 null)
  ///
  /// [videoPath] 影片檔案路徑
  /// [onProgress] 進度 callback(0.0 ~ 1.0)
  /// [fps] 每秒抽幀數,預設 2(復健動作變化慢)
  /// [maxAnalyzeSec] 最多分析前 N 秒,預設 60(避免太久)
  static Future<MotionAnalysisResult?> analyzeVideo({
    required String videoPath,
    void Function(double progress)? onProgress,
    bool Function()? shouldCancel,
    int fps = 2,
    int maxAnalyzeSec = 60,
    Duration? startTime,
    Duration? endTime,
  }) async {
    final result = await analyzeVideoDetailed(
      videoPath: videoPath,
      onProgress: onProgress,
      shouldCancel: shouldCancel,
      fps: fps,
      maxAnalyzeSec: maxAnalyzeSec,
      startTime: startTime,
      endTime: endTime,
    );
    return result.summary;
  }

  /// 離線 Body 影片的完整分析資料。
  ///
  /// 每個嘗試時間點都會保留，即使該幀沒有偵測到骨架也不會壓縮時間軸。
  static Future<BodyVideoAnalysisResult> analyzeVideoDetailed({
    required String videoPath,
    void Function(double progress)? onProgress,
    bool Function()? shouldCancel,
    int fps = 2,
    int maxAnalyzeSec = 60,
    Duration? startTime,
    Duration? endTime,
  }) async {
    if (fps <= 0) throw ArgumentError.value(fps, 'fps', '必須大於 0');

    final videoCtrl = VideoPlayerController.file(File(videoPath));
    late final Duration videoDuration;
    try {
      await videoCtrl.initialize();
      videoDuration = videoCtrl.value.duration;
    } finally {
      await videoCtrl.dispose();
    }

    final segment = VideoSegment.resolve(
      videoDuration: videoDuration,
      startTime: startTime,
      endTime: endTime,
      maximumDuration: Duration(seconds: maxAnalyzeSec),
    );
    final timestamps = _sampleTimestamps(segment, fps);
    final engine = BodyPoseEngine();
    debugPrint('🎬 初始化引擎中...');

    try {
      await engine.initForExternalFrames().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('引擎初始化超時(30秒)'),
          );
      debugPrint('🎬 引擎初始化完成（離線影片模式，不啟動相機）');

      debugPrint('📹 分析區段: ${segment.startMs}ms → ${segment.endMs}ms, '
          '預計 ${timestamps.length} 幀');

      final List<List<Offset>> framePoses = [];
      final List<List<double>> frameScores = [];
      final attemptedFrames = <BodyVideoFrameSample>[];

      // ── 逐幀分析 ──
      int successFrames = 0;
      int failedFrames = 0;

      for (int i = 0; i < timestamps.length; i++) {
        // 檢查是否被取消
        if (shouldCancel?.call() == true) {
          debugPrint('🛑 使用者取消分析');
          break;
        }

        final timeMs = timestamps[i];

        // (a) 截圖(加 10 秒 timeout)
        Uint8List? jpegBytes;
        try {
          jpegBytes = await VideoThumbnail.thumbnailData(
            video: videoPath,
            timeMs: timeMs,
            imageFormat: ImageFormat.JPEG,
            quality: 75,
          ).timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('⚠️ 第 $i 幀截圖失敗/超時: $e');
          failedFrames++;
          attemptedFrames.add(BodyVideoFrameSample(timestampMs: timeMs));
          onProgress?.call((i + 1) / timestamps.length);
          if (failedFrames > 5) {
            debugPrint('❌ 連續失敗超過 5 次,終止分析');
            break;
          }
          continue;
        }

        if (jpegBytes == null) {
          failedFrames++;
          attemptedFrames.add(BodyVideoFrameSample(timestampMs: timeMs));
          onProgress?.call((i + 1) / timestamps.length);
          continue;
        }

        // (b) JPEG 解碼
        final img_lib.Image? decoded = img_lib.decodeJpg(jpegBytes);
        if (decoded == null) {
          failedFrames++;
          attemptedFrames.add(BodyVideoFrameSample(timestampMs: timeMs));
          onProgress?.call((i + 1) / timestamps.length);
          continue;
        }

        // (c) RGB 轉換
        final Uint8List rgbBytes = _imageToRgbBytes(decoded);

        // (d) ONNX 推論(加 5 秒 timeout)
        final previousPose = engine.poseNotifier.value;
        try {
          await engine
              .processExternalFrame(
                rgbBytes,
                decoded.width,
                decoded.height,
                isMirror: false,
              )
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('⚠️ 第 $i 幀推論失敗/超時: $e');
          failedFrames++;
          attemptedFrames.add(BodyVideoFrameSample(timestampMs: timeMs));
          onProgress?.call((i + 1) / timestamps.length);
          continue;
        }

        // (e) 收集結果
        final pose = engine.poseNotifier.value;
        if (!identical(pose, previousPose) && pose.keypoints.isNotEmpty) {
          final landmarks = List<Offset>.from(pose.keypoints);
          final scores = List<double>.from(pose.scores);
          framePoses.add(landmarks);
          frameScores.add(scores);
          attemptedFrames.add(BodyVideoFrameSample(
            timestampMs: timeMs,
            landmarks: landmarks,
            scores: scores,
          ));
          successFrames++;
          failedFrames = 0;
        } else {
          failedFrames++;
          attemptedFrames.add(BodyVideoFrameSample(timestampMs: timeMs));
        }

        onProgress?.call((i + 1) / timestamps.length);

        // 每 5 幀 log 一次進度
        if ((i + 1) % 5 == 0) {
          debugPrint(
              '🎬 已處理 ${i + 1}/${timestamps.length} 幀,成功 $successFrames 幀');
        }
      }
      debugPrint('🎬 分析完成:嘗試 ${attemptedFrames.length} 幀,'
          '成功 $successFrames 幀');

      // ── 委派給共用特徵萃取器 ──
      final summary = framePoses.length < 3
          ? null
          : MotionFeatureExtractor.extractFeatures(
              framePoses: framePoses,
              frameScores: frameScores,
            );
      return BodyVideoAnalysisResult(
        segment: segment,
        attemptedFrames: attemptedFrames,
        summary: summary,
      );
    } finally {
      await engine.dispose();
    }
  }

  static List<int> _sampleTimestamps(VideoSegment segment, int fps) {
    final intervalMs = math.max(1, (1000 / fps).round());
    final timestamps = <int>[];
    for (var timeMs = segment.startMs;
        timeMs <= segment.endMs;
        timeMs += intervalMs) {
      timestamps.add(timeMs);
    }
    if (timestamps.isEmpty || timestamps.last != segment.endMs) {
      timestamps.add(segment.endMs);
    }
    return timestamps;
  }

  /// 讀取所有已存的治療師模板 JSON
  static Future<List<Map<String, dynamic>>> loadAllTemplates() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final templatesDir = Directory('${dir.path}/templates');
      if (!await templatesDir.exists()) return [];

      final files = templatesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();

      // 新到舊
      files.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      final List<Map<String, dynamic>> results = [];
      for (final f in files) {
        try {
          final content = await f.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          data['_filePath'] = f.path;
          results.add(data);
        } catch (e) {
          debugPrint('讀取模板失敗:${f.path} - $e');
        }
      }
      return results;
    } catch (e) {
      debugPrint('列出模板失敗:$e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Private
  // ─────────────────────────────────────────────────────────────

  static Uint8List _imageToRgbBytes(img_lib.Image img) {
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
}

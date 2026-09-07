// lib/features/analysis/hand_analysis_service.dart
//
// ══════════════════════════════════════════════════════════════════
//  手部影片分析服務
//
//  用途:對手部影片跑逐幀 MediaPipe 手部偵測 + 手部專屬特徵萃取
//
//  技術架構:
//    - 使用同學做的 mediapipeService.detectHandInImage(IMAGE 模式)
//    - 完全獨立於相機串流,不影響手部訓練
//    - 逐幀截圖 → 送 MediaPipe → 收 21 點手部骨架
//    - 委派給 HandFeatureExtractor 做特徵萃取
// ══════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../services/mediapipe_service.dart';
import 'hand_feature_extractor.dart';
import 'models/video_segment.dart';

class HandVideoFrameSample {
  HandVideoFrameSample({
    required this.timestampMs,
    List<Landmark>? landmarks,
  }) : landmarks =
            landmarks == null ? null : List<Landmark>.unmodifiable(landmarks);

  final int timestampMs;
  final List<Landmark>? landmarks;

  bool get isValid => landmarks != null && landmarks!.length >= 21;
}

class HandVideoAnalysisResult {
  HandVideoAnalysisResult({
    required this.segment,
    required List<HandVideoFrameSample> attemptedFrames,
    required this.summary,
  }) : attemptedFrames =
            List<HandVideoFrameSample>.unmodifiable(attemptedFrames);

  final VideoSegment segment;
  final List<HandVideoFrameSample> attemptedFrames;
  final HandAnalysisResult? summary;

  int get attemptedFrameCount => attemptedFrames.length;
  int get validFrameCount =>
      attemptedFrames.where((frame) => frame.isValid).length;
  double get validRatio =>
      attemptedFrameCount == 0 ? 0 : validFrameCount / attemptedFrameCount;
}

class HandAnalysisService {
  /// 對手部影片跑逐幀 MediaPipe 偵測 + 特徵萃取
  ///
  /// [videoPath] 影片檔案路徑
  /// [onProgress] 進度 callback(0.0 ~ 1.0)
  /// [shouldCancel] 取消檢查
  /// [fps] 每秒抽幀數,預設 3(手部動作稍快)
  /// [maxAnalyzeSec] 最多分析前 N 秒,預設 60
  static Future<HandAnalysisResult?> analyzeVideo({
    required String videoPath,
    void Function(double progress)? onProgress,
    bool Function()? shouldCancel,
    int fps = 3,
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

  /// 離線 Hand 影片的完整分析資料，包含每個嘗試時間點及原始 x/y/z。
  static Future<HandVideoAnalysisResult> analyzeVideoDetailed({
    required String videoPath,
    void Function(double progress)? onProgress,
    bool Function()? shouldCancel,
    int fps = 3,
    int maxAnalyzeSec = 60,
    Duration? startTime,
    Duration? endTime,
  }) async {
    if (fps <= 0) throw ArgumentError.value(fps, 'fps', '必須大於 0');

    // 使用同學的 MediaPipeService(獨立 IMAGE 模式)
    final mediapipeService = MediaPipeService();

    try {
      // ── 讀影片實際長度 ──
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

      debugPrint('🖐 手部影片區段: ${segment.startMs}ms → ${segment.endMs}ms, '
          '預計 ${timestamps.length} 幀 (${fps}fps)');

      final List<List<Offset>> frameHandLandmarks = [];
      final attemptedFrames = <HandVideoFrameSample>[];
      int successFrames = 0;
      int failedFrames = 0;

      // ── 逐幀分析 ──
      for (int i = 0; i < timestamps.length; i++) {
        // 檢查取消
        if (shouldCancel?.call() == true) {
          debugPrint('🛑 使用者取消手部分析');
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
          debugPrint('⚠️ 第 $i 幀截圖失敗: $e');
          failedFrames++;
          attemptedFrames.add(HandVideoFrameSample(timestampMs: timeMs));
          onProgress?.call((i + 1) / timestamps.length);
          if (failedFrames > 5) {
            debugPrint('❌ 連續失敗超過 5 次,終止分析');
            break;
          }
          continue;
        }

        if (jpegBytes == null) {
          failedFrames++;
          attemptedFrames.add(HandVideoFrameSample(timestampMs: timeMs));
          onProgress?.call((i + 1) / timestamps.length);
          continue;
        }

        // (b) 送 MediaPipe(用同學的 IMAGE 模式)
        try {
          final result = await mediapipeService
              .detectHandInImage(jpegBytes, isMirror: false)
              .timeout(const Duration(seconds: 5));

          if (result.handDetected && result.landmarks.length >= 21) {
            // 轉成 Offset 清單(x, y)
            final offsets =
                result.landmarks.map((lm) => Offset(lm.x, lm.y)).toList();
            frameHandLandmarks.add(offsets);
            attemptedFrames.add(HandVideoFrameSample(
              timestampMs: timeMs,
              landmarks: result.landmarks,
            ));
            successFrames++;
            failedFrames = 0;
          } else {
            attemptedFrames.add(HandVideoFrameSample(timestampMs: timeMs));
            failedFrames++;
          }
        } catch (e) {
          debugPrint('⚠️ 第 $i 幀 MediaPipe 失敗: $e');
          attemptedFrames.add(HandVideoFrameSample(timestampMs: timeMs));
          failedFrames++;
        }

        onProgress?.call((i + 1) / timestamps.length);

        // 每 5 幀 log 進度
        if ((i + 1) % 5 == 0) {
          debugPrint(
              '🖐 已處理 ${i + 1}/${timestamps.length} 幀,成功 $successFrames 幀');
        }
      }

      debugPrint('🖐 手部分析完成:嘗試 ${attemptedFrames.length} 幀,'
          '成功 $successFrames 幀');

      // ── 委派給手部特徵萃取器 ──
      final summary = frameHandLandmarks.length < 3
          ? null
          : HandFeatureExtractor.extractFeatures(
              frameHandLandmarks: frameHandLandmarks,
              fps: fps,
            );
      return HandVideoAnalysisResult(
        segment: segment,
        attemptedFrames: attemptedFrames,
        summary: summary,
      );
    } finally {
      // 釋放 MediaPipe 資源
      mediapipeService.dispose();
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
}

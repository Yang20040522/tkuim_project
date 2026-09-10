// lib/services/history_service.dart
//
// HistoryService 負責：
// 1. 本機歷史紀錄通知。
// 2. 手動上傳自由訓練紀錄。
// 3. 自動升級 session 一次上傳全部 Lv. 紀錄。
// 4. 同一次自動升級只上傳一支共用影片。
// 5. 手動升級仍維持每一筆各自上傳。

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/platform/app_platform.dart';
import '../features/account/app_session.dart';
import '../features/notification/notification_service.dart';
import '../models/training_action.dart';
import 'exercise_api_service.dart';
import 'history_repository.dart';

class UploadResult {
  final int success;
  final int failed;
  final int total;

  const UploadResult({
    required this.success,
    required this.failed,
    required this.total,
  });

  bool get allSucceeded => failed == 0 && total > 0;

  bool get hasNothingToUpload => total == 0;
}

abstract class TrainingHistoryGateway {
  Future<Map<String, dynamic>> uploadMetadata({
    required int userId,
    required TrainingRecord record,
  });

  Future<void> uploadVideo({
    required int historyId,
    required int userId,
    required String videoPath,
  });

  Future<List<Map<String, dynamic>>> fetchHistory({
    required int userId,
  });
}

class RestTrainingHistoryGateway implements TrainingHistoryGateway {
  const RestTrainingHistoryGateway();

  @override
  Future<Map<String, dynamic>> uploadMetadata({
    required int userId,
    required TrainingRecord record,
  }) =>
      ExerciseApiService.uploadTrainingHistory(
        userId: userId,
        clientTimestamp: record.timestamp,
        actionName: record.actionName,
        difficulty: record.difficulty,
        durationSeconds: record.durationSeconds,
        completedReps: record.completedReps,
        targetReps: record.targetReps,
        mistakeLogs: record.mistakeLogs,
        sessionId: record.sessionId,
      );

  @override
  Future<void> uploadVideo({
    required int historyId,
    required int userId,
    required String videoPath,
  }) =>
      ExerciseApiService.uploadTrainingHistoryVideo(
        historyId: historyId,
        userId: userId,
        videoPath: videoPath,
      );

  @override
  Future<List<Map<String, dynamic>>> fetchHistory({
    required int userId,
  }) =>
      ExerciseApiService.fetchTrainingHistory(
        userId: userId,
        requesterUserId: userId,
        identityToken: AppSession.customExerciseToken,
      );
}

class HistoryService extends ChangeNotifier {
  HistoryService._(this._repository, this._gateway);

  static final HistoryService _instance =
      HistoryService._(historyRepository, const RestTrainingHistoryGateway());

  factory HistoryService() => _instance;

  @visibleForTesting
  HistoryService.withRepository(
    this._repository, {
    TrainingHistoryGateway gateway = const RestTrainingHistoryGateway(),
  }) : _gateway = gateway;

  HistoryService.readOnly(
    this._repository, {
    TrainingHistoryGateway gateway = const RestTrainingHistoryGateway(),
  }) : _gateway = gateway;

  final HistoryRepository _repository;
  final TrainingHistoryGateway _gateway;

  Future<List<TrainingRecord>> getHistory() => _repository.getHistory();

  /// 所有新紀錄都必須有 sessionId。
  ///
  /// TrainingScreen / BodyTrainingScreen 會明確傳入：
  /// - auto:xxxx   自動升級
  /// - manual:xxxx 手動升級
  ///
  /// 其他舊呼叫點若沒傳，就自動視為獨立紀錄，
  /// 不讓它被誤併到自動升級群組。
  TrainingRecord _ensureSessionId(
    TrainingRecord record,
  ) {
    final current = record.sessionId?.trim();

    if (current != null && current.isNotEmpty) {
      return record;
    }

    return record.copyWith(
      sessionId: 'manual:${DateTime.now().microsecondsSinceEpoch}',
      replaceSessionId: true,
    );
  }

  Future<void> saveRecord(
    TrainingRecord record,
  ) async {
    final normalized = _ensureSessionId(record);

    await _repository.saveRecord(
      normalized,
    );

    final mistakes = normalized.mistakeLogs.length;

    final completed =
        normalized.completedReps < 0 ? 0 : normalized.completedReps;

    final attempts = completed + mistakes;

    final denominator =
        attempts > normalized.targetReps ? attempts : normalized.targetReps;

    final acc = denominator > 0
        ? (completed / denominator * 100).clamp(0, 100).round()
        : 0;

    final fullyCompleted = normalized.completedReps >= normalized.targetReps;

    if (AppPlatform.current.supportsNotifications) {
      NotificationService()
          .addAchievement(
            title: fullyCompleted && mistakes == 0 ? '完美完成一組訓練 🎯' : '完成一組訓練 ✅',
            body: '「${normalized.actionName}」'
                '${normalized.completedReps} / '
                '${normalized.targetReps} 下 · '
                '準確度 $acc%',
          )
          .catchError((_) {});
    }

    notifyListeners();
  }

  Future<void> updateLastRecordsVideoPath(
    int count,
    String? videoPath,
  ) async {
    await _repository.updateLastRecordsVideoPath(
      count,
      videoPath,
    );

    notifyListeners();
  }

  Future<void> removeByTimestamp(
    String timestamp,
  ) async {
    await _repository.removeByTimestamp(
      timestamp,
    );

    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _repository.clearHistory();
    notifyListeners();
  }

  Future<int> getPendingUploadCount() async {
    final pending = await _repository.getUnsyncedRecords();

    return pending.length;
  }

  bool _isAutoRecord(
    TrainingRecord record,
  ) {
    final sessionId = record.sessionId?.trim();

    return sessionId != null && sessionId.startsWith('auto:');
  }

  /// 舊的整批上傳功能仍保留。
  ///
  /// 現在行為改成：
  /// - auto session：整組一起處理，只傳一次影片。
  /// - manual / 單筆：維持逐筆處理。
  Future<UploadResult> uploadPendingRecords({
    required int userId,
  }) async {
    final pending = await _repository.getUnsyncedRecords();

    if (pending.isEmpty) {
      return const UploadResult(
        success: 0,
        failed: 0,
        total: 0,
      );
    }

    final autoGroups = <String, List<TrainingRecord>>{};

    final manualRecords = <TrainingRecord>[];

    for (final record in pending) {
      if (_isAutoRecord(record)) {
        autoGroups
            .putIfAbsent(
              record.sessionId!,
              () => <TrainingRecord>[],
            )
            .add(record);
      } else {
        manualRecords.add(record);
      }
    }

    int success = 0;
    int failed = 0;

    for (final record in manualRecords) {
      try {
        await _uploadSingleRecord(
          record,
          userId: userId,
        );

        success++;
      } catch (e) {
        debugPrint(
          '上傳訓練紀錄失敗'
          '(${record.timestamp}): $e',
        );

        failed++;
      }
    }

    for (final group in autoGroups.values) {
      try {
        await _uploadAutoLevelSessionInternal(
          group,
          userId: userId,
        );

        success += group.length;
      } catch (e) {
        debugPrint(
          '上傳自動升級 session 失敗'
          '(${group.first.sessionId}): $e',
        );

        failed += group.length;
      }
    }

    notifyListeners();

    return UploadResult(
      success: success,
      failed: failed,
      total: pending.length,
    );
  }

  /// 手動升級／一般單筆使用。
  Future<bool> uploadSingleRecord(
    TrainingRecord record, {
    required int userId,
  }) async {
    try {
      await _uploadSingleRecord(
        record,
        userId: userId,
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint(
        '上傳單筆訓練紀錄失敗'
        '(${record.timestamp}): $e',
      );

      return false;
    }
  }

  /// 自動升級專用：
  /// 一個按鈕一次上傳整個 session。
  ///
  /// 後端仍保留每個 Lv. 各自一列 metadata，
  /// 這樣治療師展開時還是能看 Lv.1 / Lv.2 / Lv.3
  /// 各自的次數與錯誤。
  ///
  /// 但共用錄影只會上傳一次，掛在這個 session
  /// 最後一個有影片的難度紀錄上。
  Future<bool> uploadAutoLevelSession(
    List<TrainingRecord> records, {
    required int userId,
  }) async {
    if (records.isEmpty) {
      return false;
    }

    try {
      await _uploadAutoLevelSessionInternal(
        records,
        userId: userId,
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint(
        '上傳自動升級紀錄失敗'
        '(${records.first.sessionId}): $e',
      );

      return false;
    }
  }

  Future<void> _uploadAutoLevelSessionInternal(
    List<TrainingRecord> source, {
    required int userId,
  }) async {
    final records = List<TrainingRecord>.from(source)
      ..sort(
        (a, b) => a.difficulty.compareTo(
          b.difficulty,
        ),
      );

    final sessionIds = records
        .map(
          (record) => record.sessionId?.trim() ?? '',
        )
        .toSet();

    if (sessionIds.length != 1 ||
        sessionIds.first.isEmpty ||
        !sessionIds.first.startsWith('auto:')) {
      throw const FormatException(
        '這不是有效的自動升級 session',
      );
    }

    // 同一場自動升級只保留一個真正的影片上傳者。
    //
    // BodyTrainingScreen 會把同一個 videoPath
    // 補到多個 Lv. 記錄，所以這裡一定不能每筆都傳一次。
    TrainingRecord? videoOwner;

    for (final record in records) {
      final path = record.videoPath?.trim();

      if (path != null && path.isNotEmpty) {
        videoOwner = record;
      }
    }

    for (final record in records) {
      final shouldUploadVideo =
          videoOwner != null && identical(record, videoOwner);

      await _uploadSingleRecord(
        record,
        userId: userId,
        uploadVideo: shouldUploadVideo,
        markSharedVideoAsHandled: !shouldUploadVideo,
      );
    }
  }

  Future<int> syncFromCloud({
    required int userId,
  }) async {
    final rows = await _gateway.fetchHistory(userId: userId);

    final cloud = rows
        .map(
          (row) => TrainingRecord.fromJson(
            Map<String, dynamic>.from(
              row,
            ),
          ),
        )
        .toList();

    final added = await _repository.mergeRecords(
      cloud,
    );

    if (added > 0) {
      notifyListeners();
    }

    return added;
  }

  Future<void> _uploadSingleRecord(
    TrainingRecord record, {
    required int userId,
    bool uploadVideo = true,
    bool markSharedVideoAsHandled = false,
  }) async {
    debugPrint(
      '===== TRAINING HISTORY UPLOAD =====',
    );

    debugPrint(
      'sessionId = ${record.sessionId}',
    );

    debugPrint(
      'timestamp = ${record.timestamp}',
    );

    debugPrint(
      'actionName = ${record.actionName}',
    );

    debugPrint(
      'difficulty = ${record.difficulty}',
    );

    debugPrint(
      'durationSeconds = '
      '${record.durationSeconds}',
    );

    debugPrint(
      'completedReps = '
      '${record.completedReps}',
    );

    debugPrint(
      'targetReps = ${record.targetReps}',
    );

    debugPrint(
      'mistakeCount = '
      '${record.mistakeLogs.length}',
    );

    // ───────────────────────────────────────────
    // 1. metadata
    // ───────────────────────────────────────────

    final response = await _gateway.uploadMetadata(
      userId: userId,
      record: record,
    );

    final historyId = (response['id'] as num?)?.toInt();

    if (historyId == null) {
      throw const FormatException(
        '後端未回傳 training history id',
      );
    }

    await _repository.markAsSynced(
      record.timestamp,
      historyId: historyId,
    );

    // 自動升級 group 裡非 videoOwner 的 row：
    // metadata 已經成功，且不需要重複傳同一支影片。
    if (!uploadVideo) {
      final path = record.videoPath?.trim();

      if (markSharedVideoAsHandled &&
          path != null &&
          path.isNotEmpty &&
          !record.isVideoSynced) {
        await _repository.markVideoAsSynced(
          record.timestamp,
        );
      }

      return;
    }

    // ───────────────────────────────────────────
    // 2. video
    // ───────────────────────────────────────────

    final videoPath = record.videoPath;

    if (videoPath == null || videoPath.trim().isEmpty) {
      return;
    }

    if (record.isVideoSynced) {
      return;
    }

    final videoFile = File(videoPath);

    if (!await videoFile.exists()) {
      throw FileSystemException(
        '找不到待上傳的本機訓練影片',
        videoPath,
      );
    }

    final videoBytes = await videoFile.length();

    final videoSizeMb = videoBytes / 1024 / 1024;

    debugPrint('');
    debugPrint(
      '========== VIDEO DEBUG ==========',
    );

    debugPrint(
      'historyId = $historyId',
    );

    debugPrint(
      'videoPath = $videoPath',
    );

    debugPrint(
      'videoBytes = $videoBytes',
    );

    debugPrint(
      'videoSizeMB = '
      '${videoSizeMb.toStringAsFixed(2)} MB',
    );

    debugPrint(
      '=================================',
    );

    try {
      await _gateway.uploadVideo(
        historyId: historyId,
        userId: userId,
        videoPath: videoPath,
      );
    } catch (e) {
      debugPrint(
        '❌ VIDEO UPLOAD FAILED: $e',
      );

      rethrow;
    }

    await _repository.markVideoAsSynced(
      record.timestamp,
    );

    debugPrint(
      '✅ VIDEO UPLOAD SUCCESS '
      'historyId=$historyId',
    );
  }
}

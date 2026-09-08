// lib/features/chat/user_context_builder.dart
//
// 負責：把 RehabAssist 目前可取得的使用者相關資料整理成 UserContext。
//
// 資料來源：
// 1. AppSession / Account API
// 2. HistoryService 本機訓練紀錄
// 3. 後端 training-history 雲端自由訓練紀錄
// 4. TrainingResultRepository 完整訓練結果
// 5. 治療師指派動作
// 6. 今日 RehabPlan
// 7. RehabAssist 內建動作資料
//
// 每個資料來源各自失敗時不會讓整個 AI 無法使用，
// 只會記錄在 unavailableSources，讓 AI 知道該資料目前無法取得。

import '../../models/training_action.dart';
import '../../services/exercise_api_service.dart';
import '../../services/history_service.dart';

import '../account/account_api_service.dart';
import '../account/app_session.dart';

import '../custom_exercise/repositories/unified_exercise_assignment_repository_selection.dart';

import '../plan/exercise.dart';
import '../plan/plan_repository.dart';

import '../pose_measurement/repositories/training_result_repository_selection.dart';

import 'chat_repository.dart';

class UserContextBuilder {
  final HistoryService _historyService = HistoryService();

  static const Duration _sourceTimeout = Duration(seconds: 6);

  static const int _recentTrainingLimit = 10;
  static const int _recentSessionLimit = 10;
  static const int _mistakeLimit = 10;

  Future<UserContext> build() async {
    final loadedSources = <String>[];
    final unavailableSources = <String>[];

    String name = AppSession.name?.trim().isNotEmpty == true
        ? AppSession.name!.trim()
        : '使用者';

    String role = AppSession.role?.name ?? '未知';

    final userIdText = AppSession.userId?.trim();
    final numericUserId =
        userIdText == null ? null : int.tryParse(userIdText);

    List<TrainingRecord> localRecords = [];
    List<TrainingRecord> cloudRecords = [];

    final historyFuture = _historyService.getHistory();

    final accountFuture =
        AppSession.isLoggedIn ? AccountApiClient().getAccountInfo() : null;

    final assignedFuture = AppSession.isLoggedIn
        ? unifiedExerciseAssignmentRepository.getPatientAssignedExercises()
        : null;

    final sessionResultFuture =
        AppSession.isLoggedIn ? trainingResultRepository.getMyResults() : null;

    final cloudHistoryFuture = numericUserId == null
        ? null
        : ExerciseApiService.fetchTrainingHistory(
            userId: numericUserId,
          );

    final planFuture = userIdText == null || userIdText.isEmpty
        ? null
        : planRepository.getPlanByDate(
            patientId: userIdText,
            date: DateTime.now(),
          );

    try {
      localRecords =
          await historyFuture.timeout(_sourceTimeout);

      loadedSources.add('本機訓練紀錄');
    } catch (_) {
      unavailableSources.add('本機訓練紀錄');
    }

    if (accountFuture != null) {
      try {
        final account =
            await accountFuture.timeout(_sourceTimeout);

        if (account.name.trim().isNotEmpty) {
          name = account.name.trim();
        }

        if (account.role.trim().isNotEmpty) {
          role = account.role.trim();
        }

        loadedSources.add('帳號資料庫');
      } catch (_) {
        unavailableSources.add('帳號資料庫');
      }
    } else {
      unavailableSources.add('帳號資料庫（目前未登入）');
    }

    if (cloudHistoryFuture != null) {
      try {
        final rows =
            await cloudHistoryFuture.timeout(_sourceTimeout);

        cloudRecords = rows
            .map(
              (row) => TrainingRecord.fromJson(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList();

        loadedSources.add('雲端自由訓練紀錄');
      } catch (_) {
        unavailableSources.add('雲端自由訓練紀錄');
      }
    } else {
      unavailableSources.add('雲端自由訓練紀錄（缺少有效 userId）');
    }

    final mergedRecords = _mergeTrainingRecords(
      localRecords,
      cloudRecords,
    );

    final sortedRecords =
        List<TrainingRecord>.from(mergedRecords)
          ..sort(
            (a, b) => _recordDate(b)
                .compareTo(_recordDate(a)),
          );

    final streak = _calcStreak(mergedRecords);
    final weekly = _calcWeeklyCompleted(mergedRecords);

    final currentLevel =
        sortedRecords.isNotEmpty
            ? sortedRecords.first.difficulty
            : 1;

    final recentTraining =
        _buildRecentTraining(sortedRecords);

    final recentMistakes =
        _buildRecentMistakes(sortedRecords);

    final assignedExercises = <String>[];

    if (assignedFuture != null) {
      try {
        final assigned =
            await assignedFuture.timeout(_sourceTimeout);

        for (final exercise in assigned) {
          final type =
              exercise.type.apiValue == 'CUSTOM'
                  ? '自訂動作'
                  : '系統動作';

          final description =
              exercise.description.trim();

          assignedExercises.add(
            description.isEmpty
                ? '${exercise.name}｜$type'
                : '${exercise.name}｜$type｜$description',
          );
        }

        loadedSources.add('治療師指派動作');
      } catch (_) {
        unavailableSources.add('治療師指派動作');
      }
    } else {
      unavailableSources.add('治療師指派動作（目前未登入）');
    }

    final recentSessionResults = <String>[];
    double? latestSessionScore;

    if (sessionResultFuture != null) {
      try {
        final results =
            await sessionResultFuture.timeout(_sourceTimeout);

        final sortedResults = [...results]
          ..sort(
            (a, b) =>
                b.completedAt.compareTo(a.completedAt),
          );

        if (sortedResults.isNotEmpty) {
          latestSessionScore =
              sortedResults.first.score;
        }

        for (final result
            in sortedResults.take(_recentSessionLimit)) {
          recentSessionResults.add(
            '${_formatDateTime(result.completedAt)}｜'
            '${result.exerciseName}｜'
            '完成 ${result.completedSets}/${result.targetSets} 組｜'
            '${result.completedReps}/${result.targetReps} 次｜'
            'App 分數 ${result.score.toStringAsFixed(0)}｜'
            '訓練 ${_formatDuration(result.durationSeconds)}',
          );
        }

        loadedSources.add('完整訓練結果');
      } catch (_) {
        unavailableSources.add('完整訓練結果');
      }
    } else {
      unavailableSources.add('完整訓練結果（目前未登入）');
    }

    final todayPlan = <String>[];

    if (planFuture != null) {
      try {
        final plan =
            await planFuture.timeout(_sourceTimeout);

        if (plan != null) {
          final sortedItems = [...plan.items]
            ..sort((a, b) => a.order.compareTo(b.order));

          for (final item in sortedItems) {
            final exercise =
                _findPlanExercise(item.exerciseId);

            final exerciseName =
                exercise?.name ?? item.exerciseId;

            todayPlan.add(
              '$exerciseName｜'
              '${item.sets} 組 × ${item.repsPerSet} 次｜'
              '${item.done ? '已完成' : '未完成'}',
            );
          }
        }

        loadedSources.add(
          '今日復健計畫（${planRepository.runtimeType}）',
        );
      } catch (_) {
        unavailableSources.add(
          '今日復健計畫（${planRepository.runtimeType}）',
        );
      }
    } else {
      unavailableSources.add('今日復健計畫（缺少登入使用者）');
    }

    final exerciseCatalog =
        _buildExerciseCatalog();

    loadedSources.add('RehabAssist 內建動作資料');

    final historyScore =
        _calcLastScore(sortedRecords);

    final lastScore =
        latestSessionScore ?? historyScore;

    return UserContext(
      name: name,
      role: role,
      currentLevel: currentLevel,
      weeklyCompleted: weekly.completed,
      weeklyTarget: weekly.target,
      streak: streak,
      lastScore: lastScore,
      todayPlan: todayPlan,
      assignedExercises: assignedExercises,
      recentTraining: recentTraining,
      recentSessionResults: recentSessionResults,
      recentMistakes: recentMistakes,
      exerciseCatalog: exerciseCatalog,
      loadedSources: loadedSources,
      unavailableSources: unavailableSources,
    );
  }

  List<TrainingRecord> _mergeTrainingRecords(
    List<TrainingRecord> local,
    List<TrainingRecord> cloud,
  ) {
    final byTimestamp =
        <String, TrainingRecord>{};

    for (final record in local) {
      byTimestamp[record.timestamp] = record;
    }

    for (final record in cloud) {
      byTimestamp[record.timestamp] = record;
    }

    return byTimestamp.values.toList();
  }

  List<String> _buildRecentTraining(
    List<TrainingRecord> records,
  ) {
    return records
        .take(_recentTrainingLimit)
        .map((record) {
      final mistakes = record.mistakeLogs.length;

      return '${_formatRecordTimestamp(record.timestamp)}｜'
          '${record.actionName}｜'
          '難度 Level ${record.difficulty}｜'
          '目標 ${record.targetReps} 次｜'
          '訓練 ${_formatDuration(record.durationSeconds)}｜'
          '錯誤 $mistakes 項｜'
          '${record.isSynced ? '已同步雲端' : '本機紀錄'}';
    }).toList();
  }

  List<String> _buildRecentMistakes(
    List<TrainingRecord> records,
  ) {
    final counts = <String, int>{};

    for (final record
        in records.take(_recentTrainingLimit)) {
      for (final rawLog in record.mistakeLogs) {
        final log = rawLog.trim();

        if (log.isEmpty) {
          continue;
        }

        counts[log] = (counts[log] ?? 0) + 1;
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final countCompare =
            b.value.compareTo(a.value);

        if (countCompare != 0) {
          return countCompare;
        }

        return a.key.compareTo(b.key);
      });

    return sorted
        .take(_mistakeLimit)
        .map(
          (entry) =>
              '${entry.key}｜最近出現 ${entry.value} 次',
        )
        .toList();
  }

  List<String> _buildExerciseCatalog() {
    return kTrainingActions
        .where(
          (action) =>
              action.type != ActionType.bodyTest,
        )
        .map((action) {
      final difficulties =
          action.difficulties.map((difficulty) {
        return '${difficulty.label}：'
            '${difficulty.description}，'
            '預設 ${difficulty.targetReps} 次';
      }).join('；');

      return '${action.name}｜'
          '${action.description}｜'
          '$difficulties';
    }).toList();
  }

  Exercise? _findPlanExercise(String id) {
    for (final exercise in exerciseLibrary) {
      if (exercise.id == id) {
        return exercise;
      }
    }

    return null;
  }

  DateTime _recordDate(TrainingRecord record) {
    return DateTime.tryParse(record.timestamp) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _calcStreak(List<TrainingRecord> records) {
    if (records.isEmpty) {
      return 0;
    }

    final days = records
        .map((record) {
          final date = DateTime.tryParse(record.timestamp);

          if (date != null) {
            return _formatDate(date);
          }

          if (record.timestamp.length >= 10) {
            return record.timestamp.substring(0, 10);
          }

          return '';
        })
        .where((date) => date.isNotEmpty)
        .toSet();

    if (days.isEmpty) {
      return 0;
    }

    final now = DateTime.now();

    final todayStr =
        _formatDate(now);

    final yesterdayStr = _formatDate(
      now.subtract(const Duration(days: 1)),
    );

    DateTime anchor;

    if (days.contains(todayStr)) {
      anchor = now;
    } else if (days.contains(yesterdayStr)) {
      anchor = now.subtract(
        const Duration(days: 1),
      );
    } else {
      return 0;
    }

    int streak = 0;
    DateTime check = anchor;

    while (days.contains(_formatDate(check))) {
      streak++;

      check = check.subtract(
        const Duration(days: 1),
      );
    }

    return streak;
  }

  double? _calcLastScore(
    List<TrainingRecord> records,
  ) {
    if (records.isEmpty) {
      return null;
    }

    final last = records.first;

    final accuracy =
        ((10 - last.mistakeLogs.length) /
                10 *
                100)
            .clamp(0, 100);

    return accuracy.toDouble();
  }

  ({int completed, int target})
      _calcWeeklyCompleted(
    List<TrainingRecord> records,
  ) {
    final now = DateTime.now();

    final last7Days = List.generate(
      7,
      (index) => _formatDate(
        now.subtract(
          Duration(days: index),
        ),
      ),
    ).toSet();

    final trainedDays = records
        .map((record) {
          final date =
              DateTime.tryParse(record.timestamp);

          if (date != null) {
            return _formatDate(date);
          }

          if (record.timestamp.length >= 10) {
            return record.timestamp.substring(0, 10);
          }

          return '';
        })
        .where(
          (date) =>
              date.isNotEmpty &&
              last7Days.contains(date),
        )
        .toSet()
        .length;

    return (
      completed: trainedDays,
      target: 7,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatRecordTimestamp(
    String timestamp,
  ) {
    final parsed =
        DateTime.tryParse(timestamp);

    if (parsed == null) {
      return timestamp;
    }

    return _formatDateTime(parsed);
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) {
      return '0 秒';
    }

    if (seconds < 60) {
      return '$seconds 秒';
    }

    final minutes = seconds ~/ 60;
    final remainSeconds = seconds % 60;

    if (remainSeconds == 0) {
      return '$minutes 分鐘';
    }

    return '$minutes 分 $remainSeconds 秒';
  }
}
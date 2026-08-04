// lib/features/stats/stats_calculator.dart
//
// 從 TrainingRecord 算統計 — 目前只算雷達圖用的資料
// 未來擴充成就徽章、個人紀錄等時,新方法都放這裡

import '../../services/history_service.dart';

/// 雷達圖一個軸的資料:一個動作 + 這個動作在期間內的平均準確度
class RadarAxis {
  final String actionName;
  final double accuracy; // 0.0 ~ 100.0
  final int recordCount; // 這段期間這個動作練了幾次

  const RadarAxis({
    required this.actionName,
    required this.accuracy,
    required this.recordCount,
  });
}

class StatsCalculator {
  final HistoryService _historyService = HistoryService();

  /// 近 30 天使用者練過的動作 + 各自平均準確度
  /// 回傳的 list 已經按準確度由低到高排序(讓弱項容易被看到)
  Future<List<RadarAxis>> getRecentRadarData({int daysBack = 30}) async {
    final records = await _historyService.getHistory();
    final cutoff = DateTime.now().subtract(Duration(days: daysBack));

    // 篩出時間範圍內的紀錄
    final recent = records.where((r) {
      final dt = DateTime.tryParse(r.timestamp);
      return dt != null && dt.isAfter(cutoff);
    }).toList();

    if (recent.isEmpty) return [];

    // 依動作分組 → 算平均準確度
    final Map<String, List<double>> accByAction = {};
    for (final r in recent) {
      final perfect = (r.targetReps - r.mistakeLogs.length)
          .clamp(0, r.targetReps);
      final acc = r.targetReps > 0
          ? (perfect / r.targetReps * 100)
          : 0.0;
      accByAction.putIfAbsent(r.actionName, () => []).add(acc);
    }

    final axes = accByAction.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return RadarAxis(
        actionName: e.key,
        accuracy: avg,
        recordCount: e.value.length,
      );
    }).toList();

    // 由低到高排序 — 弱項在前面
    axes.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return axes;
  }

  /// 算出個人紀錄卡需要的四個數字
  Future<PersonalRecords> getPersonalRecords() async {
    final records = await _historyService.getHistory();
    if (records.isEmpty) return PersonalRecords.empty;

    // 累積組數
    final total = records.length;

    // 單日最多:把紀錄按日期分組數量最多的那天
    final Map<String, int> byDay = {};
    for (final r in records) {
      final day = r.timestamp.substring(0, 10); // YYYY-MM-DD
      byDay[day] = (byDay[day] ?? 0) + 1;
    }
    final maxDaily =
        byDay.values.fold<int>(0, (max, v) => v > max ? v : max);

    // 最高單組準確度
    int maxAcc = 0;
    for (final r in records) {
      if (r.targetReps <= 0) continue;
      final perfect =
          (r.targetReps - r.mistakeLogs.length).clamp(0, r.targetReps);
      final acc = (perfect / r.targetReps * 100).round();
      if (acc > maxAcc) maxAcc = acc;
    }

    // 連續達成天數(跟首頁同一套算法)
    final streak = _calcStreak(records.map((r) => r.timestamp).toList());

    return PersonalRecords(
      streakDays: streak,
      maxDailySessions: maxDaily,
      totalSessions: total,
      maxAccuracy: maxAcc,
    );
  }

  int _calcStreak(List<String> timestamps) {
    final days = timestamps.map((t) => t.substring(0, 10)).toSet();
    if (days.isEmpty) return 0;

    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final yesterdayStr = _formatDate(now.subtract(const Duration(days: 1)));

    DateTime? anchor;
    if (days.contains(todayStr)) {
      anchor = now;
    } else if (days.contains(yesterdayStr)) {
      anchor = now.subtract(const Duration(days: 1));
    } else {
      return 0;
    }

    int streak = 0;
    var check = anchor;
    while (days.contains(_formatDate(check))) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// 個人紀錄卡的所有數字
class PersonalRecords {
  final int streakDays;         // 連續達成天數
  final int maxDailySessions;   // 單日最多訓練組數
  final int totalSessions;      // 累積訓練組數
  final int maxAccuracy;        // 最高單組準確度 (0~100)

  const PersonalRecords({
    required this.streakDays,
    required this.maxDailySessions,
    required this.totalSessions,
    required this.maxAccuracy,
  });

  static const empty = PersonalRecords(
    streakDays: 0,
    maxDailySessions: 0,
    totalSessions: 0,
    maxAccuracy: 0,
  );
}
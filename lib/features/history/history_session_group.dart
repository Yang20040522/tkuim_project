// lib/features/history/history_session_group.dart
//
// 將同一次自動升級訓練的多筆 TrainingRecord 合併成一張可展開卡片。
// 新資料優先使用 sessionId 分組；舊資料沒有 sessionId 時，會以
// 「相同動作 + 10 分鐘內 + 難度連續上升」做相容性分組。

import 'package:flutter/material.dart';

import '../../core/ui/app_colors.dart';
import '../../models/training_action.dart';

class HistorySessionGroup {
  HistorySessionGroup({
    required this.key,
    required List<TrainingRecord> records,
  }) : records = List<TrainingRecord>.from(records)
          ..sort((a, b) => a.difficulty.compareTo(b.difficulty));

  final String key;
  final List<TrainingRecord> records;

  bool get isMultiLevel =>
      records.length > 1 &&
      records.map((e) => e.difficulty).toSet().length > 1;

  List<int> get levels {
    final values = records.map((e) => e.difficulty).toSet().toList()..sort();
    return values;
  }

  int get totalMistakes =>
      records.fold<int>(0, (sum, r) => sum + r.mistakeLogs.length);

  bool get allComplete => records.every(
        (r) => r.targetReps > 0 && r.completedReps >= r.targetReps,
      );

  TrainingRecord get firstRecord {
    final copy = List<TrainingRecord>.from(records)
      ..sort((a, b) => _recordTime(a).compareTo(_recordTime(b)));
    return copy.first;
  }

  TrainingRecord get lastRecord {
    final copy = List<TrainingRecord>.from(records)
      ..sort((a, b) => _recordTime(a).compareTo(_recordTime(b)));
    return copy.last;
  }

  TrainingRecord? get localVideoRecord {
    for (final r in records) {
      if (r.videoPath != null && r.videoPath!.trim().isNotEmpty) {
        return r;
      }
    }
    return null;
  }

  DateTime get latestTime => _recordTime(lastRecord);
}

DateTime _recordTime(TrainingRecord record) =>
    DateTime.tryParse(record.timestamp) ??
    DateTime.fromMillisecondsSinceEpoch(0);

/// 新資料：sessionId 相同就同組。
///
/// 舊資料：沒有 sessionId 時仍可把像
/// Lv.1 18:12:38 → Lv.2 18:12:50 → Lv.3 18:13:09
/// 這種明顯的自動升級紀錄合併。
List<HistorySessionGroup> groupTrainingRecords(
  List<TrainingRecord> source, {
  Duration legacyWindow = const Duration(minutes: 10),
}) {
  if (source.isEmpty) return const <HistorySessionGroup>[];

  final explicitGroups = <String, List<TrainingRecord>>{};
  final legacy = <TrainingRecord>[];

  for (final record in source) {
    final sessionId = record.sessionId?.trim();

    if (sessionId != null && sessionId.isNotEmpty) {
      // actionName 一併放入 key，避免錯誤資料把不同動作硬合在一起。
      final key = 'session:$sessionId:${record.actionName}';
      explicitGroups.putIfAbsent(key, () => <TrainingRecord>[]).add(record);
    } else {
      legacy.add(record);
    }
  }

  final groups = <HistorySessionGroup>[];

  for (final entry in explicitGroups.entries) {
    groups.add(
      HistorySessionGroup(
        key: entry.key,
        records: entry.value,
      ),
    );
  }

  // 舊資料 fallback：
  // 依時間由舊到新檢查，只允許難度 +1 才接續到同組。
  legacy.sort((a, b) => _recordTime(a).compareTo(_recordTime(b)));

  List<TrainingRecord>? current;
  int legacyGroupIndex = 0;

  void flushCurrent() {
    if (current == null || current!.isEmpty) return;
    groups.add(
      HistorySessionGroup(
        key: 'legacy:$legacyGroupIndex:${current!.first.timestamp}',
        records: current!,
      ),
    );
    legacyGroupIndex++;
    current = null;
  }

  for (final record in legacy) {
    if (current == null || current!.isEmpty) {
      current = <TrainingRecord>[record];
      continue;
    }

    final previous = current!.last;
    final sameAction = previous.actionName == record.actionName;
    final gap = _recordTime(record).difference(_recordTime(previous)).abs();
    final withinWindow = gap <= legacyWindow;
    final nextLevel = record.difficulty == previous.difficulty + 1;

    if (sameAction && withinWindow && nextLevel) {
      current!.add(record);
    } else {
      flushCurrent();
      current = <TrainingRecord>[record];
    }
  }

  flushCurrent();

  // 整組依最新一筆時間排序：最新 session 在上面。
  groups.sort((a, b) => b.latestTime.compareTo(a.latestTime));

  return groups;
}

class HistorySessionExpansionCard extends StatelessWidget {
  const HistorySessionExpansionCard({
    super.key,
    required this.group,
    required this.onUpload,
    required this.isUploading,
    required this.onPlay,
    required this.onAnalyze,
  });

  final HistorySessionGroup group;
  final Future<void> Function(TrainingRecord record) onUpload;
  final bool Function(TrainingRecord record) isUploading;
  final void Function(TrainingRecord record) onPlay;
  final void Function(TrainingRecord record) onAnalyze;

  @override
  Widget build(BuildContext context) {
    final records = group.records;
    final levels = group.levels;
    final first = group.firstRecord;
    final videoRecord = group.localVideoRecord;

    final firstLevel = levels.first;
    final lastLevel = levels.last;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${records.length}',
                      style: const TextStyle(
                        color: Color(0xFF4A65FF),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      '階',
                      style: TextStyle(
                        color: Color(0xFF4A65FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first.actionName,
                      style: const TextStyle(
                        color: Color(0xFF1A1D2E),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      first.timestamp,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      firstLevel == lastLevel
                          ? 'Lv.$firstLevel'
                          : '自動升級 · Lv.$firstLevel → Lv.$lastLevel',
                      style: const TextStyle(
                        color: Color(0xFF4A65FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    group.allComplete ? '✅ 完成' : '尚未完成',
                    style: TextStyle(
                      color: group.allComplete
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF4B4B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    group.totalMistakes == 0
                        ? '0 次失誤'
                        : '${group.totalMistakes} 次失誤',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 同一場訓練共用一支影片，因此外層只顯示一次播放/分析。
          if (videoRecord != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.play_circle_outline,
                    label: '播放錄影',
                    foreground: const Color(0xFF4A65FF),
                    onTap: () => onPlay(videoRecord),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.analytics_outlined,
                    label: '分析錄影',
                    foreground: const Color(0xFF4CAF50),
                    onTap: () => onAnalyze(videoRecord),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 4),

          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              key: PageStorageKey<String>('history-session-${group.key}'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              title: const Text(
                '查看各難度結果',
                style: TextStyle(
                  color: Color(0xFF4A65FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                '${records.length} 個難度紀錄',
                style: const TextStyle(
                  color: Color(0xFF8A8F9E),
                  fontSize: 10,
                ),
              ),
              children: [
                for (int i = 0; i < records.length; i++) ...[
                  _buildLevelResult(context, records[i]),
                  if (i != records.length - 1)
                    const Divider(
                      height: 18,
                      color: Color(0xFFDDE0F0),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelResult(
    BuildContext context,
    TrainingRecord record,
  ) {
    final completed = record.completedReps;
    final target = record.targetReps;
    final mistakes = record.mistakeLogs;
    final minutes = record.durationSeconds ~/ 60;
    final seconds = record.durationSeconds % 60;
    final complete = target > 0 && completed >= target;
    final needsUpload =
        !record.isSynced ||
        (record.videoPath != null && !record.isVideoSynced);
    final uploading = isUploading(record);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Lv.${record.difficulty}',
                  style: const TextStyle(
                    color: Color(0xFF4A65FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$completed / $target 次  •  '
                  '$minutes:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                mistakes.isEmpty
                    ? (complete ? '✅ 完美' : '尚未完成')
                    : '❌ ${mistakes.length} 次失誤',
                style: TextStyle(
                  color: mistakes.isEmpty && complete
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF4B4B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (mistakes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F7),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: mistakes
                    .map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '• $m',
                          style: const TextStyle(
                            color: Color(0xFFB45353),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (needsUpload) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: uploading ? null : () => onUpload(record),
                icon: uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.cloud_upload_outlined,
                        size: 16,
                      ),
                label: Text(
                  uploading
                      ? '上傳中...'
                      : record.isSynced
                          ? '補傳 Lv.${record.difficulty} 錄影'
                          : '上傳 Lv.${record.difficulty} 紀錄',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4A65FF),
                  side: const BorderSide(color: Color(0xFFBCC5FF)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: foreground.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../models/training_action.dart';
import '../history/network_video_playback_screen.dart';

class PatientTrainingVideosCard extends StatelessWidget {
  const PatientTrainingVideosCard({
    super.key,
    required this.records,
    this.httpHeaders = const {},
  });

  final List<TrainingRecord> records;
  final Map<String, String> httpHeaders;

  @override
  Widget build(BuildContext context) {
    final videos = records
        .where((record) => record.videoUrl?.trim().isNotEmpty == true)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.video_library_outlined, color: Color(0xFF4A65FF)),
              SizedBox(width: 10),
              Text(
                '患者訓練影片',
                style: TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (videos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  '患者目前沒有已上傳的訓練影片',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
              ),
            )
          else
            ...videos.map((record) => _VideoRow(
                  record: record,
                  httpHeaders: httpHeaders,
                )),
        ],
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  const _VideoRow({required this.record, required this.httpHeaders});

  final TrainingRecord record;
  final Map<String, String> httpHeaders;

  String get _displayTime {
    final parsed = DateTime.tryParse(record.timestamp);
    if (parsed == null) return record.timestamp;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE0F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.actionName,
                    style: const TextStyle(
                      color: Color(0xFF1A1D2E),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _displayTime,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lv.${record.difficulty} · '
                    '${record.completedReps}/${record.targetReps} · '
                    '${record.durationSeconds}秒 · '
                    '${record.mistakeLogs.length}次失誤',
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: '播放影片',
              icon: const Icon(Icons.play_arrow),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NetworkVideoPlaybackScreen(
                    videoUrl: record.videoUrl!,
                    title: '${record.actionName} · $_displayTime',
                    httpHeaders: httpHeaders,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../models/exercise_keyframe.dart';

class KeyframeTimeline extends StatelessWidget {
  final List<ExerciseKeyframe> keyframes;
  final String? selectedKeyframeId;
  final double playbackTime;
  final double duration;
  final bool canPlay;
  final VoidCallback onAdd;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onDeleted;

  const KeyframeTimeline({
    super.key,
    required this.keyframes,
    required this.selectedKeyframeId,
    required this.playbackTime,
    required this.duration,
    required this.canPlay,
    required this.onAdd,
    required this.onSelected,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration > 0
        ? (playbackTime / duration).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline,
                color: Color(0xFF4A65FF),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '姿勢時間軸',
                  style: TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.icon(
                key: const Key('add-keyframe'),
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增目前姿勢'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4A65FF),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (keyframes.isEmpty)
            const _EmptyTimeline()
          else
            SizedBox(
              height: 88,
              child: ListView.separated(
                key: const Key('keyframe-list'),
                scrollDirection: Axis.horizontal,
                itemCount: keyframes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final keyframe = keyframes[index];
                  return _KeyframeCard(
                    keyframe: keyframe,
                    sequence: index + 1,
                    selected: selectedKeyframeId == keyframe.id,
                    onSelected: () => onSelected(keyframe.id),
                    onDeleted: () => onDeleted(keyframe.id),
                  );
                },
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    key: const Key('playback-progress'),
                    value: progress,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFE5E7EB),
                    color: const Color(0xFF4A65FF),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${playbackTime.toStringAsFixed(1)} / '
                '${duration.toStringAsFixed(1)} 秒',
                key: const Key('playback-time'),
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (!canPlay) ...[
            const SizedBox(height: 8),
            const Text(
              '至少新增 2 個 Keyframe 後才能播放預覽',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Text(
        '調整目前姿勢後，按「新增目前姿勢」建立第一個 Keyframe。',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
      ),
    );
  }
}

class _KeyframeCard extends StatelessWidget {
  final ExerciseKeyframe keyframe;
  final int sequence;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onDeleted;

  const _KeyframeCard({
    required this.keyframe,
    required this.sequence,
    required this.selected,
    required this.onSelected,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? const Color(0xFF4A65FF) : const Color(0xFFDDE0F0);
    return Material(
      color: selected ? const Color(0xFFEFF1FF) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('keyframe-${keyframe.id}'),
        onTap: onSelected,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 126,
          padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'K$sequence',
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF3347C5)
                            : const Color(0xFF374151),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${keyframe.time.toStringAsFixed(1)}s',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('delete-keyframe-${keyframe.id}'),
                tooltip: '刪除 K$sequence',
                onPressed: onDeleted,
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                color: const Color(0xFFEF4444),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

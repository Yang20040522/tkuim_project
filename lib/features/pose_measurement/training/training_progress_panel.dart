import 'package:flutter/material.dart';

import 'pose_training_session_controller.dart';
import 'training_session_state_machine.dart';

class TrainingProgressPanel extends StatelessWidget {
  const TrainingProgressPanel({
    super.key,
    required this.controller,
  });

  final PoseTrainingSessionController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TrainingSessionSnapshot>(
      valueListenable: controller.snapshot,
      builder: (_, snapshot, __) => Container(
        key: const Key('pose-training-progress'),
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE0F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '第 ${snapshot.currentRep} / ${snapshot.targetReps} 次',
                    key: const Key('pose-training-reps'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '第 ${snapshot.currentSet} / ${snapshot.targetSets} 組',
                  key: const Key('pose-training-sets'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '訓練時間 ${_elapsed(snapshot.sessionElapsed)}',
              key: const Key('pose-training-elapsed'),
              style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              _phaseLabel(snapshot),
              key: Key('pose-training-phase-${snapshot.phase.name}'),
              style: TextStyle(
                color: snapshot.isCompleted
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF4A65FF),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (snapshot.phase == TrainingSessionPhase.holding) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: snapshot.holdProgress),
              const SizedBox(height: 4),
              Text(
                '${_seconds(snapshot.holdElapsed)} / '
                '${_seconds(snapshot.holdDuration)} 秒',
                key: const Key('pose-training-hold-time'),
                style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
              ),
            ],
            if (snapshot.phase == TrainingSessionPhase.setCompleted) ...[
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('pose-training-next-set'),
                onPressed: controller.beginNextSet,
                child: const Text('下一組'),
              ),
            ],
            if (snapshot.isCompleted) ...[
              const SizedBox(height: 6),
              Text(
                '完成分數 ${snapshot.score.toStringAsFixed(0)} 分',
                key: const Key('pose-training-score'),
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w800,
                ),
              ),
              ValueListenableBuilder<TrainingResultSubmissionStatus>(
                valueListenable: controller.submission,
                builder: (_, status, __) => _SubmissionStatus(
                  status: status,
                  onRetry: controller.retrySubmission,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _phaseLabel(TrainingSessionSnapshot snapshot) {
    if (!snapshot.autoCountEnabled) return '未設定評估規則，無法自動計次';
    return switch (snapshot.phase) {
      TrainingSessionPhase.ready => '準備開始',
      TrainingSessionPhase.waitingForCorrect => '請調整到目標姿勢',
      TrainingSessionPhase.holding => '姿勢正確，保持中…',
      TrainingSessionPhase.waitingForRelease => snapshot.currentRep == 0
          ? '下一組開始前，請先離開目標姿勢'
          : '第 ${snapshot.currentRep} 次完成，請先離開目標姿勢',
      TrainingSessionPhase.setCompleted => '第 ${snapshot.currentSet} 組完成',
      TrainingSessionPhase.completed => '訓練完成',
    };
  }

  String _seconds(Duration duration) =>
      (duration.inMilliseconds / 1000).toStringAsFixed(1);

  String _elapsed(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _SubmissionStatus extends StatelessWidget {
  const _SubmissionStatus({required this.status, required this.onRetry});

  final TrainingResultSubmissionStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => switch (status) {
        TrainingResultSubmissionStatus.idle => const SizedBox.shrink(),
        TrainingResultSubmissionStatus.submitting => const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('正在儲存訓練結果…'),
          ),
        TrainingResultSubmissionStatus.saved => const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '訓練結果已儲存',
              key: Key('pose-training-result-saved'),
              style: TextStyle(color: Color(0xFF2E7D32)),
            ),
          ),
        TrainingResultSubmissionStatus.failed => Row(
            children: [
              const Expanded(
                child: Text(
                  '結果儲存失敗，請確認網路後重試',
                  style: TextStyle(color: Color(0xFFC2410C)),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('重試')),
            ],
          ),
      };
}

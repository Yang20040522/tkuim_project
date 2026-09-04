import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/custom_rehab_exercise.dart';
import '../../models/joint_type.dart';
import 'controllers/custom_exercise_playback_controller.dart';
import 'widgets/custom_exercise_3d_viewer.dart';

class CustomExercisePlaybackPage extends StatelessWidget {
  final CustomRehabExercise exercise;

  const CustomExercisePlaybackPage({
    super.key,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CustomExercisePlaybackController(exercise: exercise),
      child: _CustomExercisePlaybackView(exercise: exercise),
    );
  }
}

class _CustomExercisePlaybackView extends StatelessWidget {
  final CustomRehabExercise exercise;

  const _CustomExercisePlaybackView({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(exercise.name),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
      ),
      body: Consumer<CustomExercisePlaybackController>(
        builder: (context, controller, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ExerciseSummary(exercise: exercise),
                const SizedBox(height: 14),
                CustomExercise3dViewer(
                  selectedJoint: JointType.rightShoulder,
                  jointRotations: controller.restingPose,
                  keyframes: exercise.keyframes,
                  duration: exercise.duration,
                  playbackStatus: controller.status,
                  onPlaybackProgress: controller.updateProgress,
                  onPlaybackCompleted: controller.complete,
                ),
                const SizedBox(height: 14),
                _ReadOnlyTimeline(
                  exercise: exercise,
                  playbackTime: controller.playbackTime,
                ),
                const SizedBox(height: 14),
                _PlaybackControls(controller: controller),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExerciseSummary extends StatelessWidget {
  final CustomRehabExercise exercise;

  const _ExerciseSummary({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: const TextStyle(
                color: Color(0xFF1A1D2E),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (exercise.description.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                exercise.description,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _InfoChip(label: '${exercise.sets} 組'),
                _InfoChip(label: '每組 ${exercise.repetitions} 次'),
                _InfoChip(
                    label: '停留 ${exercise.holdSeconds.toStringAsFixed(0)} 秒'),
                _InfoChip(
                    label: '休息 ${exercise.restSeconds.toStringAsFixed(0)} 秒'),
                _InfoChip(
                    label: '動作 ${exercise.duration.toStringAsFixed(1)} 秒'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF3347C5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReadOnlyTimeline extends StatelessWidget {
  final CustomRehabExercise exercise;
  final double playbackTime;

  const _ReadOnlyTimeline({
    required this.exercise,
    required this.playbackTime,
  });

  @override
  Widget build(BuildContext context) {
    final progress = exercise.duration <= 0
        ? 0.0
        : (playbackTime / exercise.duration).clamp(0.0, 1.0).toDouble();
    return Card(
      key: const Key('read-only-custom-exercise-timeline'),
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '動作時間軸',
              style: TextStyle(
                color: Color(0xFF1A1D2E),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              key: const Key('assigned-exercise-playback-progress'),
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFE5E7EB),
              color: const Color(0xFF4A65FF),
            ),
            const SizedBox(height: 8),
            Text(
              '${playbackTime.toStringAsFixed(1)} / '
              '${exercise.duration.toStringAsFixed(1)} 秒',
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < exercise.keyframes.length; index++)
                  Chip(
                    label: Text(
                      'K${index + 1}  '
                      '${exercise.keyframes[index].time.toStringAsFixed(1)}s',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  final CustomExercisePlaybackController controller;

  const _PlaybackControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isPlaying = controller.status == CustomExercisePlaybackStatus.playing;
    final isPaused = controller.status == CustomExercisePlaybackStatus.paused;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const Key('play-assigned-custom-exercise'),
            onPressed: controller.canPlay
                ? (isPaused ? controller.resume : controller.play)
                : null,
            icon: Icon(isPaused ? Icons.play_arrow : Icons.play_circle),
            label: Text(
              isPaused
                  ? '繼續'
                  : controller.isCompleted
                      ? '重播'
                      : '播放',
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          key: const Key('pause-assigned-custom-exercise'),
          onPressed: isPlaying ? controller.pause : null,
          icon: const Icon(Icons.pause),
          label: const Text('暫停'),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          key: const Key('stop-assigned-custom-exercise'),
          onPressed: isPlaying || isPaused || controller.playbackTime > 0
              ? controller.stop
              : null,
          icon: const Icon(Icons.stop),
          label: const Text('停止'),
        ),
      ],
    );
  }
}

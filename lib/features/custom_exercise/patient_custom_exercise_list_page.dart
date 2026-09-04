import 'package:flutter/material.dart';

import '../../models/custom_rehab_exercise.dart';
import 'custom_exercise_playback_page.dart';
import 'repositories/custom_exercise_assignment_repository.dart';
import 'repositories/custom_exercise_assignment_repository_selection.dart';

typedef CustomExercisePlaybackBuilder = Widget Function(
  CustomRehabExercise exercise,
);

class PatientCustomExerciseListPage extends StatefulWidget {
  final CustomExerciseAssignmentRepository? repository;
  final CustomExercisePlaybackBuilder playbackBuilder;

  PatientCustomExerciseListPage({
    super.key,
    this.repository,
    CustomExercisePlaybackBuilder? playbackBuilder,
  }) : playbackBuilder = playbackBuilder ??
            ((exercise) => CustomExercisePlaybackPage(exercise: exercise));

  @override
  State<PatientCustomExerciseListPage> createState() =>
      _PatientCustomExerciseListPageState();
}

class _PatientCustomExerciseListPageState
    extends State<PatientCustomExerciseListPage> {
  late final CustomExerciseAssignmentRepository _repository;
  late Future<List<CustomRehabExercise>> _exercises;
  String? _openingExerciseId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? customExerciseAssignmentRepository;
    _reload();
  }

  void _reload() {
    _exercises = _repository.getPatientExercises();
  }

  void _retry() {
    setState(_reload);
  }

  Future<void> _openExercise(CustomRehabExercise summary) async {
    if (_openingExerciseId != null) return;
    setState(() => _openingExerciseId = summary.id);
    try {
      final exercise = await _repository.getPatientExercise(summary.id);
      if (!mounted) return;
      if (exercise == null) {
        throw StateError('此動作已取消指派或不存在');
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => widget.playbackBuilder(exercise)),
      );
      if (mounted) _retry();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('開啟自訂動作失敗：$error')),
      );
    } finally {
      if (mounted) setState(() => _openingExerciseId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('我的自訂復健動作'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
      ),
      body: FutureBuilder<List<CustomRehabExercise>>(
        future: _exercises,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _PatientListMessage(
              icon: Icons.error_outline,
              message: '讀取已指派復健動作失敗\n${snapshot.error}',
              actionLabel: '重試',
              onAction: _retry,
            );
          }
          final exercises = snapshot.data ?? const [];
          if (exercises.isEmpty) {
            return const _PatientListMessage(
              icon: Icons.assignment_outlined,
              message: '治療師尚未指派自訂復健動作',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _retry(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: exercises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                final opening = _openingExerciseId == exercise.id;
                return Card(
                  key: Key('patient-custom-exercise-${exercise.id}'),
                  margin: EdgeInsets.zero,
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      exercise.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${exercise.duration.toStringAsFixed(1)} 秒 · '
                        '${exercise.keyframes.length} Keyframes · '
                        '${exercise.sets} 組',
                      ),
                    ),
                    trailing: opening
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_circle_outline),
                    onTap: opening ? null : () => _openExercise(exercise),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PatientListMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _PatientListMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

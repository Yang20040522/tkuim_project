import 'package:flutter/material.dart';

import '../../core/ui/app_colors.dart';
import '../../models/assignable_exercise.dart';
import '../../models/custom_rehab_exercise.dart';
import '../pose_measurement/pose_training_page.dart';
import 'assigned_default_exercise_page.dart';
import 'custom_exercise_playback_page.dart';
import 'repositories/unified_exercise_assignment_repository.dart';
import 'repositories/unified_exercise_assignment_repository_selection.dart';

typedef AssignedDefaultExerciseBuilder = Widget Function(
  AssignableExercise exercise,
);
typedef AssignedCustomExerciseBuilder = Widget Function(
  CustomRehabExercise exercise,
);

class PatientAssignedExerciseListPage extends StatefulWidget {
  final UnifiedExerciseAssignmentRepository? repository;
  final AssignedDefaultExerciseBuilder defaultExerciseBuilder;
  final AssignedCustomExerciseBuilder customExerciseBuilder;
  final AssignedDefaultExerciseBuilder poseMeasurementBuilder;

  PatientAssignedExerciseListPage({
    super.key,
    this.repository,
    AssignedDefaultExerciseBuilder? defaultExerciseBuilder,
    AssignedCustomExerciseBuilder? customExerciseBuilder,
    AssignedDefaultExerciseBuilder? poseMeasurementBuilder,
  })  : defaultExerciseBuilder = defaultExerciseBuilder ??
            ((exercise) => AssignedDefaultExercisePage(exercise: exercise)),
        customExerciseBuilder = customExerciseBuilder ??
            ((exercise) => CustomExercisePlaybackPage(exercise: exercise)),
        poseMeasurementBuilder = poseMeasurementBuilder ??
            ((exercise) => PoseTrainingPage(exercise: exercise));

  @override
  State<PatientAssignedExerciseListPage> createState() =>
      _PatientAssignedExerciseListPageState();
}

class _PatientAssignedExerciseListPageState
    extends State<PatientAssignedExerciseListPage> {
  late final UnifiedExerciseAssignmentRepository _repository;
  late Future<List<AssignableExercise>> _exercises;
  String? _openingExerciseKey;
  bool _openingPosePage = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? unifiedExerciseAssignmentRepository;
    _reload();
  }

  void _reload() {
    _exercises = _repository.getPatientAssignedExercises();
  }

  void _retry() => setState(_reload);

  Future<void> _openExercise(AssignableExercise exercise) async {
    if (_openingExerciseKey != null || _openingPosePage) return;
    if (exercise.type == AssignableExerciseType.defaultExercise) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => widget.defaultExerciseBuilder(exercise),
        ),
      );
      return;
    }

    setState(() => _openingExerciseKey = exercise.identityKey);
    try {
      final detail = await _repository.getPatientCustomExercise(exercise.id);
      if (!mounted) return;
      if (detail == null) {
        throw StateError('此動作已取消指派或不存在');
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => widget.customExerciseBuilder(detail),
        ),
      );
      if (mounted) _retry();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('開啟自訂動作失敗：$error')),
      );
    } finally {
      if (mounted) setState(() => _openingExerciseKey = null);
    }
  }

  Future<void> _openPoseMeasurement(AssignableExercise exercise) async {
    if (exercise.type != AssignableExerciseType.defaultExercise) return;
    if (_openingExerciseKey != null || _openingPosePage) return;
    setState(() => _openingPosePage = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => widget.poseMeasurementBuilder(exercise),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingPosePage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('我的復健動作'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
      ),
      body: FutureBuilder<List<AssignableExercise>>(
        future: _exercises,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _PatientAssignedMessage(
              message: '讀取已指派復健動作失敗\n${snapshot.error}',
              onRetry: _retry,
            );
          }
          final exercises = snapshot.data ?? const [];
          if (exercises.isEmpty) {
            return const _PatientAssignedMessage(
              message: '治療師尚未指派復健動作',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _retry(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: exercises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) => _buildItem(exercises[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItem(AssignableExercise exercise) {
    final isDefault = exercise.type == AssignableExerciseType.defaultExercise;
    final opening = _openingExerciseKey == exercise.identityKey;
    return Card(
      key: Key('patient-assigned-exercise-${exercise.identityKey}'),
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor:
                  isDefault ? const Color(0xFFE8F5E9) : const Color(0xFFEFF1FF),
              child: Icon(
                isDefault ? Icons.fitness_center : Icons.accessibility_new,
                color: isDefault
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF4A65FF),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    key: Key(
                      'patient-assigned-exercise-title-${exercise.identityKey}',
                    ),
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  isDefault ? '預設' : '自訂',
                  style: TextStyle(
                    color: isDefault
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF4A65FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            subtitle: exercise.description.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      exercise.description,
                      style: const TextStyle(color: AppColors.secondaryText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            trailing: opening
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.arrow_forward_ios,
                    size: 15,
                    color: AppColors.secondaryText,
                  ),
            onTap: opening ? null : () => _openExercise(exercise),
          ),
          if (isDefault)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 8),
                child: TextButton.icon(
                  key: Key('patient-pose-measurement-${exercise.identityKey}'),
                  onPressed: _openingExerciseKey != null || _openingPosePage
                      ? null
                      : () => _openPoseMeasurement(exercise),
                  icon: const Icon(Icons.accessibility_new),
                  label: const Text('姿勢量測'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PatientAssignedMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _PatientAssignedMessage({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined,
                size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('重試')),
            ],
          ],
        ),
      ),
    );
  }
}

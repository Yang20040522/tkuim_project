import 'package:flutter/material.dart';

import '../../models/assignable_exercise.dart';
import '../../models/custom_exercise_assignment.dart';
import 'repositories/unified_exercise_assignment_repository.dart';
import 'repositories/unified_exercise_assignment_repository_selection.dart';

enum AssignableExerciseFilter { all, defaultExercise, custom }

class UnifiedExerciseAssignmentPage extends StatefulWidget {
  final UnifiedExerciseAssignmentRepository? repository;

  const UnifiedExerciseAssignmentPage({super.key, this.repository});

  @override
  State<UnifiedExerciseAssignmentPage> createState() =>
      _UnifiedExerciseAssignmentPageState();
}

class _UnifiedExerciseAssignmentPageState
    extends State<UnifiedExerciseAssignmentPage> {
  late final UnifiedExerciseAssignmentRepository _repository;
  bool _loadingPatients = true;
  bool _loadingExercises = false;
  Object? _error;
  List<AssignablePatient> _patients = const [];
  List<AssignableExercise> _exercises = const [];
  String? _selectedPatientId;
  AssignableExerciseFilter _filter = AssignableExerciseFilter.all;
  final Set<String> _busyExerciseKeys = {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? unifiedExerciseAssignmentRepository;
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _loadingPatients = true;
      _error = null;
    });
    try {
      final patients = await _repository.getAssignablePatients();
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _selectedPatientId = patients.isEmpty ? null : patients.first.patientId;
        _loadingPatients = false;
      });
      if (_selectedPatientId != null) await _loadExercises();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loadingPatients = false;
      });
    }
  }

  Future<void> _loadExercises() async {
    final patientId = _selectedPatientId;
    if (patientId == null) return;
    setState(() {
      _loadingExercises = true;
      _error = null;
    });
    try {
      final exercises = await _repository.getAssignableExercises(patientId);
      if (!mounted || patientId != _selectedPatientId) return;
      setState(() {
        _exercises = exercises;
        _loadingExercises = false;
      });
    } on Object catch (error) {
      if (!mounted || patientId != _selectedPatientId) return;
      setState(() {
        _error = error;
        _loadingExercises = false;
      });
    }
  }

  void _selectPatient(String? patientId) {
    if (patientId == null || patientId == _selectedPatientId) return;
    setState(() {
      _selectedPatientId = patientId;
      _exercises = const [];
    });
    _loadExercises();
  }

  Future<void> _toggleAssignment(
    AssignableExercise exercise,
    bool assigned,
  ) async {
    final patientId = _selectedPatientId;
    if (patientId == null || _busyExerciseKeys.contains(exercise.identityKey)) {
      return;
    }
    setState(() => _busyExerciseKeys.add(exercise.identityKey));
    try {
      if (assigned) {
        await _repository.assign(exercise, patientId);
      } else {
        await _repository.unassign(exercise, patientId);
      }
      if (!mounted || patientId != _selectedPatientId) return;
      setState(() {
        _exercises = [
          for (final item in _exercises)
            if (item.identityKey == exercise.identityKey)
              item.copyWith(assigned: assigned)
            else
              item,
        ];
      });
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新指派失敗：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyExerciseKeys.remove(exercise.identityKey));
      }
    }
  }

  List<AssignableExercise> get _filteredExercises {
    return switch (_filter) {
      AssignableExerciseFilter.all => _exercises,
      AssignableExerciseFilter.defaultExercise => _exercises
          .where((item) => item.type == AssignableExerciseType.defaultExercise)
          .toList(growable: false),
      AssignableExerciseFilter.custom => _exercises
          .where((item) => item.type == AssignableExerciseType.custom)
          .toList(growable: false),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('指派復健動作'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingPatients) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _patients.isEmpty) {
      return _UnifiedAssignmentMessage(
        message: '讀取患者清單失敗\n$_error',
        onRetry: _loadPatients,
      );
    }
    if (_patients.isEmpty) {
      return const _UnifiedAssignmentMessage(message: '尚無已綁定的患者');
    }

    final exercises = _filteredExercises;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('assignment-patient-selector'),
                initialValue: _selectedPatientId,
                decoration: const InputDecoration(
                  labelText: '選擇患者',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final patient in _patients)
                    DropdownMenuItem(
                      value: patient.patientId,
                      child: Text(patient.patientName),
                    ),
                ],
                onChanged: _selectPatient,
              ),
              const SizedBox(height: 12),
              SegmentedButton<AssignableExerciseFilter>(
                key: const Key('exercise-type-filter'),
                segments: const [
                  ButtonSegment(
                    value: AssignableExerciseFilter.all,
                    label: Text('全部'),
                  ),
                  ButtonSegment(
                    value: AssignableExerciseFilter.defaultExercise,
                    label: Text('預設動作'),
                  ),
                  ButtonSegment(
                    value: AssignableExerciseFilter.custom,
                    label: Text('自訂動作'),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (selection) {
                  setState(() => _filter = selection.single);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingExercises
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _UnifiedAssignmentMessage(
                      message: '讀取可指派動作失敗\n$_error',
                      onRetry: _loadExercises,
                    )
                  : exercises.isEmpty
                      ? const _UnifiedAssignmentMessage(
                          message: '此分類目前沒有可指派動作',
                        )
                      : RefreshIndicator(
                          onRefresh: _loadExercises,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: exercises.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) =>
                                _buildExerciseItem(exercises[index]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildExerciseItem(AssignableExercise exercise) {
    final busy = _busyExerciseKeys.contains(exercise.identityKey);
    final isDefault = exercise.type == AssignableExerciseType.defaultExercise;
    return Card(
      key: Key('assignable-exercise-${exercise.identityKey}'),
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        title: Row(
          children: [
            Expanded(
              child: Text(
                exercise.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            _ExerciseTypeBadge(isDefault: isDefault),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            exercise.description.isEmpty ? '無動作說明' : exercise.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        value: exercise.assigned,
        onChanged: busy ? null : (value) => _toggleAssignment(exercise, value),
        secondary: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(isDefault ? Icons.fitness_center : Icons.accessibility_new),
      ),
    );
  }
}

class _ExerciseTypeBadge extends StatelessWidget {
  final bool isDefault;

  const _ExerciseTypeBadge({required this.isDefault});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(isDefault ? 'default-exercise-badge' : 'custom-exercise-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDefault ? const Color(0xFFE8F5E9) : const Color(0xFFEFF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isDefault ? '預設' : '自訂',
        style: TextStyle(
          color: isDefault ? const Color(0xFF2E7D32) : const Color(0xFF4A65FF),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _UnifiedAssignmentMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _UnifiedAssignmentMessage({required this.message, this.onRetry});

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

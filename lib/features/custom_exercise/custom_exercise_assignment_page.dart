import 'package:flutter/material.dart';

import '../../models/custom_exercise_assignment.dart';
import '../../models/custom_rehab_exercise.dart';
import 'repositories/custom_exercise_assignment_repository.dart';

class CustomExerciseAssignmentPage extends StatefulWidget {
  final CustomRehabExercise exercise;
  final CustomExerciseAssignmentRepository repository;

  const CustomExerciseAssignmentPage({
    super.key,
    required this.exercise,
    required this.repository,
  });

  @override
  State<CustomExerciseAssignmentPage> createState() =>
      _CustomExerciseAssignmentPageState();
}

class _CustomExerciseAssignmentPageState
    extends State<CustomExerciseAssignmentPage> {
  bool _isLoading = true;
  Object? _error;
  List<AssignablePatient> _patients = const [];
  Set<String> _assignedPatientIds = const {};
  final Set<String> _busyPatientIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        widget.repository.getAssignablePatients(),
        widget.repository.getExerciseAssignments(widget.exercise.id),
      ]);
      if (!mounted) return;
      final patients = results[0] as List<AssignablePatient>;
      final assignments = results[1] as List<CustomExerciseAssignment>;
      setState(() {
        _patients = patients;
        _assignedPatientIds =
            assignments.map((assignment) => assignment.patientId).toSet();
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAssignment(AssignablePatient patient, bool assign) async {
    if (_busyPatientIds.contains(patient.patientId)) return;
    setState(() => _busyPatientIds.add(patient.patientId));
    try {
      if (assign) {
        await widget.repository.assign(widget.exercise.id, patient.patientId);
      } else {
        await widget.repository.unassign(widget.exercise.id, patient.patientId);
      }
      if (!mounted) return;
      setState(() {
        if (assign) {
          _assignedPatientIds = {..._assignedPatientIds, patient.patientId};
        } else {
          _assignedPatientIds = {..._assignedPatientIds}
            ..remove(patient.patientId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(assign ? '已指派給 ${patient.patientName}' : '已取消指派'),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新指派失敗：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyPatientIds.remove(patient.patientId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('指派患者'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.exercise.name,
                  style: const TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '只有與目前治療師已綁定的患者可以選擇。',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _AssignmentMessage(
        icon: Icons.error_outline,
        message: '讀取可指派患者失敗\n$_error',
        actionLabel: '重試',
        onAction: _load,
      );
    }
    if (_patients.isEmpty) {
      return const _AssignmentMessage(
        icon: Icons.people_outline,
        message: '尚無已綁定的患者',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _patients.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final patient = _patients[index];
          final assigned = _assignedPatientIds.contains(patient.patientId);
          final busy = _busyPatientIds.contains(patient.patientId);
          return Card(
            key: Key('assignable-patient-${patient.patientId}'),
            margin: EdgeInsets.zero,
            color: Colors.white,
            child: SwitchListTile(
              title: Text(
                patient.patientName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(assigned ? '已指派' : '未指派'),
              value: assigned,
              onChanged:
                  busy ? null : (value) => _toggleAssignment(patient, value),
              secondary: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_outline),
            ),
          );
        },
      ),
    );
  }
}

class _AssignmentMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _AssignmentMessage({
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

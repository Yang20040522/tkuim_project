import 'package:flutter/material.dart';

import '../../models/therapist_patient.dart';
import '../history/training_result_history_page.dart';
import '../custom_exercise/services/custom_exercise_api_client.dart';
import 'bind_patient_page.dart';
import 'repositories/therapist_patient_repository.dart';
import 'repositories/therapist_patient_repository_selection.dart';

class PatientManagementPage extends StatefulWidget {
  final TherapistPatientRepository? repository;

  const PatientManagementPage({super.key, this.repository});

  @override
  State<PatientManagementPage> createState() => _PatientManagementPageState();
}

class _PatientManagementPageState extends State<PatientManagementPage> {
  late final TherapistPatientRepository _repository;
  List<TherapistPatient> _patients = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _busyPatientIds = {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? therapistPatientRepository;
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final patients = await _repository.getPatients();
      if (!mounted) return;
      setState(() => _patients = patients);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _safeMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openBindPatient() async {
    final bound = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BindPatientPage(repository: _repository),
      ),
    );
    if (bound == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('患者綁定成功')),
      );
      await _loadPatients();
    }
  }

  Future<void> _confirmUnbind(TherapistPatient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('解除患者綁定'),
        content: Text(
          '確定解除與 ${patient.patientName} 的治療關係嗎？\n'
          '此治療師對該患者的既有指派也會一併取消。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-unbind-patient'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE24B4A),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('解除綁定'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyPatientIds.add(patient.patientId));
    try {
      await _repository.unbindPatient(patient.patientId);
      if (!mounted) return;
      setState(() {
        _patients = _patients
            .where((item) => item.patientId != patient.patientId)
            .toList(growable: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已解除患者綁定')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_safeMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyPatientIds.remove(patient.patientId));
      }
    }
  }

  void _openTrainingResults(TherapistPatient patient) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainingResultHistoryPage(
          patientId: patient.patientId,
          patientName: patient.patientName,
        ),
      ),
    );
  }

  String _safeMessage(Object error) {
    if (error is CustomExerciseApiException) return error.message;
    return '網路連線失敗，請稍後再試';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('患者管理'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: const Key('bind-patient-button'),
                onPressed: _openBindPatient,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('綁定新患者'),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _PatientManagementMessage(
        key: const Key('patient-management-error'),
        icon: Icons.cloud_off_outlined,
        message: '讀取患者失敗\n$_error',
        actionLabel: '重試',
        onAction: _loadPatients,
      );
    }
    if (_patients.isEmpty) {
      return _PatientManagementMessage(
        key: const Key('patient-management-empty'),
        icon: Icons.people_outline,
        message: '尚無已綁定患者\n請使用患者提供的綁定碼新增患者',
        actionLabel: '綁定新患者',
        onAction: _openBindPatient,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPatients,
      child: ListView.separated(
        key: const Key('therapist-patient-list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _patients.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) => _buildPatientCard(_patients[index]),
      ),
    );
  }

  Widget _buildPatientCard(TherapistPatient patient) {
    final busy = _busyPatientIds.contains(patient.patientId);
    return Card(
      key: Key('therapist-patient-${patient.patientId}'),
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFEFF1FF),
              foregroundColor: Color(0xFF4A65FF),
              child: Icon(Icons.person_outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.patientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    patient.patientEmail,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        patient.relationship,
                        style: const TextStyle(
                          color: Color(0xFF4A65FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '綁定時間 ${_formatDate(patient.boundAt)}',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  key: Key('patient-training-results-${patient.patientId}'),
                  onPressed: () => _openTrainingResults(patient),
                  child: const Text('訓練紀錄'),
                ),
                TextButton(
                  key: Key('unbind-patient-${patient.patientId}'),
                  onPressed: busy ? null : () => _confirmUnbind(patient),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE24B4A),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('解除綁定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '未提供';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}/${two(value.month)}/${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _PatientManagementMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _PatientManagementMessage({
    super.key,
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

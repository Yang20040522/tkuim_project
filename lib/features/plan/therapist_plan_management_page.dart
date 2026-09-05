import 'package:flutter/material.dart';

import '../../models/therapist_patient.dart';
import '../account/repositories/therapist_patient_repository.dart';
import '../account/repositories/therapist_patient_repository_selection.dart';
import 'exercise.dart';
import 'plan_builder_screen.dart';
import 'plan_repository.dart';
import 'rehab_plan.dart';

class TherapistPlanManagementPage extends StatefulWidget {
  final TherapistPatientRepository? patientRepository;
  final PlanRepository? repository;

  const TherapistPlanManagementPage({
    super.key,
    this.patientRepository,
    this.repository,
  });

  @override
  State<TherapistPlanManagementPage> createState() =>
      _TherapistPlanManagementPageState();
}

class _TherapistPlanManagementPageState
    extends State<TherapistPlanManagementPage> {
  late final TherapistPatientRepository _patientRepository;
  late final PlanRepository _repository;

  bool _loadingPatients = true;
  bool _loadingPlan = false;
  bool _saving = false;
  Object? _patientError;
  Object? _planError;
  List<TherapistPatient> _patients = const [];
  String? _selectedPatientId;
  DateTime _selectedDate = _dateOnly(DateTime.now());
  RehabPlan? _currentPlan;

  @override
  void initState() {
    super.initState();
    _patientRepository = widget.patientRepository ?? therapistPatientRepository;
    _repository = widget.repository ?? planRepository;
    _loadPatients();
  }

  TherapistPatient? get _selectedPatient {
    final patientId = _selectedPatientId;
    if (patientId == null) return null;
    for (final patient in _patients) {
      if (patient.patientId == patientId) return patient;
    }
    return null;
  }

  bool get _isPast {
    return _selectedDate.isBefore(_dateOnly(DateTime.now()));
  }

  Future<void> _loadPatients() async {
    setState(() {
      _loadingPatients = true;
      _patientError = null;
    });
    try {
      final patients = await _patientRepository.getPatients();
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _selectedPatientId = patients.isEmpty ? null : patients.first.patientId;
        _loadingPatients = false;
        _currentPlan = null;
      });
      if (_selectedPatientId != null) await _loadPlan();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _patientError = error;
        _loadingPatients = false;
      });
    }
  }

  Future<void> _loadPlan() async {
    final patientId = _selectedPatientId;
    if (patientId == null) return;
    final requestedDate = _selectedDate;
    setState(() {
      _loadingPlan = true;
      _planError = null;
      _currentPlan = null;
    });
    try {
      final plan = await _repository.getPlanByDate(
        patientId: patientId,
        date: requestedDate,
      );
      if (!mounted ||
          patientId != _selectedPatientId ||
          !_isSameDay(requestedDate, _selectedDate)) {
        return;
      }
      setState(() {
        _currentPlan = plan;
        _loadingPlan = false;
      });
    } on Object catch (error) {
      if (!mounted ||
          patientId != _selectedPatientId ||
          !_isSameDay(requestedDate, _selectedDate)) {
        return;
      }
      setState(() {
        _planError = error;
        _loadingPlan = false;
      });
    }
  }

  void _selectPatient(String? patientId) {
    if (patientId == null || patientId == _selectedPatientId) return;
    setState(() {
      _selectedPatientId = patientId;
      _currentPlan = null;
    });
    _loadPlan();
  }

  void _selectDate(DateTime date) {
    if (_isSameDay(date, _selectedDate)) return;
    setState(() {
      _selectedDate = _dateOnly(date);
      _currentPlan = null;
    });
    _loadPlan();
  }

  void _changeWeek(int dayOffset) {
    _selectDate(_selectedDate.add(Duration(days: dayOffset)));
  }

  Future<void> _createPlan() async {
    final patient = _selectedPatient;
    if (patient == null || _isPast || _saving) return;
    final condition = await showModalBottomSheet<PatientCondition>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: _buildConditionSheet,
    );
    if (condition == null || !mounted) return;

    final patientId = patient.patientId;
    final planId = buildPlanId(patientId: patientId, date: _selectedDate);
    if (condition == PatientCondition.fracture) {
      final template = _repository.buildFractureTemplate(
        patientId,
        planId,
        _selectedDate,
      );
      await _savePlan(template);
      return;
    }

    final emptyPlan = RehabPlan(
      patientId: patientId,
      planId: planId,
      createdBy: 'therapist',
      date: _selectedDate,
      condition: PatientCondition.stroke,
      items: const [],
    );
    await _openBuilder(emptyPlan, patient);
  }

  Future<void> _openBuilder(
    RehabPlan plan,
    TherapistPatient patient,
  ) async {
    if (_isPast || _saving) return;
    final patientId = patient.patientId;
    final requestedDate = _selectedDate;
    final updatedPlan = await Navigator.of(context).push<RehabPlan>(
      MaterialPageRoute(
        builder: (_) => PlanBuilderScreen(
          existingPlan: plan,
          patientName: patient.patientName,
        ),
      ),
    );
    if (updatedPlan == null ||
        !mounted ||
        patientId != _selectedPatientId ||
        !_isSameDay(requestedDate, _selectedDate)) {
      return;
    }
    await _savePlan(updatedPlan);
  }

  Future<void> _editPlan() async {
    final patient = _selectedPatient;
    final plan = _currentPlan;
    if (patient == null || plan == null) return;
    await _openBuilder(plan, patient);
  }

  Future<void> _applyFractureTemplate() async {
    final patient = _selectedPatient;
    final plan = _currentPlan;
    if (patient == null || plan == null || _isPast || _saving) return;
    final template = _repository.buildFractureTemplate(
      patient.patientId,
      plan.planId,
      _selectedDate,
    );
    await _savePlan(template);
  }

  Future<void> _savePlan(RehabPlan plan) async {
    final patientId = _selectedPatientId;
    final requestedDate = _selectedDate;
    if (patientId == null || plan.patientId != patientId) return;
    setState(() {
      _saving = true;
      _planError = null;
    });
    try {
      await _repository.savePlan(plan);
      if (!mounted ||
          patientId != _selectedPatientId ||
          !_isSameDay(requestedDate, _selectedDate)) {
        return;
      }
      setState(() => _saving = false);
      await _loadPlan();
    } on Object catch (error) {
      if (!mounted ||
          patientId != _selectedPatientId ||
          !_isSameDay(requestedDate, _selectedDate)) {
        return;
      }
      setState(() {
        _saving = false;
        _planError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('制定復健計畫'),
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
    if (_patientError != null) {
      return _PlanMessage(
        key: const Key('therapist-plan-patient-error'),
        message: '讀取患者清單失敗\n$_patientError',
        onRetry: _loadPatients,
      );
    }
    if (_patients.isEmpty) {
      return const _PlanMessage(
        key: Key('therapist-plan-empty-patients'),
        message: '尚無已綁定患者，請先至患者管理完成綁定',
      );
    }

    return Column(
      children: [
        _buildSelectionHeader(),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _buildPlanBody()),
              if (_saving)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66FFFFFF),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            key: const Key('therapist-plan-patient-selector'),
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
            onChanged: _saving ? null : _selectPatient,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                key: const Key('therapist-plan-previous-week'),
                onPressed: _saving ? null : () => _changeWeek(-7),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _weekLabel(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: const Key('therapist-plan-next-week'),
                onPressed: _saving ? null : () => _changeWeek(7),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          _buildWeekRow(),
        ],
      ),
    );
  }

  Widget _buildWeekRow() {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final monday =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        final date = monday.add(Duration(days: index));
        final selected = _isSameDay(date, _selectedDate);
        return InkWell(
          key: Key('therapist-plan-day-${_dateKey(date)}'),
          onTap: _saving ? null : () => _selectDate(date),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              children: [
                Text(
                  weekdays[index],
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF4A65FF)
                        : const Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        selected ? const Color(0xFF4A65FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF374151),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPlanBody() {
    if (_loadingPlan) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_planError != null) {
      return _PlanMessage(
        key: const Key('therapist-plan-error'),
        message: '讀取或儲存復健計畫失敗\n$_planError',
        onRetry: _loadPlan,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${_selectedPatient!.patientName} · ${_selectedDate.month}/${_selectedDate.day}',
          style: const TextStyle(
            color: Color(0xFF1A1D2E),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (_currentPlan == null) _buildEmptyPlan() else _buildExistingPlan(),
      ],
    );
  }

  Widget _buildEmptyPlan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _planCard(
          const Text(
            '這一天尚未建立復健計畫',
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ),
        const SizedBox(height: 14),
        if (_isPast)
          _readOnlyNotice()
        else
          ElevatedButton(
            key: const Key('create-rehab-plan'),
            onPressed: _saving ? null : _createPlan,
            child: const Text('新增計畫'),
          ),
      ],
    );
  }

  Widget _buildExistingPlan() {
    final plan = _currentPlan!;
    final sortedItems = [...plan.items]
      ..sort((a, b) => a.order.compareTo(b.order));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _planCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.condition == PatientCondition.fracture ? '骨折' : '中風',
                style: const TextStyle(
                  color: Color(0xFF4A65FF),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (sortedItems.isEmpty)
                const Text(
                  '尚未安排動作',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                )
              else
                for (final item in sortedItems) _buildPlanItem(item),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_isPast)
          _readOnlyNotice()
        else ...[
          ElevatedButton(
            key: const Key('edit-rehab-plan'),
            onPressed: _saving ? null : _editPlan,
            child: const Text('修改計畫'),
          ),
          if (plan.condition == PatientCondition.fracture) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('apply-fracture-template'),
              onPressed: _saving ? null : _applyFractureTemplate,
              child: const Text('套用標準範本'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPlanItem(PlanItem item) {
    final exercise = findExerciseById(item.exerciseId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            item.done ? Icons.check_circle : Icons.radio_button_unchecked,
            color:
                item.done ? const Color(0xFF4A65FF) : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 10),
          Text(exercise.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              exercise.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${item.sets} 組 × ${item.repsPerSet} 下',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _planCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: child,
    );
  }

  Widget _readOnlyNotice() {
    return _planCard(
      const Row(
        children: [
          Icon(Icons.lock_outline, color: Color(0xFF9CA3AF), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '過去日期僅供查看，無法建立或修改計畫',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionSheet(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '新增計畫',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${_selectedPatient!.patientName} · ${_selectedDate.month}/${_selectedDate.day}',
              style: const TextStyle(color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),
            _conditionOption(
              context,
              key: const Key('rehab-condition-fracture'),
              condition: PatientCondition.fracture,
              emoji: '🦴',
              title: '骨折',
              subtitle: '先套用標準範本，建立後仍可修改',
            ),
            const SizedBox(height: 10),
            _conditionOption(
              context,
              key: const Key('rehab-condition-stroke'),
              condition: PatientCondition.stroke,
              emoji: '🧠',
              title: '中風',
              subtitle: '由治療師手動安排訓練動作',
            ),
          ],
        ),
      ),
    );
  }

  Widget _conditionOption(
    BuildContext context, {
    required Key key,
    required PatientCondition condition,
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      key: key,
      onTap: () => Navigator.pop(context, condition),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE0F0)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  String _weekLabel() {
    final monday =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return '${monday.month}/${monday.day} - ${sunday.month}/${sunday.day}';
  }
}

class _PlanMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _PlanMessage({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

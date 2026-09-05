import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../pose_measurement/evaluation/pose_measurement_rule.dart';
import '../../pose_measurement/models/joint_angle_frame.dart';
import '../controllers/custom_exercise_editor_controller.dart';

class PoseMeasurementRulesEditor extends StatelessWidget {
  const PoseMeasurementRulesEditor({super.key});

  Future<void> _openRuleDialog(
    BuildContext context, {
    int? index,
    PoseMeasurementRule? initialRule,
  }) async {
    final rule = await showDialog<PoseMeasurementRule>(
      context: context,
      builder: (_) => _PoseMeasurementRuleDialog(
        isEditing: index != null,
        initialRule: initialRule,
      ),
    );
    if (rule == null || !context.mounted) return;
    final controller = context.read<CustomExerciseEditorController>();
    final error = index == null
        ? controller.addPoseMeasurementRule(rule)
        : controller.updatePoseMeasurementRule(index, rule);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomExerciseEditorController>(
      builder: (context, controller, _) => Container(
        key: const Key('pose-measurement-rules-editor'),
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
            const Row(
              children: [
                Icon(Icons.monitor_heart, color: Color(0xFF4A65FF), size: 20),
                SizedBox(width: 8),
                Text(
                  '真人姿勢評估',
                  style: TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '依 MediaPipe 人體關節角度評估，與上方 3D 骨骼 X/Y/Z 角度分開設定。',
              style: TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (controller.poseMeasurementRules.isEmpty)
              const Text(
                '尚未設定真人姿勢評估規則',
                style: TextStyle(color: Color(0xFF9CA3AF)),
              )
            else
              for (var index = 0;
                  index < controller.poseMeasurementRules.length;
                  index++)
                _RuleTile(
                  index: index,
                  rule: controller.poseMeasurementRules[index],
                  onEdit: () => _openRuleDialog(
                    context,
                    index: index,
                    initialRule: controller.poseMeasurementRules[index],
                  ),
                  onDelete: () => controller.deletePoseMeasurementRule(index),
                ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('add-pose-measurement-rule'),
              onPressed: controller.poseMeasurementRules.length >=
                      PoseMeasurementRule.supportedCustomMeasurements.length
                  ? null
                  : () => _openRuleDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('新增評估條件'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoseMeasurementRuleDialog extends StatefulWidget {
  const _PoseMeasurementRuleDialog({
    required this.isEditing,
    this.initialRule,
  });

  final bool isEditing;
  final PoseMeasurementRule? initialRule;

  @override
  State<_PoseMeasurementRuleDialog> createState() =>
      _PoseMeasurementRuleDialogState();
}

class _PoseMeasurementRuleDialogState
    extends State<_PoseMeasurementRuleDialog> {
  late JointMeasurementType _measurement;
  late final TextEditingController _targetController;
  late final TextEditingController _toleranceController;
  late final TextEditingController _lowController;
  late final TextEditingController _highController;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRule;
    _measurement = initial?.measurement ??
        PoseMeasurementRule.supportedCustomMeasurements.first;
    _targetController = TextEditingController(
      text: initial?.targetAngleDegrees.toStringAsFixed(0) ?? '',
    );
    _toleranceController = TextEditingController(
      text: initial?.toleranceDegrees.toStringAsFixed(0) ?? '',
    );
    _lowController = TextEditingController(text: initial?.feedbackTooLow ?? '');
    _highController =
        TextEditingController(text: initial?.feedbackTooHigh ?? '');
  }

  @override
  void dispose() {
    _targetController.dispose();
    _toleranceController.dispose();
    _lowController.dispose();
    _highController.dispose();
    super.dispose();
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _submit() {
    final target = double.tryParse(_targetController.text.trim());
    final tolerance = double.tryParse(_toleranceController.text.trim());
    if (target == null) {
      setState(() => _validationMessage = '目標角度必須介於 0°～180°');
      return;
    }
    if (tolerance == null) {
      setState(() => _validationMessage = '容許誤差必須大於 0°');
      return;
    }
    final candidate = PoseMeasurementRule(
      measurement: _measurement,
      targetAngleDegrees: target,
      toleranceDegrees: tolerance,
      feedbackTooLow: _optionalText(_lowController.text),
      feedbackTooHigh: _optionalText(_highController.text),
    );
    final error = candidate.validationError;
    if (error != null) {
      setState(() => _validationMessage = error);
      return;
    }
    Navigator.of(context).pop(candidate);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? '編輯評估條件' : '新增評估條件'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<JointMeasurementType>(
              key: const Key('pose-rule-measurement'),
              initialValue: _measurement,
              decoration: const InputDecoration(
                labelText: '量測關節',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final item
                    in PoseMeasurementRule.supportedCustomMeasurements)
                  DropdownMenuItem(
                    value: item,
                    child: Text(item.poseRuleLabel),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _measurement = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pose-rule-target'),
              controller: _targetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '目標角度',
                suffixText: '°',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pose-rule-tolerance'),
              controller: _toleranceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '容許誤差',
                prefixText: '± ',
                suffixText: '°',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pose-rule-feedback-low'),
              controller: _lowController,
              decoration: const InputDecoration(
                labelText: '角度不足提示（選填）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pose-rule-feedback-high'),
              controller: _highController,
              decoration: const InputDecoration(
                labelText: '角度過大提示（選填）',
                border: OutlineInputBorder(),
              ),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _validationMessage!,
                key: const Key('pose-rule-validation-error'),
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('confirm-pose-rule'),
          onPressed: _submit,
          child: Text(widget.isEditing ? '儲存' : '新增'),
        ),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.index,
    required this.rule,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final PoseMeasurementRule rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    String degrees(double value) => '${value.toStringAsFixed(0)}°';
    return Card(
      key: Key('pose-measurement-rule-$index'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(rule.measurement.poseRuleLabel),
        subtitle: Text(
          '目標 ${degrees(rule.targetAngleDegrees)}　'
          '容許 ±${degrees(rule.toleranceDegrees)}\n'
          '有效範圍 ${degrees(rule.lowerBound)} – ${degrees(rule.upperBound)}',
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              key: Key('edit-pose-measurement-rule-$index'),
              tooltip: '編輯',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              key: Key('delete-pose-measurement-rule-$index'),
              tooltip: '刪除',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

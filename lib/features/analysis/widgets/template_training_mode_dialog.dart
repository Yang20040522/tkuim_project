import 'package:flutter/material.dart';

import '../../../models/training_action.dart';
import '../body/body_motion_template.dart';
import '../models/environment_metadata.dart';
import '../models/motion_action_registry.dart';
import '../models/motion_template_catalog.dart';

enum TemplateTrainingMode { general, aiTemplate }

class TemplateTrainingSelection {
  const TemplateTrainingSelection.general()
      : mode = TemplateTrainingMode.general,
        selectedTemplate = null;

  const TemplateTrainingSelection.ai(this.selectedTemplate)
      : assert(selectedTemplate != null),
        mode = TemplateTrainingMode.aiTemplate;

  final TemplateTrainingMode mode;
  final MotionTemplateCatalogEntry? selectedTemplate;

  bool get aiEnabled => mode == TemplateTrainingMode.aiTemplate;
  BodyMotionTemplate? get selectedBodyTemplate =>
      aiEnabled ? selectedTemplate?.bodyTemplate : null;
}

class TemplateTrainingAvailability {
  TemplateTrainingAvailability._({
    required this.capability,
    required List<MotionTemplateCatalogEntry> compatibleTemplates,
  }) : compatibleTemplates =
            List<MotionTemplateCatalogEntry>.unmodifiable(compatibleTemplates);

  factory TemplateTrainingAvailability.evaluate({
    required MotionActionCapability capability,
    required Iterable<MotionTemplateCatalogEntry> templates,
  }) {
    final compatible = templates
        .where((template) =>
            template.actionId == capability.actionId &&
            template.modelType == capability.modelType)
        .toList();
    return TemplateTrainingAvailability._(
      capability: capability,
      compatibleTemplates: compatible,
    );
  }

  final MotionActionCapability capability;
  final List<MotionTemplateCatalogEntry> compatibleTemplates;

  bool get showAiMode =>
      capability.supportsPostRepAnalyzer && compatibleTemplates.isNotEmpty;
}

class MotionTemplateTrainingPicker {
  const MotionTemplateTrainingPicker._();

  static Future<TemplateTrainingSelection?> choose({
    required BuildContext context,
    required TrainingAction action,
    MotionTemplateCatalog? catalog,
  }) async {
    final capability = MotionActionRegistry.forActionType(action.type);
    if (!capability.supportsPostRepAnalyzer) {
      return const TemplateTrainingSelection.general();
    }

    List<MotionTemplateCatalogEntry> templates;
    try {
      templates = await (catalog ?? MotionTemplateCatalog()).compatibleFor(
        actionType: action.type,
        cameraView: CameraView.front,
      );
    } on Object {
      return const TemplateTrainingSelection.general();
    }
    if (!context.mounted) return null;

    final availability = TemplateTrainingAvailability.evaluate(
      capability: capability,
      templates: templates,
    );
    if (!availability.showAiMode) {
      return const TemplateTrainingSelection.general();
    }

    return showDialog<TemplateTrainingSelection>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TemplateTrainingModeDialog(
        actionName: action.name,
        templates: availability.compatibleTemplates,
      ),
    );
  }
}

class TemplateTrainingModeDialog extends StatefulWidget {
  const TemplateTrainingModeDialog({
    super.key,
    required this.actionName,
    required this.templates,
  }) : assert(templates.length > 0);

  final String actionName;
  final List<MotionTemplateCatalogEntry> templates;

  @override
  State<TemplateTrainingModeDialog> createState() =>
      _TemplateTrainingModeDialogState();
}

class _TemplateTrainingModeDialogState
    extends State<TemplateTrainingModeDialog> {
  TemplateTrainingMode _mode = TemplateTrainingMode.general;
  late MotionTemplateCatalogEntry _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _selectedTemplate = widget.templates.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.actionName}訓練模式'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _modeTile(
              key: const Key('template-mode-general'),
              value: TemplateTrainingMode.general,
              title: '一般訓練',
            ),
            _modeTile(
              key: const Key('template-mode-ai'),
              value: TemplateTrainingMode.aiTemplate,
              title: 'AI 標準模板訓練',
              subtitle: '每次既有計分完成後，比較一次動作軌跡',
            ),
            if (_mode == TemplateTrainingMode.aiTemplate) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<MotionTemplateCatalogEntry>(
                key: const Key('template-selector'),
                initialValue: _selectedTemplate,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '選擇標準模板',
                  border: OutlineInputBorder(),
                ),
                items: widget.templates
                    .map((template) => DropdownMenuItem(
                          value: template,
                          child: Text(
                            _templateLabel(template),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (template) {
                  if (template != null) {
                    setState(() => _selectedTemplate = template);
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                _templateDetails(_selectedTemplate),
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('template-mode-confirm'),
          onPressed: () => Navigator.pop(
            context,
            _mode == TemplateTrainingMode.general
                ? const TemplateTrainingSelection.general()
                : TemplateTrainingSelection.ai(_selectedTemplate),
          ),
          child: const Text('繼續'),
        ),
      ],
    );
  }

  Widget _modeTile({
    required Key key,
    required TemplateTrainingMode value,
    required String title,
    String? subtitle,
  }) {
    final selected = _mode == value;
    return InkWell(
      key: key,
      onTap: () => setState(() => _mode = value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color:
                  selected ? const Color(0xFF4A65FF) : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _templateLabel(MotionTemplateCatalogEntry template) {
    final side = template.environment.movementSide.label;
    return '${template.templateName} · $side';
  }

  String _templateDetails(MotionTemplateCatalogEntry template) {
    final environment = template.environment;
    final support = environment.supportType == SupportType.none
        ? '無支撐'
        : '${environment.supportType.label}／${environment.supportSide.label}';
    final date = template.createdAt.toLocal().toString().split('.').first;
    return '${environment.cameraView.label} · $support\n建立時間：$date';
  }
}

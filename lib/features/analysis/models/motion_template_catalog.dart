import '../body/body_motion_template.dart';
import '../hand/hand_motion_template.dart';
import '../storage/local_motion_template_repository.dart';
import '../../../models/training_action.dart';
import 'environment_metadata.dart';
import 'motion_action_registry.dart';

class MotionTemplateCatalogEntry {
  MotionTemplateCatalogEntry.body({
    required this.actionId,
    required BodyMotionTemplate template,
  })  : modelType = MotionTemplateModelType.body,
        bodyTemplate = template,
        handTemplate = null;

  MotionTemplateCatalogEntry.hand({
    required this.actionId,
    required HandMotionTemplate template,
  })  : modelType = MotionTemplateModelType.hand,
        bodyTemplate = null,
        handTemplate = template;

  final String actionId;
  final MotionTemplateModelType modelType;
  final BodyMotionTemplate? bodyTemplate;
  final HandMotionTemplate? handTemplate;

  String get templateId => bodyTemplate?.templateId ?? handTemplate!.templateId;
  String get templateName =>
      bodyTemplate?.templateName ?? handTemplate!.templateName;
  DateTime get createdAt => bodyTemplate?.createdAt ?? handTemplate!.createdAt;
  EnvironmentMetadata get environment =>
      bodyTemplate?.environment ?? handTemplate!.environment;
}

class MotionTemplateCatalog {
  MotionTemplateCatalog({LocalMotionTemplateRepository? storage})
      : _storage = storage ?? LocalMotionTemplateRepository();

  final LocalMotionTemplateRepository _storage;

  Future<List<MotionTemplateCatalogEntry>> loadAll() async {
    final rawTemplates = await _storage.listTemplateJson();
    return fromJsonTemplates(rawTemplates);
  }

  Future<List<MotionTemplateCatalogEntry>> compatibleFor({
    required ActionType actionType,
    BodySide? movementSide,
    CameraView? cameraView,
  }) async {
    final entries = await loadAll();
    return filterCompatible(
      entries: entries,
      actionType: actionType,
      movementSide: movementSide,
      cameraView: cameraView,
    );
  }

  static List<MotionTemplateCatalogEntry> fromJsonTemplates(
    Iterable<Map<String, dynamic>> rawTemplates,
  ) {
    final entries = <MotionTemplateCatalogEntry>[];
    for (final json in rawTemplates) {
      final declaredModelType =
          MotionTemplateModelTypeX.tryParse(json['modelType']);
      final capability = MotionActionRegistry.resolveTemplateJson(json);
      final modelType = declaredModelType ??
          capability?.modelType ??
          MotionTemplateModelType.body;
      final rawActionId = json['actionId']?.toString().trim();
      final actionId = capability?.actionId ??
          ((rawActionId?.isNotEmpty ?? false)
              ? rawActionId!
              : json['actionType']?.toString().trim() ?? '');
      try {
        if (modelType == MotionTemplateModelType.hand) {
          final template = HandMotionTemplate.fromJson(json);
          if (template.normalizedTrajectory.length >= 2) {
            entries.add(MotionTemplateCatalogEntry.hand(
              actionId: actionId,
              template: template,
            ));
          }
        } else {
          final template = BodyMotionTemplate.fromJson(json);
          if (template.normalizedTrajectory.length >= 2) {
            entries.add(MotionTemplateCatalogEntry.body(
              actionId: actionId,
              template: template,
            ));
          }
        }
      } on Object {
        // A corrupt or mismatched local file must not block other templates.
      }
    }
    entries.sort(_newestFirst);
    return List<MotionTemplateCatalogEntry>.unmodifiable(entries);
  }

  static List<Map<String, dynamic>> sortRawTemplates(
    Iterable<Map<String, dynamic>> rawTemplates,
  ) {
    final sorted = rawTemplates.toList()
      ..sort((left, right) {
        final leftCreatedAt =
            DateTime.tryParse(left['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
        final rightCreatedAt =
            DateTime.tryParse(right['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
        final createdComparison = rightCreatedAt.compareTo(leftCreatedAt);
        if (createdComparison != 0) return createdComparison;
        return (right['templateId']?.toString() ?? '')
            .compareTo(left['templateId']?.toString() ?? '');
      });
    return sorted;
  }

  static List<MotionTemplateCatalogEntry> filterCompatible({
    required Iterable<MotionTemplateCatalogEntry> entries,
    required ActionType actionType,
    BodySide? movementSide,
    CameraView? cameraView,
  }) {
    final capability = MotionActionRegistry.forActionType(actionType);
    final compatible = entries.where((entry) {
      if (entry.actionId != capability.actionId ||
          entry.modelType != capability.modelType) {
        return false;
      }
      if (cameraView != null && entry.environment.cameraView != cameraView) {
        return false;
      }
      if (movementSide == BodySide.left || movementSide == BodySide.right) {
        final templateSide = entry.environment.movementSide;
        if (templateSide != movementSide &&
            templateSide != BodySide.none &&
            templateSide != BodySide.both) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort(_newestFirst);
    return List<MotionTemplateCatalogEntry>.unmodifiable(compatible);
  }

  static int _newestFirst(
    MotionTemplateCatalogEntry left,
    MotionTemplateCatalogEntry right,
  ) {
    final createdComparison = right.createdAt.compareTo(left.createdAt);
    if (createdComparison != 0) return createdComparison;
    return right.templateId.compareTo(left.templateId);
  }
}

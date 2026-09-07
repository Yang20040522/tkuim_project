import '../../../models/training_action.dart';

enum MotionTemplateModelType { body, hand }

enum PostRepAnalyzerKind { none, bodyTrajectory }

class MotionActionCapability {
  const MotionActionCapability({
    required this.actionType,
    required this.actionId,
    required this.displayName,
    required this.modelType,
    required this.canCreateTemplate,
    required this.postRepAnalyzerKind,
    this.legacyAliases = const [],
    this.unsupportedReason,
  });

  final ActionType actionType;
  final String actionId;
  final String displayName;
  final MotionTemplateModelType modelType;
  final bool canCreateTemplate;
  final PostRepAnalyzerKind postRepAnalyzerKind;
  final List<String> legacyAliases;
  final String? unsupportedReason;

  bool get supportsPostRepAnalyzer =>
      postRepAnalyzerKind != PostRepAnalyzerKind.none;
}

class MotionActionRegistry {
  const MotionActionRegistry._();

  static const capabilities = <MotionActionCapability>[
    MotionActionCapability(
      actionType: ActionType.turnPalm,
      actionId: 'turn_palm',
      displayName: '翻掌訓練',
      modelType: MotionTemplateModelType.hand,
      canCreateTemplate: true,
      postRepAnalyzerKind: PostRepAnalyzerKind.none,
      legacyAliases: ['turnPalm', '翻掌'],
      unsupportedReason: '手部訓練流程尚未提供 completed-rep 軌跡邊界。',
    ),
    MotionActionCapability(
      actionType: ActionType.sidePinch,
      actionId: 'side_pinch',
      displayName: '側捏訓練',
      modelType: MotionTemplateModelType.hand,
      canCreateTemplate: true,
      postRepAnalyzerKind: PostRepAnalyzerKind.none,
      legacyAliases: ['sidePinch', '側捏'],
      unsupportedReason: '手部訓練流程尚未提供 completed-rep 軌跡邊界。',
    ),
    MotionActionCapability(
      actionType: ActionType.wristExtension,
      actionId: 'wrist_extension',
      displayName: '翹手腕式',
      modelType: MotionTemplateModelType.hand,
      canCreateTemplate: true,
      postRepAnalyzerKind: PostRepAnalyzerKind.none,
      legacyAliases: ['wristExtension', '翹手腕', '手腕伸展'],
      unsupportedReason: '手部訓練流程尚未提供 completed-rep 軌跡邊界。',
    ),
    MotionActionCapability(
      actionType: ActionType.wristSideBend,
      actionId: 'wrist_side_bend',
      displayName: '左右彎手腕式',
      modelType: MotionTemplateModelType.hand,
      canCreateTemplate: true,
      postRepAnalyzerKind: PostRepAnalyzerKind.none,
      legacyAliases: ['wristSideBend', '左右彎手腕'],
      unsupportedReason: '手部訓練流程尚未提供 completed-rep 軌跡邊界。',
    ),
    MotionActionCapability(
      actionType: ActionType.wipeBody,
      actionId: 'standing_knee_raise',
      displayName: '站姿抬腳式訓練',
      modelType: MotionTemplateModelType.body,
      canCreateTemplate: true,
      postRepAnalyzerKind: PostRepAnalyzerKind.bodyTrajectory,
      legacyAliases: ['wipeBody', '站姿抬腳', '站姿抬腳(示範)'],
    ),
    MotionActionCapability(
      actionType: ActionType.drawCircle,
      actionId: 'draw_circle',
      displayName: '畫圓訓練',
      modelType: MotionTemplateModelType.body,
      canCreateTemplate: true,
      postRepAnalyzerKind: PostRepAnalyzerKind.none,
      legacyAliases: ['drawCircle', '畫圓'],
      unsupportedReason: '尚未校準畫圓動作的關節 weighting 與偏差解讀。',
    ),
    MotionActionCapability(
      actionType: ActionType.reach,
      actionId: 'overhead_reach',
      displayName: '伸手舉高訓練',
      modelType: MotionTemplateModelType.body,
      canCreateTemplate: true,
      postRepAnalyzerKind: PostRepAnalyzerKind.none,
      legacyAliases: ['reach', '伸手舉高'],
      unsupportedReason: '尚未校準單側上舉動作的關節 weighting。',
    ),
    MotionActionCapability(
      actionType: ActionType.raiseBothArms,
      actionId: 'raise_both_arms',
      displayName: '雙手抬舉式',
      modelType: MotionTemplateModelType.body,
      canCreateTemplate: true,
      postRepAnalyzerKind: PostRepAnalyzerKind.none,
      legacyAliases: ['raiseBothArms', '雙手抬舉'],
      unsupportedReason: '尚未校準雙側上舉動作的關節 weighting。',
    ),
    MotionActionCapability(
      actionType: ActionType.elbowForward,
      actionId: 'elbow_forward',
      displayName: '手肘屈伸訓練',
      modelType: MotionTemplateModelType.body,
      canCreateTemplate: true,
      postRepAnalyzerKind: PostRepAnalyzerKind.none,
      legacyAliases: ['elbowForward', '手肘屈伸'],
      unsupportedReason: '尚未校準手肘屈伸動作的關節 weighting。',
    ),
    MotionActionCapability(
      actionType: ActionType.sitToStand,
      actionId: 'sit_to_stand',
      displayName: '坐站訓練',
      modelType: MotionTemplateModelType.body,
      canCreateTemplate: true,
      postRepAnalyzerKind: PostRepAnalyzerKind.none,
      legacyAliases: ['sitToStand', '坐站'],
      unsupportedReason: '尚未校準坐站動作的下肢與軀幹 weighting。',
    ),
    MotionActionCapability(
      actionType: ActionType.lateralStep,
      actionId: 'lateral_step',
      displayName: '側跨步訓練',
      modelType: MotionTemplateModelType.body,
      canCreateTemplate: true,
      postRepAnalyzerKind: PostRepAnalyzerKind.none,
      legacyAliases: ['lateralStep', '側跨步'],
      unsupportedReason: '尚未校準移動側、支撐側與模式組合的 weighting。',
    ),
    MotionActionCapability(
      actionType: ActionType.bodyTest,
      actionId: 'body_skeleton_test',
      displayName: '全身骨架偵測',
      modelType: MotionTemplateModelType.body,
      canCreateTemplate: false,
      postRepAnalyzerKind: PostRepAnalyzerKind.none,
      legacyAliases: ['bodyTest'],
      unsupportedReason: '這是骨架診斷頁，不是具有 completed-rep 的復健動作。',
    ),
  ];

  static MotionActionCapability forActionType(ActionType actionType) =>
      capabilities.firstWhere((item) => item.actionType == actionType);

  static MotionActionCapability? resolve(
    Object? raw, {
    MotionTemplateModelType? modelType,
  }) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    final normalized = value.toLowerCase();
    for (final capability in capabilities) {
      if (modelType != null && capability.modelType != modelType) continue;
      final aliases = <String>{
        capability.actionId,
        capability.actionType.name,
        capability.displayName,
        ...capability.legacyAliases,
      };
      if (aliases.any((alias) => alias.trim().toLowerCase() == normalized)) {
        return capability;
      }
    }
    return null;
  }

  static MotionActionCapability? resolveTemplateJson(
    Map<String, dynamic> json,
  ) {
    final modelType = MotionTemplateModelTypeX.tryParse(json['modelType']);
    return resolve(json['actionId'], modelType: modelType) ??
        resolve(json['actionType'], modelType: modelType);
  }
}

extension MotionTemplateModelTypeX on MotionTemplateModelType {
  String get label => switch (this) {
        MotionTemplateModelType.body => 'Body',
        MotionTemplateModelType.hand => 'Hand',
      };

  static MotionTemplateModelType? tryParse(Object? raw) =>
      switch (raw?.toString()) {
        'body' => MotionTemplateModelType.body,
        'hand' => MotionTemplateModelType.hand,
        _ => null,
      };
}

import 'body_research_contract.dart';
import 'body_research_feature_extractor.dart';

/// Versioned research contract, independent of camera, training/counting and UI.
/// A registry entry is not clinical validation or permission to collect data.
class MlActionDefinition {
  const MlActionDefinition({
    required this.actionId,
    required this.version,
    required this.displayName,
    required this.featureNames,
    required this.labels,
    this.angleLabels = const {},
    this.schemaVersion = 1,
    this.labelVersion = 'research-v1',
    this.acceptLegacyVersion = false,
    this.preprocessing = 'rtmpose17-normalized-2d-v1;features-identity;float32',
  });

  final String actionId;
  final String version;
  final String displayName;
  final int schemaVersion;
  final String labelVersion;
  final List<String> featureNames;
  final Map<String, String> labels;
  final Map<String, String> angleLabels;
  final bool acceptLegacyVersion;
  final String preprocessing;
  bool get isHand => schemaVersion == 2;

  bool accepts(Map<String, dynamic> sample) {
    if (schemaVersion == 3) return BodyResearchContract.accepts(sample);
    if (schemaVersion == 4) {
      return sample['schemaVersion'] == 4 &&
          sample['modality'] == 'body' &&
          sample['actionId'] == actionId &&
          sample['actionDefinitionVersion'] == version &&
          sample['featureNames'] is List &&
          (sample['featureNames'] as List).isEmpty &&
          sample['features'] is List &&
          (sample['features'] as List).isEmpty &&
          sample['featuresStatus'] == 'not_applicable';
    }
    final names = sample['featureNames'];
    final features = sample['features'];
    return (!isHand ||
            (sample['landmarkSource'] == 'mediapipe_hand_21' &&
                sample['extractorVersion'] == 'hand-image-proxy-v1' &&
                sample['modelInputVersion'] == 'hand-features-v1' &&
                sample['orderedFeatureNames'] is List &&
                (sample['orderedFeatureNames'] as List).join('|') ==
                    featureNames.join('|'))) &&
        sample['actionId'] == actionId &&
        sample['schemaVersion'] == schemaVersion &&
        (sample['actionDefinitionVersion'] == version ||
            (acceptLegacyVersion &&
                !sample.containsKey('actionDefinitionVersion'))) &&
        names is List &&
        names.length == featureNames.length &&
        List.generate(names.length, (i) => names[i] == featureNames[i])
            .every((same) => same) &&
        features is List &&
        features.length == featureNames.length &&
        features.every((value) => value is num && value.isFinite);
  }
}

class MlActionRegistry {
  MlActionRegistry(Iterable<MlActionDefinition> definitions)
      : _definitions = Map.unmodifiable({
          for (final definition in definitions) definition.actionId: definition,
        });

  final Map<String, MlActionDefinition> _definitions;

  static const standingFeatureNames = [
    'peak_leg_height',
    'minimum_hip_angle_deg',
    'minimum_knee_angle_deg',
    'peak_abs_trunk_lean_deg',
    'duration_seconds',
  ];

  static const standingKneeRaise = MlActionDefinition(
    actionId: 'standing_knee_raise',
    version: 'standing-knee-raise-v1',
    displayName: '站姿抬腳',
    acceptLegacyVersion: true,
    featureNames: standingFeatureNames,
    labels: {
      'meets_requirement': '符合指定動作要求',
      'insufficient_range': '活動幅度不足',
      'trunk_compensation': '軀幹代償',
      'unassessable': '無法評估',
    },
    angleLabels: {'hipDeg': '髖角', 'kneeDeg': '膝角', 'trunkLeanDeg': '軀幹傾斜'},
  );

  static const handPreprocessing =
      'mediapipe21-image-proxy-v1;features-identity;float32';
  static const turnPalm = MlActionDefinition(
    actionId: 'turnPalm',
    version: 'turnPalm-hand-v1',
    displayName: '翻掌訓練',
    schemaVersion: 2,
    labelVersion: 'hand-research-v1',
    preprocessing: handPreprocessing,
    featureNames: [
      'axis_x_range',
      'palm_normal_z_range',
      'orientation_range_deg',
      'orientation_step_mean_deg',
      'duration_seconds'
    ],
    labels: {
      'meets_requirement': '符合指定動作要求',
      'limited_rotation_proxy': '翻掌影像變化不足',
      'unstable_motion': '動作穩定度不足',
      'unassessable': '無法評估'
    },
  );
  static const sidePinch = MlActionDefinition(
    actionId: 'sidePinch',
    version: 'sidePinch-hand-v1',
    displayName: '側捏訓練',
    schemaVersion: 2,
    labelVersion: 'hand-research-v1',
    preprocessing: handPreprocessing,
    featureNames: [
      'minimum_pinch_ratio',
      'maximum_pinch_ratio',
      'pinch_range',
      'wrist_travel_ratio',
      'duration_seconds'
    ],
    labels: {
      'meets_requirement': '符合指定動作要求',
      'limited_pinch_motion': '側捏開合幅度不足',
      'unstable_motion': '動作穩定度不足',
      'unassessable': '無法評估'
    },
  );
  static const wristFeatures = [
    'minimum_relative_axis_deg',
    'maximum_relative_axis_deg',
    'axis_range_deg',
    'axis_step_mean_deg',
    'duration_seconds'
  ];
  static const wristLabels = {
    'meets_requirement': '符合指定動作要求',
    'limited_wrist_motion': '手部影像變化不足',
    'unstable_motion': '動作穩定度不足',
    'unassessable': '無法評估'
  };
  static const wristExtension = MlActionDefinition(
    actionId: 'wristExtension',
    version: 'wristExtension-hand-v1',
    displayName: '翹手腕式',
    schemaVersion: 2,
    labelVersion: 'hand-research-v1',
    preprocessing: handPreprocessing,
    featureNames: wristFeatures,
    labels: wristLabels,
  );
  static const wristSideBend = MlActionDefinition(
    actionId: 'wristSideBend',
    version: 'wristSideBend-hand-v1',
    displayName: '左右彎手腕式',
    schemaVersion: 2,
    labelVersion: 'hand-research-v1',
    preprocessing: handPreprocessing,
    featureNames: wristFeatures,
    labels: wristLabels,
  );
  static const hands = [turnPalm, sidePinch, wristExtension, wristSideBend];
  static final bodyAttempt = MlActionDefinition(
      actionId: 'standing_knee_raise',
      version: BodyResearchFeatureExtractor.actionDefinitionVersion,
      displayName: '站姿抬腳（Body attempt）',
      schemaVersion: 3,
      featureNames: BodyResearchFeatureExtractor.featureNames,
      labels: standingKneeRaise.labels,
      angleLabels: standingKneeRaise.angleLabels,
      preprocessing: 'body-attempt-aspect-2d-v2;NOT_DEPLOYED');
  static const bodyReviewLabels = {
    'meets_requirement': '符合指定動作要求',
    'needs_correction': '需要調整',
    'unassessable': '無法評估',
  };
  static const bodyReviews = [
    MlActionDefinition(actionId: 'draw_circle', version: 'draw-circle-body-review-v1',
        displayName: '畫圓訓練', schemaVersion: 4, labelVersion: 'body-review-label-v1',
        featureNames: [], labels: bodyReviewLabels),
    MlActionDefinition(actionId: 'overhead_reach', version: 'overhead-reach-body-review-v1',
        displayName: '伸手舉高訓練', schemaVersion: 4, labelVersion: 'body-review-label-v1',
        featureNames: [], labels: bodyReviewLabels),
    MlActionDefinition(actionId: 'raise_both_arms', version: 'raise-both-arms-body-review-v1',
        displayName: '雙手抬舉式', schemaVersion: 4, labelVersion: 'body-review-label-v1',
        featureNames: [], labels: bodyReviewLabels),
    MlActionDefinition(actionId: 'elbow_forward', version: 'elbow-forward-body-review-v1',
        displayName: '手肘屈伸訓練', schemaVersion: 4, labelVersion: 'body-review-label-v1',
        featureNames: [], labels: bodyReviewLabels),
    MlActionDefinition(actionId: 'sit_to_stand', version: 'sit-to-stand-body-review-v1',
        displayName: '坐站訓練', schemaVersion: 4, labelVersion: 'body-review-label-v1',
        featureNames: [], labels: bodyReviewLabels),
    MlActionDefinition(actionId: 'lateral_step', version: 'lateral-step-body-review-v1',
        displayName: '側跨步訓練', schemaVersion: 4, labelVersion: 'body-review-label-v1',
        featureNames: [], labels: bodyReviewLabels),
  ];
  static final production = MlActionRegistry([standingKneeRaise, ...hands, ...bodyReviews]);
  Iterable<MlActionDefinition> get definitions => _definitions.values;

  MlActionDefinition? byId(String? id) => _definitions[id];
  MlActionDefinition? forSample(Map<String, dynamic> sample) {
    if (sample['schemaVersion'] == 3 &&
        _definitions.containsKey('standing_knee_raise')) {
      return bodyAttempt.accepts(sample) ? bodyAttempt : null;
    }
    final definition = byId(sample['actionId']?.toString());
    return definition != null && definition.accepts(sample) ? definition : null;
  }
}

/// Action-specific collectors/extractors implement this; shared storage/queue
/// only handles versioned JSON and must never infer success from pose presence.
abstract interface class MlResearchSample {
  String get id;
  Map<String, Object> toJson();
}

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

  bool accepts(Map<String, dynamic> sample) {
    final names = sample['featureNames'];
    final features = sample['features'];
    return sample['actionId'] == actionId &&
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

  // Only this action is exposed in production. Synthetic definitions live in tests.
  static final production = MlActionRegistry([standingKneeRaise]);

  MlActionDefinition? byId(String? id) => _definitions[id];
  MlActionDefinition? forSample(Map<String, dynamic> sample) {
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

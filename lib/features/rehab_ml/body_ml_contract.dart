import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'body_research_feature_extractor.dart';
import 'body_research_sample.dart';

const bodyMlEngineeringValidation =
    bool.fromEnvironment('BODY_ML_ENGINEERING_VALIDATION');
const bodyMlEngineeringNotice =
    'SYNTHETIC MODEL · ENGINEERING ONLY · NOT FOR CLINICAL USE';

enum BodyMlDecision {
  predicted,
  lowConfidence,
  inputUnavailable,
  modelUnavailable,
  modelIncompatible,
  modelIntegrityFailed,
  inferenceError,
  disabled,
  modelNotApplicable,
  domainMismatch;

  String get wireName => switch (this) {
        predicted => 'PREDICTED',
        lowConfidence => 'LOW_CONFIDENCE',
        inputUnavailable => 'INPUT_UNAVAILABLE',
        modelUnavailable => 'MODEL_UNAVAILABLE',
        modelIncompatible => 'MODEL_INCOMPATIBLE',
        modelIntegrityFailed => 'MODEL_INTEGRITY_FAILED',
        inferenceError => 'INFERENCE_ERROR',
        disabled => 'DISABLED',
        modelNotApplicable => 'MODEL_NOT_APPLICABLE',
        domainMismatch => 'DOMAIN_MISMATCH',
      };
}

/// Versions are deliberately separate from the legacy v1/hand contracts.
abstract final class BodyMlContract {
  static const featureSchema = 'body-aspect-baseline-v1';
  static const labelsVersion = 'body-attempt-label-v1';
  static const poseVersion = 'rtmpose-wholebody-133-v1';
  static const classes = [
    'meets_requirement',
    'insufficient_range',
    'trunk_compensation'
  ];
  static const features = BodyResearchFeatureExtractor.featureNames;
  static const storeKey = 'body-v3-standing_knee_raise';
}

class BodyMlContractFailure implements Exception {
  const BodyMlContractFailure(this.status);
  final BodyMlDecision status;
}

/// Checksums detect corruption, not provenance/signatures. Bundles must originate
/// from trusted build tooling or an app-private, governed local model store.
class BodyMlBundle {
  factory BodyMlBundle.decodeFixture(String encoded) {
    final json = jsonDecode(utf8.decode(base64Decode(encoded))) as Map;
    return BodyMlBundle(
        manifest: base64Decode(json['manifest.json'] as String),
        model: base64Decode(json['model.onnx'] as String),
        featureSchema: base64Decode(json['feature_schema.json'] as String),
        labelMapping: base64Decode(json['label_mapping.json'] as String),
        checksums: Map<String, String>.from(json['checksums'] as Map));
  }
  BodyMlBundle(
      {required Uint8List manifest,
      required Uint8List model,
      required Uint8List featureSchema,
      required Uint8List labelMapping,
      required Map<String, String> checksums})
      : manifest = Uint8List.fromList(manifest),
        model = Uint8List.fromList(model),
        featureSchema = Uint8List.fromList(featureSchema),
        labelMapping = Uint8List.fromList(labelMapping),
        checksums = Map.unmodifiable(checksums);
  final Uint8List manifest, model, featureSchema, labelMapping;
  final Map<String, String> checksums;
  Map<String, Uint8List> get files => {
        'manifest.json': manifest,
        'model.onnx': model,
        'feature_schema.json': featureSchema,
        'label_mapping.json': labelMapping
      };
  static String hash(List<int> bytes) => sha256.convert(bytes).toString();
  String get artifactHash => hash(utf8.encode([
        'model.onnx',
        'feature_schema.json',
        'label_mapping.json'
      ].map((name) => '$name:${hash(files[name]!)}').join('\n')));

  BodyMlManifest validate(
      {bool engineering = false, bool requireActivation = true}) {
    if (model.isEmpty ||
        files.entries.any((e) => checksums[e.key] != hash(e.value))) {
      throw const BodyMlContractFailure(BodyMlDecision.modelIntegrityFailed);
    }
    try {
      final json = jsonDecode(utf8.decode(manifest)) as Map<String, dynamic>;
      if (json['modelHash'] != hash(model) ||
          json['artifactHash'] != artifactHash) {
        throw const BodyMlContractFailure(BodyMlDecision.modelIntegrityFailed);
      }
      final schema = jsonDecode(utf8.decode(featureSchema)) as Map;
      final labels = jsonDecode(utf8.decode(labelMapping)) as Map;
      if (json['manifestVersion'] != 1 ||
          json['modality'] != 'body' ||
          json['schemaVersion'] != 3 ||
          json['actionId'] != 'standing_knee_raise' ||
          json['actionDefinitionVersion'] !=
              BodyResearchFeatureExtractor.actionDefinitionVersion ||
          json['extractorVersion'] != BodyResearchFeatureExtractor.version ||
          json['modelInputVersion'] !=
              BodyResearchFeatureExtractor.modelInputVersion ||
          json['featureSchemaVersion'] != BodyMlContract.featureSchema ||
          json['labelMappingVersion'] != BodyMlContract.labelsVersion ||
          json['poseModelVersion'] != BodyMlContract.poseVersion ||
          !listEquals(json['featureNames'] as List?, BodyMlContract.features) ||
          !listEquals(json['featureOrder'] as List?, BodyMlContract.features) ||
          !listEquals(json['classOrder'] as List?, BodyMlContract.classes) ||
          json['inputDimension'] != 5 ||
          json['inputDtype'] != 'float32' ||
          !listEquals(json['inputShape'] as List?, [1, 5]) ||
          json['inputName'] != 'features' ||
          json['labelOutputName'] != 'label' ||
          json['probabilityOutputName'] != 'probabilities' ||
          json['labelEncoding'] != 'int64' ||
          !const {'EXPERIMENTAL', 'CANDIDATE', 'APPROVED', 'RETIRED'}
              .contains(json['modelStatus']) ||
          !const {'phone', 'tv_pi'}.contains(json['sourceDomain']) ||
          !const {'SYNTHETIC', 'REVIEWED_REAL'}.contains(json['dataOrigin']) ||
          !['modelId', 'modelVersion'].every((k) =>
              json[k] is String &&
              RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(json[k] as String)) ||
          schema['featureSchemaVersion'] != BodyMlContract.featureSchema ||
          schema['extractorVersion'] != BodyResearchFeatureExtractor.version ||
          schema['modelInputVersion'] !=
              BodyResearchFeatureExtractor.modelInputVersion ||
          schema['actionDefinitionVersion'] !=
              BodyResearchFeatureExtractor.actionDefinitionVersion ||
          schema['poseModelVersion'] != BodyMlContract.poseVersion ||
          schema['schemaVersion'] != 3 ||
          schema['modality'] != 'body' ||
          schema['actionId'] != 'standing_knee_raise' ||
          schema['dtype'] != 'float32' ||
          !listEquals(
              schema['featureNames'] as List?, BodyMlContract.features) ||
          labels['version'] != BodyMlContract.labelsVersion ||
          !listEquals(labels['classOrder'] as List?, BodyMlContract.classes)) {
        throw const BodyMlContractFailure(BodyMlDecision.modelIncompatible);
      }
      final threshold = json['abstentionThreshold'];
      if (threshold != null &&
          (threshold is! num ||
              !threshold.isFinite ||
              threshold < 0 ||
              threshold > 1)) {
        throw const BodyMlContractFailure(BodyMlDecision.modelIncompatible);
      }
      final result = BodyMlManifest._(Map.unmodifiable(json));
      if (!requireActivation) return result;
      if (engineering) {
        if (!bodyMlEngineeringValidation ||
            result.status != 'EXPERIMENTAL' ||
            !result.synthetic ||
            json['deploymentApproved'] != false) {
          throw const BodyMlContractFailure(BodyMlDecision.disabled);
        }
      } else if (!result.productionEligible) {
        throw const BodyMlContractFailure(BodyMlDecision.disabled);
      }
      // No invented clinical threshold: production abstains without separately
      // documented calibration evidence; probabilities remain descriptive only.
      return result;
    } on BodyMlContractFailure {
      rethrow;
    } catch (_) {
      throw const BodyMlContractFailure(BodyMlDecision.modelIncompatible);
    }
  }
}

class BodyMlManifest {
  BodyMlManifest._(this.json);
  final Map<String, dynamic> json;
  String get id => json['modelId'] as String;
  String get version => json['modelVersion'] as String;
  String get status => json['modelStatus'] as String;
  String get domain => json['sourceDomain'] as String;
  bool get synthetic => json['dataOrigin'] == 'SYNTHETIC';
  bool get productionEligible =>
      status == 'APPROVED' &&
      json['deploymentApproved'] == true &&
      json['dataOrigin'] == 'REVIEWED_REAL';
  double? get threshold => (json['abstentionThreshold'] as num?)?.toDouble();
  bool get calibrated =>
      json['calibrationValidated'] == true &&
      json['calibrationReference'] is String &&
      (json['calibrationReference'] as String).trim().isNotEmpty;
}

/// Only finalized vectors; never accepts v1/hand vectors by dimension alone.
class BodyMlInput {
  BodyMlInput(
      {required this.attemptId,
      required List<double?> features,
      required this.source,
      this.action = 'standing_knee_raise',
      this.modality = 'body',
      this.schemaVersion = 3,
      this.exerciseType = 'DEFAULT',
      this.quality = 'available',
      this.extractorVersion = BodyResearchFeatureExtractor.version,
      this.inputVersion = BodyResearchFeatureExtractor.modelInputVersion,
      this.actionVersion = BodyResearchFeatureExtractor.actionDefinitionVersion,
      this.poseVersion = BodyMlContract.poseVersion,
      List<String> featureNames = BodyMlContract.features})
      : features = List.unmodifiable(features),
        featureNames = List.unmodifiable(featureNames);
  factory BodyMlInput.fromSample(BodyResearchSample sample) => BodyMlInput(
      attemptId: sample.id,
      features: sample.features.values,
      source: sample.context.source,
      exerciseType: sample.context.exerciseType,
      quality: sample.features.status,
      poseVersion: sample.observations.first.poseModelVersion);
  factory BodyMlInput.fromPayload(Map<String, dynamic> json) => BodyMlInput(
      attemptId: json['sampleId']?.toString() ?? '',
      features: (json['features'] as List? ?? [])
          .map((v) => v is num ? v.toDouble() : null)
          .toList(),
      source: json['source']?.toString() ?? '',
      action: json['actionId']?.toString() ?? '',
      modality: json['modality']?.toString() ?? '',
      schemaVersion: json['schemaVersion'] as int? ?? 0,
      exerciseType: json['exerciseType']?.toString() ?? '',
      quality: json['featuresStatus']?.toString() ?? '',
      extractorVersion: json['extractorVersion']?.toString() ?? '',
      inputVersion: json['modelInputVersion']?.toString() ?? '',
      actionVersion: json['actionDefinitionVersion']?.toString() ?? '',
      poseVersion: json['poseModelVersion']?.toString() ?? '',
      featureNames: List<String>.from(json['featureNames'] as List? ?? []));
  final String attemptId, source, action, modality, exerciseType, quality;
  final String extractorVersion, inputVersion, actionVersion, poseVersion;
  final int schemaVersion;
  final List<double?> features;
  final List<String> featureNames;
  BodyMlDecision? get problem {
    if (action != 'standing_knee_raise' ||
        modality != 'body' ||
        exerciseType != 'DEFAULT') {
      return BodyMlDecision.modelNotApplicable;
    }
    if (schemaVersion != 3 ||
        extractorVersion != BodyResearchFeatureExtractor.version ||
        inputVersion != BodyResearchFeatureExtractor.modelInputVersion ||
        actionVersion != BodyResearchFeatureExtractor.actionDefinitionVersion ||
        poseVersion != BodyMlContract.poseVersion ||
        !listEquals(featureNames, BodyMlContract.features)) {
      return BodyMlDecision.modelIncompatible;
    }
    if (attemptId.isEmpty ||
        quality != 'available' ||
        features.length != 5 ||
        features
            .any((v) => v == null || !v.isFinite || !v.toFloat32().isFinite)) {
      return BodyMlDecision.inputUnavailable;
    }
    final f = features.cast<double>();
    if (f[0] < 0 ||
        f.sublist(1, 4).any((v) => v < 0 || v > 180) ||
        f[4] <= 0 ||
        f[4] > 20) {
      return BodyMlDecision.inputUnavailable;
    }
    if (!const {'phone', 'tv_pi'}.contains(source)) {
      return BodyMlDecision.domainMismatch;
    }
    return null;
  }
}

extension on double {
  double toFloat32() => Float32List.fromList([this]).first;
}

class BodyMlPrediction {
  BodyMlPrediction(
      {required this.decisionStatus,
      required this.input,
      this.manifest,
      this.label,
      this.confidence,
      List<double> probabilities = const []})
      : probabilities = List.unmodifiable(probabilities),
        inferenceTimestamp = DateTime.now().toUtc();
  final BodyMlDecision decisionStatus;
  final BodyMlInput input;
  final BodyMlManifest? manifest;
  final String? label;
  final double? confidence;
  final List<double> probabilities;
  final DateTime inferenceTimestamp;
  Map<String, Object?> toJson() => {
        'metadataKind': 'derived_advisory_NOT_GROUND_TRUTH',
        'action': input.action,
        'modelId': manifest?.id,
        'modelVersion': manifest?.version,
        'modelStatus': manifest?.status,
        'label': label,
        'confidence': confidence,
        'probabilities': probabilities,
        'featureSchemaVersion': BodyMlContract.featureSchema,
        'extractorVersion': input.extractorVersion,
        'modelInputVersion': input.inputVersion,
        'labelMappingVersion': BodyMlContract.labelsVersion,
        'sourceDomain': manifest?.domain,
        'inputSource': input.source,
        'inputQuality': input.quality,
        'inferenceTimestamp': inferenceTimestamp.toIso8601String(),
        'decisionStatus': decisionStatus.wireName,
        'engineeringOnly': manifest?.synthetic == true,
      };
}

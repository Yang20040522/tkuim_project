import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_body/features/rehab_ml/body_ml_contract.dart';
import 'package:flutter_body/features/rehab_ml/body_ml_evaluator.dart';

final fixtureJson = jsonDecode(
    File('test/fixtures/body_ml_engineering_bundle.json')
        .readAsStringSync()) as Map<String, dynamic>;
BodyMlBundle fixtureBundle() => BodyMlBundle(
    manifest: base64Decode(fixtureJson['manifest.json'] as String),
    model: base64Decode(fixtureJson['model.onnx'] as String),
    featureSchema: base64Decode(fixtureJson['feature_schema.json'] as String),
    labelMapping: base64Decode(fixtureJson['label_mapping.json'] as String),
    checksums: Map<String, String>.from(fixtureJson['checksums'] as Map));

// Simulated governance with NON-MODEL bytes, never reuse the synthetic ONNX
// artifact with a forged APPROVED manifest. Native inference is not involved.
BodyMlBundle fakeBundle({Map<String, Object?> changes = const {}}) {
  final original = fixtureBundle();
  final model = Uint8List.fromList([1, 2, 3]);
  final metadata = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(original.manifest)) as Map)
    ..addAll({
      'modelId': 'unit-test-only',
      'modelVersion': 'A',
      'modelStatus': 'APPROVED',
      'deploymentApproved': true,
      'dataOrigin': 'REVIEWED_REAL',
      'modelHash': BodyMlBundle.hash(model)
    });
  final hashes = {
    'model.onnx': BodyMlBundle.hash(model),
    'feature_schema.json': BodyMlBundle.hash(original.featureSchema),
    'label_mapping.json': BodyMlBundle.hash(original.labelMapping)
  };
  metadata['artifactHash'] = BodyMlBundle.hash(
      utf8.encode(hashes.entries.map((e) => '${e.key}:${e.value}').join('\n')));
  metadata.addAll(changes);
  final manifest = Uint8List.fromList(utf8.encode(jsonEncode(metadata)));
  return BodyMlBundle(
      manifest: manifest,
      model: model,
      featureSchema: original.featureSchema,
      labelMapping: original.labelMapping,
      checksums: {...hashes, 'manifest.json': BodyMlBundle.hash(manifest)});
}

BodyMlInput input(
        {String id = 'attempt',
        String source = 'tv_pi',
        List<double?>? features,
        String action = 'standing_knee_raise',
        String modality = 'body',
        int schema = 3,
        String exerciseType = 'DEFAULT',
        String quality = 'available'}) =>
    BodyMlInput(
        attemptId: id,
        source: source,
        features: features ?? [0.5, 90, 80, 8, 2],
        action: action,
        modality: modality,
        schemaVersion: schema,
        exerciseType: exerciseType,
        quality: quality);

class FakeBodySession implements BodyMlOnnxSession {
  int calls = 0, closes = 0;
  BodyMlOutput output = const BodyMlOutput(0, [0.8, 0.1, 0.1]);
  Future<BodyMlOutput> Function()? handler;
  @override
  Future<BodyMlOutput> infer(Float32List features) async {
    calls++;
    return handler == null ? output : await handler!();
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

Map<String, dynamic> proof(BodyMlBundle bundle) => {
      'professionalDefinitionsApproved': true,
      'realDataReviewed': true,
      'androidValidated': true,
      'approvedBy': 'FAKE-TEST',
      'approvedAt': '2026-10-07T00:00:00Z',
      'approvalReference': 'UNIT-ONLY',
      'runtimeValidated': true,
      'sourceDomain': 'tv_pi',
      'modelSha256': BodyMlBundle.hash(bundle.model),
      'manifestSha256': BodyMlBundle.hash(bundle.manifest)
    };

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/rehab_ml/ml_action_definition.dart';
import 'package:flutter_body/features/rehab_ml/ml_quality_evaluator.dart';
import 'package:flutter_body/features/rehab_ml/onnx_ml_quality_evaluator.dart';
import 'package:flutter_body/features/rehab_ml/ml_rep_quality_controller.dart';
import 'package:flutter_body/features/rehab_ml/standing_knee_raise_sample.dart';
import 'package:flutter_body/features/analysis/body/body_rep_trajectory_collector.dart';

// Fake bytes/approval only in tests: no synthetic model is packaged in assets.
final fakeBytes = Uint8List.fromList([1, 2, 3]);
Map<String, dynamic> metadata() => {
      'manifestVersion': 1,
      'modelVersion': 'synthetic-test-only',
      'actionId': 'standing_knee_raise',
      'schemaVersion': 1,
      'actionDefinitionVersion': 'standing-knee-raise-v1',
      'labelVersion': 'research-v1',
      'featureNames': MlActionRegistry.standingFeatureNames,
      'classes': [
        'insufficient_range',
        'meets_requirement',
        'trunk_compensation'
      ],
      'inputDimension': 5,
      'inputShape': [null, 5],
      'inputDtype': 'float32',
      'preprocessing': mlPreprocessing,
      'inputName': 'input',
      'labelOutputName': 'label',
      'probabilityOutputName': 'probabilities',
      'modelSha256': sha256.convert(fakeBytes).toString(),
      'dataOrigin': 'reviewed_export',
      'validationStatus': 'approved_research',
      'deploymentApproved': true,
      'onnxParity': {
        'status': 'PASS',
        'absoluteTolerance': 1e-5,
        'maxAbsoluteError': 0,
        'rows': 3
      },
      'confidenceThreshold': null,
      'confidenceThresholdValidated': false,
    };

class FakeSession implements MlOnnxSession {
  int calls = 0;
  bool closed = false;
  Float32List? input;
  MlModelOutput output =
      const MlModelOutput('meets_requirement', [0.1, 0.8, 0.1]);
  Completer<MlModelOutput>? pending;
  @override
  Future<MlModelOutput> infer(Float32List features) async {
    calls++;
    input = features;
    return pending == null ? output : await pending!.future;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

Future<MlQualityEvaluator> load(FakeSession session,
        {Map<String, dynamic>? manifest}) =>
    OnnxMlQualityEvaluator.load(
      manifestLoader: () async =>
          Uint8List.fromList(utf8.encode(jsonEncode(manifest ?? metadata()))),
      modelLoader: () async => fakeBytes,
      sessionFactory: (_, __) async => session,
    );

void main() {
  test('lazy load occurs once and loader failures do not affect training',
      () async {
    var loads = 0;
    final lazy = LazyMlQualityEvaluator(loader: () async {
      loads++;
      throw StateError('test load failure');
    });
    expect((await lazy.evaluate([0, 90, 90, 0, 1])).available, isFalse);
    expect((await lazy.evaluate([0, 90, 90, 0, 1])).available, isFalse);
    expect(loads, 1);
    await lazy.dispose();
    expect((await lazy.evaluate([0, 90, 90, 0, 1])).available, isFalse);
  });

  test('busy/reset rep never publishes stale previous analysis', () async {
    final session = FakeSession()..pending = Completer<MlModelOutput>();
    final controller = MlRepQualityController(await load(session));
    StandingKneeRaiseSample sample(String id) => StandingKneeRaiseSample(
            id: id,
            subjectId: 'synthetic_group',
            movementSide: 'left',
            cameraView: 'front',
            capturedAt: DateTime.utc(2026),
            frames: const [
              {'timestampMs': 0},
              {'timestampMs': 1000}
            ],
            features: const [
              0,
              90,
              90,
              0,
              1
            ]);
    final first = controller.completed(sample('one'));
    await controller.completed(sample('two'));
    expect(controller.latest.value.available, isFalse);
    session.pending!.complete(session.output);
    await first;
    expect(session.calls, 1);
    expect(controller.latest.value.available, isFalse);
    controller.reset();
    await controller.dispose();
    expect(session.closed, isTrue);
  });

  test('validated manifest creates float32 inference and preserves class order',
      () async {
    final session = FakeSession();
    final evaluator = await load(session);
    final result = await evaluator.evaluate([-0.5, 180, 180, 0, 1.5]);
    expect(result.label, 'meets_requirement');
    expect(result.confidence, 0.8);
    expect(result.modelVersion, 'synthetic-test-only');
    expect(session.input, [-0.5, 180, 180, 0, 1.5]);
    await evaluator.dispose();
    expect(session.closed, isTrue);
  });

  test('unapproved, synthetic, hash and every contract mismatch fail closed',
      () async {
    final changes = [
      {'deploymentApproved': false},
      {'validationStatus': 'parity_verified'},
      {'dataOrigin': 'synthetic_fixture'},
      {'modelSha256': 'wrong'},
      {'actionId': 'other'},
      {'schemaVersion': 2},
      {'actionDefinitionVersion': 'v2'},
      {'labelVersion': 'unknown'},
      {'featureNames': MlActionRegistry.standingFeatureNames.reversed.toList()},
      {'inputDimension': 4},
      {
        'inputShape': [null, 4]
      },
      {'inputDtype': 'float64'},
      {'preprocessing': 'different'},
      {
        'classes': ['unassessable']
      },
      {'confidenceThreshold': 0.9, 'confidenceThresholdValidated': false},
      {
        'onnxParity': {
          'status': 'PASS',
          'absoluteTolerance': 1,
          'maxAbsoluteError': 0,
          'rows': 3
        }
      },
    ];
    for (final change in changes) {
      final session = FakeSession();
      final evaluator =
          await load(session, manifest: {...metadata(), ...change});
      expect((await evaluator.evaluate([0, 90, 90, 0, 1])).available, isFalse);
      expect(session.calls, 0);
      await evaluator.dispose();
    }
  });

  test('missing model and native load failure safely fall back', () async {
    for (final failure in [false, true]) {
      final evaluator = await OnnxMlQualityEvaluator.load(
        manifestLoader: () async =>
            Uint8List.fromList(utf8.encode(jsonEncode(metadata()))),
        modelLoader: () async {
          if (!failure) throw const FormatException('missing');
          return fakeBytes;
        },
        sessionFactory: (_, __) async => throw StateError('native unavailable'),
      );
      expect((await evaluator.evaluate([0, 90, 90, 0, 1])).available, isFalse);
      await evaluator.dispose();
    }
  });

  test('invalid features never run native inference', () async {
    final session = FakeSession();
    final evaluator = await load(session);
    for (final features in [
      [1.0],
      [double.nan, 90.0, 90.0, 0.0, 1.0],
      [double.infinity, 90.0, 90.0, 0.0, 1.0],
      [0.0, 190.0, 90.0, 0.0, 1.0],
      [0.0, 90.0, 90.0, 0.0, 0.1]
    ]) {
      expect((await evaluator.evaluate(features)).available, isFalse);
    }
    expect(session.calls, 0);
    await evaluator.dispose();
  });

  test(
      'bad probabilities, label order and validated low confidence unavailable',
      () async {
    final session = FakeSession();
    final evaluator = await load(session);
    for (final output in [
      const MlModelOutput('insufficient_range', [0.1, 0.8, 0.1]),
      const MlModelOutput('meets_requirement', [0.8]),
      const MlModelOutput('meets_requirement', [0.1, double.nan, 0.1]),
      const MlModelOutput('meets_requirement', [0.1, 1.1, -0.2]),
    ]) {
      session.output = output;
      expect((await evaluator.evaluate([0, 90, 90, 0, 1])).available, isFalse);
    }
    await evaluator.dispose();
    final low = await load(FakeSession(), manifest: {
      ...metadata(),
      'confidenceThreshold': 0.9,
      'confidenceThresholdValidated': true
    });
    expect((await low.evaluate([0, 90, 90, 0, 1])).available, isFalse);
    await low.dispose();
  });

  test('dispose waits for inference and does not publish late result',
      () async {
    final session = FakeSession()..pending = Completer<MlModelOutput>();
    final evaluator = await load(session);
    final pending = evaluator.evaluate([0, 90, 90, 0, 1]);
    final disposal = evaluator.dispose();
    expect(session.closed, isFalse);
    session.pending!.complete(session.output);
    expect((await pending).available, isFalse);
    await disposal;
    expect(session.closed, isTrue);
    await evaluator.dispose(); // idempotent
  });

  test('completed rep only once, reset and unsupported sample safe', () async {
    final session = FakeSession();
    final controller = MlRepQualityController(await load(session));
    final sample = StandingKneeRaiseSample(
        id: 'synthetic',
        subjectId: 'synthetic_group',
        movementSide: 'left',
        cameraView: 'front',
        capturedAt: DateTime.utc(2026),
        frames: const [
          {'timestampMs': 0},
          {'timestampMs': 1000}
        ],
        features: const [
          0,
          90,
          90,
          0,
          1
        ]);
    await controller.completed(sample);
    await controller.completed(sample);
    expect(session.calls, 1);
    expect(controller.latest.value.available, isTrue);
    controller.reset();
    expect(controller.latest.value.available, isFalse);
    await controller.dispose();
    expect(session.closed, isTrue);
  });

  test('same golden trajectories as Python, including legacy and invalid cases',
      () {
    final golden = jsonDecode(
            File('ml/tests/fixtures/g4_features.json').readAsStringSync())
        as Map<String, dynamic>;
    for (final raw in golden['cases'] as List) {
      final c = raw as Map<String, dynamic>;
      final points = (golden['rawPoints'] as List)
          .map(
              (p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList();
      for (final e in (c['overrides'] as Map<String, dynamic>? ?? {}).entries) {
        points[int.parse(e.key)] = Offset(
            (e.value[0] as num).toDouble(), (e.value[1] as num).toDouble());
      }
      if (c['mutation'] == 'nan') points[13] = const Offset(double.nan, 0);
      final sample = StandingKneeRaiseSample.fromCompletedRep(
          consentGranted: true,
          id: 'synthetic',
          subjectId: 'synthetic_group',
          movementSide: c['side'] as String,
          cameraView: 'front',
          capturedAt: DateTime.utc(2026),
          samples: List.generate(
              c['frameCount'] as int? ?? 4,
              (i) => BodyTrajectorySample(
                  timestampMs: i * 100,
                  landmarks: points,
                  scores: List.filled(
                      17, (c['confidence'] as num? ?? 0.9).toDouble()))));
      if (!c.containsKey('features')) {
        expect(sample, isNull, reason: c['name'] as String);
        continue;
      }
      final data = Map<String, dynamic>.from(sample!.toJson());
      if (c['legacy'] == true) data.remove('actionDefinitionVersion');
      if (c.containsKey('version')) {
        data['actionDefinitionVersion'] = c['version'];
      }
      if (c['reverseFeatures'] == true) {
        data['featureNames'] =
            MlActionRegistry.standingFeatureNames.reversed.toList();
      }
      if (c.containsKey('version') || c['reverseFeatures'] == true) {
        expect(MlActionRegistry.production.forSample(data), isNull);
      } else {
        expect(MlActionRegistry.production.forSample(data), isNotNull);
        for (var i = 0; i < 5; i++) {
          expect(sample.features[i],
              closeTo((c['features'][i] as num).toDouble(), 1e-5));
        }
      }
    }
  });
}

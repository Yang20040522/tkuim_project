import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/rehab_ml/local_ml_model_store.dart';
import 'package:flutter_body/features/rehab_ml/ml_action_definition.dart';
import 'package:flutter_body/features/rehab_ml/onnx_ml_quality_evaluator.dart';
import 'g4_onnx_evaluator_test.dart' show metadata, fakeBytes, FakeSession;

// Fake approval/bytes exercise release gates only; never packaged patient models.
Map<String, dynamic> handManifest(MlActionDefinition a, String version) => {
      ...metadata(),
      'modelVersion': version,
      'actionId': a.actionId,
      'schemaVersion': 2,
      'actionDefinitionVersion': a.version,
      'labelVersion': a.labelVersion,
      'featureNames': a.featureNames,
      'classes': a.labels.keys.where((k) => k != 'unassessable').toList(),
      'landmarkSource': 'mediapipe_hand_21',
      'extractorVersion': 'hand-image-proxy-v1',
      'modelInputVersion': 'hand-features-v1',
      'preprocessing': a.preprocessing,
      'validationStatus': 'parity_verified',
      'deploymentApproved': false,
    };
Map<String, dynamic> proof(Map<String, dynamic> m) => {
      'professionalDefinitionsApproved': true,
      'realDataReviewed': true,
      'androidValidated': true,
      'approvedBy': 'synthetic_test_operator',
      'approvedAt': '2026-01-01T00:00:00Z',
      'approvalReference': 'fixture_only',
      'modelSha256': m['modelSha256'],
    };

void main() {
  late Directory dir;
  late LocalMlModelStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('g5_model_test_');
    store = LocalMlModelStore(directoryProvider: () async => dir);
  });
  tearDown(() async => dir.delete(recursive: true));
  for (final a in MlActionRegistry.hands) {
    test('${a.actionId} independent lazy session/approval/disable/rollback',
        () async {
      var loads = 0;
      final session = FakeSession()
        ..output = const MlModelOutput('meets_requirement', [0.8, 0.1, 0.1]);
      final evaluator = CatalogMlQualityEvaluator(a, store: store,
          sessionFactory: (_, m) async {
        loads++;
        expect(m.definition, a);
        return session;
      });
      expect(loads, 0);
      expect((await evaluator.evaluate([0, 1, 2, 3, 1.5])).available, false);
      final first = handManifest(a, 'fixture_v1'),
          next = handManifest(a, 'fixture_v2');
      await store.register(a, first, fakeBytes);
      expect(await store.activeVersion(a), isNull);
      expect(await store.load(a, 'fixture_v1'), isNull);
      await expectLater(
          store.approveAndActivate(a, 'fixture_v1', {}), throwsFormatException);
      await store.approveAndActivate(a, 'fixture_v1', proof(first));
      expect((await evaluator.evaluate([0, 1, 2, 3, 1.5])).available, true);
      expect((await evaluator.evaluate([0, 1, 2, 3, 1.5])).available, true);
      expect(loads, 1);
      await store.register(a, next, fakeBytes);
      await store.approveAndActivate(a, 'fixture_v2', proof(next));
      await store.disable(a);
      expect((await evaluator.evaluate([0, 1, 2, 3, 1.5])).available, false);
      expect(session.closed, true);
      await expectLater(store.approveAndActivate(a, 'fixture_v2', proof(next)),
          throwsFormatException);
      await store.rollback(a);
      expect(await store.activeVersion(a), 'fixture_v1');
      await File('${dir.path}/${a.actionId}/fixture_v1/model.onnx')
          .writeAsBytes([9]);
      expect(await store.load(a, 'fixture_v1'), isNull);
      await evaluator.dispose();
    });
  }
  test('contract/action/source/order/hash/synthetic/parity fail closed',
      () async {
    final a = MlActionRegistry.turnPalm,
        m = handManifest(MlActionRegistry.turnPalm, 'v1');
    for (final change in [
      {'actionId': 'sidePinch'},
      {'schemaVersion': 1},
      {'labelVersion': 'wrong'},
      {'featureNames': a.featureNames.reversed.toList()},
      {'inputDimension': 4},
      {'landmarkSource': 'rtmpose'},
      {'extractorVersion': 'wrong'},
      {'modelInputVersion': 'wrong'},
      {'preprocessing': mlPreprocessing},
      {'dataOrigin': 'synthetic_fixture'},
      {'modelSha256': 'wrong'},
      {
        'onnxParity': {'status': 'FAIL'}
      },
      {'disabled': true},
    ]) {
      await expectLater(store.register(a, {...m, ...change}, fakeBytes),
          throwsFormatException);
    }
    await expectLater(store.rollback(a), throwsFormatException);
    await store.register(a, m, fakeBytes);
    await expectLater(store.register(a, m, fakeBytes), throwsFormatException);
    expect(await store.activeVersion(MlActionRegistry.sidePinch), isNull);
  });
  test(
      'disable during inference suppresses result; busy and dispose do not leak',
      () async {
    final a = MlActionRegistry.sidePinch,
        m = handManifest(MlActionRegistry.sidePinch, 'v1');
    await store.register(a, m, fakeBytes);
    await store.approveAndActivate(a, 'v1', proof(m));
    final entered = Completer<void>(), pending = Completer<MlModelOutput>();
    final session = FakeSession()..pending = pending;
    final evaluator = CatalogMlQualityEvaluator(a, store: store,
        sessionFactory: (_, __) async {
      entered.complete();
      return session;
    });
    final first = evaluator.evaluate([0, 1, 2, 3, 1]);
    await entered.future;
    expect((await evaluator.evaluate([0, 1, 2, 3, 1])).available, false);
    await store.disable(a);
    final disposed = evaluator.dispose();
    pending.complete(const MlModelOutput('meets_requirement', [0.8, 0.1, 0.1]));
    expect((await first).available, false);
    await disposed;
    expect(session.calls, 1);
    expect(session.closed, true);
  });
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/rehab_ml/body_ml_contract.dart';
import 'package:flutter_body/features/rehab_ml/body_ml_evaluator.dart';
import 'package:flutter_body/features/rehab_ml/body_ml_advisory_controller.dart';
import 'package:flutter_body/features/rehab_ml/body_ml_advisory_card.dart';
import 'package:flutter_body/features/rehab_ml/local_ml_model_store.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'body_ml_test_support.dart';
import 'package:flutter_body/features/rehab_ml/body_research_sample.dart';
import 'package:flutter_body/features/rehab_ml/body_research_context.dart';
import 'body_research_foundation_test.dart' show observation;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('valid body manifest and both hashes', () {
    expect(fakeBundle().validate().version, 'A');
    expect(
        fixtureBundle().validate(requireActivation: false).synthetic, isTrue);
  });
  final mismatches = <String, Object>{
    'schemaVersion': 2,
    'actionId': 'sidePinch',
    'extractorVersion': 'v1',
    'modelInputVersion': 'wrong',
    'poseModelVersion': 'hand',
    'labelMappingVersion': 'v1',
    'featureSchemaVersion': 'body-aspect-extended-v1',
    'actionDefinitionVersion': 'v1',
    'featureOrder': BodyMlContract.features.reversed.toList(),
    'featureNames': ['wrong'],
    'inputDimension': 8,
    'classOrder': BodyMlContract.classes.reversed.toList(),
    'inputName': 'wrong',
    'sourceDomain': 'validated_multi_domain'
  };
  for (final entry in mismatches.entries) {
    test(
        'contract mismatch ${entry.key} fails closed',
        () => expect(
            () => fakeBundle(changes: {entry.key: entry.value}).validate(),
            throwsA(isA<BodyMlContractFailure>().having(
                (e) => e.status, 'status', BodyMlDecision.modelIncompatible))));
  }
  for (final name in ['model.onnx', 'manifest.json']) {
    test('integrity mismatch $name', () {
      final b = fakeBundle();
      final bad = BodyMlBundle(
          manifest: b.manifest,
          model: b.model,
          featureSchema: b.featureSchema,
          labelMapping: b.labelMapping,
          checksums: {...b.checksums, name: 'bad'});
      expect(
          () => bad.validate(),
          throwsA(isA<BodyMlContractFailure>().having(
              (e) => e.status, 'status', BodyMlDecision.modelIntegrityFailed)));
    });
  }
  for (final value in [null, double.nan, double.infinity, 1e100]) {
    test(
        'input rejects $value without imputation',
        () => expect(input(features: [value, 90, 80, 8, 2]).problem,
            BodyMlDecision.inputUnavailable));
  }
  test('wrong dimension/unavailable input rejected', () {
    expect(input(features: [1, 2]).problem, BodyMlDecision.inputUnavailable);
    expect(
        input(quality: 'unavailable').problem, BodyMlDecision.inputUnavailable);
  });
  test('hand/other body/CUSTOM/legacy v1 cannot enter body v3', () {
    expect(input(action: 'sidePinch', modality: 'hand', schema: 2).problem,
        BodyMlDecision.modelNotApplicable);
    expect(
        input(action: 'arm_raise').problem, BodyMlDecision.modelNotApplicable);
    expect(input(exerciseType: 'CUSTOM').problem,
        BodyMlDecision.modelNotApplicable);
    expect(input(schema: 1).problem, BodyMlDecision.modelIncompatible);
  });
  for (var c = 0; c < 3; c++) {
    test('numeric class $c mapped by explicit classOrder', () async {
      final session = FakeBodySession()
        ..output = BodyMlOutput(c, List.generate(3, (i) => i == c ? 0.8 : 0.1));
      final evaluator = BodyMlEvaluator(
          bundleLoader: (_) async => fixtureBundle(),
          revision: () async => 'r5-engineering-fixture-v1',
          engineering: true,
          sessionFactory: (_, __) async => session);
      final result = await evaluator.evaluate(input());
      expect(
          result.decisionStatus,
          bodyMlEngineeringValidation
              ? BodyMlDecision.predicted
              : BodyMlDecision.disabled);
      if (bodyMlEngineeringValidation) {
        expect(result.label, BodyMlContract.classes[c]);
      }
      await evaluator.dispose();
    });
  }
  test('production without calibration abstains, never clinical threshold',
      () async {
    final session = FakeBodySession();
    final evaluator = BodyMlEvaluator(
        bundleLoader: (_) async => fakeBundle(),
        revision: () async => 'A',
        sessionFactory: (_, __) async => session);
    final result = await evaluator.evaluate(input());
    expect(result.decisionStatus, BodyMlDecision.lowConfidence);
    expect(result.label, isNull);
    expect(result.probabilities, [0.8, 0.1, 0.1]);
    expect(
        result.toJson()['metadataKind'], 'derived_advisory_NOT_GROUND_TRUTH');
    await evaluator.dispose();
  });
  test('domain mismatch never initializes ORT', () async {
    var opens = 0;
    final evaluator = BodyMlEvaluator(
        bundleLoader: (_) async => fakeBundle(),
        revision: () async => 'A',
        sessionFactory: (_, __) async {
          opens++;
          return FakeBodySession();
        });
    expect((await evaluator.evaluate(input(source: 'phone'))).decisionStatus,
        BodyMlDecision.domainMismatch);
    expect(opens, 0);
    await evaluator.dispose();
  });
  test(
      'frozen extractor sample adapter leaves counters and annotation untouched',
      () async {
    final sample = BodyResearchSample(
        context: BodyResearchContext(
            ownerId: 'FAKE',
            accountGeneration: 0,
            exerciseId: '99',
            movementSide: 'left',
            capturedAt: DateTime.utc(2026)),
        attemptId: 'immutable',
        observations: [
          for (final t in [0, 100, 200, 300]) observation(t)
        ],
        termination: BodyAttemptTermination.returnedToBaseline,
        setIndex: 2,
        completedRepsBefore: 4,
        completedRepsAfter: 5,
        intendedRepetition: 5);
    final before = sample.toJson();
    final annotation = <String, Object>{
      'label': 'trunk_compensation',
      'revision': 2
    };
    final evaluator = BodyMlEvaluator(
        revision: () async => null, bundleLoader: (_) async => null);
    final vector = BodyMlInput.fromSample(sample);
    expect(vector.features, sample.features.values);
    expect(vector.problem, isNull);
    expect((await evaluator.evaluate(vector)).decisionStatus,
        BodyMlDecision.modelUnavailable);
    expect(sample.toJson(), before);
    expect(sample.completedRepsAfter, 5);
    expect(sample.setIndex, 2);
    expect(annotation, {'label': 'trunk_compensation', 'revision': 2});
    await evaluator.dispose();
  });
  test('engineering threshold abstains without a clinical confidence claim',
      () async {
    final bundle = fakeBundle(changes: {
      'modelStatus': 'EXPERIMENTAL',
      'dataOrigin': 'SYNTHETIC',
      'deploymentApproved': false,
      'abstentionThreshold': 0.9
    });
    final evaluator = BodyMlEvaluator(
        engineering: true,
        revision: () async => 'A',
        bundleLoader: (_) async => bundle,
        sessionFactory: (_, __) async => FakeBodySession());
    final result = await evaluator.evaluate(input());
    expect(
        result.decisionStatus,
        bodyMlEngineeringValidation
            ? BodyMlDecision.lowConfidence
            : BodyMlDecision.disabled);
    expect(result.label, isNull);
    await evaluator.dispose();
  });
  test('model version change invalidates and reloads scoped native session',
      () async {
    String? version = 'A';
    final sessions = <FakeBodySession>[];
    final evaluator = BodyMlEvaluator(
        revision: () async => version,
        bundleLoader: (v) async => fakeBundle(changes: {'modelVersion': v}),
        sessionFactory: (_, __) async {
          final s = FakeBodySession();
          sessions.add(s);
          return s;
        });
    await evaluator.evaluate(input());
    version = 'B';
    await evaluator.evaluate(input(id: 'next'));
    expect(sessions, hasLength(2));
    expect(sessions.first.closes, 1);
    version = null;
    await evaluator.evaluate(input(id: 'disabled'));
    expect(sessions.last.closes, 1);
    await evaluator.dispose();
  });
  test('logout during inference ignores result and releases session', () async {
    AppSession.userId = 'FAKE-A';
    final started = Completer<void>(), completion = Completer<BodyMlOutput>();
    final s = FakeBodySession()
      ..handler = () {
        started.complete();
        return completion.future;
      };
    final controller = BodyMlAdvisoryController(
        evaluator: BodyMlEvaluator(
            revision: () async => 'A',
            bundleLoader: (_) async => fakeBundle(),
            sessionFactory: (_, __) async => s));
    final result = controller.evaluate(input());
    await started.future;
    AppSession.userId = null;
    AppSession.changes.value++;
    completion.complete(const BodyMlOutput(0, [0.8, 0.1, 0.1]));
    await result;
    await Future<void>.delayed(Duration.zero);
    expect(controller.latest.value, isNull);
    expect(s.closes, 1);
    await controller.dispose();
  });
  test('missing/corrupt/ORT failure/inference failure structured fallback',
      () async {
    for (var scenario = 0; scenario < 4; scenario++) {
      final session = FakeBodySession()
        ..handler = () async => throw StateError('fake inference failure');
      final evaluator = BodyMlEvaluator(
          revision: () async => 'A',
          bundleLoader: (_) async => scenario == 0
              ? null
              : scenario == 1
                  ? fakeBundle(changes: {'modelHash': 'bad'})
                  : fakeBundle(),
          sessionFactory: (_, __) async {
            if (scenario == 2) throw StateError('fake ORT/opset failure');
            return session;
          });
      expect(
          (await evaluator.evaluate(input())).decisionStatus,
          [
            BodyMlDecision.modelUnavailable,
            BodyMlDecision.modelIntegrityFailed,
            BodyMlDecision.inferenceError,
            BodyMlDecision.inferenceError
          ][scenario]);
      await evaluator.dispose();
    }
  });
  test('invalid output probabilities/labels fail closed', () async {
    for (final out in [
      const BodyMlOutput(3, [0.8, 0.1, 0.1]),
      const BodyMlOutput(0, [0.1, 0.8, 0.1]),
      const BodyMlOutput(0, [double.nan, 0.1, 0.1])
    ]) {
      final s = FakeBodySession()..output = out;
      final evaluator = BodyMlEvaluator(
          bundleLoader: (_) async => fakeBundle(),
          revision: () async => 'A',
          sessionFactory: (_, __) async => s);
      expect((await evaluator.evaluate(input())).decisionStatus,
          BodyMlDecision.inferenceError);
      await evaluator.dispose();
    }
  });
  test('duplicate attempt+version shares inference, session is cached',
      () async {
    final s = FakeBodySession();
    var loads = 0;
    final evaluator = BodyMlEvaluator(
        bundleLoader: (_) async {
          loads++;
          return fakeBundle();
        },
        revision: () async => 'A',
        sessionFactory: (_, __) async => s);
    await Future.wait(
        [evaluator.evaluate(input()), evaluator.evaluate(input())]);
    await evaluator.evaluate(input(id: 'next'));
    expect(s.calls, 2);
    expect(loads, 1);
    await evaluator.dispose();
    expect(s.closes, 1);
  });
  test('disable while pending inference ignores stale weights', () async {
    final completion = Completer<BodyMlOutput>(), started = Completer<void>();
    String? revision = 'A';
    final s = FakeBodySession()
      ..handler = () {
        started.complete();
        return completion.future;
      };
    final evaluator = BodyMlEvaluator(
        bundleLoader: (_) async => fakeBundle(),
        revision: () async => revision,
        sessionFactory: (_, __) async => s);
    final pending = evaluator.evaluate(input());
    await started.future;
    revision = null;
    completion.complete(const BodyMlOutput(0, [0.8, 0.1, 0.1]));
    expect((await pending).decisionStatus, BodyMlDecision.disabled);
    expect((await evaluator.evaluate(input(id: 'next'))).decisionStatus,
        BodyMlDecision.modelUnavailable);
    expect(s.closes, 1);
    await evaluator.dispose();
  });
  test(
      'account switch/logout closes cache and clears advisory; counters unowned',
      () async {
    AppSession.userId = 'FAKE-A';
    final s = FakeBodySession();
    final controller = BodyMlAdvisoryController(
        evaluator: BodyMlEvaluator(
            bundleLoader: (_) async => fakeBundle(),
            revision: () async => 'A',
            sessionFactory: (_, __) async => s));
    await controller.evaluate(input());
    expect(controller.latest.value, isNotNull);
    AppSession.userId = 'FAKE-B';
    AppSession.changes.value++; // production login/logout emits this notifier
    await Future<void>.delayed(Duration.zero);
    expect(controller.latest.value, isNull);
    expect(s.closes, 1);
    await controller.evaluate(input(id: 'after-switch'));
    expect(s.calls, 1);
    await controller.dispose();
    AppSession.userId = null;
  });
  test('new attempt result cannot be overwritten by old completion', () async {
    AppSession.userId = 'FAKE-A';
    final started = Completer<void>(), pending = Completer<BodyMlOutput>();
    var calls = 0;
    final s = FakeBodySession()
      ..handler = () {
        calls++;
        if (calls == 1) {
          started.complete();
          return pending.future;
        }
        return Future.value(const BodyMlOutput(1, [0.1, 0.8, 0.1]));
      };
    final controller = BodyMlAdvisoryController(
        evaluator: BodyMlEvaluator(
            bundleLoader: (_) async => fakeBundle(),
            revision: () async => 'A',
            sessionFactory: (_, __) async => s));
    final old = controller.evaluate(input(id: 'old'));
    await started.future;
    final next = controller.evaluate(input(id: 'new'));
    pending.complete(const BodyMlOutput(0, [0.8, 0.1, 0.1]));
    await old;
    await next;
    expect(controller.latest.value!.input.attemptId, 'new');
    await controller.dispose();
    AppSession.userId = null;
  });
  for (final status in ['EXPERIMENTAL', 'CANDIDATE', 'RETIRED']) {
    test(
        '$status never production activates',
        () => expect(
            () => fakeBundle(changes: {'modelStatus': status}).validate(),
            throwsA(isA<BodyMlContractFailure>())));
  }
  test(
      'synthetic cannot production activate even if forged APPROVED state',
      () => expect(
          () => fakeBundle(changes: {'dataOrigin': 'SYNTHETIC'}).validate(),
          throwsA(isA<BodyMlContractFailure>())));
  test(
      'store activation/failed candidate/rollback/disable preserves approved model',
      () async {
    final dir = await Directory.systemTemp.createTemp('body-r5-test-');
    addTearDown(() => dir.delete(recursive: true));
    final store = LocalMlModelStore(directoryProvider: () async => dir);
    final a = fakeBundle(),
        b = fakeBundle(changes: {'modelVersion': 'B'}),
        candidate = fakeBundle(
            changes: {'modelVersion': 'C', 'modelStatus': 'CANDIDATE'});
    for (final bundle in [a, b, candidate, fixtureBundle()]) {
      await store.registerBody(bundle);
    }
    await store.activateBody('A', proof(a),
        sourceDomain: 'tv_pi', runtimeCheck: (_) async => true);
    expect(
        store.activateBody('C', proof(candidate),
            sourceDomain: 'tv_pi', runtimeCheck: (_) async => true),
        throwsA(isA<BodyMlContractFailure>()));
    expect(await store.activeBodyVersion(), 'A');
    expect(
        store.activateBody('B', proof(b),
            sourceDomain: 'tv_pi', runtimeCheck: (_) async => false),
        throwsFormatException);
    expect(await store.activeBodyVersion(), 'A');
    await store.activateBody('B', proof(b),
        sourceDomain: 'tv_pi', runtimeCheck: (_) async => true);
    await store.rollbackBody();
    expect(await store.activeBodyVersion(), 'A');
    expect(await store.loadBody('r5-engineering-fixture-v1'), isNull);
    await store.disableBody();
    expect(await store.activeBodyVersion(), isNull);
    expect(await store.loadBody('A'), isNull);
  });
  testWidgets(
      'no-model and advisory UI keep professional annotation independent',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: BodyMlAdvisoryCard(prediction: null, therapist: true))));
    expect(find.text('MODEL_UNAVAILABLE'), findsOneWidget);
    expect(find.textContaining('不自動填入'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}

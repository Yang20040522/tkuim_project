import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/rehab_ml/hand_research_session.dart';
import 'package:flutter_body/features/rehab_ml/ml_action_definition.dart';
import 'package:flutter_body/features/rehab_ml/ml_quality_evaluator.dart';
import 'package:flutter_body/features/rehab_ml/ml_research_api.dart';
import 'package:flutter_body/features/rehab_ml/ml_sample_repository.dart';
import 'package:flutter_body/features/rehab_ml/research_collection_gate.dart';
import 'package:flutter_body/services/pose_model_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hand_research_sample_test.dart' show pose;

class _Evaluator extends MlQualityEvaluator {
  int calls = 0;
  bool closed = false;
  @override
  Future<MlQualityResult> evaluate(List<double> features) async {
    calls++;
    return const MlQualityResult.unavailable('研究模型尚未開放。');
  }

  @override
  Future<void> dispose() async {
    closed = true;
  }
}

class _ConsentRemote extends MlResearchApi {
  bool active = false, handAvailable = true;
  int uploads = 0;
  @override
  Future<MlResearchConsent> getConsent() async => MlResearchConsent(
      active: active, available: true, currentVersion: 'fixture',
      subjectId: active ? 'server-subject' : null,
      handAvailable: handAvailable);
  @override
  Future<MlResearchConsent> setConsent(bool agree, String version) async {
    active = agree;
    return getConsent();
  }
  @override
  Future<void> upload(Map<String, dynamic> sample) async { uploads++; }
}

void cycle(HandResearchSession s, {bool raw = true, int start = 0}) {
  s.observe(
      PoseFrame(
          handLandmarks: pose(0),
          observedHandLandmarks: raw ? pose(0) : null,
          handDetected: true),
      start,
      0,
      1,
      true);
  for (var i = 0; i < 6; i++) {
    s.observe(
        PoseFrame(
            handLandmarks: pose(i),
            observedHandLandmarks: raw ? pose(i) : null,
            handDetected: true),
        start + 1 + i * 300,
        i == 5 ? 2 : 1,
        1,
        true);
  }
}

Future<void> settleIo() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late Directory dir;
  late MlSampleRepository repo;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSession.userId = '1';
    AppSession.customExerciseToken = 'fixture';
    dir = await Directory.systemTemp.createTemp('g5_session_test_');
    repo = MlSampleRepository(directoryProvider: () async => dir);
  });
  tearDown(() async {
    AppSession.userId = null;
    AppSession.customExerciseToken = null;
    await dir.delete(recursive: true);
  });
  for (final a in MlActionRegistry.hands) {
    test('${a.actionId} collects only after server and hand scope agree',
        () async {
      final evaluator = _Evaluator();
      final api = _ConsentRemote();
      final gate = ResearchCollectionGate(remote: api);
      final s = HandResearchSession(a,
          repository: repo, remote: api, collectionGate: gate,
          evaluator: evaluator);
      cycle(s);
      await settleIo();
      expect(await repo.list(), isEmpty);
      expect(await gate.setEnabled(true), true);
      cycle(s, raw: false, start: 2000);
      await settleIo();
      expect(await repo.list(), isEmpty); // predicted poses cannot be samples
      cycle(s, start: 4000);
      await settleIo();
      expect((await repo.list()).length, 1);
      expect(api.uploads, 1);
      expect(evaluator.calls, 1);
      expect(s.quality.latest.value.available, false);
      s.reset();
      cycle(s, start: 6000);
      await settleIo();
      expect(api.uploads, 2);
      s.foreground = false;
      s.reset();
      cycle(s, start: 8000);
      await settleIo();
      expect((await repo.list()).length, 2);
      expect(api.uploads, 2);
      await s.dispose();
      gate.dispose();
      expect(evaluator.closed, true);
    });
  }
  test('hand scope blocks collection even while master is ON',
      () async {
    final remote = _ConsentRemote()..handAvailable = false;
    final gate = ResearchCollectionGate(remote: remote);
    final s = HandResearchSession(MlActionRegistry.turnPalm,
        repository: repo,
        evaluator: _Evaluator(),
        remote: remote, collectionGate: gate);
    expect(await gate.setEnabled(true), true);
    cycle(s);
    await settleIo();
    expect(remote.uploads, 0);
    expect(await s.sync.pendingIds(), isEmpty);
    expect(await repo.list(), isEmpty);
    await s.dispose();
    gate.dispose();
  });
  test(
      'save failure and consent withdrawal/re-enable never crash or retro-upload',
      () async {
    final gate = Completer<Directory>();
    final slow = MlSampleRepository(directoryProvider: () => gate.future);
    final remote = _ConsentRemote();
    final privacy = ResearchCollectionGate(remote: remote);
    final s = HandResearchSession(MlActionRegistry.sidePinch,
        repository: slow, remote: remote, collectionGate: privacy,
        evaluator: _Evaluator());
    await privacy.setEnabled(true);
    cycle(s);
    await privacy.setEnabled(false);
    gate.complete(dir);
    await settleIo();
    expect(await s.sync.pendingIds(), isEmpty);
    await s.dispose();
    await privacy.setEnabled(true);
    final failed = HandResearchSession(MlActionRegistry.sidePinch,
        repository: MlSampleRepository(
            directoryProvider: () async => throw StateError('fixture')),
        evaluator: _Evaluator(), remote: remote,
        collectionGate: privacy);
    cycle(failed);
    await settleIo();
    expect(failed.message.value, contains('現有復健訓練不受影響'));
    await failed.dispose();
    privacy.dispose();
  });
}

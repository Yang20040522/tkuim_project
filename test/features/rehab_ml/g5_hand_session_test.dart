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
    test('${a.actionId} opt-in raw only, one completion, local/cloud separate',
        () async {
      var uploads = 0;
      final evaluator = _Evaluator();
      final api = MlResearchApi(
          baseUrl: 'https://example.invalid',
          client: MockClient((r) async {
            if (r.url.path.endsWith('/consent')) {
              return http.Response(
                  jsonEncode({
                    'active': true,
                    'available': true,
                    'handAvailable': true,
                    'currentVersion': 'fixture'
                  }),
                  200);
            }
            uploads++;
            return http.Response('{}', 200);
          }));
      final s = HandResearchSession(a,
          repository: repo, remote: api, evaluator: evaluator);
      cycle(s);
      await settleIo();
      expect(await repo.list(), isEmpty);
      s.setLocalConsent(true, 'synthetic_group');
      cycle(s, raw: false, start: 2000);
      await settleIo();
      expect(await repo.list(), isEmpty); // predicted poses cannot be samples
      cycle(s, start: 4000);
      await settleIo();
      expect((await repo.list()).length, 1);
      expect(uploads, 0);
      expect(evaluator.calls, 1);
      expect(s.quality.latest.value.available, false);
      s.reset();
      s.cloudConsent = true;
      cycle(s, start: 6000);
      await settleIo();
      expect(uploads, 1);
      s.foreground = false;
      s.reset();
      cycle(s, start: 8000);
      await settleIo();
      expect((await repo.list()).length, 2);
      expect(uploads, 1);
      await s.dispose();
      expect(evaluator.closed, true);
    });
  }
  test('hand approval gate preserves pending queue without uploading',
      () async {
    var uploads = 0;
    final s = HandResearchSession(MlActionRegistry.turnPalm,
        repository: repo,
        evaluator: _Evaluator(),
        remote: MlResearchApi(
            baseUrl: 'https://example.invalid',
            client: MockClient((r) async {
              if (r.url.path.endsWith('/consent')) {
                return http.Response(
                    '{"active":true,"available":true,"handAvailable":false}',
                    200);
              }
              uploads++;
              return http.Response('{}', 200);
            })));
    s.setLocalConsent(true, 'synthetic');
    s.cloudConsent = true;
    cycle(s);
    await settleIo();
    expect(uploads, 0);
    expect(await s.sync.pendingIds(), hasLength(1));
    await s.dispose();
  });
  test(
      'save failure and consent withdrawal/re-enable never crash or retro-upload',
      () async {
    final gate = Completer<Directory>();
    final slow = MlSampleRepository(directoryProvider: () => gate.future);
    final s = HandResearchSession(MlActionRegistry.sidePinch,
        repository: slow, evaluator: _Evaluator());
    s.setLocalConsent(true, 'synthetic');
    s.cloudConsent = true;
    cycle(s);
    s.cloudConsent = false;
    s.cloudConsent = true;
    gate.complete(dir);
    await settleIo();
    expect(await s.sync.pendingIds(), isEmpty);
    await s.dispose();
    final failed = HandResearchSession(MlActionRegistry.sidePinch,
        repository: MlSampleRepository(
            directoryProvider: () async => throw StateError('fixture')),
        evaluator: _Evaluator());
    failed.setLocalConsent(true, 'synthetic');
    cycle(failed);
    await settleIo();
    expect(failed.message.value, contains('現有復健訓練不受影響'));
    await failed.dispose();
  });
}

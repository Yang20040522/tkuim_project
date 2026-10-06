import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/models/body_pose_observation.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/rehab_ml/body_research_session.dart';
import 'package:flutter_body/features/rehab_ml/body_research_settings_page.dart';
import 'package:flutter_body/features/rehab_ml/body_research_attempt_collector.dart';
import 'package:flutter_body/features/rehab_ml/ml_research_api.dart';
import 'package:flutter_body/features/rehab_ml/ml_sample_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'body_research_foundation_test.dart' show observation;
import 'body_research_owner_test.dart' show login;

class Remote extends MlResearchApi {
  int uploads = 0, consentChanges = 0;
  bool active = false;
  String disposition = 'NEEDS_RESAMPLE';
  @override
  Future<List<Map<String, dynamic>>> listSamples({int page = 0}) async => [
        {
          'id': '00000000-0000-4000-8000-000000000001',
          'schemaVersion': 3,
          'disposition': disposition,
          'exerciseType': 'DEFAULT',
          'exerciseId': '99',
          'reasonCode': 'LOW_QUALITY'
        }
      ];
  @override
  Future<Map<String, dynamic>> sampleDetail(String id) async => {
        'sample': {
          'schemaVersion': 3,
          'disposition': disposition,
          'exerciseType': 'DEFAULT',
          'exerciseId': '99'
        }
      };
  @override
  Future<MlResearchConsent> getConsent() async => MlResearchConsent(
      active: active, available: true, currentVersion: 'synthetic-v1');
  @override
  Future<MlResearchConsent> setConsent(bool agree, String version) async {
    active = agree;
    consentChanges++;
    return getConsent();
  }

  @override
  Future<void> upload(Map<String, dynamic> payload) async {
    uploads++;
  }
}

BodyPoseObservation moving(int time) {
  final base = observation(time);
  final points = base.keypoints.toList();
  points[13] = const Offset(.65, .5);
  points[15] = const Offset(.65, .8);
  return BodyPoseObservation(
      frameId: time,
      streamSessionId: base.streamSessionId,
      receivedAtMs: time,
      imageWidth: 640,
      imageHeight: 480,
      source: 'tv_pi',
      keypoints: points,
      scores: base.scores);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late BodyResearchSession session;
  late Remote remote;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    login('synthetic');
    root = await Directory.systemTemp.createTemp('body-session-');
    remote = Remote();
    session = BodyResearchSession(
        exerciseId: '99',
        movementSide: 'left',
        repository: MlSampleRepository(directoryProvider: () async => root),
        remote: remote);
  });
  tearDown(() async {
    session.dispose();
    AppSession.userId = null;
    AppSession.changes.value++;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await root.delete(recursive: true);
  });
  void begin() {
    for (final t in [0, 100, 200, 300]) {
      session.observe(moving(t), completedReps: 0, setIndex: 1);
    }
  }

  test('local consent independent of cloud; uncounted attempt persists',
      () async {
    begin();
    expect(session.collector.state, BodyCollectorState.disabled);
    session.setLocalConsent(true);
    begin();
    session.userFinished();
    await session.pendingPersistence;
    final samples = await session.repository.list();
    expect(samples, hasLength(1));
    expect(samples.single['completedRepsAfter'], 0);
    expect(remote.uploads, 0);
  });
  test('cloud consent queues/upload; suspension does not mutate counts',
      () async {
    session.setLocalConsent(true);
    session.setCloudConsent(true);
    remote.active = true;
    begin();
    session.setForeground(false);
    session.observe(moving(400), completedReps: 7, setIndex: 2);
    await session.pendingPersistence;
    final samples = await session.repository.list();
    expect(samples.single['terminationReason'], 'INTERRUPTED');
    expect(samples.single['completedRepsAfter'], 0);
    expect(remote.uploads, 1);
  });
  test('resample creates a fresh attempt link without changing counts',
      () async {
    session.setLocalConsent(true);
    await session.selectResample('00000000-0000-4000-8000-000000000001');
    begin();
    session.userFinished();
    await session.pendingPersistence;
    final samples = await session.repository.list();
    expect(samples.single['resampleOfSampleId'],
        '00000000-0000-4000-8000-000000000001');
    expect(samples.single['sampleId'],
        isNot('00000000-0000-4000-8000-000000000001'));
    expect(samples.single['attemptId'], samples.single['sampleId']);
    expect(samples.single['completedRepsAfter'], 0);
    expect(samples.single['setIndex'], 1);
  });
  test('active attempt cannot be retargeted and ACTIVE parent is refused',
      () async {
    session.setLocalConsent(true);
    begin();
    await expectLater(session.selectResample('parent'), throwsStateError);
    session.userFinished();
    remote.disposition = 'ACTIVE';
    await expectLater(session.selectResample('parent'), throwsStateError);
  });
  test('account change disables collector and rejects old consent', () {
    session.setLocalConsent(true);
    begin();
    login('other');
    expect(session.localConsent, false);
    expect(session.cloudConsent, false);
    expect(session.collector.state, BodyCollectorState.disabled);
    expect(() => session.setLocalConsent(true),
        throwsA(isA<MlResearchException>()));
  });
  testWidgets(
      'settings do not auto-consent; local toggle never opts into cloud',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: BodyResearchSettingsPage(session: session)));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('Body 研究資料'), findsOneWidget);
    expect(remote.consentChanges, 0);
    await tester.tap(find.text('同意本機 Body attempt 收集'));
    await tester.pump();
    expect(session.localConsent, true);
    expect(session.cloudConsent, false);
    await tester.tap(find.text('另行同意雲端同步'));
    await tester.pumpAndSettle();
    expect(session.cloudConsent, true);
    expect(remote.consentChanges, 1);
    await tester.tap(find.text('同意本機 Body attempt 收集'));
    await tester.pumpAndSettle();
    expect(session.cloudConsent, false);
    expect(remote.active, false);
    expect(session.localConsent, false);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

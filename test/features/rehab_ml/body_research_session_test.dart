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
import 'package:flutter_body/features/rehab_ml/research_collection_gate.dart';
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
          'actionId': 'standing_knee_raise',
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
          'actionId': 'standing_knee_raise',
          'disposition': disposition,
          'exerciseType': 'DEFAULT',
          'exerciseId': '99'
        }
      };
  @override
  Future<MlResearchConsent> getConsent() async => MlResearchConsent(
      active: active, available: true, currentVersion: 'synthetic-v1',
      subjectId: 'server-subject',
      bodyAvailableActions: const ['standing_knee_raise']);
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
  late ResearchCollectionGate gate;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    login('synthetic');
    root = await Directory.systemTemp.createTemp('body-session-');
    remote = Remote();
    gate = ResearchCollectionGate(remote: remote);
    session = BodyResearchSession(
        exerciseId: '99',
        movementSide: 'left',
        repository: MlSampleRepository(directoryProvider: () async => root),
        remote: remote, collectionGate: gate);
    await gate.refresh(force: true);
  });
  tearDown(() async {
    session.dispose();
    gate.dispose();
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

  test('no collection before server consent; uncounted attempt persists after consent',
      () async {
    begin();
    expect(session.collector.state, BodyCollectorState.disabled);
    expect(await session.repository.list(), isEmpty);
    expect(await gate.setEnabled(true), true);
    begin();
    session.userFinished();
    await session.pendingPersistence;
    final samples = await session.repository.list();
    expect(samples, hasLength(1));
    expect(samples.single['completedRepsAfter'], 0);
    expect(remote.uploads, 1);
  });
  test('server consent queues/upload; suspension does not mutate counts',
      () async {
    await gate.setEnabled(true);
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
    await gate.setEnabled(true);
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
    await gate.setEnabled(true);
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
      'settings reflect one server-authoritative master switch',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: BodyResearchSettingsPage(session: session)));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('Body 研究資料'), findsOneWidget);
    expect(remote.consentChanges, 0);
    await tester.tap(find.text('允許匿名復健研究資料收集'));
    await tester.pumpAndSettle();
    expect(session.localConsent, true);
    expect(session.cloudConsent, true);
    expect(remote.consentChanges, 1);
    await tester.tap(find.text('允許匿名復健研究資料收集'));
    await tester.pumpAndSettle();
    expect(session.cloudConsent, false);
    expect(remote.active, false);
    expect(session.localConsent, false);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

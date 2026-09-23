import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/rehab_ml/ml_research_api.dart';
import 'package:flutter_body/features/rehab_ml/ml_research_sync.dart';
import 'package:flutter_body/features/rehab_ml/ml_sample_repository.dart';
import 'package:flutter_body/features/rehab_ml/ml_sample_sheet.dart';
import 'package:flutter_body/features/rehab_ml/therapist_research_samples_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Remote implements MlResearchRemote {
  MlResearchConsent consent = const MlResearchConsent(
      active: false, available: true, currentVersion: 'study-v1');
  final uploaded = <String>[];
  bool failUpload = false;
  bool deleted = false;
  String? label;
  @override
  Future<MlResearchConsent> getConsent() async => consent;
  @override
  Future<MlResearchConsent> setConsent(bool agree, String version) async {
    expect(version, 'study-v1');
    consent = MlResearchConsent(
        active: agree,
        available: true,
        currentVersion: version,
        subjectId: agree ? 'server-subject' : null);
    return consent;
  }

  @override
  Future<void> upload(Map<String, dynamic> sample) async {
    if (failUpload) throw const MlResearchException('offline');
    uploaded.add(sample['sampleId'] as String);
  }

  @override
  Future<List<Map<String, dynamic>>> listSamples({int page = 0}) async => [
        {
          'id': 'server-1',
          'subjectId': 'server-subject',
          'movementSide': 'left',
          'capturedAt': '2026-09-23T00:00:00Z',
          'annotationStatus': 'UNLABELED'
        }
      ];
  @override
  Future<Map<String, dynamic>> sampleDetail(String id) async => {
        'sample': {'subjectId': 'server-subject'},
        'payload': {
          'frames': [
            for (var t = 0; t < 4; t++)
              {
                'timestampMs': t * 100,
                'landmarks': [
                  for (var i = 0; i < 17; i++) [i.toDouble(), t.toDouble()]
                ],
                'angles': {'hipDeg': 90, 'kneeDeg': 90, 'trunkLeanDeg': 0},
              }
          ]
        },
      };
  @override
  Future<void> labelSample(String id, String value, String note) async =>
      label = value;
  @override
  Future<void> deleteMyData() async => deleted = true;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.userId = '1';
    AppSession.customExerciseToken = 'test-token';
  });
  tearDown(() {
    AppSession.userId = null;
    AppSession.customExerciseToken = null;
  });

  test(
      'HTTPS API sends existing HMAC headers, payload, and rejects missing token',
      () async {
    final seen = <http.Request>[];
    final api = MlResearchApi(
      baseUrl: 'https://example.invalid',
      client: MockClient((request) async {
        seen.add(request);
        if (request.url.path.endsWith('/consent')) {
          return http.Response(
              jsonEncode({
                'active': false,
                'available': true,
                'currentVersion': 'study-v1'
              }),
              200);
        }
        return http.Response(jsonEncode({'id': 'server-1'}), 200);
      }),
    );
    expect((await api.getConsent()).currentVersion, 'study-v1');
    await api.upload({'sampleId': 'local-1'});
    expect(seen.last.headers['X-User-Id'], '1');
    expect(seen.last.headers['X-Custom-Exercise-Token'], 'test-token');
    expect(jsonDecode(seen.last.body)['sampleId'], 'local-1');
    AppSession.customExerciseToken = null;
    await expectLater(api.getConsent(), throwsA(isA<MlResearchException>()));
    expect(seen.length, 2);
  });

  test('offline queue retains sample and retry uploads once', () async {
    final dir = await Directory.systemTemp.createTemp('ml-cloud-test-');
    addTearDown(() => dir.delete(recursive: true));
    final local = MlSampleRepository(directoryProvider: () async => dir);
    await File('${dir.path}/rep_1.json').writeAsString(
        jsonEncode({'sampleId': 'rep_1', 'actionId': 'standing_knee_raise'}));
    final remote = _Remote();
    remote.consent = await remote.setConsent(true, 'study-v1');
    final queue = MlResearchSync(remote: remote, local: local);
    await queue.enqueue('rep_1');
    await queue.enqueue('rep_1');
    expect(await queue.pendingIds(), ['rep_1']);
    remote.failUpload = true;
    await expectLater(queue.sync(), throwsA(isA<MlResearchException>()));
    expect(await queue.pendingIds(), ['rep_1']);
    remote.failUpload = false;
    await queue.sync();
    await queue.sync();
    expect(remote.uploaded, ['rep_1']);
    expect(await queue.pendingIds(), isEmpty);
    expect(await queue.syncedIds(), ['rep_1']);
    await queue.withdraw();
    expect(remote.consent.active, isFalse);
  });

  testWidgets('patient cloud consent is explicit and revocable',
      (tester) async {
    final remote = _Remote();
    final local = MlSampleRepository(
        directoryProvider: () async =>
            Directory.systemTemp.createTemp('ml-cloud-empty-'));
    final queue = MlResearchSync(remote: remote, local: local);
    bool collecting = false;
    bool cloudCollecting = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MlSampleSheet(
      repository: local,
      cloudSync: queue,
      initialConsent: false,
      initialSubjectId: null,
      onConsentChanged: (value, _) => collecting = value,
      onCloudConsentChanged: (value) => cloudCollecting = value,
    ))));
    await tester.pumpAndSettle();
    expect(remote.consent.active, isFalse);
    await tester.enterText(find.byType(TextField).first, 'subject_01');
    await tester.tap(find.byKey(const Key('ml-local-consent')));
    await tester.pumpAndSettle();
    expect(collecting, isTrue);
    expect(remote.consent.active, isFalse);
    expect(cloudCollecting, isFalse);
    await tester.tap(find.byKey(const Key('ml-cloud-consent')));
    await tester.pumpAndSettle();
    expect(remote.consent.active, isTrue);
    expect(cloudCollecting, isTrue);
    await tester.tap(find.byKey(const Key('ml-local-consent')));
    await tester.pumpAndSettle();
    expect(collecting, isFalse);
    expect(cloudCollecting, isFalse);
    expect(remote.consent.active, isFalse);
  });

  testWidgets('therapist opens a real sample and saves explicit label',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final remote = _Remote();
    await tester.pumpWidget(
        MaterialApp(home: TherapistResearchSamplesPage(remote: remote)));
    await tester.pumpAndSettle();
    expect(find.text('站姿抬腳'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('research-sample-server-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('research-skeleton-player')), findsOneWidget);
    expect(find.textContaining('第 1 / 4 幀'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.textContaining('第 2 / 4 幀'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    await tester.tap(find.byKey(const Key('research-label')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('無法評估').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存標註'));
    await tester.pumpAndSettle();
    expect(remote.label, 'unassessable');
  });
}

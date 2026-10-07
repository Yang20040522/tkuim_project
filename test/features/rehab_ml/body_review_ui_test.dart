import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/rehab_ml/ml_research_api.dart';
import 'package:flutter_body/features/rehab_ml/research_sample_presentation.dart';
import 'package:flutter_body/features/rehab_ml/therapist_research_samples_page.dart';
import 'package:flutter_body/features/rehab_ml/research_management_page.dart';

Map<String, dynamic> fixture() => jsonDecode(
        File('test/fixtures/body_attempt_v3_synthetic.json').readAsStringSync())
    as Map<String, dynamic>;

class _Remote extends MlResearchRemote {
  _Remote({bool review = false}) {
    if (review) {
      payload['schemaVersion'] = 4;
      payload['actionId'] = 'sit_to_stand';
      payload['actionDefinitionVersion'] = 'sit-to-stand-body-review-v1';
      payload['features'] = <double>[];
      payload['featureNames'] = <String>[];
      payload['featuresStatus'] = 'not_applicable';
      payload['movementSide'] = 'bilateral';
      payload['terminationReason'] = 'SCORED_REP';
      payload['completedRepsAfter'] = 1;
      for (final frame in payload['frames'] as List) {
        (frame as Map).remove('angles');
      }
    }
  }
  final payload = fixture();
  String? status, decision, label, exportSource;
  int revision = 0;
  bool permitted = true;
  String disposition = 'ACTIVE';
  Map<String, dynamic> get sample => {
        'id': 'sample-v3',
        'subjectId': 'synthetic',
        'schemaVersion': payload['schemaVersion'],
        'modality': 'body',
        'source': 'tv_pi',
        'exerciseId': payload['exerciseId'],
        'exerciseType': 'DEFAULT',
        'actionId': payload['actionId'],
        'movementSide': payload['movementSide'],
        'sessionId': payload['sessionId'],
        'annotationStatus': status ?? 'UNLABELED',
        'disposition': disposition
      };
  @override
  Future<Map<String, dynamic>> authority() async => {
        'canAnnotate': permitted,
        'canReview': permitted,
        'canManage': permitted
      };
  @override
  Future<List<Map<String, dynamic>>> listSamples({int page = 0}) async =>
      [sample];
  @override
  Future<List<Map<String, dynamic>>> reviewQueue() async => [sample];
  @override
  Future<Map<String, dynamic>> sampleDetail(String id) async => {
        'sample': sample,
        'payload': payload,
        'annotation': status == null
            ? null
            : {
                'status': status,
                'label': label ?? 'insufficient_range',
                'annotatorUserId': 8,
                'revision': revision,
                'note': ''
              }
      };
  @override
  Future<void> labelSampleRevision(String id, String value, String note,
      {required String labelVersion,
      required String actionDefinitionVersion,
      required int expectedRevision}) async {
    expect(labelVersion, payload['schemaVersion'] == 4
        ? 'body-review-label-v1' : 'body-attempt-label-v1');
    expect(expectedRevision, revision);
    label = value;
    status = 'DRAFT';
    revision++;
  }

  @override
  Future<Map<String, dynamic>> submitLabelRevision(
      String id, int expectedRevision) async {
    expect(expectedRevision, revision);
    status = 'SUBMITTED';
    revision++;
    return {};
  }

  @override
  Future<Map<String, dynamic>> reviewDecision(
      String id, String value, String note,
      {required int expectedRevision, String? reasonCode}) async {
    expect(expectedRevision, revision);
    decision = value;
    revision++;
    if (value != 'APPROVE') {
      expect(note, isNotEmpty);
      expect(reasonCode, 'LOW_QUALITY');
    }
    status = value == 'APPROVE' ? 'APPROVED' : 'RETURNED';
    disposition = value == 'REJECT'
        ? 'REJECTED'
        : value == 'NEEDS_RESAMPLE'
            ? 'NEEDS_RESAMPLE'
            : 'ACTIVE';
    return {};
  }

  @override
  Future<Map<String, dynamic>> managementStats() async => {};
  @override
  Future<List<Map<String, dynamic>>> pendingReviewRequests() async => [];
  @override
  Future<List<Map<String, dynamic>>> retentionPolicies() async => [];
  @override
  Future<Uint8List> exportBodyApproved({required String source}) async {
    exportSource = source;
    return Uint8List.fromList([1]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    AppSession.userId = '1';
    AppSession.customExerciseToken = 'test-token';
  });
  tearDown(() {
    AppSession.userId = null;
    AppSession.customExerciseToken = null;
  });
  Future<void> page(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home: widget));
    await tester.pumpAndSettle();
  }

  testWidgets('v4 review displays action context, skeleton and review-only label',
      (tester) async {
    final remote = _Remote(review: true);
    await page(tester, ResearchSampleDetailPage(remote: remote,
        sampleId: 'sample-v3'));
    expect(find.textContaining('坐站訓練'), findsWidgets);
    expect(find.textContaining('不作為 ML 訓練標籤'), findsOneWidget);
    expect(find.textContaining('雙側'), findsOneWidget);
    expect(find.byKey(const Key('research-skeleton-player')), findsOneWidget);
    await tester.tap(find.byKey(const Key('research-label')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('需要調整').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存草稿'));
    await tester.pumpAndSettle();
    expect(remote.label, 'needs_correction');
  });

  test('seven filters distinguish legacy hand/body and v3 source', () {
    final body = _Remote().sample;
    for (final field in {
      'modality': 'body',
      'source': 'tv_pi',
      'patient': 'synthetic',
      'exercise': body['exerciseId'].toString(),
      'session': body['sessionId'].toString(),
      'status': 'UNLABELED',
      'disposition': 'ACTIVE'
    }.entries) {
      expect(ResearchSamplePresentation.matches(body, {field.key: field.value}),
          true);
      expect(ResearchSamplePresentation.matches(body, {field.key: 'wrong'}),
          false);
    }
    expect(ResearchSamplePresentation.originLabel({'schemaVersion': 2}),
        'Phone Hand');
    expect(ResearchSamplePresentation.originLabel({'schemaVersion': 1}),
        'Phone Body');
    expect(ResearchSamplePresentation.originLabel(body), 'TV + Pi Body');
  });
  test('timeline preserves irregular observations and tracking gaps', () {
    const timeline = ResearchPlaybackTimeline([
      {'timestampMs': 0},
      {'timestampMs': 125},
      {'timestampMs': 925}
    ]);
    expect(timeline.intervalAfter(0), const Duration(milliseconds: 125));
    expect(timeline.intervalAfter(1), const Duration(milliseconds: 800));
    expect(timeline.gapAfter(1), true);
    expect(timeline.gapAfter(0), false);
  });
  testWidgets('therapist v3 list displays source and source filter works',
      (tester) async {
    await page(tester, TherapistResearchSamplesPage(remote: _Remote()));
    expect(find.textContaining('TV + Pi Body'), findsOneWidget);
    await tester.tap(find.text('篩選研究樣本'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('research-filter-disposition')), findsOneWidget);
    await tester.tap(find.byKey(const Key('research-filter-source')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tv_pi').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('research-sample-sample-v3')), findsOneWidget);
  });
  testWidgets(
      'v3 playback uses timestamps, stops background, displays gaps and unavailable',
      (tester) async {
    final remote = _Remote();
    final frames = remote.payload['frames'] as List;
    await page(tester,
        ResearchSampleDetailPage(remote: remote, sampleId: 'sample-v3'));
    final interval = ResearchPlaybackTimeline(frames).intervalAfter(0);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(interval - const Duration(milliseconds: 1));
    expect(find.textContaining('第 1 /'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('第 2 /'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('第 2 /'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    remote.payload['frames'] = [
      {
        'timestampMs': 0,
        'keypoints': List.filled(17, null),
        'validity': List.filled(17, false)
      },
      {
        'timestampMs': 800,
        'keypoints': List.filled(17, null),
        'validity': List.filled(17, false)
      }
    ];
    remote.payload['features'] = List.filled(5, null);
    remote.payload['featuresStatus'] = 'unavailable';
    await page(tester,
        ResearchSampleDetailPage(remote: remote, sampleId: 'sample-v3'));
    expect(find.byKey(const Key('research-tracking-gap')), findsOneWidget);
    expect(find.textContaining('peak_leg_height：unavailable'), findsOneWidget);
  });
  test('invalid points are skipped without zero-point fallback or paint crash',
      () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = ResearchSkeletonPainter(null,
        bodyPoints: List.filled(17, null),
        validity: List.filled(17, false),
        imageWidth: 640,
        imageHeight: 480);
    expect(() => painter.paint(canvas, const Size(320, 320)), returnsNormally);
    recorder.endRecording().dispose();
    expect(
        painter.shouldRepaint(ResearchSkeletonPainter(null,
            bodyPoints: List.filled(17, [0.5, 0.5]))),
        true);
  });
  testWidgets('v3 draft and submit send expected revisions', (tester) async {
    final remote = _Remote();
    await page(tester,
        ResearchSampleDetailPage(remote: remote, sampleId: 'sample-v3'));
    await tester.ensureVisible(find.byKey(const Key('research-label')));
    await tester.tap(find.byKey(const Key('research-label')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('活動幅度不足').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('儲存草稿'));
    await tester.tap(find.text('儲存草稿'));
    await tester.pumpAndSettle();
    expect(remote.status, 'DRAFT');
    expect(remote.revision, 1);
    await tester.ensureVisible(find.byKey(const Key('research-submit-label')));
    await tester.tap(find.byKey(const Key('research-submit-label')));
    await tester.pumpAndSettle();
    expect(remote.status, 'SUBMITTED');
    expect(remote.revision, 2);
  });
  for (final entry in {
    'APPROVE': '核准',
    'RETURN': '退回',
    'REJECT': '排除樣本',
    'NEEDS_RESAMPLE': '需要重採樣'
  }.entries) {
    testWidgets('v3 reviewer ${entry.key} sends reason and revision',
        (tester) async {
      final remote = _Remote()
        ..status = 'SUBMITTED'
        ..revision = 3;
      await page(
          tester,
          ResearchSampleDetailPage(
              remote: remote, sampleId: 'sample-v3', reviewMode: true));
      if (entry.key != 'APPROVE') {
        await tester.ensureVisible(find.byType(TextField).last);
        await tester.enterText(find.byType(TextField).last, 'synthetic reason');
      }
      await tester.ensureVisible(find.text(entry.value));
      await tester.tap(find.text(entry.value));
      await tester.pumpAndSettle();
      expect(remote.decision, entry.key);
      expect(remote.revision, 4);
    });
  }
  testWidgets('unauthorized list and self review cannot expose operations',
      (tester) async {
    await page(tester,
        TherapistResearchSamplesPage(remote: _Remote()..permitted = false));
    expect(find.byKey(const Key('research-sample-sample-v3')), findsNothing);
    AppSession.userId = '8';
    await page(
        tester,
        ResearchSampleDetailPage(
            remote: _Remote()..status = 'SUBMITTED',
            sampleId: 'sample-v3',
            reviewMode: true));
    expect(find.text('核准'), findsNothing);
  });
  testWidgets('account change removes cached sample and stops playback',
      (tester) async {
    await page(tester,
        ResearchSampleDetailPage(remote: _Remote(), sampleId: 'sample-v3'));
    expect(find.byKey(const Key('research-skeleton-player')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    AppSession.userId = 'another-user';
    AppSession.changes.value++;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('research-skeleton-player')), findsNothing);
    expect(find.text('登入狀態已變更，請重新開啟樣本。'), findsOneWidget);
  });
  testWidgets('management exports explicit tv_pi domain', (tester) async {
    final remote = _Remote();
    await page(tester,
        ResearchManagementPage(remote: remote, saveExport: (_) async => true));
    await tester.ensureVisible(find.byKey(const Key('research-export-domain')));
    await tester.tap(find.byKey(const Key('research-export-domain')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TV + Pi Body v3').last);
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const Key('research-export-approved')));
    await tester.tap(find.byKey(const Key('research-export-approved')));
    await tester.pumpAndSettle();
    expect(remote.exportSource, 'tv_pi');
  });
  test('v3 API sends revision and exports only selected source', () async {
    final requests = <http.Request>[];
    final api = MlResearchApi(
        baseUrl: 'https://example.invalid',
        client: MockClient((r) async {
          requests.add(r);
          return r.url.path.endsWith('/export')
              ? http.Response.bytes([80, 75, 3, 4], 200,
                  headers: {'content-type': 'application/zip'})
              : http.Response('{}', 200);
        }));
    await api.labelSampleRevision('id', 'insufficient_range', '',
        labelVersion: 'body-attempt-label-v1',
        actionDefinitionVersion: fixture()['actionDefinitionVersion'] as String,
        expectedRevision: 2);
    await api.submitLabelRevision('id', 3);
    await api.reviewDecision('id', 'NEEDS_RESAMPLE', 'note',
        expectedRevision: 4, reasonCode: 'LOW_QUALITY');
    expect(jsonDecode(requests.last.body)['expectedRevision'], 4);
    expect(jsonDecode(requests.last.body)['decision'], 'NEEDS_RESAMPLE');
    await api.exportBodyApproved(source: 'tv_pi');
    expect(requests.last.url.queryParameters['source'], 'tv_pi');
    expect(requests.last.url.queryParameters['schemaVersion'], '3');
    expect(
        requests
            .every((r) => r.headers['X-Custom-Exercise-Token'] == 'test-token'),
        true);
  });
}

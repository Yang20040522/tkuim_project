import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/rehab_ml/body_research_context.dart';
import 'package:flutter_body/features/rehab_ml/body_research_sample.dart';
import 'package:flutter_body/features/rehab_ml/ml_action_definition.dart';
import 'package:flutter_body/features/rehab_ml/ml_sample_repository.dart';
import 'package:flutter_body/features/rehab_ml/ml_research_api.dart';
import 'package:flutter_body/features/rehab_ml/ml_research_sync.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'body_research_foundation_test.dart' show observation;

class FakeRemote extends MlResearchApi {
  Completer<MlResearchConsent>? consentGate;
  Completer<void>? uploadGate;
  int uploads = 0;
  @override
  Future<MlResearchConsent> getConsent() async => consentGate == null
      ? const MlResearchConsent(
          active: true, available: true, currentVersion: 'test-v1')
      : await consentGate!.future;
  @override
  Future<void> upload(Map<String, dynamic> sample) async {
    uploads++;
    await uploadGate?.future;
  }
}

BodyResearchSample sample() => BodyResearchSample(
    context: BodyResearchContext(
        ownerId: AppSession.userId!,
        accountGeneration: AppSession.changes.value,
        exerciseId: '99',
        movementSide: 'left',
        capturedAt: DateTime.utc(2026, 10, 6),
        sessionId: 'test-session'),
    attemptId: 'test-attempt',
    observations: [
      observation(0),
      observation(200),
      observation(400),
      observation(600)
    ],
    termination: BodyAttemptTermination.userFinished,
    setIndex: 1,
    completedRepsBefore: 0,
    completedRepsAfter: 0,
    intendedRepetition: 1);

void login(String id) {
  AppSession.userId = id;
  AppSession.customExerciseToken = 'synthetic-token-$id';
  AppSession.changes.value++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    login('a');
    root = await Directory.systemTemp.createTemp('body-owner-');
  });
  tearDown(() async {
    AppSession.userId = null;
    AppSession.customExerciseToken = null;
    AppSession.changes.value++;
    await root.delete(recursive: true);
  });
  test('v3 save/list/export and owner isolation; legacy root untouched',
      () async {
    final repo = MlSampleRepository(directoryProvider: () async => root);
    final captured = sample();
    expect(
        MlActionRegistry.production
            .forSample(Map<String, dynamic>.from(captured.toJson()))
            ?.schemaVersion,
        3);
    await repo.save(captured);
    await repo.save(captured);
    expect(await repo.list(), hasLength(1));
    expect(
        jsonDecode(
            utf8.decode(await repo.exportJson(captured.id)))['schemaVersion'],
        3);
    final legacy = File('${root.path}/legacy.json');
    await legacy.writeAsString('{}');
    login('b');
    final other = MlSampleRepository(directoryProvider: () async => root);
    expect(await other.list(), isEmpty);
    expect(await legacy.exists(), true);
    await expectLater(repo.list(), throwsA(isA<MlResearchException>()));
    await expectLater(other.save(captured), throwsFormatException);
    login('a');
    final again = MlSampleRepository(directoryProvider: () async => root);
    expect(await again.list(), hasLength(1));
  });
  test(
      'await directory then logout/login cannot write captured sample to new owner',
      () async {
    final gate = Completer<Directory>();
    final repo = MlSampleRepository(directoryProvider: () => gate.future);
    final saving = repo.save(sample());
    final assertion = expectLater(saving, throwsA(isA<MlResearchException>()));
    login('b');
    gate.complete(root);
    await assertion;
    expect(await root.list(recursive: true).toList(), isEmpty);
  });
  test('v3 opt-in queue dedup and successful ACK; old owner never crosses sync',
      () async {
    final repo = MlSampleRepository(directoryProvider: () async => root);
    await repo.save(sample());
    final remote = FakeRemote();
    final sync = MlResearchSync(remote: remote, local: repo);
    await sync.enqueue('test-attempt');
    await sync.enqueue('test-attempt');
    expect(await sync.pendingIds(), ['test-attempt']);
    await sync.sync();
    await sync.sync();
    expect(remote.uploads, 1);
    expect(await sync.syncedIds(), ['test-attempt']);
    login('b');
    final other = MlResearchSync(
        remote: FakeRemote(),
        local: MlSampleRepository(directoryProvider: () async => root));
    expect(await other.pendingIds(), isEmpty);
    expect(await other.syncedIds(), isEmpty);
    await expectLater(sync.sync(), throwsA(isA<MlResearchException>()));
  });
  test('logout while consent awaits prevents any upload', () async {
    final repo = MlSampleRepository(directoryProvider: () async => root);
    await repo.save(sample());
    final remote = FakeRemote()..consentGate = Completer<MlResearchConsent>();
    final sync = MlResearchSync(remote: remote, local: repo);
    await sync.enqueue('test-attempt');
    final pending = sync.sync();
    final assertion = expectLater(pending, throwsA(isA<MlResearchException>()));
    login('b');
    remote.consentGate!.complete(const MlResearchConsent(
        active: true, available: true, currentVersion: 'test-v1'));
    await assertion;
    expect(remote.uploads, 0);
  });
  test('logout while upload awaits cannot ACK against new owner queue',
      () async {
    final repo = MlSampleRepository(directoryProvider: () async => root);
    await repo.save(sample());
    final remote = FakeRemote()..uploadGate = Completer<void>();
    final sync = MlResearchSync(remote: remote, local: repo);
    await sync.enqueue('test-attempt');
    final pending = sync.sync();
    final assertion = expectLater(pending, throwsA(isA<MlResearchException>()));
    while (remote.uploads == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    login('b');
    remote.uploadGate!.complete();
    await assertion;
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('ml_cloud_pending_a'), ['test-attempt']);
    expect(prefs.getStringList('ml_cloud_pending_b_synced'), null);
  });
  test('API identity snapshot refuses reuse after account changes', () async {
    final headers = <String>[];
    final api = MlResearchApi(
        baseUrl: 'https://example.invalid',
        client: MockClient((r) async {
          headers.add(r.headers['X-User-Id']!);
          return http.Response(
              '{"active":false,"available":true,"currentVersion":"test-v1"}',
              200);
        }));
    await api.getConsent();
    login('b');
    await expectLater(api.getConsent(), throwsA(isA<MlResearchException>()));
    expect(headers, ['a']);
  });
  test('repository captured before first save cannot inherit next account',
      () async {
    final repo = MlSampleRepository(directoryProvider: () async => root);
    final captured = sample();
    login('b');
    await expectLater(repo.save(captured), throwsA(isA<MlResearchException>()));
    expect(await root.list(recursive: true).toList(), isEmpty);
  });
  test('concurrent duplicate writes are idempotent', () async {
    final a = MlSampleRepository(directoryProvider: () async => root);
    final b = MlSampleRepository(directoryProvider: () async => root);
    final captured = sample();
    await Future.wait([a.save(captured), b.save(captured)]);
    expect(await a.list(), hasLength(1));
  });
}

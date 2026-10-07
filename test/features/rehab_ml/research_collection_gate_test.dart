import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/rehab_ml/ml_research_api.dart';
import 'package:flutter_body/features/rehab_ml/research_collection_gate.dart';

class ConsentRemote extends MlResearchApi {
  bool active = false, available = true, offline = false, hand = false;
  int reads = 0, writes = 0;
  Completer<void>? withdrawal;
  @override
  Future<MlResearchConsent> getConsent() async {
    reads++;
    if (offline) throw StateError('offline');
    return MlResearchConsent(active: active, available: available,
        currentVersion: 'study-v1', subjectId: 'server-pseudonym',
        handAvailable: hand,
        bodyAvailableActions: const ['standing_knee_raise', 'draw_circle']);
  }
  @override
  Future<MlResearchConsent> setConsent(bool agree, String version) async {
    writes++;
    if (!agree) await withdrawal?.future;
    active = agree;
    return getConsent();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ConsentRemote remote;
  late ResearchCollectionGate gate;
  late DateTime now;
  setUp(() {
    AppSession.userId = 'patient';
    AppSession.customExerciseToken = 'test-token';
    AppSession.changes.value++;
    remote = ConsentRemote();
    now = DateTime.utc(2026, 10, 7);
    gate = ResearchCollectionGate(remote: remote, now: () => now);
  });
  tearDown(() {
    gate.dispose();
    AppSession.userId = null;
    AppSession.customExerciseToken = null;
    AppSession.changes.value++;
  });

  test('server confirmation is required before capture and both devices converge', () async {
    expect(gate.enabled, false);
    expect(await gate.setEnabled(true), true);
    expect(gate.bodyEnabled('draw_circle'), true);
    expect(gate.bodyEnabled('sit_to_stand'), false);
    expect(gate.handEnabled, false);
    now = now.add(const Duration(seconds: 24));
    expect(gate.enabled, true);
    remote.active = false; // withdrawal on the other device
    now = now.add(const Duration(seconds: 1));
    expect(gate.enabled, false);
    expect(await gate.canCollect(actionId: 'draw_circle'), false);
    expect(remote.reads, greaterThanOrEqualTo(3));
  });

  test('offline after TTL fails closed without changing the session owner', () async {
    remote.active = true;
    await gate.refresh(force: true);
    now = now.add(ResearchCollectionGate.freshness);
    remote.offline = true;
    expect(await gate.canCollect(actionId: 'standing_knee_raise'), false);
    expect(gate.enabled, false);
  });

  test('turning off immediately blocks local capture before PUT finishes', () async {
    expect(await gate.setEnabled(true), true);
    remote.withdrawal = Completer<void>();
    final pending = gate.setEnabled(false);
    expect(gate.enabled, false);
    remote.withdrawal!.complete();
    expect(await pending, false);
    expect(remote.active, false);
  });

  test('account change invalidates verified consent and hand scope remains separate', () async {
    remote.hand = true;
    expect(await gate.setEnabled(true), true);
    expect(gate.handEnabled, true);
    AppSession.userId = 'other';
    AppSession.changes.value++;
    expect(gate.enabled, false);
    expect(gate.handEnabled, false);
  });
}

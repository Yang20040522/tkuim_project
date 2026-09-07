import 'package:flutter_body/features/call/call_invitation_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same session initializes invitation service once', () async {
    final gateway = _FakeGateway();
    final lifecycle = CallInvitationLifecycle(gateway);

    await lifecycle.synchronize(userId: '14', userName: '患者 A');
    await lifecycle.synchronize(userId: '14', userName: '患者 A');

    expect(gateway.initializedUsers, ['14:患者 A']);
    expect(gateway.uninitializeCalls, 0);
  });

  test('logout uninitializes invitation service', () async {
    final gateway = _FakeGateway();
    final lifecycle = CallInvitationLifecycle(gateway);

    await lifecycle.synchronize(userId: '14', userName: '患者 A');
    await lifecycle.synchronize();
    await lifecycle.synchronize();

    expect(lifecycle.isInitialized, isFalse);
    expect(gateway.uninitializeCalls, 1);
  });

  test('user switch uninitializes old identity before new init', () async {
    final gateway = _FakeGateway();
    final lifecycle = CallInvitationLifecycle(gateway);

    await lifecycle.synchronize(userId: '14', userName: '患者 A');
    await lifecycle.synchronize(userId: '3', userName: '治療師 B');

    expect(gateway.events, [
      'init:14:患者 A',
      'uninit',
      'init:3:治療師 B',
    ]);
    expect(lifecycle.activeUserId, '3');
  });

  test('blank name uses stable localized fallback', () async {
    final gateway = _FakeGateway();
    final lifecycle = CallInvitationLifecycle(gateway);

    await lifecycle.synchronize(userId: '14', userName: '  ');

    expect(gateway.initializedUsers, ['14:使用者 14']);
  });
}

class _FakeGateway implements CallInvitationLifecycleGateway {
  final List<String> initializedUsers = [];
  final List<String> events = [];
  int uninitializeCalls = 0;

  @override
  Future<void> initialize({
    required String userId,
    required String userName,
  }) async {
    initializedUsers.add('$userId:$userName');
    events.add('init:$userId:$userName');
  }

  @override
  Future<void> uninitialize() async {
    uninitializeCalls++;
    events.add('uninit');
  }
}

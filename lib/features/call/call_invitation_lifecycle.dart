abstract interface class CallInvitationLifecycleGateway {
  Future<void> initialize({
    required String userId,
    required String userName,
  });

  Future<void> uninitialize();
}

class CallInvitationLifecycle {
  CallInvitationLifecycle(this._gateway);

  final CallInvitationLifecycleGateway _gateway;

  String? _activeUserId;
  String? _activeUserName;
  Future<void> _operation = Future<void>.value();

  String? get activeUserId => _activeUserId;
  bool get isInitialized => _activeUserId != null;

  Future<void> synchronize({String? userId, String? userName}) {
    final next = _operation.then((_) => _synchronizeNow(
          userId: userId,
          userName: userName,
        ));
    _operation = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return next;
  }

  Future<void> _synchronizeNow({String? userId, String? userName}) async {
    final normalizedId = userId?.trim() ?? '';
    final normalizedName = userName?.trim() ?? '';

    if (normalizedId.isEmpty) {
      if (_activeUserId != null) {
        await _gateway.uninitialize();
        _activeUserId = null;
        _activeUserName = null;
      }
      return;
    }

    final displayName =
        normalizedName.isEmpty ? '使用者 $normalizedId' : normalizedName;
    if (_activeUserId == normalizedId && _activeUserName == displayName) {
      return;
    }

    if (_activeUserId != null) {
      await _gateway.uninitialize();
      _activeUserId = null;
      _activeUserName = null;
    }

    await _gateway.initialize(userId: normalizedId, userName: displayName);
    _activeUserId = normalizedId;
    _activeUserName = displayName;
  }
}

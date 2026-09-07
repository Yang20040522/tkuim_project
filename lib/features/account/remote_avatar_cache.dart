import 'app_session.dart';
import 'remote_user_avatar_repository.dart';
import 'user_avatar_api_client.dart';

/// On-demand, memory-only cache. Failures are cached too, so rebuilding an
/// unavailable avatar never retries the server. Identities never share entries.
class RemoteAvatarCache {
  RemoteAvatarCache({RemoteUserAvatarRepository? repository})
      : _repository = repository ?? RestRemoteUserAvatarRepository();

  static final shared = RemoteAvatarCache();
  final RemoteUserAvatarRepository _repository;
  final Map<String, Future<RemoteUserAvatar?>> _entries = {};
  (String?, String?)? _identity;

  Future<RemoteUserAvatar?> get(String userId) {
    final identity = (AppSession.userId, AppSession.customExerciseToken);
    if (_identity != identity) {
      _entries.clear();
      _identity = identity;
    }
    if ((identity.$1 ?? '').trim().isEmpty ||
        (identity.$2 ?? '').trim().isEmpty) {
      return Future.value(null);
    }
    return _entries.putIfAbsent(userId, () => _load(userId, identity));
  }

  Future<RemoteUserAvatar?> _load(
    String userId,
    (String?, String?) identity,
  ) async {
    try {
      final avatar = await _repository.getUserAvatar(userId);
      if ((AppSession.userId, AppSession.customExerciseToken) != identity) {
        return null;
      }
      return avatar;
    } catch (_) {
      return null;
    }
  }
}

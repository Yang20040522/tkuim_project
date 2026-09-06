import 'user_avatar_api_client.dart';

abstract interface class RemoteUserAvatarRepository {
  Future<void> uploadCurrentUserAvatar(String filePath);

  Future<void> syncGoogleAvatar(String photoUrl);

  Future<RemoteUserAvatar?> getUserAvatar(String userId);
}

class RestRemoteUserAvatarRepository implements RemoteUserAvatarRepository {
  RestRemoteUserAvatarRepository({UserAvatarApiClient? apiClient})
      : _apiClient = apiClient ?? UserAvatarApiClient();

  final UserAvatarApiClient _apiClient;

  @override
  Future<void> uploadCurrentUserAvatar(String filePath) {
    return _apiClient.uploadCurrentUserAvatar(filePath);
  }

  @override
  Future<void> syncGoogleAvatar(String photoUrl) {
    return _apiClient.syncGoogleAvatar(photoUrl);
  }

  @override
  Future<RemoteUserAvatar?> getUserAvatar(String userId) {
    return _apiClient.getUserAvatar(userId);
  }
}

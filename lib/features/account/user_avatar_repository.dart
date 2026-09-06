import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_session.dart';

class UserAvatar {
  const UserAvatar({this.customPath, this.googlePhotoUrl});

  final String? customPath;
  final String? googlePhotoUrl;

  UserAvatarSource get source {
    if (customPath?.isNotEmpty == true) return UserAvatarSource.custom;
    if (googlePhotoUrl?.isNotEmpty == true) return UserAvatarSource.google;
    return UserAvatarSource.initials;
  }
}

enum UserAvatarSource { custom, google, initials }

abstract interface class UserAvatarRepository {
  Future<UserAvatar> load(String ownerKey);

  Future<void> saveGooglePhotoUrl(String ownerKey, String? photoUrl);

  Future<String?> pickAndSaveCustomAvatar(String ownerKey);
}

typedef AvatarPreferencesFactory = Future<SharedPreferences> Function();
typedef AvatarDirectoryProvider = Future<Directory> Function();
typedef AvatarPicker = Future<String?> Function();

class LocalUserAvatarRepository implements UserAvatarRepository {
  LocalUserAvatarRepository({
    AvatarPreferencesFactory? preferencesFactory,
    AvatarDirectoryProvider? directoryProvider,
    AvatarPicker? picker,
  })  : _preferencesFactory =
            preferencesFactory ?? SharedPreferences.getInstance,
        _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory,
        _picker = picker ?? _pickImage;

  final AvatarPreferencesFactory _preferencesFactory;
  final AvatarDirectoryProvider _directoryProvider;
  final AvatarPicker _picker;

  static String? currentOwnerKey() {
    final userId = AppSession.userId?.trim();
    if (userId != null && userId.isNotEmpty) return 'user_$userId';
    final accountId = AppSession.accountId?.trim();
    if (accountId != null && accountId.isNotEmpty) {
      return 'account_${accountId.toLowerCase()}';
    }
    final email = AppSession.email?.trim();
    if (email != null && email.isNotEmpty) {
      return 'email_${email.toLowerCase()}';
    }
    return null;
  }

  @override
  Future<UserAvatar> load(String ownerKey) async {
    final preferences = await _preferencesFactory();
    var customPath = preferences.getString(_customKey(ownerKey));
    if (customPath != null && !await File(customPath).exists()) {
      await preferences.remove(_customKey(ownerKey));
      customPath = null;
    }
    return UserAvatar(
      customPath: customPath,
      googlePhotoUrl: preferences.getString(_googleKey(ownerKey)),
    );
  }

  @override
  Future<void> saveGooglePhotoUrl(String ownerKey, String? photoUrl) async {
    final normalizedUrl = photoUrl?.trim();
    if (normalizedUrl == null || normalizedUrl.isEmpty) return;
    final preferences = await _preferencesFactory();
    await preferences.setString(_googleKey(ownerKey), normalizedUrl);
  }

  @override
  Future<String?> pickAndSaveCustomAvatar(String ownerKey) async {
    final sourcePath = await _picker();
    if (sourcePath == null || sourcePath.trim().isEmpty) return null;
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('選取的圖片不存在');
    }

    final documents = await _directoryProvider();
    final avatarDirectory = Directory(
      '${documents.path}${Platform.pathSeparator}profile_avatars',
    );
    await avatarDirectory.create(recursive: true);
    final encodedOwner =
        base64Url.encode(utf8.encode(ownerKey)).replaceAll('=', '');
    final destination = File(
      '${avatarDirectory.path}${Platform.pathSeparator}'
      'avatar_$encodedOwner${_safeExtension(source.path)}',
    );
    if (source.absolute.path != destination.absolute.path) {
      await source.copy(destination.path);
    }

    final preferences = await _preferencesFactory();
    final previousPath = preferences.getString(_customKey(ownerKey));
    await preferences.setString(_customKey(ownerKey), destination.path);
    if (previousPath != null && previousPath != destination.path) {
      final previous = File(previousPath);
      if (await previous.exists()) await previous.delete();
    }
    return destination.path;
  }

  static Future<String?> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    return result?.files.single.path;
  }

  static String _customKey(String ownerKey) => 'custom_avatar_$ownerKey';

  static String _googleKey(String ownerKey) => 'google_avatar_$ownerKey';

  static String _safeExtension(String path) {
    final fileName = path.split(RegExp(r'[\\/]')).last;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return '.jpg';
    final extension = fileName.substring(dot).toLowerCase();
    return const {'.jpg', '.jpeg', '.png', '.webp'}.contains(extension)
        ? extension
        : '.jpg';
  }
}

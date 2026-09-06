import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/api_config.dart';
import 'app_session.dart';

class RemoteUserAvatar {
  const RemoteUserAvatar({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

class UserAvatarApiFailure implements Exception {
  const UserAvatarApiFailure({
    required this.statusCode,
    required this.message,
    this.code,
  });

  final int statusCode;
  final String message;
  final String? code;

  @override
  String toString() => message;
}

class UserAvatarApiClient {
  UserAvatarApiClient({
    String? baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 90),
  })  : _baseUrl =
            (baseUrl ?? ApiConfig.baseUrl).replaceFirst(RegExp(r'/+$'), ''),
        _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _httpClient;
  final Duration timeout;
  static const int maxAvatarBytes = 5 * 1024 * 1024;

  Future<void> uploadCurrentUserAvatar(String filePath) async {
    final mediaType = _mediaTypeForPath(filePath);
    await _uploadAvatar(
      '/api/account/avatar',
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: 'avatar.${_extensionForMediaType(mediaType)}',
        contentType: MediaType.parse(mediaType),
      ),
    );
  }

  Future<void> syncGoogleAvatar(String photoUrl) async {
    _identityHeaders();
    final uri = Uri.tryParse(photoUrl.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const UserAvatarApiFailure(
        statusCode: 400,
        code: 'INVALID_GOOGLE_AVATAR_URL',
        message: 'Google 頭像網址無效',
      );
    }

    final downloadRequest = http.Request('GET', uri)
      ..followRedirects = false
      ..headers['Accept'] = 'image/jpeg, image/png, image/webp';
    final download = await _httpClient.send(downloadRequest).timeout(timeout);
    if (download.statusCode < 200 || download.statusCode >= 300) {
      await download.stream.drain<void>();
      throw const UserAvatarApiFailure(
        statusCode: 502,
        code: 'GOOGLE_AVATAR_DOWNLOAD_FAILED',
        message: '無法下載 Google 頭像',
      );
    }
    final declaredLength = download.contentLength;
    if (declaredLength != null && declaredLength > maxAvatarBytes) {
      await download.stream.drain<void>();
      throw const UserAvatarApiFailure(
        statusCode: 413,
        code: 'AVATAR_TOO_LARGE',
        message: '頭像不可超過 5 MB',
      );
    }
    final contentType =
        download.headers['content-type']?.split(';').first.trim().toLowerCase();
    if (contentType == null || !_allowedMediaTypes.contains(contentType)) {
      await download.stream.drain<void>();
      throw const UserAvatarApiFailure(
        statusCode: 415,
        code: 'UNSUPPORTED_AVATAR_TYPE',
        message: 'Google 頭像格式不受支援',
      );
    }

    final bytes = await _readAvatarBytes(download.stream);
    if (bytes.isEmpty) {
      throw const UserAvatarApiFailure(
        statusCode: 400,
        code: 'AVATAR_EMPTY',
        message: 'Google 頭像內容為空',
      );
    }
    await _uploadAvatar(
      '/api/account/avatar/google',
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'google-avatar.${_extensionForMediaType(contentType)}',
        contentType: MediaType.parse(contentType),
      ),
    );
  }

  Future<void> _uploadAvatar(
    String path,
    http.MultipartFile file,
  ) async {
    final request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl$path'));
    request.headers.addAll(_identityHeaders());
    request.files.add(file);

    final response = await _httpClient.send(request).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw await _parseFailure(response);
    }
    await response.stream.drain<void>();
  }

  Future<Uint8List> _readAvatarBytes(
    Stream<List<int>> stream,
  ) async {
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in stream) {
      length += chunk.length;
      if (length > maxAvatarBytes) {
        throw const UserAvatarApiFailure(
          statusCode: 413,
          code: 'AVATAR_TOO_LARGE',
          message: '頭像不可超過 5 MB',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<RemoteUserAvatar?> getUserAvatar(String userId) async {
    final targetUserId = userId.trim();
    if (targetUserId.isEmpty) {
      throw const UserAvatarApiFailure(
        statusCode: 400,
        code: 'INVALID_TARGET_USER',
        message: '使用者 ID 不可為空',
      );
    }
    final response = await _httpClient
        .get(
          Uri.parse(
            '$_baseUrl/api/users/${Uri.encodeComponent(targetUserId)}/avatar',
          ),
          headers: _identityHeaders(),
        )
        .timeout(timeout);
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _parseResponseFailure(response);
    }
    final contentType =
        response.headers['content-type']?.split(';').first.trim().toLowerCase();
    if (contentType == null || !_allowedMediaTypes.contains(contentType)) {
      throw const UserAvatarApiFailure(
        statusCode: 502,
        code: 'INVALID_AVATAR_RESPONSE',
        message: '伺服器回傳的頭像格式無效',
      );
    }
    return RemoteUserAvatar(
      bytes: response.bodyBytes,
      contentType: contentType,
    );
  }

  Map<String, String> _identityHeaders() {
    final userId = AppSession.userId?.trim();
    final token = AppSession.customExerciseToken?.trim();
    if (userId == null || userId.isEmpty || token == null || token.isEmpty) {
      throw const UserAvatarApiFailure(
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: '登入狀態已失效，請重新登入',
      );
    }
    return {
      'Accept': 'application/json',
      'X-User-Id': userId,
      'X-Custom-Exercise-Token': token,
    };
  }

  String _mediaTypeForPath(String path) {
    final normalized = path.toLowerCase();
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.webp')) return 'image/webp';
    throw const UserAvatarApiFailure(
      statusCode: 415,
      code: 'UNSUPPORTED_AVATAR_TYPE',
      message: '只接受 JPEG、PNG 或 WEBP 圖片',
    );
  }

  String _extensionForMediaType(String mediaType) {
    return switch (mediaType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }

  Future<UserAvatarApiFailure> _parseFailure(
    http.StreamedResponse response,
  ) async {
    final bytes = await response.stream.toBytes();
    return _failureFromBytes(response.statusCode, bytes);
  }

  UserAvatarApiFailure _parseResponseFailure(http.Response response) {
    return _failureFromBytes(response.statusCode, response.bodyBytes);
  }

  UserAvatarApiFailure _failureFromBytes(int statusCode, List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);
        return UserAvatarApiFailure(
          statusCode: statusCode,
          code: data['code']?.toString(),
          message: data['message']?.toString() ?? _defaultError(statusCode),
        );
      }
    } catch (_) {
      // Raw provider/server content is intentionally not exposed to the UI.
    }
    return UserAvatarApiFailure(
      statusCode: statusCode,
      message: _defaultError(statusCode),
    );
  }

  String _defaultError(int statusCode) {
    if (statusCode == 401) return '登入狀態已失效，請重新登入';
    if (statusCode == 403) return '沒有權限存取此使用者的頭像';
    if (statusCode == 413) return '頭像不可超過 5 MB';
    if (statusCode == 415) return '只接受 JPEG、PNG 或 WEBP 圖片';
    return '頭像服務暫時無法使用，請稍後再試';
  }

  static const Set<String> _allowedMediaTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };
}

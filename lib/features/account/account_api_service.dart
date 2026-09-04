import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import 'api_service.dart';
import 'app_session.dart';
import 'auth_service.dart';

class AccountInfo {
  const AccountInfo({
    required this.userId,
    required this.name,
    required this.email,
    required this.accountId,
    required this.role,
    required this.bindingCode,
    required this.friendCode,
    required this.googleLinked,
    required this.googleEmail,
    required this.hasPassword,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    return AccountInfo(
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      accountId: _nullableString(json['accountId']),
      role: json['role']?.toString() ?? '',
      bindingCode: _nullableString(json['bindingCode']),
      friendCode: _nullableString(json['friendCode']),
      googleLinked: json['googleLinked'] == true,
      googleEmail: _nullableString(json['googleEmail']),
      hasPassword: json['hasPassword'] == true,
    );
  }

  final String userId;
  final String name;
  final String email;
  final String? accountId;
  final String role;
  final String? bindingCode;
  final String? friendCode;
  final bool googleLinked;
  final String? googleEmail;
  final bool hasPassword;

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class AccountApiClient {
  AccountApiClient({
    String? baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 90),
  })  : _baseUrl =
            (baseUrl ?? ApiConfig.baseUrl).replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  final Duration timeout;

  Future<AccountInfo> getAccountInfo() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/api/account/me'), headers: _headers())
        .timeout(timeout);
    return _parseAccountInfo(response);
  }

  Future<AccountInfo> updateAccountId(String accountId) async {
    final response = await _client
        .put(
          Uri.parse('$_baseUrl/api/account/account-id'),
          headers: _headers(),
          body: jsonEncode({'accountId': accountId}),
        )
        .timeout(timeout);
    return _parseAccountInfo(response);
  }

  Future<AccountInfo> updatePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    final response = await _client
        .put(
          Uri.parse('$_baseUrl/api/account/password'),
          headers: _headers(),
          body: jsonEncode({
            'currentPassword': currentPassword,
            'newPassword': newPassword,
          }),
        )
        .timeout(timeout);
    return _parseAccountInfo(response);
  }

  Future<LoginResult> linkGoogle(String idToken) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/api/account/google/link'),
          headers: _headers(),
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(timeout);
    return LoginResult.fromResponse(_parseJsonResponse(response));
  }

  Future<void> deleteAccount({String? currentPassword, String? idToken}) async {
    final response = await _client
        .delete(
          Uri.parse('$_baseUrl/api/account/me'),
          headers: _headers(),
          body: jsonEncode({
            'currentPassword': currentPassword,
            'idToken': idToken,
          }),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _parseFailure(response);
    }
  }

  Map<String, String> _headers() {
    final userId = AppSession.userId?.trim();
    final token = AppSession.customExerciseToken?.trim();
    if (userId == null || userId.isEmpty || token == null || token.isEmpty) {
      throw const AuthApiFailure(
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: '登入狀態已失效，請重新登入',
      );
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'X-User-Id': userId,
      'X-Custom-Exercise-Token': token,
    };
  }

  AccountInfo _parseAccountInfo(http.Response response) =>
      AccountInfo.fromJson(_parseJsonResponse(response));

  Map<String, dynamic> _parseJsonResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _parseFailure(response);
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Converted to a safe UI error below.
    }
    throw AuthApiFailure(
      statusCode: response.statusCode,
      message: '伺服器回傳格式錯誤，請稍後再試',
    );
  }

  AuthApiFailure _parseFailure(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);
        return AuthApiFailure(
          statusCode: response.statusCode,
          code: data['code']?.toString(),
          message: data['message']?.toString() ?? '帳號操作失敗，請稍後再試',
        );
      }
    } catch (_) {
      // Do not expose raw transport responses.
    }
    return AuthApiFailure(
      statusCode: response.statusCode,
      message: '帳號操作失敗，請稍後再試',
    );
  }
}

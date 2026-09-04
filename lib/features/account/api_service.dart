import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  static final AuthApiClient _client = AuthApiClient(baseUrl: baseUrl);

  static Future<String> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return _client.register(
      name: name,
      email: email,
      password: password,
    );
  }

  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    return _client.login(
      identifier: identifier,
      password: password,
    );
  }

  static Future<Map<String, dynamic>> googleLogin({
    required String idToken,
  }) {
    return _client.googleLogin(idToken: idToken);
  }

  static Future<Map<String, dynamic>> linkGoogle({
    required String idToken,
    required String currentPassword,
  }) {
    return _client.linkGoogle(
      idToken: idToken,
      currentPassword: currentPassword,
    );
  }
}

class AuthApiClient {
  AuthApiClient({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 90),
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  final Duration timeout;

  static const _headers = <String, String>{
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };

  Future<String> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/api/auth/register'),
          headers: _headers,
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
          }),
        )
        .timeout(timeout);
    final responseText = utf8.decode(response.bodyBytes);
    if (!_isSuccess(response.statusCode)) {
      throw _parseFailure(response.statusCode, responseText);
    }
    if (responseText.trim() != '註冊成功') {
      throw AuthApiFailure(
        statusCode: response.statusCode,
        message: '註冊失敗，請稍後再試',
      );
    }
    return responseText;
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) {
    return _postAuth(
      '/api/auth/login',
      {
        'identifier': identifier,
        // Backward compatibility during a rolling backend deployment.
        'email': identifier,
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>> googleLogin({required String idToken}) {
    return _postAuth('/api/auth/google', {'idToken': idToken});
  }

  Future<Map<String, dynamic>> linkGoogle({
    required String idToken,
    required String currentPassword,
  }) {
    return _postAuth(
      '/api/auth/google/link',
      {'idToken': idToken, 'currentPassword': currentPassword},
    );
  }

  Future<Map<String, dynamic>> _postAuth(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(timeout);

    final responseText = utf8.decode(response.bodyBytes);
    if (!_isSuccess(response.statusCode)) {
      throw _parseFailure(response.statusCode, responseText);
    }

    try {
      final dynamic decoded = jsonDecode(responseText);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Converted below to a safe user-facing failure.
    }
    throw AuthApiFailure(
      statusCode: response.statusCode,
      message: '伺服器回傳格式錯誤，請稍後再試',
    );
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  AuthApiFailure _parseFailure(int statusCode, String responseText) {
    try {
      final dynamic decoded = jsonDecode(responseText);
      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);
        return AuthApiFailure(
          statusCode: statusCode,
          code: data['code']?.toString(),
          message: data['message']?.toString() ?? '登入失敗，請稍後再試',
        );
      }
    } catch (_) {
      // Legacy backend errors are plain Traditional Chinese text.
    }
    final safeMessage = responseText.trim();
    return AuthApiFailure(
      statusCode: statusCode,
      message: safeMessage.isEmpty ? '登入失敗，請稍後再試' : safeMessage,
    );
  }
}

class AuthApiFailure implements Exception {
  const AuthApiFailure({
    required this.statusCode,
    required this.message,
    this.code,
  });

  final int statusCode;
  final String? code;
  final String message;

  @override
  String toString() => message;
}

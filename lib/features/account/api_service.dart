import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'https://trianing-system.onrender.com';

  static Future<String> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    ).timeout(
      const Duration(seconds: 90),
    );

    final responseText = utf8.decode(response.bodyBytes);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        '註冊失敗：${response.statusCode}\n$responseText',
      );
    }

    if (responseText.trim() != '註冊成功') {
      throw Exception(responseText);
    }

    return responseText;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    ).timeout(
      const Duration(seconds: 90),
    );

    final responseText = utf8.decode(response.bodyBytes);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        '登入失敗：${response.statusCode}\n$responseText',
      );
    }

    try {
      final dynamic decoded = jsonDecode(responseText);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // 後端登入失敗時會回傳一般文字。
    }

    throw Exception(responseText);
  }
}
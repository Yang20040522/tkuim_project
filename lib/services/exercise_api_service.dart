import 'dart:convert';

import 'package:http/http.dart' as http;

class ExerciseApiService {
  // Flutter Windows 使用 localhost。
  static const String baseUrl =
    'https://trianing-system.onrender.com';
  /// 取得復健動作清單
  static Future<List<Map<String, dynamic>>> fetchExercises() async {
    final uri = Uri.parse(
      '$baseUrl/api/exercise/list',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
      },
    ).timeout(
      const Duration(seconds: 90),
    );

    final responseText = utf8.decode(
      response.bodyBytes,
    );

    if (response.statusCode != 200) {
      throw Exception(
        '取得動作失敗：${response.statusCode}\n'
        '$responseText',
      );
    }

    final List<dynamic> data = jsonDecode(
      responseText,
    );

    return data
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  /// 儲存訓練結果
  static Future<Map<String, dynamic>> saveResult({
    required int userId,
    required int exerciseId,
    required int repCount,
    required double accuracy,
    required double progress,
    required String speedState,
    required bool isComplete,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/exercise/result',
    );

    final requestBody = {
      'userId': userId,
      'exerciseId': exerciseId,
      'repCount': repCount,
      'accuracy': accuracy,
      'progress': progress,
      'speedState': speedState,
      'isComplete': isComplete,
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(requestBody),
    ).timeout(
      const Duration(seconds: 90),
    );

    final responseText = utf8.decode(
      response.bodyBytes,
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        '儲存訓練結果失敗：${response.statusCode}\n'
        '$responseText',
      );
    }

    final dynamic decoded = jsonDecode(responseText);

    return Map<String, dynamic>.from(
      decoded as Map,
    );
  }

  /// 取得指定使用者的訓練紀錄
  static Future<List<Map<String, dynamic>>> fetchHistory({
    required int userId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/exercise/history/$userId',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
      },
    ).timeout(
      const Duration(seconds: 90),
    );

    final responseText = utf8.decode(
      response.bodyBytes,
    );

    if (response.statusCode != 200) {
      throw Exception(
        '取得訓練紀錄失敗：${response.statusCode}\n'
        '$responseText',
      );
    }

    final List<dynamic> data = jsonDecode(
      responseText,
    );

    return data
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  /// 取得指定使用者的統計報告
  static Future<Map<String, dynamic>> fetchReport({
    required int userId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/exercise/report/$userId',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
      },
    ).timeout(
      const Duration(seconds: 90),
    );

    final responseText = utf8.decode(
      response.bodyBytes,
    );

    if (response.statusCode != 200) {
      throw Exception(
        '取得訓練報告失敗：${response.statusCode}\n'
        '$responseText',
      );
    }

    final dynamic decoded = jsonDecode(responseText);

    return Map<String, dynamic>.from(
      decoded as Map,
    );
  }
}
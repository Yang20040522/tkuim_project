import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';

class ExerciseApiService {
  // Flutter Windows 使用 localhost。
  static const String baseUrl =
    'https://trianing-system.onrender.com';

  // 🆕 自由訓練歷史紀錄（/api/training-history）用的後端網址。
  //    刻意改用 ApiConfig.baseUrl（跟能正常運作的「姿勢訓練紀錄」同一台），
  //    避免上面那個舊 baseUrl 跟 ApiConfig 指到不同部署造成「傳到 A、讀不到」。
  static const String _historyBaseUrl = ApiConfig.baseUrl;
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

  // 🆕 ═══════════════════════════════════════════════════════════
  //  自由訓練歷史紀錄（訓練進步曲線）—— 對接 /api/training-history
  // ═══════════════════════════════════════════════════════════════

  /// 上傳單筆自由訓練紀錄到後端。
  ///
  /// 欄位直接對齊 TrainingRecord，後端用 (userId, clientTimestamp) 做冪等
  /// upsert，所以同一筆重複上傳不會在資料庫產生重複列。
  static Future<Map<String, dynamic>> uploadTrainingHistory({
    required int userId,
    required String clientTimestamp,
    required String actionName,
    required int difficulty,
    required int durationSeconds,
    required int targetReps,
    required List<String> mistakeLogs,
  }) async {
    final uri = Uri.parse(
      '$_historyBaseUrl/api/training-history',
    );

    final requestBody = {
      'userId': userId,
      'clientTimestamp': clientTimestamp,
      'actionName': actionName,
      'difficulty': difficulty,
      'durationSeconds': durationSeconds,
      'targetReps': targetReps,
      'mistakeLogs': mistakeLogs,
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
        '上傳訓練紀錄失敗：${response.statusCode}\n'
        '$responseText',
      );
    }

    final dynamic decoded = jsonDecode(responseText);

    return Map<String, dynamic>.from(
      decoded as Map,
    );
  }

  /// 取得某使用者在後端的自由訓練紀錄（新到舊)。
  ///
  /// 回傳的每一筆欄位已對齊 TrainingRecord.toJson()，
  /// 呼叫端可以直接用 TrainingRecord.fromJson() 解析。
  static Future<List<Map<String, dynamic>>> fetchTrainingHistory({
    required int userId,
  }) async {
    final uri = Uri.parse(
      '$_historyBaseUrl/api/training-history/$userId',
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
        '取得雲端訓練紀錄失敗：${response.statusCode}\n'
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
}
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/api_config.dart';

class ExerciseApiService {
  // Flutter Windows 使用 localhost。
  static const String baseUrl =
      'https://trianing-system.onrender.com';

  // 自由訓練歷史紀錄使用 ApiConfig.baseUrl。
  static const String _historyBaseUrl =
      ApiConfig.baseUrl;

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

    final dynamic decoded =
        jsonDecode(responseText);

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

    final dynamic decoded =
        jsonDecode(responseText);

    return Map<String, dynamic>.from(
      decoded as Map,
    );
  }

  // ═════════════════════════════════════════════════════════════
  // 自由訓練歷史紀錄
  // ═════════════════════════════════════════════════════════════

  /// 上傳單筆自由訓練 metadata。
  ///
  /// sessionId：
  /// - auto:xxxx   = 同一次自動升級訓練
  /// - manual:xxxx = 手動升級／單獨紀錄
  static Future<Map<String, dynamic>> uploadTrainingHistory({
    required int userId,
    required String clientTimestamp,
    required String actionName,
    required int difficulty,
    required int durationSeconds,
    required int completedReps,
    required int targetReps,
    required List<String> mistakeLogs,
    String? sessionId,
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
      'completedReps': completedReps,
      'targetReps': targetReps,
      'mistakeLogs': mistakeLogs,
      'sessionId': sessionId,
    };

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type':
                'application/json; charset=UTF-8',
            'Accept': 'application/json',
          },
          body: jsonEncode(requestBody),
        )
        .timeout(
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

    final dynamic decoded =
        jsonDecode(responseText);

    return Map<String, dynamic>.from(
      decoded as Map,
    );
  }

  /// 將手機上的真正影片檔案以 multipart binary 上傳。
  static Future<void> uploadTrainingHistoryVideo({
    required int historyId,
    required int userId,
    required String videoPath,
  }) async {
    final uri = Uri.parse(
      '$_historyBaseUrl/api/training-history/$historyId/video',
    );

    final fileName =
        videoPath.split(RegExp(r'[/\\]')).last;

    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    final contentType = switch (extension) {
      'mov' => MediaType('video', 'quicktime'),
      'webm' => MediaType('video', 'webm'),
      'm4v' => MediaType('video', 'x-m4v'),
      _ => MediaType('video', 'mp4'),
    };

    final request =
        http.MultipartRequest('POST', uri)
          ..fields['userId'] = '$userId'
          ..files.add(
            await http.MultipartFile.fromPath(
              'file',
              videoPath,
              filename: fileName,
              contentType: contentType,
            ),
          );

    final streamed = await request.send().timeout(
          const Duration(minutes: 3),
        );

    final response =
        await http.Response.fromStream(streamed);

    final responseText =
        utf8.decode(response.bodyBytes);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        '上傳訓練影片失敗：${response.statusCode}\n'
        '$responseText',
      );
    }
  }

  /// 取得某使用者在後端的自由訓練紀錄（新到舊）。
  static Future<List<Map<String, dynamic>>> fetchTrainingHistory({
    required int userId,
    int? requesterUserId,
    String? identityToken,
  }) async {
    final uri = Uri.parse(
      '$_historyBaseUrl/api/training-history/$userId',
    );

    final headers = <String, String>{
      'Accept': 'application/json',
      if (requesterUserId != null)
        'X-User-Id': '$requesterUserId',
      if (identityToken != null &&
          identityToken.trim().isNotEmpty)
        'X-Custom-Exercise-Token':
            identityToken.trim(),
    };

    final response = await http
        .get(
          uri,
          headers: headers,
        )
        .timeout(
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

    final List<dynamic> data =
        jsonDecode(responseText);

    return data.map((item) {
      final row =
          Map<String, dynamic>.from(item);

      final rawVideoUrl =
          row['videoUrl']?.toString();

      if (rawVideoUrl != null &&
          rawVideoUrl.isNotEmpty) {
        row['videoUrl'] =
            Uri.parse(_historyBaseUrl)
                .resolve(rawVideoUrl)
                .toString();
      }

      return row;
    }).toList();
  }
}

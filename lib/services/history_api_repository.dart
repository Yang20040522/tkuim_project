// lib/services/history_api_repository.dart
//
// 真正連接後端資料庫的 HistoryRepository 實作。
// API 規格對照文件: history_api_spec.md(給後端組員參考實作用)
//
// 使用方式:
//   之前 history_repository.dart 最下面是:
//     final HistoryRepository historyRepository = LocalHistoryRepository();
//   等後端把對應的 API 做好之後,把上面那行換成:
//     final HistoryRepository historyRepository = HistoryApiRepository();
//
// 目前後端尚未提供這組 API,在後端做好之前,呼叫這裡的方法會直接連線失敗
// (拋出例外),屬於正常現象,不是程式寫錯。

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/training_action.dart';
import 'history_repository.dart';

class HistoryApiRepository implements HistoryRepository {
  static String get _baseUrl => ApiConfig.baseUrl;

  /// 取得使用者所有訓練紀錄(原始列表,不做任何統計)。
  /// 前端(stats_calculator.dart)拿到這份原始列表後,自己算雷達圖/徽章/週摘要。
  /// 對應後端: GET /api/records
  @override
  Future<List<TrainingRecord>> getHistory() async {
    final uri = Uri.parse('$_baseUrl/api/records');

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('取得訓練紀錄失敗(狀態碼 ${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((e) => TrainingRecord.fromJson(e)).toList();
  }

  /// 新增一筆訓練紀錄。
  /// 對應後端: POST /api/records
  @override
  Future<void> saveRecord(TrainingRecord record) async {
    final uri = Uri.parse('$_baseUrl/api/records');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(record.toJson()),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('儲存訓練紀錄失敗(狀態碼 ${response.statusCode})');
    }
  }

  /// 把「最後 count 筆」紀錄的 videoPath 更新成同一個值。
  ///
  /// 因為後端是用 timestamp 當作紀錄的識別方式,這裡會先向後端拿一次
  /// 最新的紀錄列表,在本地端算出「最後 count 筆」對應的 timestamp,
  /// 再把這些明確的 timestamp 一起送給後端做批次更新,
  /// 避免「最後幾筆」這種模糊的說法在後端造成認知落差。
  /// 對應後端: PATCH /api/records/video-path
  ///   body: { "timestamps": ["...", "..."], "videoPath": "..." }
  @override
  Future<void> updateLastRecordsVideoPath(
      int count, String? videoPath) async {
    if (count <= 0) return;

    final history = await getHistory();
    if (history.isEmpty) return;

    final updateCount = count > history.length ? history.length : count;
    final startIndex = history.length - updateCount;
    final timestamps =
        history.sublist(startIndex).map((r) => r.timestamp).toList();

    final uri = Uri.parse('$_baseUrl/api/records/video-path');

    final response = await http
        .patch(
          uri,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({
            'timestamps': timestamps,
            'videoPath': videoPath,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('更新錄影路徑失敗(狀態碼 ${response.statusCode})');
    }
  }

  /// 刪除單一筆訓練紀錄。
  /// 對應後端: DELETE /api/records/{timestamp}
  /// timestamp 含冒號等特殊字元,用 Uri.encodeComponent 避免路徑解析錯誤
  @override
  Future<void> removeByTimestamp(String timestamp) async {
    final uri = Uri.parse(
      '$_baseUrl/api/records/${Uri.encodeComponent(timestamp)}',
    );

    final response =
        await http.delete(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('刪除訓練紀錄失敗(狀態碼 ${response.statusCode})');
    }
  }

  /// 清空使用者所有訓練紀錄。
  /// 對應後端: DELETE /api/records
  @override
  Future<void> clearHistory() async {
    final uri = Uri.parse('$_baseUrl/api/records');

    final response =
        await http.delete(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('清空訓練紀錄失敗(狀態碼 ${response.statusCode})');
    }
  }
}
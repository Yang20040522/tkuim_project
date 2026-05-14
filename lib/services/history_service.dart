import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training_action.dart';

class HistoryService {
  static const String _key = 'rehab_history';

  Future<List<TrainingRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key) ?? '[]';
    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((e) => TrainingRecord.fromJson(e)).toList();
  }

  Future<void> saveRecord(TrainingRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.add(record);
    await prefs.setString(_key, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
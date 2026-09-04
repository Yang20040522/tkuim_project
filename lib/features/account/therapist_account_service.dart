// lib/features/account/therapist_account_service.dart
//
// 治療端專用帳號服務(空殼,尚未接後端)。
// 完全獨立於病人端的 AuthService/ApiService,不打任何網路請求,
// 帳號資料存在本機 SharedPreferences,單純用來讓治療端的
// 註冊/登入畫面先能跑起來、有基本的帳密驗證流程。
//
// ⚠️ 之後要接治療師專屬後端時,把這個檔案裡的邏輯換成呼叫真正的
// API 即可,上層畫面(therapist_register_screen.dart / 
// therapist_login_screen.dart)不需要跟著大改。

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TherapistAccountService {
  static const _kAccountsKey = 'therapist_local_accounts'; // 存一個 JSON list

  String _simpleHash(String input) {
    final bytes = utf8.encode(input);
    int hash = 0;
    for (final b in bytes) {
      hash = (hash * 31 + b) & 0x7FFFFFFF;
    }
    return hash.toString();
  }

  Future<List<Map<String, dynamic>>> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kAccountsKey) ?? '[]';
    final List<dynamic> list = jsonDecode(jsonStr);
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> _saveAccounts(List<Map<String, dynamic>> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccountsKey, jsonEncode(accounts));
  }

  /// 註冊:email 不能重複。成功回傳 null,失敗回傳錯誤訊息。
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final accounts = await _loadAccounts();
    final exists = accounts.any((a) => a['email'] == email);
    if (exists) return '這個 Email 已經註冊過了';

    accounts.add({
      'name': name,
      'email': email,
      'passwordHash': _simpleHash(password),
    });
    await _saveAccounts(accounts);
    return null;
  }

  /// 登入:成功回傳帳號資料,失敗回傳 null。
  Future<Map<String, String>?> login({
    required String email,
    required String password,
  }) async {
    final accounts = await _loadAccounts();
    final hash = _simpleHash(password);
    final match = accounts.where(
      (a) => a['email'] == email && a['passwordHash'] == hash,
    );
    if (match.isEmpty) return null;

    final a = match.first;
    return {
      'name': a['name'] as String,
      'email': a['email'] as String,
    };
  }
}
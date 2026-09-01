// lib/features/account/account_profile_service.dart
//
// 個人資訊(生日/年齡/密碼狀態)本機儲存服務。
//
// ⚠️ 重要提醒:這裡的「密碼」目前只是本機占位機制,
// 不是真正的帳號認證系統。存的是一個簡單雜湊值,單純用來
// 讓 UI 上可以顯示「已設定密碼」跟提供「變更密碼」的操作流程,
// 沒有串接任何後端驗證。等之後接上真正的登入/帳號後端 API 時,
// 這裡要整個替換成呼叫後端(舊密碼驗證、新密碼送到後端更新等),
// 不能只靠本機儲存的雜湊值當作正式的密碼驗證機制。

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AccountProfileService {
  static const _kBirthdayKey = 'account_birthday'; // 存 ISO8601 字串
  static const _kPasswordHashKey = 'account_password_hash';

  // ── 生日 / 年齡 ──

  Future<DateTime?> getBirthday() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_kBirthdayKey);
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  Future<void> setBirthday(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBirthdayKey, date.toIso8601String());
  }

  /// 依生日算出目前實歲,沒有生日資料時回傳 null。
  int? calculateAge(DateTime? birthday) {
    if (birthday == null) return null;
    final now = DateTime.now();
    int age = now.year - birthday.year;
    final hasHadBirthdayThisYear = (now.month > birthday.month) ||
        (now.month == birthday.month && now.day >= birthday.day);
    if (!hasHadBirthdayThisYear) age--;
    return age;
  }

  // ── 密碼狀態(本機占位,見檔案開頭說明)──

  Future<bool> hasPasswordSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPasswordHashKey) != null;
  }

  /// 簡易本機雜湊,不是正式加密強度,只用來做本機占位比對。
  String _simpleHash(String input) {
    final bytes = utf8.encode(input);
    int hash = 0;
    for (final b in bytes) {
      hash = (hash * 31 + b) & 0x7FFFFFFF;
    }
    return hash.toString();
  }

  Future<void> setPassword(String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPasswordHashKey, _simpleHash(newPassword));
  }

  /// 目前只用來做「本機曾經設過的密碼」比對,並非正式登入驗證。
  Future<bool> verifyPassword(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kPasswordHashKey);
    if (stored == null) return false;
    return stored == _simpleHash(input);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBirthdayKey);
    await prefs.remove(_kPasswordHashKey);
  }
}
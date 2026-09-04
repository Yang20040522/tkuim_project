import 'package:shared_preferences/shared_preferences.dart';

import 'account_api_service.dart';
import 'auth_service.dart';

class AccountProfileService {
  AccountProfileService({AccountApiClient? apiClient})
      : _apiClient = apiClient ?? AccountApiClient();

  static const _birthdayKey = 'account_birthday';
  static const _legacyPasswordHashKey = 'account_password_hash';
  final AccountApiClient _apiClient;

  Future<AccountInfo> getAccountInfo() => _apiClient.getAccountInfo();

  Future<AccountInfo> updateAccountId(String accountId) =>
      _apiClient.updateAccountId(accountId);

  Future<AccountInfo> updatePassword({
    String? currentPassword,
    required String newPassword,
  }) =>
      _apiClient.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  Future<LoginResult> linkGoogle(String idToken) =>
      _apiClient.linkGoogle(idToken);

  Future<void> deleteAccount({String? currentPassword, String? idToken}) =>
      _apiClient.deleteAccount(
        currentPassword: currentPassword,
        idToken: idToken,
      );

  Future<DateTime?> getBirthday() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_birthdayKey);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<void> setBirthday(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_birthdayKey, date.toIso8601String());
  }

  int? calculateAge(DateTime? birthday) {
    if (birthday == null) return null;
    final now = DateTime.now();
    var age = now.year - birthday.year;
    final hadBirthday = now.month > birthday.month ||
        (now.month == birthday.month && now.day >= birthday.day);
    if (!hadBirthday) age--;
    return age;
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_birthdayKey);
    await prefs.remove(_legacyPasswordHashKey);
  }
}

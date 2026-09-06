// lib/features/account/app_session.dart
// 目前的登入狀態。登入時寫入記憶體 + 本機儲存(shared_preferences),
// 這樣下次開 App 時可以讀回來,不用每次都重新選身分、重新登入。
import 'package:shared_preferences/shared_preferences.dart';
import 'user_role.dart';

class AppSession {
  static UserRole? role;
  static String? userId;
  static String? name;
  static String? email;
  static String? accountId;
  static String? bindingCode;
  static String? friendCode;
  static String? customExerciseToken;

  static bool get isLoggedIn => userId != null || email != null;

  static const _keyRole = 'session_role';
  static const _keyUserId = 'session_userId';
  static const _keyName = 'session_name';
  static const _keyEmail = 'session_email';
  static const _keyAccountId = 'session_accountId';
  static const _keyBindingCode = 'session_bindingCode';
  static const _keyFriendCode = 'session_friendCode';
  static const _keyCustomExerciseToken = 'session_customExerciseToken';

  /// App 啟動時呼叫一次,把上次登入狀態從本機讀回記憶體。
  /// 沒有登入過的話,所有欄位維持 null,不會有任何影響。
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final roleName = prefs.getString(_keyRole);

    if (roleName != null) {
      role = UserRole.values.firstWhere(
        (r) => r.name == roleName,
        orElse: () => UserRole.patient,
      );
    }
    userId = prefs.getString(_keyUserId);
    name = prefs.getString(_keyName);
    email = prefs.getString(_keyEmail);
    accountId = prefs.getString(_keyAccountId);
    bindingCode = prefs.getString(_keyBindingCode);
    friendCode = prefs.getString(_keyFriendCode);
    customExerciseToken = prefs.getString(_keyCustomExerciseToken);
  }

  /// 登入成功時呼叫,同時寫進記憶體跟本機儲存。
  static Future<void> save({
    required UserRole role,
    String? userId,
    String? name,
    String? email,
    String? accountId,
    String? bindingCode,
    String? friendCode,
    String? customExerciseToken,
  }) async {
    AppSession.role = role;
    AppSession.userId = userId;
    AppSession.name = name;
    AppSession.email = email;
    AppSession.accountId = accountId;
    AppSession.bindingCode = bindingCode;
    AppSession.friendCode = friendCode;
    AppSession.customExerciseToken = customExerciseToken;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRole, role.name);
    if (userId != null) await prefs.setString(_keyUserId, userId);
    if (name != null) await prefs.setString(_keyName, name);
    if (email != null) await prefs.setString(_keyEmail, email);
    if (accountId != null) {
      await prefs.setString(_keyAccountId, accountId);
    } else {
      await prefs.remove(_keyAccountId);
    }
    if (bindingCode != null) {
      await prefs.setString(_keyBindingCode, bindingCode);
    } else {
      await prefs.remove(_keyBindingCode);
    }
    if (friendCode != null) {
      await prefs.setString(_keyFriendCode, friendCode);
    } else {
      await prefs.remove(_keyFriendCode);
    }
    if (customExerciseToken != null) {
      await prefs.setString(_keyCustomExerciseToken, customExerciseToken);
    } else {
      await prefs.remove(_keyCustomExerciseToken);
    }
  }

  /// 登出時呼叫,同時清掉記憶體跟本機儲存。
  static Future<void> clear() async {
    role = null;
    userId = null;
    name = null;
    email = null;
    accountId = null;
    bindingCode = null;
    friendCode = null;
    customExerciseToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRole);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyAccountId);
    await prefs.remove(_keyBindingCode);
    await prefs.remove(_keyFriendCode);
    await prefs.remove(_keyCustomExerciseToken);
  }
}

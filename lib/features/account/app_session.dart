// lib/features/account/app_session.dart
//
// 目前的登入狀態。
// 登入時寫入記憶體 + shared_preferences。
// App 開啟時只讀本機登入資料，不再讓 ZEGO 初始化阻塞 Splash 畫面。
//
// 2026-09-09 修正：
// 原本 AppSession.load() 最後會 await ZEGO synchronizeSession()。
// ZEGO 若正在初始化推播 / 網路 / ZIM，SplashScreen 就會一直等它，
// 看起來像「開 App 卡住」。
// 現在改成：
//   1. 本機 Session 讀完立即返回。
//   2. ZEGO 延後在背景同步。
//   3. ZEGO 最多等 6 秒，失敗不影響 App 主流程。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../call/zego_call_invitation_service.dart';
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

  // 避免短時間內 load/save 連續觸發很多次 ZEGO 初始化。
  static Timer? _zegoSyncTimer;

  /// App 啟動時呼叫一次，把上次登入狀態從本機讀回記憶體。
  ///
  /// 重要：
  /// 這裡只做 SharedPreferences。
  /// 不等待 ZEGO，避免 Splash 被第三方 SDK 卡住。
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

    // 不 await。
    // 讓 SplashScreen 可以立即繼續跑。
    _scheduleZegoSync(
      userId: userId,
      userName: name,
      delay: const Duration(seconds: 3),
    );
  }

  /// 登入成功時呼叫，同時寫進記憶體跟本機儲存。
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

    if (userId != null) {
      await prefs.setString(_keyUserId, userId);
    } else {
      await prefs.remove(_keyUserId);
    }

    if (name != null) {
      await prefs.setString(_keyName, name);
    } else {
      await prefs.remove(_keyName);
    }

    if (email != null) {
      await prefs.setString(_keyEmail, email);
    } else {
      await prefs.remove(_keyEmail);
    }

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
      await prefs.setString(
        _keyCustomExerciseToken,
        customExerciseToken,
      );
    } else {
      await prefs.remove(_keyCustomExerciseToken);
    }

    // 登入畫面不要等 ZEGO。
    _scheduleZegoSync(
      userId: userId,
      userName: name,
      delay: const Duration(milliseconds: 800),
    );
  }

  /// 登出時呼叫，同時清掉記憶體跟本機儲存。
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

    // 登出後背景解除 ZEGO，不阻塞頁面切換。
    _scheduleZegoSync(
      delay: Duration.zero,
    );
  }

  static void _scheduleZegoSync({
    String? userId,
    String? userName,
    Duration delay = Duration.zero,
  }) {
    _zegoSyncTimer?.cancel();

    _zegoSyncTimer = Timer(delay, () {
      unawaited(
        _syncZegoSafely(
          userId: userId,
          userName: userName,
        ),
      );
    });
  }

  static Future<void> _syncZegoSafely({
    String? userId,
    String? userName,
  }) async {
    try {
      await ZegoCallInvitationService.instance
          .synchronizeSession(
            userId: userId,
            userName: userName,
          )
          .timeout(
            const Duration(seconds: 6),
          );
    } on TimeoutException {
      debugPrint(
        'ZEGO synchronizeSession timeout — 已略過，不阻塞 App',
      );
    } catch (e) {
      debugPrint(
        'ZEGO synchronizeSession error: ${e.runtimeType}',
      );
    }
  }
}

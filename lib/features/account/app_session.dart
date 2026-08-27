// lib/features/account/app_session.dart
// 目前的登入狀態(只存記憶體,app 重開會消失)。登入時寫入,其他畫面直接讀。
import 'user_role.dart';

class AppSession {
  static UserRole? role;
  static String? userId;
  static String? name;
  static String? email;

  static bool get isLoggedIn => userId != null || email != null;

  static void save({
    required UserRole role,
    String? userId,
    String? name,
    String? email,
  }) {
    AppSession.role = role;
    AppSession.userId = userId;
    AppSession.name = name;
    AppSession.email = email;
  }

  static void clear() {
    role = null;
    userId = null;
    name = null;
    email = null;
  }
}
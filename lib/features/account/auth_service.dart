// lib/features/account/auth_service.dart
//
// 集中管理後端連線設定與登入/註冊 API 呼叫
//
// 對應後端: AuthController.java (com.example.trainingsystems.controller)
//   POST /api/auth/login    body: { "email": ..., "password": ... }
//   POST /api/auth/register body: { "email": ..., "password": ..., "name": ... }
//
// 後端回傳格式:
//   - 失敗時：回傳一段文字訊息,例如 "帳號不存在"、"密碼錯誤"
//   - 成功時：回傳一個物件 { message, userId, name, email }
//
// ============================================================
// 【正式後端】實際打 API 的邏輯已交給 api_service.dart(同學寫的 ApiService),
//   這裡的 AuthService 只負責把 ApiService 回傳的原始資料包裝成
//   LoginResult,讓 login_screen.dart 不用管底層是怎麼打的。
//
// 【模擬登入開關】_useMockLogin
//   想離線開發(後端斷線、額度用完睡著等狀況)時,把這裡改回 true,
//   輸入任何符合格式的帳密都直接視為登入成功,login_screen.dart 完全不用改。
// ============================================================
import 'api_service.dart';

class AuthService {
  // 🔧 開發階段開關:true = 模擬登入(不連後端),false = 真的打 API
  static const bool _useMockLogin = false;

  /// 呼叫後端登入 API。
  /// 成功時回傳 LoginResult(success: true, ...使用者資料)
  /// 失敗時回傳 LoginResult(success: false, message: 後端給的錯誤訊息)
  static Future<LoginResult> login({
    required String identifier,
    required String password,
  }) async {
    if (_useMockLogin) {
      return _mockLogin(email: identifier, password: password);
    }

    try {
      final data = await ApiService.login(
        identifier: identifier,
        password: password,
      );
      return LoginResult.fromResponse(data, fallbackEmail: identifier);
    } on AuthApiFailure catch (error) {
      return LoginResult.failure(error.message, errorCode: error.code);
    } catch (_) {
      return LoginResult.failure('無法連線到伺服器，請確認網路狀態或稍後再試');
    }
  }

  static Future<LoginResult> googleLogin({required String idToken}) async {
    try {
      final data = await ApiService.googleLogin(idToken: idToken);
      return LoginResult.fromResponse(data);
    } on AuthApiFailure catch (error) {
      return LoginResult.failure(error.message, errorCode: error.code);
    } catch (_) {
      return LoginResult.failure('Google 登入失敗，請稍後再試');
    }
  }

  static Future<LoginResult> linkGoogle({
    required String idToken,
    required String currentPassword,
  }) async {
    try {
      final data = await ApiService.linkGoogle(
        idToken: idToken,
        currentPassword: currentPassword,
      );
      return LoginResult.fromResponse(data);
    } on AuthApiFailure catch (error) {
      return LoginResult.failure(error.message, errorCode: error.code);
    } catch (_) {
      return LoginResult.failure('帳號連結失敗，請稍後再試');
    }
  }

  static Future<LoginResult> registerTherapist({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    try {
      final data = await ApiService.registerTherapist(
        name: name,
        email: email,
        password: password,
        inviteCode: inviteCode,
      );
      return LoginResult.fromResponse(data, fallbackEmail: email);
    } on AuthApiFailure catch (error) {
      return LoginResult.failure(error.message, errorCode: error.code);
    } catch (_) {
      return LoginResult.failure('無法連線到伺服器，請稍後再試');
    }
  }

  /// 呼叫後端註冊 API。
  static Future<LoginResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (_useMockLogin) {
      return _mockLogin(email: email, password: password);
    }

    try {
      await ApiService.register(name: name, email: email, password: password);
      // 註冊成功後直接接著登入一次,拿到 userId 好存進 AppSession
      return login(identifier: email, password: password);
    } on AuthApiFailure catch (error) {
      return LoginResult.failure(error.message, errorCode: error.code);
    } catch (_) {
      return LoginResult.failure('無法連線到伺服器，請確認網路狀態或稍後再試');
    }
  }

  /// 模擬登入:不連網路,直接回傳成功。
  static Future<LoginResult> _mockLogin({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final namePart = email.contains('@') ? email.split('@').first : email;

    return LoginResult.success(
      userId: 'mock-${email.hashCode}',
      name: namePart.isEmpty ? '測試使用者' : namePart,
      email: email,
      bindingCode: null,
      customExerciseToken: null,
      backendRole: 'THERAPIST',
    );
  }
}

class LoginResult {
  final bool success;
  final String? message;
  final String? userId;
  final String? name;
  final String? email;
  final String? accountId;
  final String? bindingCode;
  final String? customExerciseToken;
  final String? backendRole;
  final String? errorCode;

  LoginResult.success({
    required this.userId,
    required this.name,
    required this.email,
    this.accountId,
    required this.bindingCode,
    required this.customExerciseToken,
    required this.backendRole,
    this.errorCode,
  })  : success = true,
        message = null;

  LoginResult.failure(this.message, {this.errorCode})
      : success = false,
        userId = null,
        name = null,
        email = null,
        accountId = null,
        bindingCode = null,
        customExerciseToken = null,
        backendRole = null;

  factory LoginResult.fromResponse(
    Map<String, dynamic> data, {
    String fallbackEmail = '',
  }) {
    return LoginResult.success(
      userId: data['userId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? fallbackEmail,
      accountId: data['accountId']?.toString(),
      bindingCode: data['bindingCode']?.toString(),
      customExerciseToken: data['customExerciseToken']?.toString(),
      backendRole: data['role']?.toString(),
    );
  }
}

// lib/features/account/auth_service.dart
//
// 集中管理後端連線設定與登入/註冊 API 呼叫
//
// 對應後端: AuthController.java (com.example.trainingsystems.controller)
//   POST /api/auth/login    body: { "email": ..., "password": ... }
//   POST /api/auth/register body: { "email": ..., "password": ..., "name": ... }
//
// 後端回傳格式目前不太一致(這是後端那邊的寫法,前端這邊做相容處理):
//   - 失敗時：回傳一段文字訊息,例如 "帳號不存在"、"密碼錯誤"
//   - 成功時：回傳一個物件 { message, userId, name, email }
//
// ============================================================
// 【重要】_baseUrl 這裡先用組員電腦的區域網路 IP 佔位,之後依實際狀況修改:
//   - 若後端部署到雲端(Render / Railway 等),改成雲端網址即可,例如
//     'https://your-app-name.onrender.com'
//   - 若用 Android 模擬器連本機後端,改成 'http://10.0.2.2:8080'
//   - 若用實體手機連組員電腦,且雙方在同一個 Wi-Fi,改成
//     'http://組員電腦的區網IP:8080'(在組員電腦上用 ipconfig 查詢 IPv4 位址)
//   - 目前你們不同 Wi-Fi,這個網址暫時連不通,等後端部署到雲端後
//     把下面這行換成雲端網址即可，其餘程式碼都不用改
//
// ============================================================
// 【模擬登入開關】_useMockLogin
//   後端還沒接好之前,先設 true → 不打真的 API,輸入任何符合格式的帳密
//   都直接視為登入成功,回傳一組假的使用者資料,讓其他畫面可以正常往下開發。
//   等後端網址填好、確定連得通之後,把這裡改回 false 即可,
//   login_screen.dart 完全不用改。
// ============================================================
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _baseUrl = 'http://REPLACE_WITH_BACKEND_HOST:8080';

  // 🔧 開發階段開關:true = 模擬登入(不連後端),false = 真的打 API
  static const bool _useMockLogin = true;

  static String get loginUrl => '$_baseUrl/api/auth/login';
  static String get registerUrl => '$_baseUrl/api/auth/register';

  /// 呼叫後端登入 API。
  /// 成功時回傳 LoginResult(success: true, ...使用者資料)
  /// 失敗時回傳 LoginResult(success: false, message: 後端給的錯誤訊息)
  /// 連線本身失敗(連不到伺服器、逾時等)會丟出例外,呼叫端要 try/catch
  static Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    if (_useMockLogin) {
      return _mockLogin(email: email, password: password);
    }

    final response = await http
        .post(
          Uri.parse(loginUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return LoginResult.failure('伺服器錯誤(狀態碼 ${response.statusCode})');
    }

    // 後端目前不管成功失敗都回傳 200,靠回傳內容的型態分辨是文字訊息還是物件
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is Map<String, dynamic>) {
      // 成功: { message, userId, name, email }
      return LoginResult.success(
        userId: decoded['userId']?.toString() ?? '',
        name: decoded['name']?.toString() ?? '',
        email: decoded['email']?.toString() ?? email,
      );
    }

    // 失敗: 後端直接回傳一段文字,例如 "帳號不存在"、"密碼錯誤"
    return LoginResult.failure(decoded.toString());
  }

  /// 模擬登入:不連網路,直接回傳成功。
  /// 刻意加一點延遲(模擬真實網路請求的等待感),
  /// 讓 loading 動畫、按鈕 disable 狀態等 UI 邏輯也能一併測試到。
  static Future<LoginResult> _mockLogin({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    // 用 email 前綴當作模擬的顯示名稱,方便一眼看出目前是哪個帳號登入
    final namePart = email.contains('@') ? email.split('@').first : email;

    return LoginResult.success(
      userId: 'mock-${email.hashCode}',
      name: namePart.isEmpty ? '測試使用者' : namePart,
      email: email,
    );
  }
}

class LoginResult {
  final bool success;
  final String? message;
  final String? userId;
  final String? name;
  final String? email;

  LoginResult.success({
    required this.userId,
    required this.name,
    required this.email,
  })  : success = true,
        message = null;

  LoginResult.failure(this.message)
      : success = false,
        userId = null,
        name = null,
        email = null;
}
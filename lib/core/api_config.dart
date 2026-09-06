// lib/core/api_config.dart
//
// 集中管理後端網址設定。
// 所有需要打 API 的地方(登入、計畫、訓練紀錄等)都應該從這裡拿 baseUrl,
// 不要各自寫死一份,不然之後要換網址(例如部署到雲端)會漏改。
//
// ============================================================
// 【重要】依實際狀況修改下面這一行:
//   - 若後端部署到雲端(Render / Railway 等),改成雲端網址,例如
//     'https://your-app-name.onrender.com'
//   - 若用 Android 模擬器連本機後端,改成 'http://10.0.2.2:8080'
//   - 若用實體手機連組員電腦,且雙方在同一個 Wi-Fi,改成
//     'http://組員電腦的區網IP:8080'(在對方電腦上用 ipconfig 查詢 IPv4 位址)
// ============================================================
class ApiConfig {
  static const String baseUrl = 'https://trianing-system-1.onrender.com';

  // Public Web OAuth client ID. Supply with
  // --dart-define=GOOGLE_SERVER_CLIENT_ID=... at run/build time.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '229850307155-70q5o0vg5d89hqidluq1obbkg2jbc2nq.apps.googleusercontent.com',
  );
}

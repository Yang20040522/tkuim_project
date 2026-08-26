// lib/services/current_user.dart
//
// App 目前還沒有帳號系統,先放一個「假的目前使用者」佔位。
// 之後接了登入系統,把 CurrentUser.id 換成真正登入者的 uid 即可,
// 其他呼叫 ChatBackend 的程式碼都不用改。

class CurrentUser {
  static const String id = 'local_user_demo'; // TODO: 接登入系統後替換
}
// lib/features/chat/chat_backend.dart
//
// 真人對真人聊天的「後端介面」。
// UI 跟其他程式碼一律只透過這個 abstract class 溝通,
// 之後決定要接 Firebase / Supabase / 自建 REST,
// 只需要新增一個 implements ChatBackend 的類別
// (例如 FirebaseChatBackend、SupabaseChatBackend、RestChatBackend),
// 這份介面跟呼叫它的程式碼完全不用改。

import 'chat_models.dart';

abstract class ChatBackend {
  /// 取得(或建立)我 跟某個對象之間的 1 對 1 對話,回傳 conversationId。
  /// 如果對話已經存在就直接回傳既有的 id,不會重複建立。
  Future<String> getOrCreateConversation({
    required String myUserId,
    required String otherUserId,
    required ConversationType type,
  });

  /// 監聽「我」的所有對話列表(依最後更新時間新到舊)。
  /// 用 Stream 是因為真人聊天需要即時看到「對方傳了新訊息」,
  /// 不像 AI 對話是一問一答、不需要背景推播式的更新。
  Stream<List<RemoteConversation>> watchConversations(String myUserId);

  /// 監聽單一對話裡的所有訊息(依時間舊到新)
  Stream<List<RemoteChatMessage>> watchMessages(String conversationId);

  /// 傳送一則訊息
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  });

  /// 把某個對話裡「不是我傳的、且還沒讀」的訊息標記為已讀
  Future<void> markAsRead({
    required String conversationId,
    required String myUserId,
  });

  /// 監聽「我」在各對話裡的未讀數
  Stream<List<UnreadCount>> watchUnreadCounts(String myUserId);

  /// 資源釋放(有些後端的連線/監聽需要手動關閉)
  void dispose();
}
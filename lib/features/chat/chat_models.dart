// lib/features/chat/chat_models.dart
//
// 真人對真人聊天(治療師 / 病友)共用的資料模型。
// 故意跟 chat_screen.dart 裡專門給 AI 用的 ChatMessage 分開:
// 1. AI 對話的 sender 只有「我」跟「AI」兩種固定角色,用 enum 就夠。
// 2. 真人對真人的對話,傳訊者要能是「任何一個使用者」,
//    要用真實的 userId 來辨識,不能再用寫死的 enum。
//
// 這份檔案不 import 任何特定後端(Firebase / Supabase / REST)的套件,
// 純粹是資料形狀的約定,之後接哪個後端都不用改這裡。

enum ConversationType { therapist, peer }

/// 目前登入者可以合法建立聊天室的對象。
class ChatContact {
  const ChatContact({
    required this.userId,
    required this.name,
    required this.role,
    required this.type,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) => ChatContact(
        userId: json['userId'].toString(),
        name: json['name']?.toString() ?? '使用者',
        role: json['role']?.toString() ?? '',
        type: ConversationType.values.firstWhere(
          (type) => type.name == json['type']?.toString(),
          orElse: () => throw const FormatException('未知的聊天室類型'),
        ),
      );

  final String userId;
  final String name;
  final String role;
  final ConversationType type;
}

/// 一則真人對真人的訊息
class RemoteChatMessage {
  final String id;
  final String conversationId;
  final String senderId; // 傳訊者的真實 userId(不是 enum)
  final String text;
  final DateTime sentAt;
  final DateTime? readAt; // null = 對方還沒讀

  RemoteChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  RemoteChatMessage copyWith({DateTime? readAt}) => RemoteChatMessage(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        text: text,
        sentAt: sentAt,
        readAt: readAt ?? this.readAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'text': text,
        'sentAt': sentAt.toIso8601String(),
        'readAt': readAt?.toIso8601String(),
      };

  factory RemoteChatMessage.fromJson(Map<String, dynamic> json) =>
      RemoteChatMessage(
        id: json['id'].toString(),
        conversationId: json['conversationId'].toString(),
        senderId: json['senderId'].toString(),
        text: json['text']?.toString() ?? '',
        sentAt: DateTime.parse(json['sentAt'].toString()),
        readAt: json['readAt'] == null
            ? null
            : DateTime.parse(json['readAt'].toString()),
      );
}

/// 一段真人對真人的對話(目前設計為 1 對 1)
class RemoteConversation {
  final String id;
  final ConversationType type;
  final List<String> participantIds; // 1 對 1,固定長度 2
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final DateTime updatedAt;

  RemoteConversation({
    required this.id,
    required this.type,
    required this.participantIds,
    this.lastMessageText,
    this.lastMessageAt,
    required this.updatedAt,
  });

  /// 在這段對話裡,除了「我」之外的那個人是誰
  String otherParticipantId(String myUserId) =>
      participantIds.firstWhere((id) => id != myUserId, orElse: () => '');

  RemoteConversation copyWith({
    String? lastMessageText,
    DateTime? lastMessageAt,
    DateTime? updatedAt,
  }) =>
      RemoteConversation(
        id: id,
        type: type,
        participantIds: participantIds,
        lastMessageText: lastMessageText ?? this.lastMessageText,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory RemoteConversation.fromJson(Map<String, dynamic> json) =>
      RemoteConversation(
        id: json['id'].toString(),
        type: ConversationType.values.firstWhere(
          (e) => e.name == json['type']?.toString(),
        ),
        participantIds: (json['participantIds'] as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
        lastMessageText: json['lastMessageText']?.toString(),
        lastMessageAt: json['lastMessageAt'] == null
            ? null
            : DateTime.parse(json['lastMessageAt'].toString()),
        updatedAt: DateTime.parse(json['updatedAt'].toString()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'participantIds': participantIds,
        'lastMessageText': lastMessageText,
        'lastMessageAt': lastMessageAt?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

/// 單一對話的未讀數(給列表頁小紅點用)
class UnreadCount {
  final String conversationId;
  final int count;
  const UnreadCount(this.conversationId, this.count);

  factory UnreadCount.fromJson(Map<String, dynamic> json) => UnreadCount(
        json['conversationId'].toString(),
        int.parse(json['count'].toString()),
      );
}

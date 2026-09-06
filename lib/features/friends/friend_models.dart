class FriendRequestItem {
  const FriendRequestItem({
    required this.requestId,
    required this.senderId,
    required this.senderName,
    required this.senderFriendCode,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequestItem.fromJson(Map<String, dynamic> json) {
    return FriendRequestItem(
      requestId: _id(json['requestId']),
      senderId: _id(json['senderId']),
      senderName: _text(json['senderName'], fallback: '使用者'),
      senderFriendCode: _text(json['senderFriendCode']).toUpperCase(),
      status: _text(json['status']),
      createdAt: _dateTime(json['createdAt']),
    );
  }

  final String requestId;
  final String senderId;
  final String senderName;
  final String senderFriendCode;
  final String status;
  final DateTime? createdAt;
}

class SentFriendRequestItem {
  const SentFriendRequestItem({
    required this.requestId,
    required this.receiverId,
    required this.receiverName,
    required this.receiverFriendCode,
    required this.status,
    required this.createdAt,
  });

  factory SentFriendRequestItem.fromJson(Map<String, dynamic> json) {
    return SentFriendRequestItem(
      requestId: _id(json['requestId']),
      receiverId: _id(json['receiverId']),
      receiverName: _text(json['receiverName'], fallback: '使用者'),
      receiverFriendCode: _text(json['receiverFriendCode']).toUpperCase(),
      status: _text(json['status']),
      createdAt: _dateTime(json['createdAt']),
    );
  }

  final String requestId;
  final String receiverId;
  final String receiverName;
  final String receiverFriendCode;
  final String status;
  final DateTime? createdAt;
}

class FriendItem {
  const FriendItem({
    required this.friendshipId,
    required this.friendId,
    required this.friendName,
    required this.friendCode,
    required this.createdAt,
  });

  factory FriendItem.fromJson(Map<String, dynamic> json) {
    return FriendItem(
      friendshipId: _id(json['friendshipId']),
      friendId: _id(json['friendId']),
      friendName: _text(json['friendName'], fallback: '使用者'),
      friendCode: _text(json['friendCode']).toUpperCase(),
      createdAt: _dateTime(json['createdAt']),
    );
  }

  final String friendshipId;
  final String friendId;
  final String friendName;
  final String friendCode;
  final DateTime? createdAt;
}

String _id(Object? value) => value?.toString() ?? '';

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

DateTime? _dateTime(Object? value) {
  final text = value?.toString();
  return text == null ? null : DateTime.tryParse(text);
}

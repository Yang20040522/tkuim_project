import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_body/features/account/account_api_service.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:flutter_body/features/chat/chat_backend.dart';
import 'package:flutter_body/features/chat/chat_models.dart';
import 'package:flutter_body/features/chat/remote_chat_screen.dart';
import 'package:flutter_body/features/friends/friend_api_service.dart';
import 'package:flutter_body/features/friends/friend_management_screen.dart';
import 'package:flutter_body/features/friends/friend_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    await AppSession.save(
      role: UserRole.patient,
      userId: '1',
      name: '病患 A',
      email: 'a@example.com',
      friendCode: 'AAAA1111',
      customExerciseToken: 'signed-token',
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('顯示並複製好友代碼，輸入會大寫且可送出邀請', (tester) async {
    final api = FakeFriendApiService();
    final chat = FakeFriendChatBackend();
    await pumpScreen(tester, api, chat);

    expect(find.text('AAAA1111'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('copy-friend-code')));
    await pumpAsyncAction(tester);
    expect(find.text('好友代碼已複製'), findsOneWidget);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('friend-code-input')),
      '  bbbb2222  ',
    );
    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('friend-code-input')),
    );
    expect(input.controller!.text, '  BBBB2222  ');

    await tester.tap(find.byKey(const ValueKey('send-friend-request')));
    await pumpAsyncAction(tester);

    expect(api.sentCodes, ['BBBB2222']);
    expect(find.text('好友邀請已送出'), findsOneWidget);
    expect(input.controller!.text, isEmpty);
  });

  testWidgets('收到邀請可接受或拒絕並刷新好友資料', (tester) async {
    final api = FakeFriendApiService(
      pending: [
        pending('11', '2', '病患 B'),
        pending('12', '3', '病患 C'),
      ],
    );
    final chat = FakeFriendChatBackend();
    await pumpScreen(tester, api, chat);

    await tester.tap(find.byKey(const ValueKey('accept-request-11')));
    await pumpAsyncAction(tester);
    expect(api.acceptedIds, ['11']);
    expect(find.text('已接受好友邀請'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('friend-2')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('friend-2')), findsOneWidget);
    expect(chat.refreshCalls, 1);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('reject-request-12')));
    await pumpAsyncAction(tester);
    expect(api.rejectedIds, ['12']);
    expect(find.byKey(const ValueKey('pending-request-12')), findsNothing);
  });

  testWidgets('已送邀請可確認取消，好友可確認刪除', (tester) async {
    final api = FakeFriendApiService(
      sent: [sent('21', '2', '病患 B')],
      friends: [friend('3', '病患 C')],
    );
    final chat = FakeFriendChatBackend();
    await pumpScreen(tester, api, chat);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('cancel-request-21')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('cancel-request-21')));
    await tester.pumpAndSettle();
    expect(find.textContaining('確定要取消送給 病患 B'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-cancel-request')));
    await tester.pumpAndSettle();
    expect(api.cancelledIds, ['21']);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('remove-friend-3')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('remove-friend-3')));
    await tester.pumpAndSettle();
    expect(find.text('確定要刪除 病患 C 嗎？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-remove-friend')));
    await tester.pumpAndSettle();

    expect(api.removedIds, ['3']);
    expect(find.byKey(const ValueKey('friend-3')), findsNothing);
    expect(chat.refreshCalls, 1);
  });

  testWidgets('好友聊天建立 peer conversation 並開啟 RemoteChatScreen', (tester) async {
    final api = FakeFriendApiService(friends: [friend('2', '病患 B')]);
    final chat = FakeFriendChatBackend();
    await pumpScreen(tester, api, chat);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('chat-friend-2')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('chat-friend-2')));
    await tester.pumpAndSettle();

    expect(find.byType(RemoteChatScreen), findsOneWidget);
    expect(chat.lastMyUserId, '1');
    expect(chat.lastOtherUserId, '2');
    expect(chat.lastType, ConversationType.peer);
    expect(find.text('好友對話'), findsOneWidget);
  });

  testWidgets('初始載入、空狀態與錯誤狀態都可見', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gate = Completer<void>();
    final loadingApi = FakeFriendApiService(loadGate: gate.future);
    final loadingChat = FakeFriendChatBackend();
    await tester.pumpWidget(
      MaterialApp(
        home: FriendManagementScreen(
          friendApiService: loadingApi,
          chatBackend: loadingChat,
        ),
      ),
    );
    await tester.pump();
    expect(
        find.byKey(const ValueKey('friend-initial-loading')), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('目前沒有好友邀請'), findsOneWidget);
    expect(find.text('目前沒有已送出的邀請'), findsOneWidget);
    expect(find.text('還沒有好友'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final errorApi = FakeFriendApiService(
      loadError: const FriendApiException('載入好友資料失敗'),
    );
    await pumpScreen(tester, errorApi, FakeFriendChatBackend());
    expect(find.byKey(const ValueKey('friend-load-error')), findsOneWidget);
    expect(find.text('載入好友資料失敗'), findsOneWidget);
  });

  testWidgets('AppSession 無代碼時由 account API 取得並同步', (tester) async {
    await AppSession.save(
      role: UserRole.patient,
      userId: '1',
      customExerciseToken: 'signed-token',
    );
    var accountCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FriendManagementScreen(
          friendApiService: FakeFriendApiService(),
          chatBackend: FakeFriendChatBackend(),
          accountLoader: () async {
            accountCalls++;
            return const AccountInfo(
              userId: '1',
              name: '病患 A',
              email: 'a@example.com',
              accountId: null,
              role: 'PATIENT',
              bindingCode: null,
              friendCode: 'fallback9',
              googleLinked: false,
              googleEmail: null,
              hasPassword: true,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FALLBACK9'), findsOneWidget);
    expect(AppSession.friendCode, 'FALLBACK9');
    expect(accountCalls, 1);
  });
}

Future<void> pumpScreen(
  WidgetTester tester,
  FakeFriendApiService api,
  FakeFriendChatBackend chat,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: FriendManagementScreen(
        friendApiService: api,
        chatBackend: chat,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpAsyncAction(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 300));
}

FriendRequestItem pending(String requestId, String senderId, String name) {
  return FriendRequestItem(
    requestId: requestId,
    senderId: senderId,
    senderName: name,
    senderFriendCode: 'CODE$senderId',
    status: 'PENDING',
    createdAt: DateTime(2026, 9, 6, 10),
  );
}

SentFriendRequestItem sent(String requestId, String receiverId, String name) {
  return SentFriendRequestItem(
    requestId: requestId,
    receiverId: receiverId,
    receiverName: name,
    receiverFriendCode: 'CODE$receiverId',
    status: 'PENDING',
    createdAt: DateTime(2026, 9, 6, 10),
  );
}

FriendItem friend(String id, String name) {
  return FriendItem(
    friendshipId: 'friendship-$id',
    friendId: id,
    friendName: name,
    friendCode: 'CODE$id',
    createdAt: DateTime(2026, 9, 6, 10),
  );
}

class FakeFriendApiService extends FriendApiService {
  FakeFriendApiService({
    List<FriendRequestItem> pending = const [],
    List<SentFriendRequestItem> sent = const [],
    List<FriendItem> friends = const [],
    this.loadGate,
    this.loadError,
  })  : pendingItems = List.of(pending),
        sentItems = List.of(sent),
        friendItems = List.of(friends);

  final Future<void>? loadGate;
  final Object? loadError;
  final List<FriendRequestItem> pendingItems;
  final List<SentFriendRequestItem> sentItems;
  final List<FriendItem> friendItems;
  final List<String> sentCodes = [];
  final List<String> acceptedIds = [];
  final List<String> rejectedIds = [];
  final List<String> cancelledIds = [];
  final List<String> removedIds = [];

  Future<void> _beforeLoad() async {
    await loadGate;
    if (loadError case final error?) throw error;
  }

  @override
  Future<List<FriendRequestItem>> getPendingRequests() async {
    await _beforeLoad();
    return List.of(pendingItems);
  }

  @override
  Future<List<SentFriendRequestItem>> getSentRequests() async {
    await _beforeLoad();
    return List.of(sentItems);
  }

  @override
  Future<List<FriendItem>> getFriends() async {
    await _beforeLoad();
    return List.of(friendItems);
  }

  @override
  Future<void> sendFriendRequest(String friendCode) async {
    sentCodes.add(friendCode);
    sentItems.add(sent('new', '2', '病患 B'));
  }

  @override
  Future<void> acceptRequest(String requestId) async {
    acceptedIds.add(requestId);
    final request = pendingItems.firstWhere(
      (item) => item.requestId == requestId,
    );
    pendingItems.remove(request);
    friendItems.add(friend(request.senderId, request.senderName));
  }

  @override
  Future<void> rejectRequest(String requestId) async {
    rejectedIds.add(requestId);
    pendingItems.removeWhere((item) => item.requestId == requestId);
  }

  @override
  Future<void> cancelRequest(String requestId) async {
    cancelledIds.add(requestId);
    sentItems.removeWhere((item) => item.requestId == requestId);
  }

  @override
  Future<void> removeFriend(String friendId) async {
    removedIds.add(friendId);
    friendItems.removeWhere((item) => item.friendId == friendId);
  }

  @override
  void dispose() {}
}

class FakeFriendChatBackend implements ChatBackend {
  int refreshCalls = 0;
  String? lastMyUserId;
  String? lastOtherUserId;
  ConversationType? lastType;

  @override
  Future<List<ChatContact>> getContacts() async => const [];

  @override
  Future<String> getOrCreateConversation({
    required String myUserId,
    required String otherUserId,
    required ConversationType type,
  }) async {
    lastMyUserId = myUserId;
    lastOtherUserId = otherUserId;
    lastType = type;
    return 'conversation-1';
  }

  @override
  Stream<List<RemoteConversation>> watchConversations(String myUserId) =>
      const Stream.empty();

  @override
  Stream<List<RemoteChatMessage>> watchMessages(String conversationId) =>
      Stream.value(const []);

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {}

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String myUserId,
  }) async {}

  @override
  Stream<List<UnreadCount>> watchUnreadCounts(String myUserId) =>
      const Stream.empty();

  @override
  void refresh() => refreshCalls++;

  @override
  void dispose() {}
}

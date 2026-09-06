import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:flutter_body/features/chat/chat_backend.dart';
import 'package:flutter_body/features/chat/chat_home_screen.dart';
import 'package:flutter_body/features/chat/chat_models.dart';
import 'package:flutter_body/features/chat/remote_chat_screen.dart';

void main() {
  setUp(() {
    AppSession.userId = '15';
    AppSession.customExerciseToken = 'signed-token';
    AppSession.role = UserRole.patient;
  });

  tearDown(() {
    AppSession.userId = null;
    AppSession.customExerciseToken = null;
    AppSession.role = null;
  });

  testWidgets('own and other messages use right and left alignment',
      (tester) async {
    final backend = FakeChatBackend();
    await tester.pumpWidget(
      MaterialApp(
        home: RemoteChatScreen(
          backend: backend,
          conversationId: '123',
          otherUserId: '25',
          otherUserName: '病友 B',
          conversationType: ConversationType.peer,
        ),
      ),
    );
    backend.messages.add([
      RemoteChatMessage(
        id: '1',
        conversationId: '123',
        senderId: '15',
        text: '我的訊息',
        sentAt: DateTime.utc(2026, 9, 6, 1),
      ),
      RemoteChatMessage(
        id: '2',
        conversationId: '123',
        senderId: '25',
        text: '對方訊息',
        sentAt: DateTime.utc(2026, 9, 6, 2),
      ),
    ]);
    await tester.pump();

    final mine = tester.widget<Align>(
      find.byKey(const ValueKey('remote-message-1-mine')),
    );
    final other = tester.widget<Align>(
      find.byKey(const ValueKey('remote-message-2-other')),
    );
    expect(mine.alignment, Alignment.centerRight);
    expect(other.alignment, Alignment.centerLeft);
    expect(backend.markReadCalls, greaterThanOrEqualTo(1));

    await tester.pumpWidget(const SizedBox());
    backend.dispose();
  });

  testWidgets(
      'read receipt only appears for my messages and updates by polling',
      (tester) async {
    final backend = FakeChatBackend();
    await tester.pumpWidget(
      MaterialApp(
        home: RemoteChatScreen(
          backend: backend,
          conversationId: '123',
          otherUserId: '25',
          otherUserName: '病友 B',
          conversationType: ConversationType.peer,
        ),
      ),
    );

    backend.messages.add([
      RemoteChatMessage(
        id: 'unread',
        conversationId: '123',
        senderId: '15',
        text: '尚未讀取',
        sentAt: DateTime(2026, 9, 6, 22, 42),
      ),
      RemoteChatMessage(
        id: 'read',
        conversationId: '123',
        senderId: '15',
        text: '已讀訊息',
        sentAt: DateTime(2026, 9, 6, 22, 43),
        readAt: DateTime(2026, 9, 6, 22, 44),
      ),
      RemoteChatMessage(
        id: 'other',
        conversationId: '123',
        senderId: '25',
        text: '對方訊息',
        sentAt: DateTime(2026, 9, 6, 22, 45),
        readAt: DateTime(2026, 9, 6, 22, 46),
      ),
    ]);
    await tester.pump();

    expect(find.text('22:42'), findsOneWidget);
    expect(find.text('22:43 · 已讀'), findsOneWidget);
    expect(find.text('22:45'), findsOneWidget);
    expect(find.text('22:42 · 已讀'), findsNothing);
    expect(find.text('22:45 · 已讀'), findsNothing);

    backend.messages.add([
      RemoteChatMessage(
        id: 'unread',
        conversationId: '123',
        senderId: '15',
        text: '尚未讀取',
        sentAt: DateTime(2026, 9, 6, 22, 42),
        readAt: DateTime(2026, 9, 6, 22, 47),
      ),
    ]);
    await tester.pump();

    expect(find.text('22:42 · 已讀'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    backend.dispose();
  });

  testWidgets('send button uses the outgoing bubble blue and sends normally',
      (tester) async {
    final backend = FakeChatBackend();
    await tester.pumpWidget(
      MaterialApp(
        home: RemoteChatScreen(
          backend: backend,
          conversationId: '123',
          otherUserId: '25',
          otherUserName: '病友 B',
          conversationType: ConversationType.peer,
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('remote-chat-send')),
    );
    expect(
      button.style!.backgroundColor!.resolve({}),
      const Color(0xFF4A65FF),
    );
    expect(
      button.style!.foregroundColor!.resolve({}),
      Colors.white,
    );
    expect(
      button.style!.backgroundColor!.resolve({WidgetState.disabled}),
      const Color(0xFFD5DAEE),
    );

    await tester.enterText(
      find.byKey(const ValueKey('remote-chat-input')),
      '你好',
    );
    await tester.tap(find.byKey(const ValueKey('remote-chat-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(backend.sentTexts, ['你好']);
    await tester.pumpWidget(const SizedBox());
    backend.dispose();
  });

  testWidgets('ChatHome renders backend contacts instead of mock contacts',
      (tester) async {
    final backend = FakeChatBackend(
      contacts: const [
        ChatContact(
          userId: '25',
          name: '真實好友',
          role: 'PATIENT',
          type: ConversationType.peer,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(backend: backend)),
    );
    await tester.pump();

    expect(find.text('真實好友'), findsOneWidget);
    expect(backend.contactsCalls, 1);
  });

  testWidgets('ChatHome does not call backend without AppSession user id',
      (tester) async {
    AppSession.userId = null;
    final backend = FakeChatBackend();

    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(backend: backend)),
    );
    await tester.pump();

    expect(find.textContaining('找不到登入使用者'), findsOneWidget);
    expect(backend.contactsCalls, 0);
    expect(backend.conversationWatchCalls, 0);
    expect(backend.unreadWatchCalls, 0);
  });

  testWidgets(
      'ChatHome refreshes peer contacts after friend management returns',
      (tester) async {
    final contacts = <ChatContact>[];
    final backend = FakeChatBackend(contacts: contacts);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatHomeScreen(
          backend: backend,
          friendManagementBuilder: (_) => Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const ValueKey('finish-friend-management'),
                  onPressed: () {
                    contacts.add(
                      const ChatContact(
                        userId: '25',
                        name: '剛接受的好友',
                        role: 'PATIENT',
                        type: ConversationType.peer,
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('完成'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-friend-management')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finish-friend-management')));
    await tester.pumpAndSettle();

    expect(find.text('剛接受的好友'), findsOneWidget);
    expect(backend.contactsCalls, 2);
    expect(backend.refreshCalls, 1);
  });
}

class FakeChatBackend implements ChatBackend {
  FakeChatBackend({this.contacts = const []});

  final List<ChatContact> contacts;
  final StreamController<List<RemoteConversation>> conversations =
      StreamController<List<RemoteConversation>>.broadcast();
  final StreamController<List<RemoteChatMessage>> messages =
      StreamController<List<RemoteChatMessage>>.broadcast();
  final StreamController<List<UnreadCount>> unreads =
      StreamController<List<UnreadCount>>.broadcast();
  int contactsCalls = 0;
  int conversationWatchCalls = 0;
  int unreadWatchCalls = 0;
  int markReadCalls = 0;
  int refreshCalls = 0;
  final List<String> sentTexts = [];
  bool _disposed = false;

  @override
  Future<List<ChatContact>> getContacts() async {
    contactsCalls++;
    return contacts;
  }

  @override
  Future<String> getOrCreateConversation({
    required String myUserId,
    required String otherUserId,
    required ConversationType type,
  }) async =>
      '123';

  @override
  Stream<List<RemoteConversation>> watchConversations(String myUserId) {
    conversationWatchCalls++;
    return conversations.stream;
  }

  @override
  Stream<List<RemoteChatMessage>> watchMessages(String conversationId) =>
      messages.stream;

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    sentTexts.add(text);
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String myUserId,
  }) async {
    markReadCalls++;
  }

  @override
  Stream<List<UnreadCount>> watchUnreadCounts(String myUserId) {
    unreadWatchCalls++;
    return unreads.stream;
  }

  @override
  void refresh() => refreshCalls++;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(conversations.close());
    unawaited(messages.close());
    unawaited(unreads.close());
  }
}

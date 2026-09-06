import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/therapist_home_screen.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:flutter_body/features/chat/chat_backend.dart';
import 'package:flutter_body/features/chat/chat_home_screen.dart';
import 'package:flutter_body/features/chat/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppSession.role = UserRole.therapist;
    AppSession.userId = 'therapist-1';
    AppSession.name = '測試治療師';
  });

  testWidgets('治療師導覽點擊與滑動同步且不重複建立聊天監聽', (tester) async {
    final backend = _FakeChatBackend();
    await tester.pumpWidget(
      MaterialApp(
        home: TherapistHomeScreen(chatBackend: backend),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('首頁'), findsOneWidget);
    expect(find.text('訊息'), findsWidgets);
    expect(_selectedIndex(tester), 0);
    expect(find.text('新增自訂復健動作'), findsOneWidget);
    expect(find.text('已儲存自訂動作'), findsOneWidget);
    expect(find.text('患者管理'), findsOneWidget);
    expect(find.text('指派復健動作'), findsOneWidget);
    expect(find.text('登出'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('therapist-home-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('制定復健計畫'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('therapist-tab-chat')));
    await tester.pumpAndSettle();

    expect(_selectedIndex(tester), 1);
    expect(find.byType(ChatHomeScreen), findsOneWidget);
    expect(find.text('我的病患'), findsOneWidget);

    final pages = find.byKey(const ValueKey('therapist-tab-pages'));
    await tester.drag(pages, const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(_selectedIndex(tester), 0);

    await tester.drag(pages, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(_selectedIndex(tester), 1);
    expect(backend.contactsCalls, 1);
    expect(backend.conversationWatchCalls, 1);
    expect(backend.unreadWatchCalls, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
  });
}

int _selectedIndex(WidgetTester tester) {
  return tester
      .widget<BottomNavigationBar>(
        find.byKey(const ValueKey('therapist-bottom-navigation')),
      )
      .currentIndex;
}

class _FakeChatBackend implements ChatBackend {
  final StreamController<List<RemoteConversation>> _conversations =
      StreamController<List<RemoteConversation>>.broadcast();
  final StreamController<List<RemoteChatMessage>> _messages =
      StreamController<List<RemoteChatMessage>>.broadcast();
  final StreamController<List<UnreadCount>> _unreads =
      StreamController<List<UnreadCount>>.broadcast();

  int contactsCalls = 0;
  int conversationWatchCalls = 0;
  int unreadWatchCalls = 0;

  @override
  Future<List<ChatContact>> getContacts() async {
    contactsCalls++;
    return const [
      ChatContact(
        userId: 'patient-1',
        name: '測試患者',
        role: 'PATIENT',
        type: ConversationType.therapist,
      ),
    ];
  }

  @override
  Future<String> getOrCreateConversation({
    required String myUserId,
    required String otherUserId,
    required ConversationType type,
  }) async =>
      'conversation-1';

  @override
  Stream<List<RemoteConversation>> watchConversations(String myUserId) {
    conversationWatchCalls++;
    return _conversations.stream;
  }

  @override
  Stream<List<RemoteChatMessage>> watchMessages(String conversationId) =>
      _messages.stream;

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
  Stream<List<UnreadCount>> watchUnreadCounts(String myUserId) {
    unreadWatchCalls++;
    return _unreads.stream;
  }

  @override
  void refresh() {}

  @override
  void dispose() {
    unawaited(_conversations.close());
    unawaited(_messages.close());
    unawaited(_unreads.close());
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/remote_avatar_cache.dart';
import 'package:flutter_body/features/account/remote_user_avatar_repository.dart';
import 'package:flutter_body/features/account/user_avatar_api_client.dart';
import 'package:flutter_body/features/chat/chat_home_screen.dart';
import 'package:flutter_body/features/chat/chat_user_avatar.dart';
import 'package:flutter_body/features/chat/chat_models.dart';
import 'package:flutter_body/features/chat/remote_chat_screen.dart';

import 'remote_chat_screen_test.dart' show FakeChatBackend;

void main() {
  setUp(() {
    AppSession.userId = '15';
    AppSession.customExerciseToken = 'test-token';
  });
  tearDown(() {
    AppSession.userId = null;
    AppSession.customExerciseToken = null;
  });

  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
    'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  RemoteAvatarCache cacheFor(Future<http.Response> Function(http.Request) fn) =>
      RemoteAvatarCache(
          repository: RestRemoteUserAvatarRepository(
        apiClient: UserAvatarApiClient(
            baseUrl: 'https://example.test', httpClient: MockClient(fn)),
      ));

  test('cache deduplicates concurrent loads with existing identity headers',
      () async {
    var calls = 0;
    final response = Completer<http.Response>();
    final cache = cacheFor((request) {
      calls++;
      expect(request.url.path, '/api/users/25/avatar');
      expect(request.headers['X-User-Id'], '15');
      expect(request.headers['X-Custom-Exercise-Token'], 'test-token');
      return response.future;
    });
    final a = cache.get('25');
    final b = cache.get('25');
    expect(identical(a, b), isTrue);
    response.complete(
        http.Response.bytes(png, 200, headers: {'content-type': 'image/png'}));
    expect((await a)!.bytes, png);
    await b;
    await cache.get('25');
    expect(calls, 1);
  });

  for (final status in [404, 401, 403, 500]) {
    test('cache remembers $status fallback without automatic retries',
        () async {
      var calls = 0;
      final cache = cacheFor((_) async {
        calls++;
        return http.Response('', status);
      });
      expect(await cache.get('25'), isNull);
      expect(await cache.get('25'), isNull);
      expect(calls, 1);
    });
  }

  test('changed viewer cannot reuse prior authenticated cache', () async {
    var calls = 0;
    final cache = cacheFor((_) async {
      calls++;
      return http.Response('', 404);
    });
    await cache.get('25');
    AppSession.userId = '99';
    await cache.get('25');
    expect(calls, 2);
  });

  test('network failure is cached and missing identity sends no request',
      () async {
    var calls = 0;
    final cache = cacheFor((_) async {
      calls++;
      throw http.ClientException('offline');
    });
    expect(await cache.get('25'), isNull);
    expect(await cache.get('25'), isNull);
    expect(calls, 1);
    AppSession.customExerciseToken = null;
    expect(await cache.get('26'), isNull);
    expect(calls, 1);
  });

  testWidgets('ChatHome 404 keeps initials across reopen without retry',
      (tester) async {
    var calls = 0;
    final cache = cacheFor((_) async {
      calls++;
      return http.Response('', 404);
    });
    final backend = FakeChatBackend(contacts: const [
      ChatContact(
          userId: '25',
          name: '好友',
          role: 'PATIENT',
          type: ConversationType.peer),
    ]);
    for (var visit = 0; visit < 2; visit++) {
      await tester.pumpWidget(MaterialApp(
          home: ChatHomeScreen(backend: backend, avatarCache: cache)));
      await tester.pumpAndSettle();
      expect(find.text('好'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    await tester.pump(const Duration(minutes: 3));
    expect(calls, 1);
    backend.dispose();
  });

  testWidgets('ChatHome shows initials immediately then remote image',
      (tester) async {
    final response = Completer<http.Response>();
    var calls = 0;
    final cache = cacheFor((_) {
      calls++;
      return response.future;
    });
    final backend = FakeChatBackend(contacts: const [
      ChatContact(
          userId: '25',
          name: '好友',
          role: 'PATIENT',
          type: ConversationType.peer),
    ]);
    await tester.pumpWidget(MaterialApp(
        home: ChatHomeScreen(backend: backend, avatarCache: cache)));
    await tester.pump();
    expect(find.text('好'), findsOneWidget);
    response.complete(
        http.Response.bytes(png, 200, headers: {'content-type': 'image/png'}));
    await tester.pump();
    await tester.pump();
    expect(
        find.descendant(
            of: find.byType(ChatUserAvatar), matching: find.byType(Image)),
        findsOneWidget);
    await tester.pump(const Duration(minutes: 3));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('AppBar and received bubbles share one load; own bubble has none',
      (tester) async {
    var calls = 0;
    final cache = cacheFor((_) async {
      calls++;
      return http.Response.bytes(png, 200,
          headers: {'content-type': 'image/png'});
    });
    final backend = FakeChatBackend();
    await tester.pumpWidget(MaterialApp(
        home: RemoteChatScreen(
      backend: backend,
      avatarCache: cache,
      conversationId: '123',
      otherUserId: '25',
      otherUserName: '好友',
      conversationType: ConversationType.peer,
    )));
    backend.messages.add([
      RemoteChatMessage(
          id: '1',
          conversationId: '123',
          senderId: '25',
          text: '你好',
          sentAt: DateTime(2026)),
      RemoteChatMessage(
          id: '2',
          conversationId: '123',
          senderId: '15',
          text: '好',
          sentAt: DateTime(2026)),
    ]);
    await tester.pump();
    await tester.pump();
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.byType(ChatUserAvatar)),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('remote-message-1-other')),
            matching: find.byType(ChatUserAvatar)),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('remote-message-2-mine')),
            matching: find.byType(ChatUserAvatar)),
        findsNothing);
    expect(
        find.descendant(
            of: find.byType(ChatUserAvatar), matching: find.byType(Image)),
        findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('remote-chat-refresh')));
    await tester.pump();
    expect(backend.refreshCalls, 1);
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    backend.dispose();
  });

  testWidgets(
      'invalid image falls back and late completion after dispose is safe',
      (tester) async {
    final response = Completer<http.Response>();
    final cache = cacheFor((_) => response.future);
    await tester.pumpWidget(MaterialApp(
        home: ChatUserAvatar(userId: '25', name: '友', cache: cache)));
    await tester.pumpWidget(const SizedBox());
    response.complete(http.Response.bytes([1, 2, 3], 200,
        headers: {'content-type': 'image/png'}));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(
        home: ChatUserAvatar(userId: '25', name: '友', cache: cache)));
    await tester.pumpAndSettle();
    expect(find.text('友'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/chat/chat_realtime_connection.dart';
import 'package:flutter_body/features/chat/rest_chat_backend.dart';

class FakeTransport implements ChatRealtimeTransport {
  FakeTransport(
      this.url, this.headers, this.connected, this.event, this.disconnected);
  final Uri url;
  final Map<String, String> headers;
  final void Function() connected;
  final void Function(ChatRealtimeEvent) event;
  final void Function(bool) disconnected;
  bool stopped = false;
  @override
  void start() {}
  @override
  void stop() {
    stopped = true;
  }
}

class FakeWire {
  final transports = <FakeTransport>[];
  ChatRealtimeTransport create({
    required Uri url,
    required Map<String, String> headers,
    required void Function() onConnected,
    required void Function(ChatRealtimeEvent) onEvent,
    required void Function(bool) onDisconnected,
  }) {
    final transport =
        FakeTransport(url, headers, onConnected, onEvent, onDisconnected);
    transports.add(transport);
    return transport;
  }
}

http.Response jsonResponse(Object value) =>
    http.Response(jsonEncode(value), 200,
        headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HTTPS/HTTP derive WSS/WS with no credential query', () {
    expect(ChatRealtimeConnection.urlFromBase('https://example.test/'),
        Uri.parse('wss://example.test/ws/chat'));
    expect(ChatRealtimeConnection.urlFromBase('http://localhost:8080'),
        Uri.parse('ws://localhost:8080/ws/chat'));
    expect(() => ChatRealtimeConnection.urlFromBase('ftp://example.test'),
        throwsArgumentError);
  });

  test('invalid and unknown event payloads safely ignored', () {
    expect(ChatRealtimeEvent.parse('invalid'), isNull);
    expect(ChatRealtimeEvent.parse('{"type":"OTHER","conversationId":"123"}'),
        isNull);
    expect(
        ChatRealtimeEvent.parse(
            '{"type":"MESSAGE_READ","conversationId":null}'),
        isNull);
    expect(
        ChatRealtimeEvent.parse(
                '{"type":"MESSAGE_CREATED","conversationId":"123"}')
            ?.conversationId,
        '123');
  });

  test(
      'real STOMP client performs CONNECT and private SUBSCRIBE over local WebSocket',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final event = Completer<ChatRealtimeEvent>();
    final connected = Completer<void>();
    final captured = <String>[];
    WebSocket? socket;
    server.listen((request) async {
      expect(request.uri.path, '/ws/chat');
      expect(request.uri.query, isEmpty);
      socket = await WebSocketTransformer.upgrade(request);
      socket!.listen((data) {
        final frame = data is String ? data : utf8.decode(data as List<int>);
        captured.add(frame);
        if (frame.startsWith('CONNECT') || frame.startsWith('STOMP')) {
          socket!.add('CONNECTED\nversion:1.2\nheart-beat:0,0\n\n\u0000');
        } else if (frame.startsWith('SUBSCRIBE')) {
          final id = RegExp(r'\nid:([^\n]+)').firstMatch(frame)!.group(1)!;
          final body =
              jsonEncode({'type': 'MESSAGE_CREATED', 'conversationId': '123'});
          final ready = jsonEncode({'type': 'CONNECTION_READY'});
          socket!.add(
              'MESSAGE\nsubscription:$id\nmessage-id:ready\ncontent-type:application/json\ncontent-length:${utf8.encode(ready).length}\n\n$ready\u0000');
          socket!.add(
              'MESSAGE\nsubscription:$id\nmessage-id:1\ndestination:/user/queue/chat-events\ncontent-type:application/json\ncontent-length:${utf8.encode(body).length}\n\n$body\u0000');
        }
      });
    });
    final transport = StompChatTransport(
      url: Uri.parse('ws://127.0.0.1:${server.port}/ws/chat'),
      headers: {
        'X-User-Id': '15',
        'X-Custom-Exercise-Token': 'synthetic-fixture'
      },
      onConnected: connected.complete,
      onEvent: (value) {
        if (!event.isCompleted) event.complete(value);
      },
      onDisconnected: (_) {},
    );
    try {
      transport.start();
      await connected.future.timeout(const Duration(seconds: 5));
      expect(
          (await event.future.timeout(const Duration(seconds: 5)))
              .conversationId,
          '123');
      expect(captured.first, contains('X-User-Id:15'));
      expect(captured.first,
          contains('X-Custom-Exercise-Token:synthetic-fixture'));
      expect(
          captured.any(
              (frame) => frame.contains('destination:/user/queue/chat-events')),
          isTrue);
    } finally {
      transport.stop();
      await socket?.close();
      await server.close(force: true);
    }
  });

  testWidgets(
      'bounded exponential reconnect, background stop and no duplicate connections',
      (tester) async {
    final wire = FakeWire();
    var catchUps = 0;
    final connection = ChatRealtimeConnection(
        url: Uri.parse('wss://example.test/ws/chat'),
        headers: {},
        isCurrentSession: () => true,
        onConnected: () => catchUps++,
        onEvent: (_) {},
        transportFactory: wire.create,
        maxRetries: 3);
    connection.resume();
    connection.resume();
    expect(wire.transports, hasLength(1));
    wire.transports.last.disconnected(false);
    await tester.pump(const Duration(milliseconds: 999));
    expect(wire.transports, hasLength(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(wire.transports, hasLength(2));
    wire.transports.last.disconnected(false);
    await tester.pump(const Duration(seconds: 2));
    expect(wire.transports, hasLength(3));
    wire.transports.last.disconnected(false);
    await tester.pump(const Duration(seconds: 4));
    expect(wire.transports, hasLength(4));
    wire.transports.last.disconnected(false);
    await tester.pump(const Duration(seconds: 60));
    expect(wire.transports, hasLength(4));
    connection.resume();
    wire.transports.last.connected();
    expect(catchUps, 1);
    connection.pause();
    expect(wire.transports.last.stopped, isTrue);
    connection.resume();
    expect(wire.transports, hasLength(6));
    connection.dispose();
    await tester.pump(const Duration(seconds: 60));
    expect(wire.transports, hasLength(6));
  });

  testWidgets(
      'invalid identity is not retried and stale account events are ignored',
      (tester) async {
    final wire = FakeWire();
    var current = true;
    var delivered = 0;
    final connection = ChatRealtimeConnection(
        url: Uri.parse('wss://example.test/ws/chat'),
        headers: {},
        isCurrentSession: () => current,
        onConnected: () {},
        onEvent: (_) => delivered++,
        transportFactory: wire.create);
    connection.resume();
    wire.transports.single.disconnected(true);
    await tester.pump(const Duration(seconds: 60));
    expect(wire.transports, hasLength(1));
    connection.resume();
    current = false;
    wire.transports.last
        .event(const ChatRealtimeEvent('MESSAGE_CREATED', '123'));
    expect(delivered, 0);
    connection.dispose();
  });

  test(
      'events update messages, unread and lists without downloading contacts or unrelated rooms',
      () async {
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 10));
    final wire = FakeWire();
    final requests = <String>[];
    var read = false;
    var messages = 0;
    var unread = 0;
    final backend = RestChatBackend(
        baseUrl: 'https://example.test',
        realtimeTransportFactory: wire.create,
        userIdProvider: () => '15',
        identityTokenProvider: () => 'fixture',
        httpClient: MockClient((request) async {
          requests.add(request.url.path);
          if (request.url.path.endsWith('/messages')) {
            return jsonResponse([
              {
                'id': 456,
                'conversationId': 123,
                'senderId': 15,
                'text': 'fixture',
                'sentAt': '2026-10-03T01:00:00Z',
                'readAt': read ? '2026-10-03T01:01:00Z' : null
              }
            ]);
          }
          if (request.url.path.endsWith('/unread-counts')) {
            return jsonResponse([
              {'conversationId': 123, 'count': read ? 0 : 1}
            ]);
          }
          return jsonResponse([]);
        }));
    final subscriptions = [
      backend.watchMessages('123').listen((value) {
        expectSync(value, hasLength(1));
        messages++;
        expectSync(value.single.isRead, read);
      }),
      backend.watchConversations('15').listen((_) {}),
      backend.watchUnreadCounts('15').listen((value) {
        unread = value.single.count;
      }),
    ];
    await settle();
    expect(wire.transports, hasLength(1));
    expect(wire.transports.single.headers['X-User-Id'], '15');
    requests.clear();
    wire.transports.single
        .event(const ChatRealtimeEvent('MESSAGE_CREATED', '123'));
    await settle();
    expect(messages, 2);
    expect(unread, 1);
    expect(requests.toSet(), {
      '/api/chat/conversations/123/messages',
      '/api/chat/conversations',
      '/api/chat/unread-counts'
    });
    requests.clear();
    read = true;
    wire.transports.single
        .event(const ChatRealtimeEvent('MESSAGE_READ', '123'));
    await settle();
    expect(messages, 3);
    expect(unread, 0);
    expect(requests, isNot(contains('/api/chat/conversations')));
    requests.clear();
    wire.transports.single
        .event(const ChatRealtimeEvent('MESSAGE_CREATED', '999'));
    await settle();
    expect(requests, isNot(contains('/api/chat/conversations/999/messages')));
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    backend.dispose();
  });

  test(
      'refresh received during request schedules one follow-up and loses no last event',
      () async {
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 10));
    final first = Completer<http.Response>();
    var requests = 0;
    var emissions = 0;
    final backend = RestChatBackend(
        userIdProvider: () => '15',
        identityTokenProvider: () => 'fixture',
        httpClient: MockClient((_) async {
          requests++;
          return requests == 1 ? await first.future : jsonResponse([]);
        }));
    final subscription =
        backend.watchMessages('123').listen((_) => emissions++);
    await settle();
    backend.refresh();
    backend.refresh();
    backend.refresh();
    expect(requests, 1);
    first.complete(jsonResponse([]));
    await settle();
    expect(requests, 2);
    expect(emissions, 2);
    await subscription.cancel();
    backend.dispose();
  });

  test(
      'resume catches up REST, pauses socket, then last listener and logout close it',
      () async {
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 10));
    final wire = FakeWire();
    var requests = 0;
    String? user = '15';
    final backend = RestChatBackend(
        realtimeTransportFactory: wire.create,
        userIdProvider: () => user,
        identityTokenProvider: () => 'fixture',
        httpClient: MockClient((_) async {
          requests++;
          return jsonResponse([]);
        }));
    final subscription = backend.watchMessages('123').listen((_) {});
    await settle();
    final initial = requests;
    backend.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(wire.transports.single.stopped, isTrue);
    wire.transports.single
        .event(const ChatRealtimeEvent('MESSAGE_CREATED', '123'));
    await settle();
    expect(requests, initial);
    backend.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();
    expect(requests, greaterThan(initial));
    expect(wire.transports, hasLength(2));
    wire.transports.last.connected();
    await settle(); // reconnect catch-up
    user = null;
    AppSession.changes.value++;
    expect(wire.transports.last.stopped, isTrue);
    final afterLogout = requests;
    wire.transports.last
        .event(const ChatRealtimeEvent('MESSAGE_CREATED', '123'));
    await settle();
    expect(requests, afterLogout);
    await subscription.cancel();
    backend.dispose();
  });

  test(
      'no listeners means no queries or reconnect, REST works with socket unavailable',
      () async {
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 10));
    final wire = FakeWire();
    var requests = 0;
    final backend = RestChatBackend(
        realtimeTransportFactory: wire.create,
        userIdProvider: () => '15',
        identityTokenProvider: () => 'fixture',
        httpClient: MockClient((request) async {
          requests++;
          return request.method == 'POST'
              ? http.Response('{}', 201)
              : jsonResponse([]);
        }));
    final subscription = backend.watchMessages('123').listen((_) {});
    await settle();
    wire.transports.single.disconnected(false);
    await backend.sendMessage(
        conversationId: '123', senderId: '15', text: 'fixture');
    await settle();
    await subscription.cancel();
    expect(wire.transports.single.stopped, isTrue);
    final beforeIdle = requests;
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(requests, beforeIdle);
    expect(wire.transports, hasLength(1));
    backend.dispose();
  });
}

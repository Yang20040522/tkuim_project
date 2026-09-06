import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_body/features/chat/chat_models.dart';
import 'package:flutter_body/features/chat/rest_chat_backend.dart';

void main() {
  test('JSON Long ids map to String model ids', () {
    final conversation = RemoteConversation.fromJson({
      'id': 123,
      'type': 'peer',
      'participantIds': [15, 25],
      'lastMessageText': null,
      'lastMessageAt': null,
      'updatedAt': '2026-09-06T01:02:03Z',
    });
    final message = RemoteChatMessage.fromJson({
      'id': 456,
      'conversationId': 123,
      'senderId': 25,
      'text': 'hello',
      'sentAt': '2026-09-06T01:03:00Z',
      'readAt': null,
    });

    expect(conversation.id, '123');
    expect(conversation.participantIds, ['15', '25']);
    expect(message.id, '456');
    expect(message.conversationId, '123');
    expect(message.senderId, '25');
  });

  test('get/create sends relationship target but never authoritative senderId',
      () async {
    late http.Request captured;
    final backend = _backend(
      MockClient((request) async {
        captured = request;
        return _jsonResponse(200, {
          'id': 123,
          'type': 'peer',
          'participantIds': [15, 25],
          'lastMessageText': null,
          'lastMessageAt': null,
          'updatedAt': '2026-09-06T01:02:03Z',
        });
      }),
    );

    final id = await backend.getOrCreateConversation(
      myUserId: '15',
      otherUserId: '25',
      type: ConversationType.peer,
    );

    expect(id, '123');
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/chat/conversations');
    expect(captured.headers['X-User-Id'], '15');
    expect(captured.headers['X-Custom-Exercise-Token'], 'signed-token');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body, {'otherUserId': '25', 'type': 'peer'});
    expect(body, isNot(contains('senderId')));
    backend.dispose();
  });

  test('message polling maps message ids and sender ids', () async {
    final backend = _backend(
      MockClient((request) async {
        expect(request.url.path, '/api/chat/conversations/123/messages');
        return _jsonResponse(200, [
          {
            'id': 456,
            'conversationId': 123,
            'senderId': 25,
            'text': '跨裝置訊息',
            'sentAt': '2026-09-06T01:03:00Z',
            'readAt': '2026-09-06T01:04:00Z',
          }
        ]);
      }),
    );

    final messages = await backend.watchMessages('123').first;

    expect(messages.single.id, '456');
    expect(messages.single.senderId, '25');
    expect(messages.single.isRead, isTrue);
    backend.dispose();
  });

  test('unread polling maps numeric values', () async {
    final backend = _backend(
      MockClient((request) async {
        expect(request.url.path, '/api/chat/unread-counts');
        return _jsonResponse(200, [
          {'conversationId': 123, 'count': 3}
        ]);
      }),
    );

    final counts = await backend.watchUnreadCounts('15').first;

    expect(counts.single.conversationId, '123');
    expect(counts.single.count, 3);
    backend.dispose();
  });

  test('missing session identity fails before sending an HTTP request',
      () async {
    var requestCount = 0;
    final backend = RestChatBackend(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        requestCount++;
        return _jsonResponse(200, []);
      }),
      userIdProvider: () => null,
      identityTokenProvider: () => 'signed-token',
    );

    await expectLater(
      backend.getContacts(),
      throwsA(
        isA<ChatApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(requestCount, 0);
    backend.dispose();
  });

  test('slow polling never overlaps the same request', () async {
    var activeRequests = 0;
    var maxActiveRequests = 0;
    var requestCount = 0;
    final firstResponse = Completer<http.Response>();
    final backend = RestChatBackend(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        requestCount++;
        activeRequests++;
        if (activeRequests > maxActiveRequests) {
          maxActiveRequests = activeRequests;
        }
        final response = await firstResponse.future;
        activeRequests--;
        return response;
      }),
      userIdProvider: () => '15',
      identityTokenProvider: () => 'signed-token',
      messagePollInterval: const Duration(seconds: 1),
    );
    final subscription = backend.watchMessages('123').listen((_) {});

    await Future<void>.delayed(const Duration(milliseconds: 1150));
    expect(requestCount, 1);
    expect(maxActiveRequests, 1);

    firstResponse.complete(_jsonResponse(200, []));
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    backend.dispose();
  });
}

RestChatBackend _backend(http.Client client) => RestChatBackend(
      baseUrl: 'https://example.test',
      httpClient: client,
      userIdProvider: () => '15',
      identityTokenProvider: () => 'signed-token',
    );

http.Response _jsonResponse(int statusCode, Object body) => http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

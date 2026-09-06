import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_body/features/friends/friend_api_service.dart';

void main() {
  const baseUrl = 'https://example.test';

  FriendApiService serviceWith(
    Future<http.Response> Function(http.Request) handler,
  ) {
    return FriendApiService(
      baseUrl: baseUrl,
      client: MockClient(handler),
      userIdProvider: () => '9223372036854775807',
      identityTokenProvider: () => 'signed-token',
    );
  }

  test('send request uses authenticated headers and friendCode-only body',
      () async {
    late http.Request captured;
    final service = serviceWith((request) async {
      captured = request;
      return jsonResponse({'message': '好友邀請已送出'}, 200);
    });

    await service.sendFriendRequest('  abcd1234  ');

    expect(captured.method, 'POST');
    expect(captured.url.toString(), '$baseUrl/api/friends/requests');
    expect(captured.headers['X-User-Id'], '9223372036854775807');
    expect(captured.headers['X-Custom-Exercise-Token'], 'signed-token');
    expect(captured.headers['Accept'], 'application/json');
    expect(captured.headers['Content-Type'], contains('application/json'));
    expect(jsonDecode(captured.body), {'friendCode': 'ABCD1234'});
    expect(captured.body, isNot(contains('senderId')));
  });

  test('pending requests parse backend Long IDs as strings', () async {
    final service = serviceWith((_) async => jsonResponse(
          [
            {
              'requestId': 9223372036854775807,
              'senderId': 1234567890123456789,
              'senderName': '王小明',
              'senderFriendCode': 'abcd1234',
              'status': 'PENDING',
              'createdAt': '2026-09-06T10:00:00',
            }
          ],
          200,
        ));

    final result = await service.getPendingRequests();

    expect(result.single.requestId, '9223372036854775807');
    expect(result.single.senderId, '1234567890123456789');
    expect(result.single.senderFriendCode, 'ABCD1234');
  });

  test('sent requests use authenticated endpoint and parse receiver', () async {
    late http.Request captured;
    final service = serviceWith((request) async {
      captured = request;
      return jsonResponse(
        [
          {
            'requestId': 12,
            'receiverId': 88,
            'receiverName': '陳小華',
            'receiverFriendCode': 'EFGH5678',
            'status': 'PENDING',
            'createdAt': '2026-09-06T10:00:00',
          }
        ],
        200,
      );
    });

    final result = await service.getSentRequests();

    expect(captured.url.path, '/api/friends/requests/sent');
    expect(result.single.receiverId, '88');
    expect(result.single.receiverName, '陳小華');
  });

  test('friends endpoint parses friend list', () async {
    final service = serviceWith((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/friends');
      return jsonResponse(
        [
          {
            'friendshipId': 7,
            'friendId': 2,
            'friendName': '病患 B',
            'friendCode': 'bbbb2222',
            'createdAt': '2026-09-06T10:00:00',
          }
        ],
        200,
      );
    });

    final result = await service.getFriends();

    expect(result.single.friendId, '2');
    expect(result.single.friendCode, 'BBBB2222');
  });

  test('accept and reject use respond endpoint with action-only body',
      () async {
    final requests = <http.Request>[];
    final service = serviceWith((request) async {
      requests.add(request);
      return http.Response('{}', 200);
    });

    await service.acceptRequest('12');
    await service.rejectRequest('13');

    expect(requests.map((request) => request.method), everyElement('PUT'));
    expect(requests[0].url.path, '/api/friends/requests/12/respond');
    expect(jsonDecode(requests[0].body), {'action': 'ACCEPT'});
    expect(jsonDecode(requests[1].body), {'action': 'REJECT'});
    expect(requests[0].body, isNot(contains('receiverId')));
  });

  test('cancel and remove use current-user scoped DELETE endpoints', () async {
    final requests = <http.Request>[];
    final service = serviceWith((request) async {
      requests.add(request);
      return http.Response('{}', 200);
    });

    await service.cancelRequest('12');
    await service.removeFriend('2');

    expect(requests[0].url.path, '/api/friends/requests/12');
    expect(requests[0].url.query, isEmpty);
    expect(requests[1].url.path, '/api/friends/2');
    expect(requests[1].url.path, isNot(contains('9223372036854775807')));
  });

  test('backend JSON message is surfaced without raw transport content',
      () async {
    final service = serviceWith((_) async => jsonResponse(
          {'message': '找不到此好友代碼'},
          404,
        ));

    expect(
      () => service.sendFriendRequest('NOPE0000'),
      throwsA(
        isA<FriendApiException>()
            .having((error) => error.message, 'message', '找不到此好友代碼')
            .having((error) => error.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('401, 403 and malformed HTML return safe user messages', () async {
    for (final status in [401, 403]) {
      final service = serviceWith(
        (_) async => http.Response('<html>secret</html>', status),
      );
      await expectLater(
        service.getFriends(),
        throwsA(
          isA<FriendApiException>().having(
            (error) => error.message,
            'message',
            '登入狀態已失效，請重新登入',
          ),
        ),
      );
    }

    final service = serviceWith(
      (_) async => http.Response('<html>server trace</html>', 500),
    );
    await expectLater(
      service.getFriends(),
      throwsA(
        isA<FriendApiException>()
            .having(
              (error) => error.message,
              'message',
              '好友操作失敗，請稍後再試',
            )
            .having(
              (error) => error.message,
              'no HTML',
              isNot(contains('html')),
            ),
      ),
    );
  });

  test('missing session identity fails before sending a request', () async {
    var requested = false;
    final service = FriendApiService(
      baseUrl: baseUrl,
      client: MockClient((_) async {
        requested = true;
        return http.Response('[]', 200);
      }),
      userIdProvider: () => null,
      identityTokenProvider: () => null,
    );

    await expectLater(
      service.getFriends(),
      throwsA(
        isA<FriendApiException>().having(
          (error) => error.message,
          'message',
          '登入狀態已失效，請重新登入',
        ),
      ),
    );
    expect(requested, isFalse);
  });
}

http.Response jsonResponse(Object body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

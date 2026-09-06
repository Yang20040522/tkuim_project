import 'dart:convert';
import 'dart:io';

import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/user_avatar_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const baseUrl = 'https://example.test';

  setUp(() {
    AppSession.userId = '16';
    AppSession.customExerciseToken = 'signed-token';
  });

  tearDown(() {
    AppSession.userId = null;
    AppSession.customExerciseToken = null;
  });

  test('upload uses multipart file field and authenticated headers', () async {
    final directory = await Directory.systemTemp.createTemp('avatar-api-test');
    addTearDown(() => directory.delete(recursive: true));
    final image = await File(
      '${directory.path}${Platform.pathSeparator}avatar.png',
    ).writeAsBytes(const [0x89, 0x50, 0x4E, 0x47]);
    final transport = _RecordingClient(responseStatus: 204);
    final client = UserAvatarApiClient(
      baseUrl: baseUrl,
      httpClient: transport,
    );

    await client.uploadCurrentUserAvatar(image.path);

    final request = transport.lastRequest as http.MultipartRequest;
    expect(request.method, 'PUT');
    expect(request.url.path, '/api/account/avatar');
    expect(request.headers['X-User-Id'], '16');
    expect(request.headers['X-Custom-Exercise-Token'], 'signed-token');
    expect(request.files, hasLength(1));
    expect(request.files.single.field, 'file');
    expect(request.files.single.contentType.toString(), 'image/png');
    expect(request.files.single.filename, 'avatar.png');
  });

  test('GET sends identity and returns raw bytes with content type', () async {
    final transport = _RecordingClient(
      responseStatus: 200,
      responseBody: const [1, 2, 3],
      responseHeaders: const {'content-type': 'image/webp'},
    );
    final client = UserAvatarApiClient(
      baseUrl: baseUrl,
      httpClient: transport,
    );

    final avatar = await client.getUserAvatar('25');

    expect(transport.lastRequest!.method, 'GET');
    expect(transport.lastRequest!.url.path, '/api/users/25/avatar');
    expect(transport.lastRequest!.headers['X-User-Id'], '16');
    expect(
      transport.lastRequest!.headers['X-Custom-Exercise-Token'],
      'signed-token',
    );
    expect(avatar!.bytes, [1, 2, 3]);
    expect(avatar.contentType, 'image/webp');
  });

  test('GET 404 returns null', () async {
    final client = UserAvatarApiClient(
      baseUrl: baseUrl,
      httpClient: _RecordingClient(responseStatus: 404),
    );

    expect(await client.getUserAvatar('25'), isNull);
  });

  test('GET 401 and 403 remain actionable API failures', () async {
    for (final status in [401, 403]) {
      final client = UserAvatarApiClient(
        baseUrl: baseUrl,
        httpClient: _RecordingClient(
          responseStatus: status,
          responseBody: utf8.encode(
            jsonEncode({'code': 'DENIED', 'message': '拒絕存取'}),
          ),
          responseHeaders: const {'content-type': 'application/json'},
        ),
      );

      await expectLater(
        client.getUserAvatar('25'),
        throwsA(
          isA<UserAvatarApiFailure>()
              .having((error) => error.statusCode, 'statusCode', status)
              .having((error) => error.code, 'code', 'DENIED'),
        ),
      );
    }
  });

  test('HTTPS Google image downloads and uploads authenticated multipart',
      () async {
    final transport = _QueuedRecordingClient([
      const _ResponseSpec(
        200,
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
        {'content-type': 'image/png'},
      ),
      const _ResponseSpec(204),
    ]);
    final client = UserAvatarApiClient(
      baseUrl: baseUrl,
      httpClient: transport,
    );

    await client.syncGoogleAvatar('https://photos.example.test/avatar');

    expect(transport.requests, hasLength(2));
    expect(transport.requests.first.url.scheme, 'https');
    final upload = transport.requests.last as http.MultipartRequest;
    expect(upload.url.path, '/api/account/avatar/google');
    expect(upload.headers['X-User-Id'], '16');
    expect(upload.headers['X-Custom-Exercise-Token'], 'signed-token');
    expect(upload.files.single.field, 'file');
    expect(upload.files.single.contentType.toString(), 'image/png');
  });

  test('unsafe URL and invalid image response never upload Google avatar',
      () async {
    final unsafeTransport = _QueuedRecordingClient([]);
    final unsafeClient = UserAvatarApiClient(
      baseUrl: baseUrl,
      httpClient: unsafeTransport,
    );
    await expectLater(
      unsafeClient.syncGoogleAvatar('http://example.test/avatar.jpg'),
      throwsA(isA<UserAvatarApiFailure>()),
    );
    expect(unsafeTransport.requests, isEmpty);

    final invalidTransport = _QueuedRecordingClient([
      const _ResponseSpec(
        200,
        [1, 2, 3],
        {'content-type': 'text/html'},
      ),
    ]);
    final invalidClient = UserAvatarApiClient(
      baseUrl: baseUrl,
      httpClient: invalidTransport,
    );
    await expectLater(
      invalidClient.syncGoogleAvatar('https://example.test/avatar'),
      throwsA(isA<UserAvatarApiFailure>()),
    );
    expect(invalidTransport.requests, hasLength(1));
  });

  test('Google avatar larger than 5 MB is not uploaded', () async {
    final transport = _QueuedRecordingClient([
      _ResponseSpec(
        200,
        List<int>.filled(UserAvatarApiClient.maxAvatarBytes + 1, 0),
        const {'content-type': 'image/jpeg'},
      ),
    ]);
    final client = UserAvatarApiClient(
      baseUrl: baseUrl,
      httpClient: transport,
    );

    await expectLater(
      client.syncGoogleAvatar('https://example.test/avatar.jpg'),
      throwsA(
        isA<UserAvatarApiFailure>().having(
          (error) => error.statusCode,
          'statusCode',
          413,
        ),
      ),
    );
    expect(transport.requests, hasLength(1));
  });

  test('missing user id prevents any HTTP request', () async {
    AppSession.userId = null;
    final transport = _RecordingClient(responseStatus: 200);
    final client = UserAvatarApiClient(
      baseUrl: baseUrl,
      httpClient: transport,
    );

    await expectLater(
      client.getUserAvatar('25'),
      throwsA(isA<UserAvatarApiFailure>()),
    );
    expect(transport.calls, 0);
  });

  test('missing identity token prevents any HTTP request', () async {
    AppSession.customExerciseToken = null;
    final transport = _RecordingClient(responseStatus: 200);
    final client = UserAvatarApiClient(
      baseUrl: baseUrl,
      httpClient: transport,
    );

    await expectLater(
      client.getUserAvatar('25'),
      throwsA(isA<UserAvatarApiFailure>()),
    );
    expect(transport.calls, 0);
  });
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient({
    required this.responseStatus,
    this.responseBody = const [],
    this.responseHeaders = const {},
  });

  final int responseStatus;
  final List<int> responseBody;
  final Map<String, String> responseHeaders;
  http.BaseRequest? lastRequest;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    lastRequest = request;
    return http.StreamedResponse(
      Stream<List<int>>.value(responseBody),
      responseStatus,
      headers: responseHeaders,
    );
  }
}

class _ResponseSpec {
  const _ResponseSpec(
    this.statusCode, [
    this.body = const [],
    this.headers = const {},
  ]);

  final int statusCode;
  final List<int> body;
  final Map<String, String> headers;
}

class _QueuedRecordingClient extends http.BaseClient {
  _QueuedRecordingClient(List<_ResponseSpec> responses)
      : _responses = List.of(responses);

  final List<_ResponseSpec> _responses;
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final response = _responses.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.body),
      response.statusCode,
      headers: response.headers,
    );
  }
}

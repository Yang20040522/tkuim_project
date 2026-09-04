import 'dart:convert';

import 'package:flutter_body/features/custom_exercise/repositories/remote_custom_exercise_repository.dart';
import 'package:flutter_body/features/custom_exercise/services/custom_exercise_api_client.dart';
import 'package:flutter_body/models/custom_rehab_exercise.dart';
import 'package:flutter_body/models/exercise_keyframe.dart';
import 'package:flutter_body/models/joint_rotation.dart';
import 'package:flutter_body/models/joint_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUrl = 'https://example.test';

  test('GET list 帶統一 identity headers 並還原完整 model', () async {
    final exercise = _exercise();
    final client = _client(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), '$baseUrl/api/custom-exercises');
        expect(request.headers['X-User-Id'], '7');
        expect(request.headers['X-Custom-Exercise-Token'], 'signed-token');
        return _jsonResponse([exercise.toJson()]);
      }),
    );

    final result = await client.getAllExercises();

    expect(result, hasLength(1));
    expect(result.single.toJson(), exercise.toJson());
  });

  test('GET one 將 404 映射為 null', () async {
    final client = _client(
      MockClient((request) async => http.Response('', 404)),
    );

    expect(await client.getExercise('missing'), isNull);
  });

  test('PUT upsert 直接傳送 CustomRehabExercise JSON', () async {
    final exercise = _exercise(id: 'custom 1');
    final client = _client(
      MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.pathSegments.last, 'custom 1');
        expect(jsonDecode(request.body), exercise.toJson());
        return _jsonResponse(exercise.toJson());
      }),
    );

    final saved = await client.saveExercise(exercise);

    expect(saved.toJson(), exercise.toJson());
  });

  test('DELETE 接受 204 response', () async {
    final client = _client(
      MockClient((request) async {
        expect(request.method, 'DELETE');
        return http.Response('', 204);
      }),
    );

    await client.deleteExercise('custom_1');
  });

  test('API error 解析安全的 server message 與 status code', () async {
    final client = _client(
      MockClient((request) async => _jsonResponse(
            {'message': '只有治療師可以管理自訂動作'},
            statusCode: 403,
          )),
    );

    await expectLater(
      client.getAllExercises(),
      throwsA(
        isA<CustomExerciseApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having(
              (error) => error.message,
              'message',
              '只有治療師可以管理自訂動作',
            ),
      ),
    );
  });

  test('缺少登入 token 時不送出 request 並提示重新登入', () async {
    var requested = false;
    final client = CustomExerciseApiClient(
      baseUrl: baseUrl,
      userIdProvider: () => '7',
      identityTokenProvider: () => null,
      httpClient: MockClient((request) async {
        requested = true;
        return http.Response('', 500);
      }),
    );

    await expectLater(
      client.getAllExercises(),
      throwsA(
        isA<CustomExerciseApiException>().having(
          (error) => error.message,
          'message',
          contains('重新登入'),
        ),
      ),
    );
    expect(requested, isFalse);
  });

  test('Remote repository 的 save 與 update 都維持 PUT upsert', () async {
    var putCount = 0;
    final exercise = _exercise();
    final repository = RemoteCustomExerciseRepository(
      apiClient: _client(
        MockClient((request) async {
          expect(request.method, 'PUT');
          putCount++;
          return _jsonResponse(exercise.toJson());
        }),
      ),
    );

    await repository.saveExercise(exercise);
    await repository.updateExercise(exercise.copyWith(name: '更新'));

    expect(putCount, 2);
  });
}

CustomExerciseApiClient _client(http.Client httpClient) {
  return CustomExerciseApiClient(
    baseUrl: 'https://example.test',
    userIdProvider: () => '7',
    identityTokenProvider: () => 'signed-token',
    httpClient: httpClient,
  );
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

CustomRehabExercise _exercise({String id = 'custom_1'}) {
  Map<JointType, JointRotation> pose(double offset) => {
        for (var index = 0; index < JointType.values.length; index++)
          JointType.values[index]: JointRotation(
            x: offset + index,
            y: offset - index,
            z: offset + index / 2,
          ),
      };

  return CustomRehabExercise(
    id: id,
    name: '肩部訓練',
    description: '完整 12 關節',
    createdByTherapistId: '7',
    createdAt: DateTime.utc(2026, 9, 4, 1),
    updatedAt: DateTime.utc(2026, 9, 4, 2),
    repetitions: 10,
    sets: 3,
    holdSeconds: 5,
    restSeconds: 30,
    duration: 1,
    keyframes: [
      ExerciseKeyframe(
        id: 'kf_001',
        time: 0,
        jointRotations: pose(0),
      ),
      ExerciseKeyframe(
        id: 'kf_002',
        time: 1,
        jointRotations: pose(20),
      ),
    ],
    evaluationRules: const [],
  );
}

import 'dart:convert';

import 'package:flutter_body/features/pose_measurement/services/training_result_api_client.dart';
import 'package:flutter_body/models/assignable_exercise.dart';
import 'package:flutter_body/models/training_session_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const body = {
    'sessionId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'exerciseType': 'CUSTOM',
    'exerciseId': 'custom-1',
    'exerciseName': '手肘訓練',
    'completedSets': 2,
    'completedReps': 6,
    'targetSets': 2,
    'targetReps': 3,
    'startedAt': '2026-09-05T01:00:00Z',
    'completedAt': '2026-09-05T01:00:30Z',
    'durationSeconds': 30,
    'completionStatus': 'COMPLETED',
    'score': 100.0,
  };

  test('save sends authenticated completion and parses response', () async {
    late http.Request captured;
    final client = TrainingResultApiClient(
      baseUrl: 'https://example.test',
      userIdProvider: () => '15',
      identityTokenProvider: () => 'signed-token',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(body), 201,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
    final result = TrainingSessionResult.fromJson(body);

    final saved = await client.save(result);

    expect(captured.url.path, '/api/training-results');
    expect(captured.headers['X-User-Id'], '15');
    expect(captured.headers['X-Custom-Exercise-Token'], 'signed-token');
    expect(jsonDecode(captured.body), isNot(contains('score')));
    expect(saved.exerciseName, '手肘訓練');
  });

  test('patient and therapist history use their protected routes', () async {
    final paths = <String>[];
    final client = TrainingResultApiClient(
      baseUrl: 'https://example.test',
      userIdProvider: () => '7',
      identityTokenProvider: () => 'signed-token',
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(jsonEncode([body]), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

    expect(await client.getMyResults(), hasLength(1));
    expect(await client.getPatientResults('15'), hasLength(1));
    expect(paths, [
      '/api/training-results/me',
      '/api/therapist/patients/15/training-results',
    ]);
  });

  test('result request preserves configured exercise identity and counts', () {
    final result = TrainingSessionResult(
      sessionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      exerciseType: AssignableExerciseType.custom,
      exerciseId: 'custom-1',
      exerciseName: '手肘訓練',
      completedSets: 2,
      completedReps: 6,
      targetSets: 2,
      targetReps: 3,
      startedAt: DateTime.utc(2026, 9, 5, 1),
      completedAt: DateTime.utc(2026, 9, 5, 1, 0, 30),
      durationSeconds: 30,
      status: TrainingCompletionStatus.completed,
      score: 100,
    );

    expect(result.toRequestJson(), {
      'sessionId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'exerciseType': 'CUSTOM',
      'exerciseId': 'custom-1',
      'completedSets': 2,
      'completedReps': 6,
      'targetSets': 2,
      'targetReps': 3,
      'durationSeconds': 30,
      'completionStatus': 'COMPLETED',
    });
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_body/features/custom_exercise/controllers/custom_exercise_playback_controller.dart';
import 'package:flutter_body/features/custom_exercise/custom_exercise_assignment_page.dart';
import 'package:flutter_body/features/custom_exercise/custom_exercise_playback_page.dart';
import 'package:flutter_body/features/custom_exercise/patient_custom_exercise_list_page.dart';
import 'package:flutter_body/features/custom_exercise/repositories/custom_exercise_assignment_repository.dart';
import 'package:flutter_body/features/custom_exercise/services/custom_exercise_assignment_api_client.dart';
import 'package:flutter_body/models/custom_exercise_assignment.dart';
import 'package:flutter_body/models/custom_rehab_exercise.dart';
import 'package:flutter_body/models/exercise_keyframe.dart';
import 'package:flutter_body/models/joint_rotation.dart';
import 'package:flutter_body/models/joint_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUrl = 'https://example.test';

  test('指派 API 解析治療師可指派患者清單', () async {
    final client = _client(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          '$baseUrl/api/custom-exercise-assignments/patients',
        );
        expect(request.headers['X-User-Id'], '7');
        expect(request.headers['X-Custom-Exercise-Token'], 'signed-token');
        return _jsonResponse([
          {'patientId': 15, 'patientName': '小明'},
        ]);
      }),
    );

    final patients = await client.getAssignablePatients();

    expect(patients, hasLength(1));
    expect(patients.single.patientId, '15');
    expect(patients.single.patientName, '小明');
  });

  test('指派 API 支援查詢、assign 與 unassign', () async {
    final requests = <http.Request>[];
    final client = _client(
      MockClient((request) async {
        requests.add(request);
        if (request.method == 'DELETE') return http.Response('', 204);
        return _jsonResponse(
          request.method == 'GET' ? [_assignmentJson()] : _assignmentJson(),
        );
      }),
    );

    final assignments = await client.getExerciseAssignments('custom 1');
    final assigned = await client.assign('custom 1', '15');
    await client.unassign('custom 1', '15');

    expect(assignments.single.patientId, '15');
    expect(assigned.exerciseId, 'custom 1');
    expect(requests.map((request) => request.method), ['GET', 'PUT', 'DELETE']);
    expect(requests[1].url.pathSegments, [
      'api',
      'custom-exercise-assignments',
      'custom 1',
      'patients',
      '15',
    ]);
  });

  test('患者 API 以現有 CustomRehabExercise model 解析清單與明細', () async {
    final exercise = _exercise();
    final client = _client(
      MockClient((request) async {
        if (request.url.pathSegments.last == 'custom_1') {
          return _jsonResponse(exercise.toJson());
        }
        return _jsonResponse([exercise.toJson()]);
      }),
    );

    final list = await client.getPatientExercises();
    final detail = await client.getPatientExercise('custom_1');

    expect(list.single.toJson(), exercise.toJson());
    expect(detail?.toJson(), exercise.toJson());
    expect(detail?.keyframes.first.jointRotations, hasLength(12));
  });

  test('缺少 HMAC token 時指派 API 不送出 HTTP request', () async {
    var requested = false;
    final client = CustomExerciseAssignmentApiClient(
      baseUrl: baseUrl,
      userIdProvider: () => '7',
      identityTokenProvider: () => null,
      httpClient: MockClient((request) async {
        requested = true;
        return http.Response('', 500);
      }),
    );

    await expectLater(
      client.getAssignablePatients(),
      throwsA(isA<Exception>()),
    );
    expect(requested, isFalse);
  });

  testWidgets('指派頁顯示已綁定患者 empty state', (tester) async {
    final repository = _MemoryAssignmentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: CustomExerciseAssignmentPage(
          exercise: _exercise(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('尚無已綁定的患者'), findsOneWidget);
  });

  testWidgets('指派頁可 assign 與 unassign 患者', (tester) async {
    final repository = _MemoryAssignmentRepository()
      ..patients = const [
        AssignablePatient(patientId: '15', patientName: '小明'),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: CustomExerciseAssignmentPage(
          exercise: _exercise(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('小明'), findsOneWidget);
    expect(find.text('未指派'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(repository.assignments, hasLength(1));
    expect(find.text('已指派'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(repository.assignments, isEmpty);
    expect(find.text('未指派'), findsOneWidget);
  });

  testWidgets('指派頁顯示 network error 與重試', (tester) async {
    final repository = _MemoryAssignmentRepository()
      ..loadError = StateError('network');
    await tester.pumpWidget(
      MaterialApp(
        home: CustomExerciseAssignmentPage(
          exercise: _exercise(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('讀取可指派患者失敗'), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);
  });

  testWidgets('患者動作清單讀取 detail 後傳給 playback page', (tester) async {
    final exercise = _exercise();
    final repository = _MemoryAssignmentRepository()
      ..patientExercises = [exercise];
    CustomRehabExercise? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: PatientCustomExerciseListPage(
          repository: repository,
          playbackBuilder: (exercise) {
            opened = exercise;
            return const Scaffold(body: Text('Playback opened'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('右肩復健'));
    await tester.pumpAndSettle();

    expect(opened?.toJson(), exercise.toJson());
    expect(find.text('Playback opened'), findsOneWidget);
  });

  testWidgets('患者動作清單顯示 empty state', (tester) async {
    final repository = _MemoryAssignmentRepository();
    await tester.pumpWidget(
      MaterialApp(home: PatientCustomExerciseListPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('治療師尚未指派自訂復健動作'), findsOneWidget);
  });

  testWidgets('患者動作清單顯示 network error 與重試', (tester) async {
    final repository = _MemoryAssignmentRepository()
      ..loadError = StateError('network');
    await tester.pumpWidget(
      MaterialApp(home: PatientCustomExerciseListPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('讀取已指派復健動作失敗'), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);
  });

  testWidgets('Playback page 只提供唯讀播放而不暴露編輯控制', (tester) async {
    final exercise = _exercise();
    await tester.pumpWidget(
      MaterialApp(home: CustomExercisePlaybackPage(exercise: exercise)),
    );
    await tester.pumpAndSettle();

    expect(find.text('右肩復健'), findsWidgets);
    expect(
        find.byKey(const Key('play-assigned-custom-exercise')), findsOneWidget);
    expect(find.byKey(const Key('read-only-custom-exercise-timeline')),
        findsOneWidget);
    expect(find.byKey(const Key('add-keyframe')), findsNothing);
    expect(find.byKey(const Key('save-custom-exercise')), findsNothing);
    expect(find.byKey(const Key('rightShoulder-x-slider')), findsNothing);
  });

  test('Playback controller 支援播放、暫停、繼續、完成與重播', () {
    final controller = CustomExercisePlaybackController(exercise: _exercise());

    controller.play();
    expect(controller.status, CustomExercisePlaybackStatus.playing);
    controller.updateProgress(0.5);
    controller.pause();
    expect(controller.status, CustomExercisePlaybackStatus.paused);
    controller.resume();
    controller.complete();
    expect(controller.isCompleted, isTrue);
    controller.play();
    expect(controller.playbackTime, 0);
    expect(controller.status, CustomExercisePlaybackStatus.playing);
  });
}

CustomExerciseAssignmentApiClient _client(http.Client httpClient) {
  return CustomExerciseAssignmentApiClient(
    baseUrl: 'https://example.test',
    userIdProvider: () => '7',
    identityTokenProvider: () => 'signed-token',
    httpClient: httpClient,
  );
}

Map<String, dynamic> _assignmentJson() => {
      'assignmentId': 101,
      'exerciseId': 'custom 1',
      'exerciseName': '右肩復健',
      'exerciseDescription': '緩慢完成',
      'therapistId': 7,
      'therapistName': '治療師',
      'patientId': 15,
      'patientName': '小明',
      'assignedAt': '2026-09-04T01:02:05Z',
    };

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

class _MemoryAssignmentRepository
    implements CustomExerciseAssignmentRepository {
  List<AssignablePatient> patients = const [];
  List<CustomExerciseAssignment> assignments = const [];
  List<CustomRehabExercise> patientExercises = const [];
  Object? loadError;

  @override
  Future<CustomExerciseAssignment> assign(
    String exerciseId,
    String patientId,
  ) async {
    final assignment = CustomExerciseAssignment.fromJson(_assignmentJson());
    assignments = [...assignments, assignment];
    return assignment;
  }

  @override
  Future<List<AssignablePatient>> getAssignablePatients() async {
    final error = loadError;
    if (error != null) throw error;
    return patients;
  }

  @override
  Future<List<CustomExerciseAssignment>> getExerciseAssignments(
    String exerciseId,
  ) async {
    final error = loadError;
    if (error != null) throw error;
    return assignments;
  }

  @override
  Future<CustomRehabExercise?> getPatientExercise(String exerciseId) async {
    final error = loadError;
    if (error != null) throw error;
    for (final exercise in patientExercises) {
      if (exercise.id == exerciseId) return exercise;
    }
    return null;
  }

  @override
  Future<List<CustomRehabExercise>> getPatientExercises() async {
    final error = loadError;
    if (error != null) throw error;
    return patientExercises;
  }

  @override
  Future<void> unassign(String exerciseId, String patientId) async {
    assignments = assignments
        .where((assignment) => assignment.patientId != patientId)
        .toList();
  }
}

CustomRehabExercise _exercise() {
  Map<JointType, JointRotation> pose(double offset) => {
        for (var index = 0; index < JointType.values.length; index++)
          JointType.values[index]: JointRotation(
            x: offset + index,
            y: offset - index,
            z: offset + index / 2,
          ),
      };

  return CustomRehabExercise(
    id: 'custom_1',
    name: '右肩復健',
    description: '緩慢完成',
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

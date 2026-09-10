import 'dart:convert';

import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/plan/plan_api_repository.dart';
import 'package:flutter_body/features/plan/plan_repository.dart';
import 'package:flutter_body/features/plan/rehab_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    AppSession.userId = '42';
    AppSession.customExerciseToken = 'test-token';
  });

  tearDown(() {
    AppSession.userId = null;
    AppSession.customExerciseToken = null;
  });

  test('production repository is the persisted API implementation', () {
    expect(planRepository, isA<PlanApiRepository>());
  });

  test('plan save sends identity headers and patient payload', () async {
    late http.Request captured;
    final repository = PlanApiRepository(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response('{}', 201);
      }),
    );
    final plan = RehabPlan(
      patientId: '42',
      planId: 'plan_42_20260910',
      createdBy: 'therapist',
      date: DateTime(2026, 9, 10),
      condition: PatientCondition.fracture,
      items: [PlanItem(exerciseId: 'ex01', order: 0)],
    );

    await repository.savePlan(plan);

    expect(captured.method, 'POST');
    expect(captured.headers['X-User-Id'], '42');
    expect(captured.headers['X-Custom-Exercise-Token'], 'test-token');
    expect(jsonDecode(captured.body)['patientId'], '42');
  });

  test('missing identity rejects before making a request', () async {
    var calls = 0;
    AppSession.customExerciseToken = null;
    final repository = PlanApiRepository(
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      repository.getPlanByDate(patientId: '42', date: DateTime(2026, 9, 10)),
      throwsA(isA<Exception>()),
    );
    expect(calls, 0);
  });
}

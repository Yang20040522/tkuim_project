import 'package:flutter/material.dart';
import 'package:flutter_body/features/history/training_result_history_page.dart';
import 'package:flutter_body/features/pose_measurement/repositories/training_result_repository.dart';
import 'package:flutter_body/models/assignable_exercise.dart';
import 'package:flutter_body/models/training_session_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('patient history shows exercise, counts, score and status',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingResultHistoryPage(
          repository: _FakeRepository([_result()]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('手肘訓練'), findsOneWidget);
    expect(find.textContaining('完成 6 次／2 組'), findsOneWidget);
    expect(find.text('100 分'), findsOneWidget);
  });

  testWidgets('therapist history requests selected patient only',
      (tester) async {
    final repository = _FakeRepository([_result()]);
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingResultHistoryPage(
          patientId: '15',
          patientName: '患者甲',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('患者甲的訓練紀錄'), findsOneWidget);
    expect(repository.requestedPatientId, '15');
  });
}

TrainingSessionResult _result() => TrainingSessionResult(
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

class _FakeRepository implements TrainingResultRepository {
  _FakeRepository(this.results);

  final List<TrainingSessionResult> results;
  String? requestedPatientId;

  @override
  Future<List<TrainingSessionResult>> getMyResults() async => results;

  @override
  Future<List<TrainingSessionResult>> getPatientResults(
      String patientId) async {
    requestedPatientId = patientId;
    return results;
  }

  @override
  Future<TrainingSessionResult> save(TrainingSessionResult result) async =>
      result;
}

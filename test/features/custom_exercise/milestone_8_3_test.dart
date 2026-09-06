import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_body/features/custom_exercise/controllers/custom_exercise_editor_controller.dart';
import 'package:flutter_body/features/custom_exercise/custom_exercise_editor_page.dart';
import 'package:flutter_body/features/custom_exercise/custom_exercise_playback_page.dart';
import 'package:flutter_body/features/custom_exercise/patient_assigned_exercise_list_page.dart';
import 'package:flutter_body/features/custom_exercise/repositories/unified_exercise_assignment_repository.dart';
import 'package:flutter_body/features/pose_measurement/evaluation/pose_evaluation_engine.dart';
import 'package:flutter_body/features/pose_measurement/evaluation/pose_evaluation_result.dart';
import 'package:flutter_body/features/pose_measurement/evaluation/pose_measurement_rule.dart';
import 'package:flutter_body/features/pose_measurement/evaluation/pose_measurement_rule_resolver.dart';
import 'package:flutter_body/features/pose_measurement/models/joint_angle_frame.dart';
import 'package:flutter_body/models/assignable_exercise.dart';
import 'package:flutter_body/models/custom_exercise_assignment.dart';
import 'package:flutter_body/models/custom_rehab_exercise.dart';
import 'package:flutter_body/models/evaluation_rule.dart';
import 'package:flutter_body/models/exercise_keyframe.dart';
import 'package:flutter_body/models/joint_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const leftElbowRule = PoseMeasurementRule(
    measurement: JointMeasurementType.leftElbow,
    targetAngleDegrees: 90,
    toleranceDegrees: 10,
    feedbackTooLow: '請增加左手肘角度',
    feedbackTooHigh: '請減少左手肘角度',
  );

  const directionalShoulderRules = <PoseMeasurementRule>[
    PoseMeasurementRule(
      measurement: JointMeasurementType.leftShoulderAbduction,
      targetAngleDegrees: 90,
      toleranceDegrees: 10,
    ),
    PoseMeasurementRule(
      measurement: JointMeasurementType.rightShoulderAbduction,
      targetAngleDegrees: 90,
      toleranceDegrees: 10,
    ),
    PoseMeasurementRule(
      measurement: JointMeasurementType.leftShoulderFlexion,
      targetAngleDegrees: 90,
      toleranceDegrees: 10,
    ),
    PoseMeasurementRule(
      measurement: JointMeasurementType.rightShoulderFlexion,
      targetAngleDegrees: 90,
      toleranceDegrees: 10,
    ),
  ];

  test('PoseMeasurementRule 與 CUSTOM JSON 可完整 round-trip', () {
    final original = _customExercise(poseRules: const [leftElbowRule]);
    final decoded = CustomRehabExercise.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );

    expect(decoded.poseMeasurementRules, hasLength(1));
    expect(
        decoded.poseMeasurementRules.single.toJson(), leftElbowRule.toJson());
    expect(decoded.evaluationRules.single.joint, JointType.rightShoulder);
  });

  test('肩部側抬與前抬規則可完整 JSON round-trip', () {
    final original = _customExercise(poseRules: directionalShoulderRules);
    final decoded = CustomRehabExercise.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );

    expect(
      decoded.poseMeasurementRules.map((rule) => rule.measurement),
      directionalShoulderRules.map((rule) => rule.measurement),
    );
    expect(
      decoded.poseMeasurementRules.map((rule) => rule.toJson()),
      directionalShoulderRules.map((rule) => rule.toJson()),
    );
    expect(
      PoseMeasurementRule.supportedCustomMeasurements
          .map((measurement) => measurement.poseRuleLabel),
      containsAll(<String>['左肩側抬', '右肩側抬', '左肩前抬', '右肩前抬']),
    );
  });

  test('舊 CUSTOM 的 missing/null/壞單筆 pose rules 都安全解析', () {
    final legacy = _customExercise().toJson()..remove('poseMeasurementRules');
    expect(CustomRehabExercise.fromJson(legacy).poseMeasurementRules, isEmpty);

    final withNull = _customExercise().toJson()
      ..['poseMeasurementRules'] = null;
    expect(
        CustomRehabExercise.fromJson(withNull).poseMeasurementRules, isEmpty);

    final partiallyInvalid = _customExercise().toJson()
      ..['poseMeasurementRules'] = [
        leftElbowRule.toJson(),
        {'measurement': 'LEFT_SHOULDER_ANGLE'},
        {
          'measurement': 'RIGHT_KNEE_ANGLE',
          'targetAngleDegrees': 180,
          'toleranceDegrees': 5,
        },
      ];
    expect(
      CustomRehabExercise.fromJson(partiallyInvalid).poseMeasurementRules,
      hasLength(1),
    );
  });

  test('CUSTOM resolver 只讀 anatomical rules 且保留左右', () {
    const rightKneeRule = PoseMeasurementRule(
      measurement: JointMeasurementType.rightKnee,
      targetAngleDegrees: 120,
      toleranceDegrees: 10,
    );
    final custom = _customExercise(
      poseRules: const [leftElbowRule, rightKneeRule],
    );
    final rules = const PoseMeasurementRuleResolver().resolve(
      _assignable(AssignableExerciseType.custom),
      customExercise: custom,
    );

    expect(
      rules.map((rule) => rule.measurement),
      [JointMeasurementType.leftElbow, JointMeasurementType.rightKnee],
    );
    expect(
      const PoseMeasurementRuleResolver().resolve(
        _assignable(AssignableExerciseType.custom),
        customExercise: _customExercise(),
      ),
      isEmpty,
    );
  });

  test('CUSTOM anatomical rule 可直接交給既有 evaluation engine', () {
    final custom = _customExercise(poseRules: const [leftElbowRule]);
    final rules = const PoseMeasurementRuleResolver().resolve(
      _assignable(AssignableExerciseType.custom),
      customExercise: custom,
    );
    final result = const PoseEvaluationEngine().evaluate(
      measurements: JointAngleFrame(
        timestampMs: 1,
        angles: const {JointMeasurementType.leftElbow: 87},
      ),
      rules: rules,
    );

    expect(result.overallStatus, PoseOverallEvaluationStatus.correct);
    expect(result.rules.single.status, PoseRuleEvaluationStatus.pass);
  });

  test('Editor controller 支援 add/edit/delete 與完整驗證且不動 legacy rule', () {
    final controller = CustomExerciseEditorController(
      initialExercise: _customExercise(),
    );
    addTearDown(controller.dispose);

    expect(controller.addPoseMeasurementRule(leftElbowRule), isNull);
    expect(controller.poseMeasurementRules, hasLength(1));
    expect(
      controller.addPoseMeasurementRule(leftElbowRule),
      '左手肘角度已經有一條評估規則',
    );
    expect(
      controller.addPoseMeasurementRule(const PoseMeasurementRule(
        measurement: JointMeasurementType.rightElbow,
        targetAngleDegrees: -1,
        toleranceDegrees: 5,
      )),
      '目標角度必須介於 0°～180°',
    );
    expect(
      controller.addPoseMeasurementRule(const PoseMeasurementRule(
        measurement: JointMeasurementType.rightElbow,
        targetAngleDegrees: 90,
        toleranceDegrees: 0,
      )),
      '容許誤差必須大於 0°',
    );
    expect(
      controller.addPoseMeasurementRule(const PoseMeasurementRule(
        measurement: JointMeasurementType.rightElbow,
        targetAngleDegrees: 175,
        toleranceDegrees: 10,
      )),
      '設定後的角度範圍不可超出 0°～180°',
    );

    const edited = PoseMeasurementRule(
      measurement: JointMeasurementType.rightKnee,
      targetAngleDegrees: 120,
      toleranceDegrees: 15,
    );
    expect(controller.updatePoseMeasurementRule(0, edited), isNull);
    expect(controller.poseMeasurementRules.single.measurement,
        JointMeasurementType.rightKnee);
    expect(
        controller.draft.evaluationRules.single.joint, JointType.rightShoulder);
    controller.deletePoseMeasurementRule(0);
    expect(controller.poseMeasurementRules, isEmpty);
    expect(controller.draft.evaluationRules, hasLength(1));
  });

  testWidgets('Editor 顯示有效範圍並可從對話框新增與刪除規則', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomExerciseEditorPage(initialExercise: _customExercise()),
      ),
    );
    await tester.pumpAndSettle();
    final addButton = find.byKey(const Key('add-pose-measurement-rule'));
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pose-rule-target')),
      '90',
    );
    await tester.enterText(
      find.byKey(const Key('pose-rule-tolerance')),
      '10',
    );
    await tester.tap(find.byKey(const Key('confirm-pose-rule')));
    await tester.pumpAndSettle();

    expect(find.textContaining('有效範圍 80° – 100°'), findsOneWidget);
    await tester.tap(find.byKey(const Key('edit-pose-measurement-rule-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pose-rule-target')),
      '100',
    );
    await tester.tap(find.byKey(const Key('confirm-pose-rule')));
    await tester.pumpAndSettle();
    expect(find.textContaining('有效範圍 90° – 110°'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('delete-pose-measurement-rule-0')),
    );
    await tester.pump();
    expect(find.text('尚未設定真人姿勢評估規則'), findsOneWidget);
  });

  testWidgets('Editor 顯示正面人偶的 anatomical 左右提示', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomExerciseEditorPage(initialExercise: _customExercise()),
      ),
    );
    await tester.pumpAndSettle();

    final orientationHint = find.textContaining('人偶右側位於畫面左側');
    await tester.ensureVisible(orientationHint);
    expect(orientationHint, findsOneWidget);
  });

  testWidgets('CUSTOM 示範頁的開始訓練傳遞完整 exercise context', (tester) async {
    final custom = _customExercise(poseRules: const [leftElbowRule]);
    AssignableExercise? receivedAssignable;
    CustomRehabExercise? receivedCustom;
    await tester.pumpWidget(MaterialApp(
      home: CustomExercisePlaybackPage(
        exercise: custom,
        trainingBuilder: (assignable, exercise) {
          receivedAssignable = assignable;
          receivedCustom = exercise;
          return const Scaffold(body: Text('真人姿勢訓練頁'));
        },
      ),
    ));
    await tester.pumpAndSettle();

    final startButton = find.byKey(const Key('start-custom-pose-training'));
    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(find.text('真人姿勢訓練頁'), findsOneWidget);
    expect(receivedAssignable?.type, AssignableExerciseType.custom);
    expect(receivedAssignable?.id, custom.id);
    expect(identical(receivedCustom, custom), isTrue);
  });

  testWidgets('無 anatomical rule 的 CUSTOM 仍可由示範頁開始訓練', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CustomExercisePlaybackPage(
        exercise: _customExercise(),
        trainingBuilder: (_, exercise) => Scaffold(
          body: Text('規則數 ${exercise.poseMeasurementRules.length}'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final startButton = find.byKey(const Key('start-custom-pose-training'));
    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    expect(find.text('規則數 0'), findsOneWidget);
  });

  testWidgets('患者 DEFAULT 主入口維持舊流程，CUSTOM 主入口先開示範', (tester) async {
    final repository = _UnifiedRepository();
    await tester.pumpWidget(MaterialApp(
      home: PatientAssignedExerciseListPage(
        repository: repository,
        defaultExerciseBuilder: (_) =>
            const Scaffold(body: Text('原始 DEFAULT 訓練流程')),
        customExerciseBuilder: (_) =>
            const Scaffold(body: Text('CUSTOM 3D 示範頁')),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('預設測試'));
    await tester.pumpAndSettle();
    expect(find.text('原始 DEFAULT 訓練流程'), findsOneWidget);
    Navigator.of(tester.element(find.text('原始 DEFAULT 訓練流程'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('自訂測試'));
    await tester.pumpAndSettle();
    expect(find.text('CUSTOM 3D 示範頁'), findsOneWidget);
    expect(repository.detailReads, 1);
  });
}

AssignableExercise _assignable(AssignableExerciseType type) =>
    AssignableExercise(
      id: 'custom_83',
      name: type == AssignableExerciseType.custom ? '自訂測試' : '預設測試',
      description: '',
      type: type,
      assigned: true,
    );

CustomRehabExercise _customExercise({
  List<PoseMeasurementRule> poseRules = const [],
}) {
  return CustomRehabExercise(
    id: 'custom_83',
    name: '自訂測試',
    description: '先看示範再訓練',
    createdByTherapistId: '7',
    createdAt: DateTime.utc(2026, 9, 5),
    updatedAt: DateTime.utc(2026, 9, 5),
    repetitions: 10,
    sets: 3,
    holdSeconds: 5,
    restSeconds: 30,
    duration: 1,
    keyframes: [
      ExerciseKeyframe(id: 'k1', time: 0, jointRotations: {}),
      ExerciseKeyframe(id: 'k2', time: 1, jointRotations: {}),
    ],
    evaluationRules: const [
      EvaluationRule(
        joint: JointType.rightShoulder,
        axis: RotationAxis.x,
        targetAngle: 30,
        tolerance: 5,
      ),
    ],
    poseMeasurementRules: poseRules,
  );
}

class _UnifiedRepository implements UnifiedExerciseAssignmentRepository {
  int detailReads = 0;

  @override
  Future<List<AssignableExercise>> getPatientAssignedExercises() async => [
        _assignable(AssignableExerciseType.defaultExercise),
        _assignable(AssignableExerciseType.custom),
      ];

  @override
  Future<CustomRehabExercise?> getPatientCustomExercise(
      String exerciseId) async {
    detailReads++;
    return _customExercise();
  }

  @override
  Future<List<AssignablePatient>> getAssignablePatients() async => [];

  @override
  Future<List<AssignableExercise>> getAssignableExercises(
          String patientId) async =>
      [];

  @override
  Future<AssignableExercise> assign(
    AssignableExercise exercise,
    String patientId,
  ) async =>
      exercise;

  @override
  Future<void> unassign(
    AssignableExercise exercise,
    String patientId,
  ) async {}
}

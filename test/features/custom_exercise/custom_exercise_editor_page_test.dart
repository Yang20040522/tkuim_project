import 'package:flutter/material.dart';
import 'package:flutter_body/features/account/therapist_home_screen.dart';
import 'package:flutter_body/features/custom_exercise/controllers/custom_exercise_editor_controller.dart';
import 'package:flutter_body/features/custom_exercise/custom_exercise_editor_page.dart';
import 'package:flutter_body/features/custom_exercise/services/custom_exercise_bone_mapping.dart';
import 'package:flutter_body/features/custom_exercise/widgets/custom_exercise_3d_viewer.dart';
import 'package:flutter_body/models/joint_rotation.dart';
import 'package:flutter_body/models/joint_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller 建立帶有治療師 ID 的預設草稿並更新基本資料', () {
    final now = DateTime.utc(2026, 9, 2);
    final controller = CustomExerciseEditorController(
      therapistId: 'therapist_001',
      now: now,
    );
    addTearDown(controller.dispose);

    expect(controller.isEditing, isFalse);
    expect(controller.draft.createdByTherapistId, 'therapist_001');
    expect(controller.draft.repetitions, 10);
    expect(controller.draft.sets, 3);

    controller.updateBasicInfo(name: '右肩抬舉', description: '慢慢抬高手臂');
    expect(controller.draft.name, '右肩抬舉');
    expect(controller.draft.description, '慢慢抬高手臂');
  });

  test('12 個 JointType 使用從 editor GLB 驗證的 bone mapping', () {
    expect(CustomExerciseBoneMapping.verifiedBoneNames, {
      JointType.leftShoulder: 'DHIbody:upperarm_l',
      JointType.rightShoulder: 'DHIbody:upperarm_r',
      JointType.leftElbow: 'DHIbody:lowerarm_l',
      JointType.rightElbow: 'DHIbody:lowerarm_r',
      JointType.leftWrist: 'DHIbody:hand_l',
      JointType.rightWrist: 'DHIbody:hand_r',
      JointType.leftHip: 'DHIbody:thigh_l',
      JointType.rightHip: 'DHIbody:thigh_r',
      JointType.leftKnee: 'DHIbody:calf_l',
      JointType.rightKnee: 'DHIbody:calf_r',
      JointType.leftAnkle: 'DHIbody:foot_l',
      JointType.rightAnkle: 'DHIbody:foot_r',
    });
    expect(CustomExerciseBoneMapping.controllableJoints, [
      JointType.leftShoulder,
      JointType.rightShoulder,
      JointType.leftElbow,
      JointType.rightElbow,
      JointType.leftWrist,
      JointType.rightWrist,
      JointType.leftHip,
      JointType.rightHip,
      JointType.leftKnee,
      JointType.rightKnee,
      JointType.leftAnkle,
      JointType.rightAnkle,
    ]);
  });

  test('controller 保留上下肢各自角度並支援目前及全部歸零', () {
    final controller = CustomExerciseEditorController();
    addTearDown(controller.dispose);

    controller.selectJoint(JointType.leftShoulder);
    controller.updateSelectedJointRotation(
      const JointRotation(x: 45, y: -30, z: 90),
    );
    expect(
      controller.selectedJointRotation,
      const JointRotation(x: 45, y: -30, z: 90),
    );

    controller.selectJoint(JointType.rightElbow);
    controller.updateSelectedJointRotation(
      const JointRotation(x: 500, y: -500, z: 0),
    );
    expect(controller.selectedJointRotation.x, 180);
    expect(controller.selectedJointRotation.y, -180);

    controller.selectJoint(JointType.leftKnee);
    controller.updateSelectedJointRotation(
      const JointRotation(x: 15, y: 25, z: -35),
    );

    controller.selectJoint(JointType.leftShoulder);
    expect(
      controller.selectedJointRotation,
      const JointRotation(x: 45, y: -30, z: 90),
    );
    controller.resetSelectedJointRotation();
    expect(controller.selectedJointRotation, JointRotation.zero);
    expect(
      controller.currentPose[JointType.rightElbow],
      const JointRotation(x: 180, y: -180),
    );
    expect(
      controller.currentPose[JointType.leftKnee],
      const JointRotation(x: 15, y: 25, z: -35),
    );

    controller.resetAllJointRotations();
    expect(controller.currentPose, hasLength(12));
    expect(
      controller.currentPose.values,
      everyElement(JointRotation.zero),
    );
  });

  testWidgets('治療師首頁可進入自訂動作編輯器', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TherapistHomeScreen()),
    );

    await tester.tap(find.byKey(const Key('open-custom-exercise-editor')));
    await tester.pumpAndSettle();

    expect(find.byType(CustomExerciseEditorPage), findsOneWidget);
    expect(find.text('自訂復健動作'), findsOneWidget);
    expect(find.byKey(const Key('custom-exercise-name')), findsOneWidget);
    expect(find.byType(CustomExercise3dViewer), findsOneWidget);
    expect(find.text('姿勢時間軸'), findsOneWidget);
    expect(find.byKey(const Key('rightShoulder-x-slider')), findsOneWidget);
    for (final joint in CustomExerciseBoneMapping.controllableJoints) {
      expect(find.byKey(Key('joint-${joint.name}')), findsOneWidget);
    }
    expect(find.byKey(const Key('reset-selected-joint')), findsOneWidget);
    expect(find.byKey(const Key('reset-all-joints')), findsOneWidget);
  });

  testWidgets('切換上肢關節後顯示該關節 XYZ slider', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CustomExerciseEditorPage()),
    );
    await tester.pumpAndSettle();

    final leftElbowChip = find.byKey(const Key('joint-leftElbow'));
    await tester.ensureVisible(leftElbowChip);
    await tester.tap(leftElbowChip);
    await tester.pump();

    expect(find.text('左肘角度'), findsOneWidget);
    expect(find.byKey(const Key('leftElbow-x-slider')), findsOneWidget);
    expect(find.byKey(const Key('leftElbow-y-slider')), findsOneWidget);
    expect(find.byKey(const Key('leftElbow-z-slider')), findsOneWidget);
  });

  testWidgets('切換下肢關節後顯示該關節 XYZ slider', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CustomExerciseEditorPage()),
    );
    await tester.pumpAndSettle();

    final leftAnkleChip = find.byKey(const Key('joint-leftAnkle'));
    await tester.ensureVisible(leftAnkleChip);
    await tester.tap(leftAnkleChip);
    await tester.pump();

    expect(find.text('左踝角度'), findsOneWidget);
    expect(find.byKey(const Key('leftAnkle-x-slider')), findsOneWidget);
    expect(find.byKey(const Key('leftAnkle-y-slider')), findsOneWidget);
    expect(find.byKey(const Key('leftAnkle-z-slider')), findsOneWidget);
  });

  testWidgets('手機寬度的基本編輯器不發生 overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: CustomExerciseEditorPage()),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('save-custom-exercise')), findsOneWidget);
  });
}

import 'package:flutter/foundation.dart';

import '../../../models/custom_rehab_exercise.dart';
import '../../../models/joint_definition.dart';
import '../../../models/joint_rotation.dart';
import '../../../models/joint_type.dart';
import '../services/custom_exercise_bone_mapping.dart';

/// 自訂動作編輯器的單一狀態來源。
///
/// 草稿資料與目前編輯姿勢的單一狀態來源。
class CustomExerciseEditorController extends ChangeNotifier {
  CustomRehabExercise _draft;
  JointType _selectedJoint = JointType.rightShoulder;
  final Map<JointType, JointRotation> _currentPose = {
    for (final joint in CustomExerciseBoneMapping.controllableJoints)
      joint: JointRotation.zero,
  };
  final bool isEditing;

  CustomExerciseEditorController({
    CustomRehabExercise? initialExercise,
    String? therapistId,
    DateTime? now,
  })  : isEditing = initialExercise != null,
        _draft = initialExercise ??
            _createDraft(
              therapistId: therapistId,
              now: now ?? DateTime.now(),
            );

  CustomRehabExercise get draft => _draft;
  JointType get selectedJoint => _selectedJoint;
  List<JointType> get controllableJoints =>
      CustomExerciseBoneMapping.controllableJoints;
  Map<JointType, JointRotation> get currentPose =>
      Map.unmodifiable(_currentPose);
  JointRotation get selectedJointRotation =>
      _currentPose[_selectedJoint] ?? DefaultPose.rotationOf(_selectedJoint);

  void selectJoint(JointType joint) {
    if (!CustomExerciseBoneMapping.controllableJoints.contains(joint)) {
      throw UnsupportedError('${joint.name} 尚未在目前批次開放控制');
    }
    if (_selectedJoint == joint) return;
    _selectedJoint = joint;
    notifyListeners();
  }

  void updateSelectedJointRotation(JointRotation rotation) {
    final definition = JointDefinitions.of(_selectedJoint);
    final safeRotation = JointRotation(
      x: rotation.x
          .clamp(definition.xRange.min, definition.xRange.max)
          .toDouble(),
      y: rotation.y
          .clamp(definition.yRange.min, definition.yRange.max)
          .toDouble(),
      z: rotation.z
          .clamp(definition.zRange.min, definition.zRange.max)
          .toDouble(),
    );
    if (safeRotation == selectedJointRotation) return;
    _currentPose[_selectedJoint] = safeRotation;
    notifyListeners();
  }

  void resetSelectedJointRotation() {
    updateSelectedJointRotation(DefaultPose.rotationOf(_selectedJoint));
  }

  void resetAllJointRotations() {
    var changed = false;
    for (final joint in CustomExerciseBoneMapping.controllableJoints) {
      final defaultRotation = DefaultPose.rotationOf(joint);
      if (_currentPose[joint] != defaultRotation) {
        _currentPose[joint] = defaultRotation;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void updateBasicInfo({required String name, required String description}) {
    if (_draft.name == name && _draft.description == description) return;
    _draft = _draft.copyWith(
      name: name,
      description: description,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  static CustomRehabExercise _createDraft({
    required String? therapistId,
    required DateTime now,
  }) {
    return CustomRehabExercise(
      id: 'custom_${now.microsecondsSinceEpoch}',
      name: '',
      description: '',
      createdByTherapistId: therapistId,
      createdAt: now,
      updatedAt: now,
      repetitions: 10,
      sets: 3,
      holdSeconds: 5,
      restSeconds: 30,
      duration: 0,
      keyframes: const [],
      evaluationRules: const [],
    );
  }
}

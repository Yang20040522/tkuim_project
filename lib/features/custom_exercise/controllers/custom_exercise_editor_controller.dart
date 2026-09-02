import 'package:flutter/foundation.dart';

import '../../../models/custom_rehab_exercise.dart';
import '../../../models/exercise_keyframe.dart';
import '../../../models/joint_definition.dart';
import '../../../models/joint_rotation.dart';
import '../../../models/joint_type.dart';
import '../services/custom_exercise_bone_mapping.dart';

enum EditorPlaybackStatus { stopped, playing, paused }

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
  String? _selectedKeyframeId;
  EditorPlaybackStatus _playbackStatus = EditorPlaybackStatus.stopped;
  double _playbackTime = 0;
  int _nextKeyframeSequence = 1;
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
            ) {
    if (_draft.keyframes.isNotEmpty) {
      final firstKeyframe = _draft.keyframes.first;
      _loadPose(firstKeyframe.jointRotations);
      _selectedKeyframeId = firstKeyframe.id;
      _playbackTime = firstKeyframe.time;
    }
  }

  CustomRehabExercise get draft => _draft;
  JointType get selectedJoint => _selectedJoint;
  List<JointType> get controllableJoints =>
      CustomExerciseBoneMapping.controllableJoints;
  Map<JointType, JointRotation> get currentPose =>
      Map.unmodifiable(_currentPose);
  JointRotation get selectedJointRotation =>
      _currentPose[_selectedJoint] ?? DefaultPose.rotationOf(_selectedJoint);
  List<ExerciseKeyframe> get keyframes => _draft.keyframes;
  String? get selectedKeyframeId => _selectedKeyframeId;
  EditorPlaybackStatus get playbackStatus => _playbackStatus;
  double get playbackTime => _playbackTime;
  bool get canPlay => _draft.keyframes.length >= 2;

  String? get saveValidationError {
    if (_draft.name.trim().isEmpty) {
      return '請輸入動作名稱';
    }
    if (_draft.keyframes.length < 2) {
      return '至少需要 2 個 Keyframes 才能儲存';
    }
    if (_draft.duration != _draft.keyframes.last.time) {
      return 'Keyframes 與 duration 不一致';
    }
    try {
      CustomRehabExercise.fromJson(_draft.toJson());
    } on FormatException {
      return '動作資料格式無效，請檢查 Keyframes';
    } on ArgumentError {
      return '動作資料格式無效，請檢查 Keyframes';
    }
    return null;
  }

  void selectJoint(JointType joint) {
    if (!CustomExerciseBoneMapping.controllableJoints.contains(joint)) {
      throw UnsupportedError('${joint.name} 尚未在目前批次開放控制');
    }
    if (_selectedJoint == joint) return;
    _stopPlaybackState();
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
    var changed = _stopPlaybackState();
    if (_selectedKeyframeId != null) {
      _selectedKeyframeId = null;
      changed = true;
    }
    if (safeRotation != selectedJointRotation) {
      _currentPose[_selectedJoint] = safeRotation;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void resetSelectedJointRotation() {
    updateSelectedJointRotation(DefaultPose.rotationOf(_selectedJoint));
  }

  void resetAllJointRotations() {
    var changed = _stopPlaybackState();
    if (_selectedKeyframeId != null) {
      _selectedKeyframeId = null;
      changed = true;
    }
    for (final joint in CustomExerciseBoneMapping.controllableJoints) {
      final defaultRotation = DefaultPose.rotationOf(joint);
      if (_currentPose[joint] != defaultRotation) {
        _currentPose[joint] = defaultRotation;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void addKeyframeFromCurrentPose() {
    _stopPlaybackState();
    final time =
        _draft.keyframes.isEmpty ? 0.0 : _draft.keyframes.last.time + 1.0;
    final keyframe = ExerciseKeyframe(
      id: _createKeyframeId(),
      time: time,
      jointRotations: _completePose(_currentPose),
    );
    _draft = _draft.copyWith(
      duration: time,
      keyframes: [..._draft.keyframes, keyframe],
      updatedAt: DateTime.now(),
    );
    _selectedKeyframeId = keyframe.id;
    _playbackTime = 0;
    notifyListeners();
  }

  void selectKeyframe(String id) {
    final index = _draft.keyframes.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final keyframe = _draft.keyframes[index];
    _stopPlaybackState();
    _loadPose(keyframe.jointRotations);
    _selectedKeyframeId = keyframe.id;
    _playbackTime = keyframe.time;
    notifyListeners();
  }

  void deleteKeyframe(String id) {
    final removedIndex = _draft.keyframes.indexWhere((item) => item.id == id);
    if (removedIndex < 0) return;

    _stopPlaybackState();
    final remaining = List<ExerciseKeyframe>.of(_draft.keyframes)
      ..removeAt(removedIndex);
    final duration = remaining.isEmpty ? 0.0 : remaining.last.time;
    final wasSelected = _selectedKeyframeId == id;

    _draft = _draft.copyWith(
      duration: duration,
      keyframes: remaining,
      updatedAt: DateTime.now(),
    );

    if (wasSelected) {
      if (remaining.isEmpty) {
        _selectedKeyframeId = null;
        _playbackTime = 0;
      } else {
        final adjacentIndex = removedIndex.clamp(0, remaining.length - 1);
        final adjacent = remaining[adjacentIndex];
        _selectedKeyframeId = adjacent.id;
        _playbackTime = adjacent.time;
        _loadPose(adjacent.jointRotations);
      }
    } else {
      _playbackTime = _playbackTime.clamp(0, duration).toDouble();
    }
    notifyListeners();
  }

  void playPreview() {
    if (!canPlay || _playbackStatus == EditorPlaybackStatus.playing) return;
    if (_playbackStatus == EditorPlaybackStatus.paused) {
      resumePreview();
      return;
    }
    _playbackStatus = EditorPlaybackStatus.playing;
    _playbackTime = 0;
    notifyListeners();
  }

  void pausePreview() {
    if (_playbackStatus != EditorPlaybackStatus.playing) return;
    _playbackStatus = EditorPlaybackStatus.paused;
    notifyListeners();
  }

  void resumePreview() {
    if (_playbackStatus != EditorPlaybackStatus.paused) return;
    _playbackStatus = EditorPlaybackStatus.playing;
    notifyListeners();
  }

  void stopPreview() {
    if (!_stopPlaybackState()) return;
    notifyListeners();
  }

  void updatePlaybackProgress(double time) {
    if (_playbackStatus == EditorPlaybackStatus.stopped || !time.isFinite) {
      return;
    }
    final safeTime = time.clamp(0, _draft.duration).toDouble();
    if (safeTime == _playbackTime) return;
    _playbackTime = safeTime;
    notifyListeners();
  }

  void completePreview() {
    if (_playbackStatus == EditorPlaybackStatus.stopped) return;
    _playbackStatus = EditorPlaybackStatus.stopped;
    _playbackTime = _draft.duration;
    notifyListeners();
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

  CustomRehabExercise createSaveSnapshot({DateTime? now}) {
    final validationError = saveValidationError;
    if (validationError != null) {
      throw StateError(validationError);
    }
    return _draft.copyWith(
      name: _draft.name.trim(),
      description: _draft.description.trim(),
      updatedAt: now ?? DateTime.now(),
    );
  }

  void markSaved(CustomRehabExercise savedExercise) {
    if (savedExercise.id != _draft.id) {
      throw ArgumentError('儲存結果的 exercise id 與目前草稿不一致');
    }
    _draft = savedExercise;
    notifyListeners();
  }

  bool _stopPlaybackState() {
    final changed =
        _playbackStatus != EditorPlaybackStatus.stopped || _playbackTime != 0;
    _playbackStatus = EditorPlaybackStatus.stopped;
    _playbackTime = 0;
    return changed;
  }

  void _loadPose(Map<JointType, JointRotation> source) {
    final pose = _completePose(source);
    for (final joint in CustomExerciseBoneMapping.controllableJoints) {
      _currentPose[joint] = pose[joint]!;
    }
  }

  Map<JointType, JointRotation> _completePose(
    Map<JointType, JointRotation> source,
  ) {
    return {
      for (final joint in CustomExerciseBoneMapping.controllableJoints)
        joint: source[joint] ?? DefaultPose.rotationOf(joint),
    };
  }

  String _createKeyframeId() {
    while (true) {
      final id = 'kf_${_nextKeyframeSequence.toString().padLeft(3, '0')}';
      _nextKeyframeSequence++;
      if (_draft.keyframes.every((item) => item.id != id)) return id;
    }
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

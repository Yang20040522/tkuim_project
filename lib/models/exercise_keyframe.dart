import 'joint_rotation.dart';
import 'joint_type.dart';

class ExerciseKeyframe {
  final String id;
  final double time;
  final Map<JointType, JointRotation> jointRotations;

  ExerciseKeyframe({
    required this.id,
    required this.time,
    required Map<JointType, JointRotation> jointRotations,
  })  : assert(time >= 0 && time.isFinite),
        jointRotations = Map.unmodifiable(jointRotations);

  ExerciseKeyframe copyWith({
    String? id,
    double? time,
    Map<JointType, JointRotation>? jointRotations,
  }) {
    return ExerciseKeyframe(
      id: id ?? this.id,
      time: time ?? this.time,
      jointRotations: jointRotations ?? this.jointRotations,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time,
        'jointRotations': {
          for (final entry in jointRotations.entries)
            entry.key.name: entry.value.toJson(),
        },
      };

  factory ExerciseKeyframe.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final timeValue = json['time'];
    final rotationsValue = json['jointRotations'];
    final time = timeValue is num ? timeValue.toDouble() : double.nan;
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Keyframe id 不可為空');
    }
    if (!time.isFinite || time < 0) {
      throw const FormatException('Keyframe time 必須是非負有限數值');
    }
    if (rotationsValue is! Map) {
      throw const FormatException('jointRotations 格式錯誤');
    }

    final rotations = <JointType, JointRotation>{};
    for (final entry in rotationsValue.entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw const FormatException('jointRotations 內容格式錯誤');
      }
      rotations[JointTypeJson.fromJson(entry.key as String)] =
          JointRotation.fromJson(Map<String, dynamic>.from(entry.value as Map));
    }
    return ExerciseKeyframe(id: id, time: time, jointRotations: rotations);
  }
}

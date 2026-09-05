/// Official MediaPipe Pose Landmarker indices; these are anatomical identities.
/// A mirrored camera preview must never swap these indices.
enum PoseLandmarkType {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  mouthLeft,
  mouthRight,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

/// Either an unmodified normalized landmark or an unmodified world landmark.
/// Its containing PoseFrame map identifies the coordinate space.
class PoseLandmark {
  const PoseLandmark({
    required this.x,
    required this.y,
    required this.z,
    this.visibility,
    this.presence,
  });

  final double x;
  final double y;
  final double z;
  final double? visibility;
  final double? presence;

  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;

  /// Missing confidence is unknown, never implicitly treated as reliable.
  double? get confidence {
    final values = [visibility, presence].whereType<double>().toList();
    if (values.isEmpty ||
        values.any((value) => !value.isFinite || value < 0 || value > 1)) {
      return null;
    }
    return values.reduce((a, b) => a < b ? a : b);
  }

  bool isReliable([double minConfidence = 0.5]) {
    final value = confidence;
    return isFinite && value != null && value >= minConfidence;
  }

  static PoseLandmark? tryFromPlatform(Object? value) {
    if (value is! Map) return null;
    final x = value['x'];
    final y = value['y'];
    final z = value['z'];
    if (x is! num || y is! num || z is! num) return null;
    return PoseLandmark(
      x: x.toDouble(),
      y: y.toDouble(),
      z: z.toDouble(),
      visibility: _confidenceValue(value['visibility']),
      presence: _confidenceValue(value['presence']),
    );
  }

  static double? _confidenceValue(Object? value) =>
      value == null ? null : (value is num ? value.toDouble() : double.nan);
}

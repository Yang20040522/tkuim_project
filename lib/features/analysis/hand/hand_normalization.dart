import 'dart:math' as math;

import '../../../services/mediapipe_service.dart';

class NormalizedHandLandmark {
  const NormalizedHandLandmark(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'z': z};

  factory NormalizedHandLandmark.fromJson(Map<String, dynamic> json) =>
      NormalizedHandLandmark(
        (json['x'] as num?)?.toDouble() ?? 0,
        (json['y'] as num?)?.toDouble() ?? 0,
        (json['z'] as num?)?.toDouble() ?? 0,
      );
}

class HandNormalizedFrame {
  HandNormalizedFrame({
    required this.timestampMs,
    required List<NormalizedHandLandmark> landmarks,
    required this.scale,
  }) : landmarks = List<NormalizedHandLandmark>.unmodifiable(landmarks);

  final int timestampMs;
  final List<NormalizedHandLandmark> landmarks;
  final double scale;
}

class HandNormalization {
  const HandNormalization._();

  static const int handLandmarkCount = 21;
  static const double minimumScale = 1e-6;

  static HandNormalizedFrame? normalize({
    required int timestampMs,
    required List<Landmark> landmarks,
  }) {
    if (landmarks.length < handLandmarkCount) return null;

    final wrist = landmarks[0];
    var scale = _distance(landmarks[5], landmarks[17]);
    if (scale < minimumScale) {
      scale = _distance(wrist, landmarks[9]);
    }
    if (!scale.isFinite || scale < minimumScale) return null;

    final normalized = List<NormalizedHandLandmark>.generate(
      handLandmarkCount,
      (index) {
        final point = landmarks[index];
        return NormalizedHandLandmark(
          (point.x - wrist.x) / scale,
          (point.y - wrist.y) / scale,
          (point.z - wrist.z) / scale,
        );
      },
      growable: false,
    );

    return HandNormalizedFrame(
      timestampMs: timestampMs,
      landmarks: normalized,
      scale: scale,
    );
  }

  static double _distance(Landmark a, Landmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final dz = a.z - b.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}

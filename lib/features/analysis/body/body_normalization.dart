import 'dart:math' as math;
import 'dart:ui';

class BodyNormalizedFrame {
  BodyNormalizedFrame({
    required this.timestampMs,
    required List<Offset> landmarks,
    required List<double> scores,
    required this.keyJointConfidence,
    required this.scale,
  })  : landmarks = List<Offset>.unmodifiable(landmarks),
        scores = List<double>.unmodifiable(scores);

  final int timestampMs;
  final List<Offset> landmarks;
  final List<double> scores;
  final double keyJointConfidence;
  final double scale;
}

class BodyNormalization {
  const BodyNormalization._();

  static const int bodyLandmarkCount = 17;
  static const double confidenceThreshold = 0.3;
  static const double minimumScale = 1e-4;

  static BodyNormalizedFrame? normalize({
    required int timestampMs,
    required List<Offset> landmarks,
    required List<double> scores,
  }) {
    if (landmarks.length < bodyLandmarkCount ||
        scores.length < bodyLandmarkCount) {
      return null;
    }

    const keyIndices = [5, 6, 11, 12];
    if (keyIndices.any((index) => scores[index] < confidenceThreshold)) {
      return null;
    }

    final leftShoulder = landmarks[5];
    final rightShoulder = landmarks[6];
    final leftHip = landmarks[11];
    final rightHip = landmarks[12];
    final hipOrigin = Offset(
      (leftHip.dx + rightHip.dx) / 2,
      (leftHip.dy + rightHip.dy) / 2,
    );

    var scale = _distance(leftShoulder, rightShoulder);
    if (scale < minimumScale) {
      final shoulderMidpoint = Offset(
        (leftShoulder.dx + rightShoulder.dx) / 2,
        (leftShoulder.dy + rightShoulder.dy) / 2,
      );
      scale = _distance(shoulderMidpoint, hipOrigin);
    }
    if (!scale.isFinite || scale < minimumScale) return null;

    final normalized = List<Offset>.generate(
      bodyLandmarkCount,
      (index) => Offset(
        (landmarks[index].dx - hipOrigin.dx) / scale,
        (landmarks[index].dy - hipOrigin.dy) / scale,
      ),
      growable: false,
    );
    final bodyScores = scores.take(bodyLandmarkCount).toList(growable: false);
    final keyConfidence =
        keyIndices.map((index) => scores[index]).reduce((a, b) => a + b) /
            keyIndices.length;

    return BodyNormalizedFrame(
      timestampMs: timestampMs,
      landmarks: normalized,
      scores: bodyScores,
      keyJointConfidence: keyConfidence,
      scale: scale,
    );
  }

  static double _distance(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
}

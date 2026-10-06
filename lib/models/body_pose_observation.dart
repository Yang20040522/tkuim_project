import 'dart:ui';

/// Metadata assigned at JPEG receipt, before decode or inference.
class BodyFrameIdentity {
  const BodyFrameIdentity(
      {required this.frameId,
      required this.streamSessionId,
      required this.receivedAtMs});
  final int frameId, receivedAtMs;
  final String streamSessionId;
}

/// One processed RTMPose frame. Coordinates are normalized image coordinates;
/// indices retain RTMPose anatomical semantics, independent of display mirror.
/// SimCC peaks are NOT calibrated probabilities and may exceed one.
class BodyPoseObservation {
  BodyPoseObservation({
    required this.frameId,
    required this.streamSessionId,
    required this.receivedAtMs,
    required this.imageWidth,
    required this.imageHeight,
    required this.source,
    required List<Offset?> keypoints,
    required List<double?> scores,
    this.poseModelVersion = 'rtmpose-wholebody-133-v1',
    this.coordinateTransformVersion = 'rtmpose-image-normalized-v1',
    this.timestampOrigin = 'tv_receive_monotonic',
    this.mirrored = false,
    this.rotationDegrees = 0,
  }) {
    if (frameId < 0 ||
        receivedAtMs < 0 ||
        streamSessionId.isEmpty ||
        imageWidth <= 0 ||
        imageHeight <= 0 ||
        keypoints.length != scores.length ||
        keypoints.length < 17 ||
        !const {'phone', 'tv_pi'}.contains(source) ||
        !const {0, 90, 180, 270}.contains(rotationDegrees)) {
      throw const FormatException('Invalid body observation metadata');
    }
    this.keypoints = List.unmodifiable(keypoints.map((p) => p != null &&
            p.dx.isFinite &&
            p.dy.isFinite &&
            p.dx >= 0 &&
            p.dx <= 1 &&
            p.dy >= 0 &&
            p.dy <= 1
        ? p
        : null));
    this.scores = List.unmodifiable(
        scores.map((s) => s != null && s.isFinite && s >= 0 ? s : null));
    validity = List.unmodifiable(List.generate(
        keypoints.length,
        (i) =>
            this.keypoints[i] != null &&
            (this.scores[i] ?? -1) >= minimumScore));
  }

  static const minimumScore = 0.3;
  static const scoreSemantics = 'simcc_peak_mean_uncalibrated';
  final int frameId, receivedAtMs, imageWidth, imageHeight;
  final String streamSessionId, source, poseModelVersion;
  final String coordinateTransformVersion, timestampOrigin;
  final bool mirrored;
  final int rotationDegrees;
  // Pi JPEG protocol does not supply sensor capture time.
  DateTime? get captureTimestamp => null;
  late final List<Offset?> keypoints;
  late final List<double?> scores;
  late final List<bool> validity;

  Offset? pixelPoint(int index) {
    if (index < 0 || index >= validity.length || !validity[index]) return null;
    final point = keypoints[index]!;
    return Offset(point.dx * imageWidth, point.dy * imageHeight);
  }

  Map<String, Object?> toJson() => {
        'frameId': frameId,
        'streamSessionId': streamSessionId,
        'timestampMs': receivedAtMs,
        'timestampOrigin': timestampOrigin,
        'captureTimestamp': null,
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
        'source': source,
        'poseModelVersion': poseModelVersion,
        'coordinateTransformVersion': coordinateTransformVersion,
        'mirrored': mirrored,
        'rotationDegrees': rotationDegrees,
        'scoreSemantics': scoreSemantics,
        'keypoints': keypoints
            .take(17)
            .map((p) => p == null ? null : [p.dx, p.dy])
            .toList(),
        'scores': scores.take(17).toList(),
        'validity': validity.take(17).toList(),
      };
}

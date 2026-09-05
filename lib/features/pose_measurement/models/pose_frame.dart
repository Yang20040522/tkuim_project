import 'pose_geometry.dart';
import 'pose_landmark.dart';

export 'pose_geometry.dart';
export 'pose_landmark.dart';

/// Immutable native result. Display and measurement coordinates stay separate.
class PoseFrame {
  PoseFrame({
    required this.timestampMs,
    Map<PoseLandmarkType, PoseLandmark> landmarks = const {},
    Map<PoseLandmarkType, PoseLandmark> worldLandmarks = const {},
    this.geometry,
    this.inferenceMs = 0,
  })  : landmarks = Map.unmodifiable(landmarks),
        worldLandmarks = Map.unmodifiable(worldLandmarks);

  final int timestampMs;
  final Map<PoseLandmarkType, PoseLandmark> landmarks;
  final Map<PoseLandmarkType, PoseLandmark> worldLandmarks;
  final PoseGeometry? geometry;
  final double inferenceMs;

  /// Detection is distinct from the reliability of any particular joint.
  bool get hasPose => landmarks.isNotEmpty;

  factory PoseFrame.fromPlatform(Map<dynamic, dynamic> value) {
    final timestamp = value['timestampMs'];
    if (timestamp is! num || !timestamp.isFinite || timestamp < 0) {
      throw const FormatException('Invalid pose timestamp');
    }
    final inference = value['inferenceMs'];
    return PoseFrame(
      timestampMs: timestamp.toInt(),
      landmarks: _parseLandmarks(value['landmarks']),
      worldLandmarks: _parseLandmarks(value['worldLandmarks']),
      geometry: PoseGeometry.tryFromPlatform(value['geometry']),
      inferenceMs: inference is num && inference.isFinite && inference >= 0
          ? inference.toDouble()
          : 0,
    );
  }

  static Map<PoseLandmarkType, PoseLandmark> _parseLandmarks(Object? values) {
    if (values == null) return {};
    if (values is! List) {
      throw const FormatException('Invalid pose landmarks');
    }
    final result = <PoseLandmarkType, PoseLandmark>{};
    for (var index = 0;
        index < values.length && index < PoseLandmarkType.values.length;
        index++) {
      final landmark = PoseLandmark.tryFromPlatform(values[index]);
      if (landmark != null) {
        // Invalid entries are omitted WITHOUT shifting later anatomical indices.
        result[PoseLandmarkType.values[index]] = landmark;
      }
    }
    return result;
  }
}

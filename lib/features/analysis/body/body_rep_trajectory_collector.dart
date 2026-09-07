import 'dart:ui';

import 'body_normalization.dart';

class BodyTrajectorySample {
  BodyTrajectorySample({
    required this.timestampMs,
    required List<Offset> landmarks,
    required List<double> scores,
  })  : landmarks = List<Offset>.unmodifiable(landmarks),
        scores = List<double>.unmodifiable(scores);

  final int timestampMs;
  final List<Offset> landmarks;
  final List<double> scores;
}

/// Lightweight, bounded raw-landmark collector used before an existing action
/// reports `RehabFeedback.scored`.
///
/// No normalization or comparison happens in [addFrame].
class BodyRepTrajectoryCollector {
  BodyRepTrajectoryCollector({
    this.samplingInterval = const Duration(milliseconds: 100),
    this.retentionDuration = const Duration(seconds: 8),
    this.maximumFrames = 80,
  })  : assert(samplingInterval > Duration.zero),
        assert(retentionDuration > Duration.zero),
        assert(maximumFrames > 0);

  final Duration samplingInterval;
  final Duration retentionDuration;
  final int maximumFrames;
  final List<BodyTrajectorySample> _samples = [];

  int get length => _samples.length;
  bool get isEmpty => _samples.isEmpty;

  bool addFrame({
    required int timestampMs,
    required List<Offset> landmarks,
    required List<double> scores,
    bool force = false,
  }) {
    if (landmarks.length < BodyNormalization.bodyLandmarkCount ||
        scores.length < BodyNormalization.bodyLandmarkCount) {
      return false;
    }

    if (_samples.isNotEmpty) {
      final lastTimestamp = _samples.last.timestampMs;
      if (timestampMs < lastTimestamp) return false;
      if (timestampMs == lastTimestamp) return true;
      if (!force &&
          timestampMs - lastTimestamp < samplingInterval.inMilliseconds) {
        return false;
      }
    }

    _samples.add(BodyTrajectorySample(
      timestampMs: timestampMs,
      landmarks: landmarks.take(BodyNormalization.bodyLandmarkCount).toList(),
      scores: scores.take(BodyNormalization.bodyLandmarkCount).toList(),
    ));
    _prune(timestampMs);
    return true;
  }

  List<BodyTrajectorySample> takeCompletedRep() {
    final completed = List<BodyTrajectorySample>.unmodifiable(_samples);
    _samples.clear();
    return completed;
  }

  void reset() => _samples.clear();

  void _prune(int newestTimestampMs) {
    final earliest = newestTimestampMs - retentionDuration.inMilliseconds;
    while (_samples.isNotEmpty && _samples.first.timestampMs < earliest) {
      _samples.removeAt(0);
    }
    while (_samples.length > maximumFrames) {
      _samples.removeAt(0);
    }
  }
}

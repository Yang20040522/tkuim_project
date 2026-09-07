class TimedVectorSample {
  TimedVectorSample({
    required this.timestampMs,
    required List<double> values,
  }) : values = List<double>.unmodifiable(values);

  final int timestampMs;
  final List<double> values;
}

class ResampledVectorPoint {
  ResampledVectorPoint({
    required this.progress,
    required this.timestampMs,
    required List<double> values,
  }) : values = List<double>.unmodifiable(values);

  final double progress;
  final int timestampMs;
  final List<double> values;
}

class TrajectoryResampler {
  const TrajectoryResampler._();

  static List<ResampledVectorPoint> resample({
    required List<TimedVectorSample> samples,
    required int startMs,
    required int endMs,
    int pointCount = 21,
  }) {
    if (pointCount < 2) {
      throw ArgumentError.value(pointCount, 'pointCount', '至少需要 2 點');
    }
    if (endMs <= startMs) {
      throw ArgumentError('endMs 必須大於 startMs');
    }
    if (samples.isEmpty) return const [];

    final ordered = [...samples]
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    final dimensions = ordered.first.values.length;
    if (dimensions == 0 ||
        ordered.any((sample) => sample.values.length != dimensions)) {
      throw ArgumentError('所有 trajectory sample 必須有相同且非空的維度');
    }

    final result = <ResampledVectorPoint>[];
    var rightIndex = 0;
    for (var i = 0; i < pointCount; i++) {
      final progress = i / (pointCount - 1);
      final target = startMs + ((endMs - startMs) * progress).round();

      while (rightIndex < ordered.length &&
          ordered[rightIndex].timestampMs < target) {
        rightIndex++;
      }

      late List<double> values;
      if (rightIndex == 0) {
        values = ordered.first.values;
      } else if (rightIndex >= ordered.length) {
        values = ordered.last.values;
      } else {
        final left = ordered[rightIndex - 1];
        final right = ordered[rightIndex];
        final span = right.timestampMs - left.timestampMs;
        final ratio = span <= 0 ? 0.0 : (target - left.timestampMs) / span;
        values = List<double>.generate(
          dimensions,
          (index) =>
              left.values[index] +
              (right.values[index] - left.values[index]) * ratio,
          growable: false,
        );
      }

      result.add(ResampledVectorPoint(
        progress: progress,
        timestampMs: target,
        values: values,
      ));
    }
    return result;
  }
}

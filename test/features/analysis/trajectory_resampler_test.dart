import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_body/features/analysis/shared/trajectory_resampler.dart';

void main() {
  test('resamples against true timestamps instead of valid-frame indexes', () {
    final result = TrajectoryResampler.resample(
      samples: [
        TimedVectorSample(timestampMs: 0, values: [0, 10]),
        TimedVectorSample(timestampMs: 800, values: [8, 18]),
      ],
      startMs: 0,
      endMs: 1000,
      pointCount: 6,
    );

    expect(result.map((point) => point.timestampMs),
        [0, 200, 400, 600, 800, 1000]);
    expect(result.map((point) => point.progress), [0, 0.2, 0.4, 0.6, 0.8, 1]);
    expect(result.map((point) => point.values.first), [0, 2, 4, 6, 8, 8]);
    expect(result.last.values.last, 18);
  });

  test('default output contains 21 fixed progress points', () {
    final result = TrajectoryResampler.resample(
      samples: [
        TimedVectorSample(timestampMs: 100, values: [1]),
        TimedVectorSample(timestampMs: 1100, values: [11]),
      ],
      startMs: 100,
      endMs: 1100,
    );

    expect(result, hasLength(21));
    expect(result.first.progress, 0);
    expect(result.last.progress, 1);
    expect(result[10].timestampMs, 600);
    expect(result[10].values.single, closeTo(6, 1e-9));
  });
}

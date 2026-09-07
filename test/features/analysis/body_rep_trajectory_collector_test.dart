import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_body/features/analysis/body/body_rep_trajectory_collector.dart';

void main() {
  test('collector samples lightly and remains bounded', () {
    final collector = BodyRepTrajectoryCollector();
    final landmarks = List<Offset>.filled(17, const Offset(0.5, 0.5));
    final scores = List<double>.filled(17, 0.9);

    for (var index = 0; index < 1000; index++) {
      collector.addFrame(
        timestampMs: index * 20,
        landmarks: landmarks,
        scores: scores,
      );
    }

    expect(collector.length, lessThanOrEqualTo(80));
    final completed = collector.takeCompletedRep();
    expect(completed, isNotEmpty);
    expect(completed.last.timestampMs - completed.first.timestampMs,
        lessThanOrEqualTo(const Duration(seconds: 8).inMilliseconds));
    expect(collector.isEmpty, isTrue);
    expect(() => completed.add(completed.first), throwsUnsupportedError);
  });

  test('force keeps the scored frame inside the normal sample interval', () {
    final collector = BodyRepTrajectoryCollector();
    final landmarks = List<Offset>.filled(17, const Offset(0.5, 0.5));
    final scores = List<double>.filled(17, 0.9);

    collector.addFrame(
      timestampMs: 100,
      landmarks: landmarks,
      scores: scores,
    );
    expect(
      collector.addFrame(
        timestampMs: 150,
        landmarks: landmarks,
        scores: scores,
      ),
      isFalse,
    );
    collector.addFrame(
      timestampMs: 150,
      landmarks: landmarks,
      scores: scores,
      force: true,
    );

    expect(
      collector.takeCompletedRep().map((sample) => sample.timestampMs),
      [100, 150],
    );
  });
}

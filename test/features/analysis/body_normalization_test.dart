import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_body/features/analysis/body/body_normalization.dart';

void main() {
  test('normalizes around hip midpoint with shoulder-width scale', () {
    final landmarks = List<Offset>.filled(17, const Offset(0.5, 0.5));
    landmarks[5] = const Offset(0.4, 0.3);
    landmarks[6] = const Offset(0.6, 0.3);
    landmarks[11] = const Offset(0.4, 0.7);
    landmarks[12] = const Offset(0.6, 0.7);
    final original = List<Offset>.from(landmarks);
    final scores = List<double>.filled(17, 0.9);

    final normalized = BodyNormalization.normalize(
      timestampMs: 1250,
      landmarks: landmarks,
      scores: scores,
    );

    expect(normalized, isNotNull);
    expect(normalized!.timestampMs, 1250);
    expect(normalized.scale, closeTo(0.2, 1e-9));
    final hipMidpoint = Offset(
      (normalized.landmarks[11].dx + normalized.landmarks[12].dx) / 2,
      (normalized.landmarks[11].dy + normalized.landmarks[12].dy) / 2,
    );
    expect(hipMidpoint.dx, closeTo(0, 1e-9));
    expect(hipMidpoint.dy, closeTo(0, 1e-9));
    expect(
      (normalized.landmarks[5] - normalized.landmarks[6]).distance,
      closeTo(1, 1e-9),
    );
    expect(landmarks, original, reason: 'normalization must not mutate input');
  });

  test('rejects insufficient key-joint confidence', () {
    final landmarks = List<Offset>.filled(17, const Offset(0.5, 0.5));
    landmarks[5] = const Offset(0.4, 0.3);
    landmarks[6] = const Offset(0.6, 0.3);
    landmarks[11] = const Offset(0.4, 0.7);
    landmarks[12] = const Offset(0.6, 0.7);
    final scores = List<double>.filled(17, 0.9)..[11] = 0.1;

    expect(
      BodyNormalization.normalize(
        timestampMs: 0,
        landmarks: landmarks,
        scores: scores,
      ),
      isNull,
    );
  });

  test('rejects an unusable normalization scale', () {
    final landmarks = List<Offset>.filled(17, const Offset(0.5, 0.5));
    final scores = List<double>.filled(17, 0.9);

    expect(
      BodyNormalization.normalize(
        timestampMs: 0,
        landmarks: landmarks,
        scores: scores,
      ),
      isNull,
    );
  });
}

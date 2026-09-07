import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_body/features/analysis/hand/hand_normalization.dart';
import 'package:flutter_body/services/mediapipe_service.dart';

void main() {
  test('normalizes xyz around wrist using palm width', () {
    final landmarks = List<Landmark>.filled(21, const Landmark(0.5, 0.5, 0));
    landmarks[0] = const Landmark(0.5, 0.5, 0.1);
    landmarks[5] = const Landmark(0.6, 0.5, 0.1);
    landmarks[17] = const Landmark(0.4, 0.5, 0.1);
    landmarks[8] = const Landmark(0.7, 0.3, 0.3);

    final normalized = HandNormalization.normalize(
      timestampMs: 750,
      landmarks: landmarks,
    );

    expect(normalized, isNotNull);
    expect(normalized!.timestampMs, 750);
    expect(normalized.scale, closeTo(0.2, 1e-9));
    expect(normalized.landmarks[0].x, closeTo(0, 1e-9));
    expect(normalized.landmarks[0].y, closeTo(0, 1e-9));
    expect(normalized.landmarks[0].z, closeTo(0, 1e-9));
    expect(normalized.landmarks[8].x, closeTo(1, 1e-9));
    expect(normalized.landmarks[8].y, closeTo(-1, 1e-9));
    expect(normalized.landmarks[8].z, closeTo(1, 1e-9));
  });

  test('falls back to wrist-to-middle-MCP scale', () {
    final landmarks = List<Landmark>.filled(21, const Landmark(0.5, 0.5, 0));
    landmarks[5] = const Landmark(0.6, 0.5, 0);
    landmarks[17] = const Landmark(0.6, 0.5, 0);
    landmarks[9] = const Landmark(0.5, 0.3, 0);

    final normalized = HandNormalization.normalize(
      timestampMs: 0,
      landmarks: landmarks,
    );

    expect(normalized, isNotNull);
    expect(normalized!.scale, closeTo(0.2, 1e-9));
  });

  test('rejects an unusable normalization scale', () {
    final landmarks = List<Landmark>.filled(21, const Landmark(0.5, 0.5, 0));

    expect(
      HandNormalization.normalize(timestampMs: 0, landmarks: landmarks),
      isNull,
    );
  });
}

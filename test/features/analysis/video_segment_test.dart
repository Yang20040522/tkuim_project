import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_body/features/analysis/models/video_segment.dart';

void main() {
  test('whole video segment is valid', () {
    const duration = Duration(seconds: 12);
    final segment = VideoSegment.whole(duration);

    expect(segment.startTime, Duration.zero);
    expect(segment.endTime, duration);
    expect(segment.validationError(duration), isNull);
  });

  test('invalid segment boundaries return readable validation errors', () {
    const duration = Duration(seconds: 10);

    expect(
      const VideoSegment(
        startTime: Duration(seconds: 4),
        endTime: Duration(seconds: 4),
      ).validationError(duration),
      isNotNull,
    );
    expect(
      const VideoSegment(
        startTime: Duration(seconds: -1),
        endTime: Duration(seconds: 4),
      ).validationError(duration),
      isNotNull,
    );
    expect(
      const VideoSegment(
        startTime: Duration.zero,
        endTime: Duration(seconds: 11),
      ).validationError(duration),
      isNotNull,
    );
  });

  test('resolve respects a non-zero start and maximum duration', () {
    final segment = VideoSegment.resolve(
      videoDuration: const Duration(seconds: 100),
      startTime: const Duration(seconds: 20),
      endTime: const Duration(seconds: 90),
      maximumDuration: const Duration(seconds: 60),
    );

    expect(segment.startMs, 20000);
    expect(segment.endMs, 80000);
  });
}

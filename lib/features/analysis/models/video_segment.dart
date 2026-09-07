class VideoSegment {
  const VideoSegment({
    required this.startTime,
    required this.endTime,
  });

  final Duration startTime;
  final Duration endTime;

  int get startMs => startTime.inMilliseconds;
  int get endMs => endTime.inMilliseconds;
  Duration get duration => endTime - startTime;

  String? validationError(Duration videoDuration) {
    if (videoDuration <= Duration.zero) return '無法取得影片長度。';
    if (startTime < Duration.zero) return '開始時間不能小於 0。';
    if (endTime > videoDuration) return '結束時間不能超過影片長度。';
    if (endTime <= startTime) return '結束時間必須晚於開始時間。';
    return null;
  }

  VideoSegment limitedTo({
    required Duration videoDuration,
    Duration? maximumDuration,
  }) {
    var start = startTime;
    var end = endTime;

    if (start < Duration.zero) start = Duration.zero;
    if (start > videoDuration) start = videoDuration;
    if (end > videoDuration) end = videoDuration;
    if (maximumDuration != null && end - start > maximumDuration) {
      end = start + maximumDuration;
    }

    return VideoSegment(startTime: start, endTime: end);
  }

  static VideoSegment whole(Duration videoDuration) => VideoSegment(
        startTime: Duration.zero,
        endTime: videoDuration,
      );

  static VideoSegment resolve({
    required Duration videoDuration,
    Duration? startTime,
    Duration? endTime,
    Duration? maximumDuration,
  }) {
    final segment = VideoSegment(
      startTime: startTime ?? Duration.zero,
      endTime: endTime ?? videoDuration,
    ).limitedTo(
      videoDuration: videoDuration,
      maximumDuration: maximumDuration,
    );
    final error = segment.validationError(videoDuration);
    if (error != null) throw ArgumentError(error);
    return segment;
  }

  Map<String, dynamic> toJson() => {
        'selectedStartMs': startMs,
        'selectedEndMs': endMs,
      };

  @override
  bool operator ==(Object other) =>
      other is VideoSegment &&
      other.startTime == startTime &&
      other.endTime == endTime;

  @override
  int get hashCode => Object.hash(startTime, endTime);
}

/// Read-only presentation of existing research metadata, never clinical scoring.
class ResearchSamplePresentation {
  static String modality(Map<String, dynamic> sample) =>
      sample['modality']?.toString() ??
      (sample['schemaVersion'] == 2 ? 'hand' : 'body');
  static String source(Map<String, dynamic> sample) =>
      sample['source']?.toString() ?? 'phone';
  static String originLabel(Map<String, dynamic> sample) =>
      modality(sample) == 'hand'
          ? 'Phone Hand'
          : source(sample) == 'tv_pi'
              ? 'TV + Pi Body'
              : 'Phone Body';
  static bool matches(
      Map<String, dynamic> sample, Map<String, String> filters) {
    final values = {
      'modality': modality(sample),
      'source': source(sample),
      'patient': sample['subjectId']?.toString() ?? '',
      'exercise': sample['exerciseId']?.toString() ??
          sample['actionId']?.toString() ??
          '',
      'session': sample['sessionId']?.toString() ?? '',
      'status': sample['annotationStatus']?.toString() ?? 'UNLABELED',
      'disposition': sample['disposition']?.toString() ?? 'ACTIVE',
    };
    return filters.entries
        .every((e) => e.value == 'all' || values[e.key] == e.value);
  }
}

/// Timings come from observations, not inference FPS or widget rebuilds.
class ResearchPlaybackTimeline {
  const ResearchPlaybackTimeline(this.frames);
  final List<dynamic> frames;
  Duration intervalAfter(int index) {
    if (index < 0 || index + 1 >= frames.length) return Duration.zero;
    final a = (frames[index] as Map)['timestampMs'];
    final b = (frames[index + 1] as Map)['timestampMs'];
    if (a is! num || b is! num || !a.isFinite || !b.isFinite || b <= a) {
      return const Duration(milliseconds: 100);
    }
    return Duration(milliseconds: (b - a).round());
  }

  bool gapAfter(int index) => intervalAfter(index).inMilliseconds >= 500;
}

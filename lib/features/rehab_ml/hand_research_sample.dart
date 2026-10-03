import 'dart:math' as math;
import '../../services/mediapipe_service.dart';
import 'ml_action_definition.dart';

/// Channel observations (native smoothing retained), never Dart prediction frames.
class HandResearchSample implements MlResearchSample {
  HandResearchSample(this.payload);
  final Map<String, Object> payload;
  @override
  String get id => payload['sampleId'] as String;
  @override
  Map<String, Object> toJson() => payload;
}

class HandFeatureExtractor {
  static bool validPoints(List<List<double>> p) {
    if (p.length != 21 ||
        p.any((v) => v.length != 3 || v.any((n) => !n.isFinite)) ||
        p.any((v) =>
            v[0] < 0 || v[0] > 1 || v[1] < 0 || v[1] > 1 || v[2].abs() > 5)) {
      return false;
    }
    final scale = distance(p[0], p[9]);
    return scale >= 0.02 &&
        scale <= 0.8 &&
        distance(p[5], p[17]) / scale >= 0.1;
  }

  static double distance(List<double> a, List<double> b) =>
      math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2));
  static double bearing(List<List<double>> p) =>
      math.atan2(p[9][1] - p[0][1], p[9][0] - p[0][0]) * 180 / math.pi;
  static double delta(double a, double b) => (a - b + 540) % 360 - 180;
  static double range(List<double> v) =>
      v.reduce(math.max) - v.reduce(math.min);

  static List<double> extract(
      MlActionDefinition action, List<Map<String, Object>> frames) {
    if (!action.isHand || frames.length < 4 || frames.length > 200) {
      throw const FormatException('手部動作資料不完整');
    }
    final points = <List<List<double>>>[];
    var previous = -1;
    for (final f in frames) {
      final t = f['timestampMs'] as int;
      final p = (f['landmarks'] as List)
          .map((v) => (v as List).map((n) => (n as num).toDouble()).toList())
          .toList();
      if (t < 0 ||
          t <= previous ||
          (previous >= 0 && t - previous > 350) ||
          !validPoints(p)) {
        throw const FormatException('手部追蹤資料無效');
      }
      previous = t;
      points.add(p);
    }
    final duration = ((frames.last['timestampMs'] as int) -
            (frames.first['timestampMs'] as int)) /
        1000;
    if (duration < 0.3 || duration > 20) {
      throw const FormatException('手部週期時間無效');
    }
    final axis = <double>[0];
    for (var i = 1; i < points.length; i++) {
      axis.add(axis.last + delta(bearing(points[i]), bearing(points[i - 1])));
    }
    final step =
        List.generate(axis.length - 1, (i) => (axis[i + 1] - axis[i]).abs())
                .reduce((a, b) => a + b) /
            (axis.length - 1);
    if (action.actionId == 'sidePinch') {
      final ratios = points
          .map((p) => distance(p[4], p[6]) / distance(p[0], p[9]))
          .toList();
      final travel = points
          .map((p) =>
              distance(p[0], points.first[0]) /
              distance(points.first[0], points.first[9]))
          .reduce(math.max);
      if (range(ratios) < 0.01) throw const FormatException('缺少完整開合變化');
      return [
        ratios.reduce(math.min),
        ratios.reduce(math.max),
        range(ratios),
        travel,
        duration
      ];
    }
    if (range(axis) < 1) throw const FormatException('缺少完整姿態變化');
    if (range(axis) > 360 || axis.any((v) => v.abs() > 360)) {
      throw const FormatException('姿態變化超出研究特徵契約');
    }
    if (action.actionId == 'turnPalm') {
      final x = points
          .map((p) => (p[9][0] - p[0][0]) / distance(p[0], p[9]))
          .toList();
      final normal = points.map((p) {
        final ux = p[5][0] - p[0][0],
            uy = p[5][1] - p[0][1],
            uz = p[5][2] - p[0][2];
        final vx = p[17][0] - p[0][0],
            vy = p[17][1] - p[0][1],
            vz = p[17][2] - p[0][2];
        final nx = uy * vz - uz * vy,
            ny = uz * vx - ux * vz,
            nz = ux * vy - uy * vx;
        final length = math.sqrt(nx * nx + ny * ny + nz * nz);
        if (length < 1e-8) throw const FormatException('手掌平面無效');
        return nz / length;
      }).toList();
      return [range(x), range(normal), range(axis), step, duration];
    }
    return [
      axis.reduce(math.min),
      axis.reduce(math.max),
      range(axis),
      step,
      duration
    ];
  }
}

/// Observes rule count, never determines/counts repetitions itself.
class HandMotionCollector {
  HandMotionCollector(this.action);
  final MlActionDefinition action;
  final _frames = <Map<String, Object>>[];
  int? _rep, _level, _lastObservation;
  bool _anchored = false;
  List<List<double>>? _lastPoints;
  void reset() {
    _frames.clear();
    _rep = null;
    _level = null;
    _lastObservation = null;
    _lastPoints = null;
    _anchored = false;
  }

  void _loseInterval() {
    _frames.clear();
    _lastObservation = null;
    _lastPoints = null;
    _anchored = false;
  }

  HandResearchSample? observe(
      {required List<Landmark>? landmarks,
      required bool detected,
      required int timestampMs,
      required int repCount,
      required int level,
      required bool consent,
      required bool ready,
      required String subjectId,
      required String cameraView,
      required String sampleId,
      required DateTime capturedAt}) {
    if (!consent ||
        !ready ||
        !RegExp(r'^[A-Za-z0-9_-]{3,40}$').hasMatch(subjectId) ||
        !const {'front', 'rear'}.contains(cameraView)) {
      reset();
      return null;
    }
    if (_level != null && _level != level) reset();
    _level = level;
    final oldRep = _rep ?? repCount;
    _rep = repCount;
    final boundary = repCount == oldRep + 1;
    if (repCount < oldRep || repCount > oldRep + 1) {
      _loseInterval();
      return null;
    }
    final p = landmarks?.map((v) => [v.x, v.y, v.z]).toList();
    if (!detected ||
        p == null ||
        !HandFeatureExtractor.validPoints(p) ||
        (_lastObservation != null &&
            (timestampMs <= _lastObservation! ||
                timestampMs - _lastObservation! > 350)) ||
        (_lastPoints != null &&
            HandFeatureExtractor.distance(p[0], _lastPoints![0]) /
                    HandFeatureExtractor.distance(
                        _lastPoints![0], _lastPoints![9]) >
                1.5)) {
      _loseInterval();
      return null;
    }
    _lastObservation = timestampMs;
    _lastPoints = p;
    final frame = <String, Object>{'timestampMs': timestampMs, 'landmarks': p};
    if (_anchored &&
        (_frames.isEmpty ||
            timestampMs - (_frames.last['timestampMs'] as int) >= 100 ||
            boundary)) {
      _frames.add(frame);
      if (_frames.length > 200 ||
          timestampMs - (_frames.first['timestampMs'] as int) > 20000) {
        _loseInterval();
        return null;
      }
    }
    if (!boundary) return null;
    HandResearchSample? result;
    if (_anchored) {
      try {
        final features = HandFeatureExtractor.extract(action, _frames);
        result = HandResearchSample({
          'sampleId': sampleId,
          'subjectId': subjectId,
          'actionId': action.actionId,
          'schemaVersion': 2,
          'actionDefinitionVersion': action.version,
          'landmarkSource': 'mediapipe_hand_21',
          'extractorVersion': 'hand-image-proxy-v1',
          'modelInputVersion': 'hand-features-v1',
          'timestampOrigin': 'channel-arrival-stopwatch',
          'timestampMs': timestampMs,
          'anatomicalSide': 'unknown',
          'movementSide': 'unknown',
          'cameraView': cameraView,
          'capturedAt': capturedAt.toUtc().toIso8601String(),
          'featureNames': action.featureNames,
          'orderedFeatureNames': action.featureNames,
          'features': features,
          'segment': {
            'startMs': _frames.first['timestampMs']!,
            'endMs': timestampMs,
            'kind': 'rule-rep-boundaries',
            'completedReps': 1
          },
          'frames': List<Map<String, Object>>.from(_frames),
        });
      } catch (_) {/* Auxiliary quality rejection cannot affect training. */}
    }
    _anchored = true;
    _frames
      ..clear()
      ..add(frame);
    return result;
  }
}

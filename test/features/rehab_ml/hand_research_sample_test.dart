import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/rehab_ml/hand_research_sample.dart';
import 'package:flutter_body/features/rehab_ml/ml_action_definition.dart';
import 'package:flutter_body/services/mediapipe_service.dart';

Map<String, dynamic> golden() =>
    jsonDecode(File('ml/tests/fixtures/g5_hand_motion.json').readAsStringSync())
        as Map<String, dynamic>;
List<Landmark> pose(int i) {
  final g = golden(), angle = (g['anglesDeg'][i] as num) * math.pi / 180;
  final p = (g['basePoints'] as List)
      .map((v) => (v as List).map((n) => (n as num).toDouble()).toList())
      .toList();
  p[4][0] = p[6][0] + (g['pinchRatios'][i] as num) * 0.2;
  return p.map((v) {
    final x = v[0] - 0.5, y = v[1] - 0.5;
    return Landmark(0.5 + x * math.cos(angle) - y * math.sin(angle),
        0.5 + x * math.sin(angle) + y * math.cos(angle), v[2]);
  }).toList();
}

void main() {
  for (final a in MlActionRegistry.hands) {
    test('${a.actionId} golden and boundary aligned capture', () {
      final c = HandMotionCollector(a);
      HandResearchSample? observe(int i, int rep,
              {bool consent = true,
              List<Landmark>? points,
              bool detected = true,
              int? time}) =>
          c.observe(
              landmarks: points ?? pose(i),
              detected: detected,
              timestampMs: time ?? i * 300,
              repCount: rep,
              level: 1,
              consent: consent,
              ready: true,
              subjectId: 'synthetic_1',
              cameraView: 'front',
              sampleId: 'synthetic',
              capturedAt: DateTime.utc(2026));
      expect(
          observe(0, 0), isNull); // cannot collect a partial first repetition
      expect(observe(0, 1, time: 1), isNull); // first count anchors
      HandResearchSample? sample;
      for (var i = 1; i < 6; i++) {
        sample = observe(i, i == 5 ? 2 : 1, time: 1 + i * 300);
      }
      expect(sample, isNotNull);
      expect(
          sample!.toJson()['features'],
          orderedEquals((golden()['expected'][a.actionId] as List)
              .map((n) => (n as num).toDouble())
              .map((v) => closeTo(v, 1e-5))));
      expect(MlActionRegistry.production.forSample(sample.toJson()), a);
      expect(sample.toJson().containsKey('confidence'), isFalse);
      expect(sample.toJson()['anatomicalSide'], 'unknown');
      expect(observe(5, 2, time: 1600), isNull); // duplicate count
      c.reset();
      expect(observe(0, 0, time: 1800), isNull);
    });
    test('${a.actionId} loss/disabled/invalid/oversized time do not save', () {
      final c = HandMotionCollector(a);
      HandResearchSample? add(int t, int r,
              {bool enabled = true, bool detected = true, List<Landmark>? p}) =>
          c.observe(
              landmarks: p ?? pose(0),
              detected: detected,
              timestampMs: t,
              repCount: r,
              level: 1,
              consent: enabled,
              ready: true,
              subjectId: 'synthetic',
              cameraView: 'rear',
              sampleId: 's',
              capturedAt: DateTime.utc(2026));
      expect(add(0, 0, enabled: false), isNull);
      expect(add(100, 1), isNull);
      expect(add(200, 1, p: [const Landmark(double.nan, 0, 0)]), isNull);
      expect(add(300, 2), isNull);
      expect(add(400, 2, detected: false), isNull);
      expect(add(30000, 3), isNull);
      expect(add(30100, 3, enabled: false), isNull);
      expect(
          HandFeatureExtractor.validPoints(
              List.filled(21, const [0.5, 0.5, 0.0])),
          isFalse);
    });
  }
}

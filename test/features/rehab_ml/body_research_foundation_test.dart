import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/models/body_pose_observation.dart';
import 'package:flutter_body/features/rehab_ml/body_research_attempt_collector.dart';
import 'package:flutter_body/features/rehab_ml/body_research_context.dart';
import 'package:flutter_body/features/rehab_ml/body_research_feature_extractor.dart';
import 'package:flutter_body/features/rehab_ml/body_research_sample.dart';

BodyPoseObservation observation(int time,
    {String stream = 'stream-1',
    bool valid = true,
    bool mirror = false,
    int width = 640,
    int height = 480}) {
  final points = List<Offset?>.filled(17, const Offset(.5, .5));
  points[5] = const Offset(.4, .2);
  points[6] = const Offset(.6, .2);
  points[11] = const Offset(.4, .5);
  points[12] = const Offset(.6, .5);
  points[13] = const Offset(.4, .7);
  points[14] = const Offset(.6, .7);
  points[15] = const Offset(.4, .9);
  points[16] = const Offset(.6, .9);
  if (mirror) {
    for (int i = 0; i < points.length; i++) {
      points[i] = Offset(1 - points[i]!.dx, points[i]!.dy);
    }
  }
  return BodyPoseObservation(
      frameId: time,
      streamSessionId: stream,
      receivedAtMs: time,
      imageWidth: width,
      imageHeight: height,
      source: 'tv_pi',
      keypoints: points,
      scores: List.filled(17, valid ? 1.2 : .1),
      mirrored: mirror);
}

void main() {
  late List<BodyResearchSample> samples;
  late BodyResearchAttemptCollector collector;
  bool ownerCurrent = true;
  setUp(() {
    ownerCurrent = true;
    samples = [];
    collector = BodyResearchAttemptCollector(
        context: BodyResearchContext(
            ownerId: 'synthetic-owner',
            accountGeneration: 1,
            exerciseId: '3',
            movementSide: 'left',
            capturedAt: DateTime.utc(2026, 10, 6)),
        onSample: samples.add,
        ownerIsCurrent: () => ownerCurrent);
  });
  void add(int time,
          {bool moving = true,
          bool baseline = false,
          bool valid = true,
          int reps = 0,
          String stream = 'stream-1'}) =>
      collector.observe(observation(time, valid: valid, stream: stream),
          movementDetected: moving,
          atBaseline: baseline,
          completedReps: reps,
          setIndex: 1);
  void begin() {
    collector.setConsent(true);
    add(0);
    add(100);
    add(200);
  }

  test('observation immutable; SimCC >1 retained; no sensor capture time', () {
    final frame = observation(0);
    expect(frame.scores.first, 1.2);
    expect(frame.captureTimestamp, null);
    expect(frame.timestampOrigin, 'tv_receive_monotonic');
    expect(() => frame.keypoints[0] = Offset.zero, throwsUnsupportedError);
    expect(frame.toJson()['keypoints'], hasLength(17));
  });
  test('NaN and low confidence never become zero research points', () {
    final frame = BodyPoseObservation(
        frameId: 0,
        streamSessionId: 's',
        receivedAtMs: 0,
        imageWidth: 640,
        imageHeight: 480,
        source: 'tv_pi',
        keypoints: List.filled(17, const Offset(double.nan, double.infinity)),
        scores: List.filled(17, double.nan));
    expect(frame.keypoints.every((p) => p == null), true);
    expect(BodyResearchFeatureExtractor.frame(frame, 'left'), null);
    expect(BodyResearchFeatureExtractor.extract([frame], 'left').status,
        'unavailable');
  });
  test('anatomical indices not swapped by display mirror', () {
    final normal = BodyResearchFeatureExtractor.frame(observation(0), 'left')!;
    final mirror = BodyResearchFeatureExtractor.frame(
        observation(0, mirror: true), 'left')!;
    expect(normal.hipDeg, mirror.hipDeg);
    expect(normal.kneeDeg, mirror.kneeDeg);
    expect(normal.trunkLeanDeg.abs(), mirror.trunkLeanDeg.abs());
  });
  test('image aspect ratio is used for projected angles', () {
    final points = observation(0).keypoints.toList();
    points[13] = const Offset(.6, .5);
    final f = BodyPoseObservation(
        frameId: 0,
        streamSessionId: 's',
        receivedAtMs: 0,
        imageWidth: 1280,
        imageHeight: 480,
        source: 'tv_pi',
        keypoints: points,
        scores: List.filled(17, .8));
    expect(BodyResearchFeatureExtractor.frame(f, 'left')!.hipDeg,
        closeTo(90, 1e-6));
  });
  test('without consent or valid established movement no sample', () {
    add(0);
    collector.finish(BodyAttemptTermination.userFinished);
    expect(samples, isEmpty);
    collector.setConsent(true);
    add(100, valid: false);
    add(500, valid: false);
    collector.finish(BodyAttemptTermination.userFinished);
    expect(samples, isEmpty);
  });
  test('one matching frame cannot establish attempt', () {
    collector.setConsent(true);
    add(0);
    collector.finish(BodyAttemptTermination.interrupted);
    expect(samples, isEmpty);
  });
  test('receive gaps cannot masquerade as stable movement confirmation', () {
    collector.setConsent(true);
    add(0);
    add(1000);
    expect(collector.state, BodyCollectorState.ready);
    add(1100);
    add(1200);
    expect(collector.state, BodyCollectorState.recording);
    collector.finish(BodyAttemptTermination.userFinished);
    expect(samples.single.observations.first.receivedAtMs, 1000);
  });
  test('valid uncounted attempt finalized on stable baseline; v3 JSON', () {
    begin();
    add(300, moving: false, baseline: true);
    add(450, moving: false, baseline: true);
    add(600, moving: false, baseline: true);
    expect(samples, hasLength(1));
    final json = jsonDecode(jsonEncode(samples.single.toJson()));
    expect(json['schemaVersion'], 3);
    expect(json['modality'], 'body');
    expect(json['completedRepsAfter'], 0);
    expect(json['featuresStatus'], 'available');
    expect(json.containsKey('patientId'), false);
    expect(collector.state, BodyCollectorState.ready);
    collector.finish(BodyAttemptTermination.userFinished);
    expect(samples, hasLength(1));
  });
  test('successful rep is observed but not changed', () {
    begin();
    add(300, reps: 1);
    collector.finish(BodyAttemptTermination.userFinished);
    expect(samples.single.completedRepsAfter, 1);
    expect(samples.single.completedRepsBefore, 0);
  });
  test('tracking loss preserves attempt with unavailable features', () {
    begin();
    add(300, valid: false);
    add(800, valid: false);
    expect(samples.single.termination, BodyAttemptTermination.trackingLost);
    expect(samples.single.features.status, 'unavailable');
    expect(samples.single.features.values, everyElement(isNull));
  });
  test('no frames watchdog finalizes tracking lost', () {
    begin();
    collector.tick(700);
    expect(samples.single.termination, BodyAttemptTermination.trackingLost);
  });
  test('continuous frames timeout bounded to 200 observations', () {
    begin();
    for (int t = 300; t <= 20100; t += 100) {
      add(t);
    }
    expect(samples.first.termination, BodyAttemptTermination.timeout);
    expect(samples.first.observations.length, lessThanOrEqualTo(200));
  });
  test('explicit interrupt retained; new stream cannot join old sample', () {
    begin();
    add(300);
    add(400, stream: 'stream-2');
    expect(samples.single.termination, BodyAttemptTermination.interrupted);
    expect(
        samples.single.observations
            .every((f) => f.streamSessionId == 'stream-1'),
        true);
  });
  test('stale/duplicate frames ignored', () {
    begin();
    add(100);
    add(200);
    add(300);
    collector.finish(BodyAttemptTermination.userFinished);
    expect(
        samples.single.observations.map((f) => f.frameId), [0, 100, 200, 300]);
  });
  test('logout discards active sample without leaking to new owner', () {
    begin();
    ownerCurrent = false;
    add(300);
    expect(samples, isEmpty);
    expect(collector.state, BodyCollectorState.disabled);
  });
}

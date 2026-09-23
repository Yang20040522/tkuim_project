import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/analysis/body/body_rep_trajectory_collector.dart';
import 'package:flutter_body/features/rehab_ml/ml_quality_evaluator.dart';
import 'package:flutter_body/features/rehab_ml/ml_sample_repository.dart';
import 'package:flutter_body/features/rehab_ml/standing_knee_raise_sample.dart';

void main() {
  List<BodyTrajectorySample> frames({double confidence = 0.9}) {
    final points = List<Offset>.filled(17, Offset.zero);
    points[5] = const Offset(-0.3, -1);
    points[6] = const Offset(0.3, -1);
    points[11] = const Offset(-0.3, 0);
    points[12] = const Offset(0.3, 0);
    points[13] = const Offset(-0.3, 0.5);
    points[14] = const Offset(0.3, 0.5);
    points[15] = const Offset(-0.3, 1);
    points[16] = const Offset(0.3, 1);
    return List.generate(
      4,
      (index) => BodyTrajectorySample(
        timestampMs: index * 100,
        landmarks: points,
        scores: List<double>.filled(17, confidence),
      ),
    );
  }

  StandingKneeRaiseSample? make(List<BodyTrajectorySample> frames,
          {String side = 'left'}) =>
      StandingKneeRaiseSample.fromCompletedRep(
        consentGranted: true,
        id: 'sample_test',
        subjectId: 'participant_01',
        movementSide: side,
        cameraView: 'front',
        capturedAt: DateTime.utc(2026),
        samples: frames,
      );

  test('complete 17-point trajectory produces versioned anonymous JSON', () {
    final sample = make(frames())!;
    final json = sample.toJson();
    expect(json['actionId'], StandingKneeRaiseSample.actionId);
    expect(json['featureNames'], StandingKneeRaiseSample.featureNames);
    expect((json['frames'] as List), hasLength(4));
    expect((json['features'] as List), hasLength(5));
    expect(json.containsKey('patientId'), isFalse);
    expect(json.containsKey('image'), isFalse);
    expect(json.containsKey('video'), isFalse);
    expect(json['movementSide'], 'left');
    expect(make(frames(), side: 'right')?.movementSide, 'right');
  });

  test('missing, short, low confidence and non-finite frames are rejected', () {
    expect(make(frames().take(3).toList()), isNull);
    expect(make(frames(confidence: 0.1)), isNull);
    final invalid = frames();
    final points = List<Offset>.from(invalid[1].landmarks);
    points[13] = const Offset(double.nan, 0);
    invalid[1] = BodyTrajectorySample(
      timestampMs: 100,
      landmarks: points,
      scores: invalid[1].scores,
    );
    expect(make(invalid), isNull);
    expect(make(frames(), side: 'unknown'), isNull);
    expect(
      StandingKneeRaiseSample.fromCompletedRep(
        consentGranted: false,
        id: 'no_consent',
        subjectId: 'research_1',
        movementSide: 'left',
        cameraView: 'front',
        capturedAt: DateTime.utc(2026),
        samples: frames(),
      ),
      isNull,
    );
  });

  test('save, inspect, export and delete use local JSON only', () async {
    final directory = await Directory.systemTemp.createTemp('rehab_ml_test_');
    addTearDown(() => directory.delete(recursive: true));
    final repository =
        MlSampleRepository(directoryProvider: () async => directory);
    final sample = make(frames())!;
    await repository.save(sample);
    final entries = await repository.list();
    expect(entries, hasLength(1));
    expect(entries.single['sampleId'], sample.id);
    final exported = await repository.exportJson(sample.id);
    expect(exported, isNotEmpty);
    await repository.delete(sample.id);
    expect(await repository.list(), isEmpty);
    expect(() => repository.delete('../outside'), throwsFormatException);
  });

  test('no validated model returns unavailable rather than fake prediction',
      () async {
    const evaluator = UnavailableMlQualityEvaluator();
    final result = await evaluator.evaluate([1, 2, 3, 4, 5]);
    expect(result.available, isFalse);
    expect(result.label, isNull);
    expect(result.confidence, isNull);
  });
}

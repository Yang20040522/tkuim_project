import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/rehab_ml/body_research_action_registry.dart';
import 'package:flutter_body/features/rehab_ml/body_research_context.dart';
import 'package:flutter_body/features/rehab_ml/body_review_rep_collector.dart';
import 'package:flutter_body/features/rehab_ml/ml_action_definition.dart';

import 'body_research_foundation_test.dart' show observation;

void main() {
  BodyResearchContext context(String side) => BodyResearchContext(
    ownerId: 'synthetic-owner', accountGeneration: 1,
    exerciseId: '99', movementSide: side,
    capturedAt: DateTime.utc(2026, 10, 7));

  test('all six actions finalize only at scored rep with review-only frames', () {
    for (final action in BodyResearchActionRegistry.actions.where(
        (contract) => contract.schemaVersion == 4)) {
      final side = {'raise_both_arms', 'elbow_forward', 'sit_to_stand'}
          .contains(action.actionId) ? 'bilateral' : 'left';
      final samples = <BodyReviewSample>[];
      final collector = BodyReviewRepCollector(
          context: context(side), contract: action, onSample: samples.add);
      for (final time in [0, 100, 200]) {
        collector.observe(observation(time), scored: false,
            completedReps: 0, setIndex: 1, movementSide: side);
      }
      expect(samples, isEmpty);
      collector.observe(observation(300), scored: true,
          completedReps: 1, setIndex: 1, movementSide: side,
          movementMode: action.actionId == 'lateral_step' ? 'simple' : null,
          difficulty: '初級');
      expect(samples, hasLength(1));
      final payload = samples.single.toJson();
      expect(payload['schemaVersion'], 4);
      expect(payload['features'], isEmpty);
      expect(payload['featureNames'], isEmpty);
      expect(payload['featuresStatus'], 'not_applicable');
      expect(payload['completedRepsBefore'], 0);
      expect(payload['completedRepsAfter'], 1);
      expect(payload['movementSide'], side);
      expect((payload['frames'] as List).length, 4);
      expect(((payload['frames'] as List).first['keypoints'] as List).length, 17);
      expect(MlActionRegistry.production.forSample(
          Map<String, dynamic>.from(payload))?.schemaVersion, 4);
    }
  });

  test('unresolved side and missing scored boundary create no sample', () {
    final samples = <BodyReviewSample>[];
    final collector = BodyReviewRepCollector(context: context('left'),
        contract: BodyResearchActionRegistry.actions[1], onSample: samples.add);
    collector.observe(observation(0), scored: false, completedReps: 0,
        setIndex: 1, movementSide: null);
    collector.observe(observation(100), scored: true, completedReps: 1,
        setIndex: 1, movementSide: null);
    expect(samples, isEmpty);
    collector.observe(observation(200), scored: false, completedReps: 1,
        setIndex: 1, movementSide: 'left');
    collector.clear();
    collector.observe(observation(300), scored: true, completedReps: 2,
        setIndex: 1, movementSide: 'left');
    expect(samples, isEmpty);
  });

  test('stream changes and long sessions remain bounded', () {
    final samples = <BodyReviewSample>[];
    final collector = BodyReviewRepCollector(context: context('bilateral'),
        contract: BodyResearchActionRegistry.actions[3], onSample: samples.add);
    for (var time = 0; time < 40000; time += 100) {
      collector.observe(observation(time), scored: false,
          completedReps: 0, setIndex: 1, movementSide: 'bilateral');
    }
    collector.observe(observation(40000), scored: true,
        completedReps: 1, setIndex: 1, movementSide: 'bilateral');
    expect(samples, hasLength(1));
    expect(samples.single.observations.length, lessThanOrEqualTo(200));
  });
}

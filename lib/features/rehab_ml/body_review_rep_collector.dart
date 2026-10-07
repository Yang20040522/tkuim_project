import '../../models/body_pose_observation.dart';
import 'body_research_action_registry.dart';
import 'body_research_context.dart';
import 'ml_action_definition.dart';

class BodyReviewSample implements MlResearchSample {
  BodyReviewSample({required this.context, required this.contract,
      required this.observations, required this.movementSide,
      required this.setIndex, required this.completedRepsAfter,
      this.movementMode, this.difficulty}) : id = newResearchId();

  @override
  final String id;
  final BodyResearchContext context;
  final BodyResearchActionContract contract;
  final List<BodyPoseObservation> observations;
  final String movementSide;
  final String? movementMode;
  final String? difficulty;
  final int setIndex, completedRepsAfter;

  @override
  Map<String, Object> toJson() {
    final first = observations.first, last = observations.last;
    final valid = observations.where((frame) =>
        frame.validity.take(17).where((value) => value).length >= 8).length;
    return {
      'sampleId': id,
      if (context.resampleOfSampleId != null)
        'resampleOfSampleId': context.resampleOfSampleId!,
      'sessionId': context.sessionId,
      'attemptId': id,
      'schemaVersion': 4,
      'modality': 'body',
      'source': context.source,
      'platform': context.platform,
      'exerciseType': context.exerciseType,
      'exerciseId': context.exerciseId,
      'actionId': contract.actionId,
      'actionDefinitionVersion': contract.definitionVersion,
      'poseModelVersion': first.poseModelVersion,
      'coordinateTransformVersion': first.coordinateTransformVersion,
      'streamSessionId': first.streamSessionId,
      'frameId': last.frameId,
      'timestampOrigin': first.timestampOrigin,
      'movementSide': movementSide,
      if (movementMode != null) 'movementMode': movementMode!,
      if (difficulty != null) 'difficulty': difficulty!,
      'cameraView': context.cameraView,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
      'featureNames': const <String>[],
      'features': const <double>[],
      'featuresStatus': 'not_applicable',
      'duration': (last.receivedAtMs - first.receivedAtMs) / 1000,
      'terminationReason': 'SCORED_REP',
      'setIndex': setIndex,
      'completedRepsBefore': completedRepsAfter - 1,
      'completedRepsAfter': completedRepsAfter,
      'intendedRepetition': completedRepsAfter,
      'trackingQuality': {'validFrameRatio': valid / observations.length},
      'frames': observations.map((frame) => {
        ...frame.toJson(),
        'keypoints': List.generate(17, (index) => frame.validity[index]
            ? [frame.keypoints[index]!.dx, frame.keypoints[index]!.dy]
            : null),
      }).toList(),
    };
  }
}

/// Passive bounded buffer. The action's scored flag is the sole finalization boundary.
class BodyReviewRepCollector {
  BodyReviewRepCollector({required this.context, required this.contract,
      required this.onSample});
  static const sampleIntervalMs = 100, maximumDurationMs = 20000,
      maximumFrames = 200;
  final BodyResearchContext context;
  final BodyResearchActionContract contract;
  final void Function(BodyReviewSample) onSample;
  final List<BodyPoseObservation> _frames = [];

  void clear() => _frames.clear();

  void observe(BodyPoseObservation frame, {required bool scored,
      required int completedReps, required int setIndex,
      required String? movementSide, String? movementMode,
      String? difficulty}) {
    if (_frames.isNotEmpty &&
        (frame.streamSessionId != _frames.first.streamSessionId ||
         frame.source != _frames.first.source ||
         frame.frameId <= _frames.last.frameId ||
         frame.receivedAtMs <= _frames.last.receivedAtMs ||
         frame.receivedAtMs - _frames.first.receivedAtMs > maximumDurationMs)) {
      clear();
    }
    if (_frames.isEmpty || scored ||
        frame.receivedAtMs - _frames.last.receivedAtMs >= sampleIntervalMs) {
      _frames.add(frame);
      if (_frames.length > maximumFrames) _frames.removeAt(0);
    }
    if (!scored) return;
    if (movementSide != null && completedReps > 0 && _frames.length >= 2 &&
        _frames.last.receivedAtMs > _frames.first.receivedAtMs) {
      onSample(BodyReviewSample(context: context, contract: contract,
          observations: List.unmodifiable(_frames), movementSide: movementSide,
          movementMode: movementMode, setIndex: setIndex,
          difficulty: difficulty,
          completedRepsAfter: completedReps));
    }
    clear();
  }
}

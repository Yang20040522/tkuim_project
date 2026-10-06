import '../../models/body_pose_observation.dart';
import 'body_research_context.dart';
import 'body_research_feature_extractor.dart';
import 'ml_action_definition.dart';

enum BodyAttemptTermination {
  returnedToBaseline,
  userFinished,
  interrupted,
  trackingLost,
  timeout;

  String get wireName => switch (this) {
        returnedToBaseline => 'RETURNED_TO_BASELINE',
        userFinished => 'USER_FINISHED',
        interrupted => 'INTERRUPTED',
        trackingLost => 'TRACKING_LOST',
        timeout => 'TIMEOUT',
      };
}

class BodyResearchSample implements MlResearchSample {
  BodyResearchSample(
      {required this.context,
      required this.attemptId,
      required List<BodyPoseObservation> observations,
      required this.termination,
      required this.setIndex,
      required this.completedRepsBefore,
      required this.completedRepsAfter,
      required this.intendedRepetition})
      : observations = List.unmodifiable(observations),
        id = attemptId {
    if (observations.isEmpty ||
        observations.length > 200 ||
        observations.any((f) =>
            f.streamSessionId != observations.first.streamSessionId ||
            f.source != context.source)) {
      throw const FormatException('Mixed body stream');
    }
    features = BodyResearchFeatureExtractor.extract(
        observations, context.movementSide);
  }
  @override
  final String id;
  final String attemptId;
  final BodyResearchContext context;
  final List<BodyPoseObservation> observations;
  final BodyAttemptTermination termination;
  final int setIndex,
      completedRepsBefore,
      completedRepsAfter,
      intendedRepetition;
  late final BodyAttemptFeatures features;

  @override
  Map<String, Object> toJson() => {
        'sampleId': id,
        'sessionId': context.sessionId,
        'attemptId': attemptId,
        'schemaVersion': 3,
        'modality': 'body',
        'source': context.source,
        'platform': context.platform,
        'exerciseType': context.exerciseType,
        'exerciseId': context.exerciseId,
        'actionId': 'standing_knee_raise',
        'actionDefinitionVersion':
            BodyResearchFeatureExtractor.actionDefinitionVersion,
        'extractorVersion': BodyResearchFeatureExtractor.version,
        'modelInputVersion': BodyResearchFeatureExtractor.modelInputVersion,
        'poseModelVersion': observations.first.poseModelVersion,
        'coordinateTransformVersion':
            observations.first.coordinateTransformVersion,
        'streamSessionId': observations.first.streamSessionId,
        'frameId': observations.last.frameId,
        'timestampOrigin': observations.first.timestampOrigin,
        'movementSide': context.movementSide,
        'cameraView': context.cameraView,
        'capturedAt': context.capturedAt.toUtc().toIso8601String(),
        'featureNames': BodyResearchFeatureExtractor.featureNames,
        'features': features.values,
        'featuresStatus': features.status,
        'duration':
            (observations.last.receivedAtMs - observations.first.receivedAtMs) /
                1000,
        'terminationReason': termination.wireName,
        'setIndex': setIndex,
        'completedRepsBefore': completedRepsBefore,
        'completedRepsAfter': completedRepsAfter,
        'intendedRepetition': intendedRepetition,
        'trackingQuality': {'validFrameRatio': features.validFrameRatio},
        'frames': observations
            .map((f) => {
                  ...f.toJson(),
                  'angles': BodyResearchFeatureExtractor.frame(
                          f, context.movementSide)
                      ?.toJson()
                })
            .toList(),
      };
}

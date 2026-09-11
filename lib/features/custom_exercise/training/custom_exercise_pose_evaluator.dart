import 'dart:math' as math;

import '../../../models/joint_type.dart';
import 'custom_exercise_pose_features.dart';
import 'custom_exercise_pose_reference.dart';

class CustomPoseDeviation {
  const CustomPoseDeviation({
    required this.type,
    required this.referenceDegrees,
    required this.liveDegrees,
    required this.errorDegrees,
  });

  final CustomPoseFeatureType type;
  final double referenceDegrees;
  final double liveDegrees;
  final double errorDegrees;
}

class CustomPoseEvaluation {
  const CustomPoseEvaluation({
    required this.score,
    required this.isMatched,
    required this.isAvailable,
    required this.feedback,
    required this.deviations,
  });

  final double score;
  final bool isMatched;
  final bool isAvailable;
  final String feedback;
  final List<CustomPoseDeviation> deviations;

  CustomPoseDeviation? get largestDeviation =>
      deviations.isEmpty ? null : deviations.first;
}

class CustomExercisePoseEvaluator {
  const CustomExercisePoseEvaluator({
    this.matchScoreThreshold = 82,
    this.minimumFeatureCoverage = 0.6,
  });

  final double matchScoreThreshold;
  final double minimumFeatureCoverage;

  CustomPoseEvaluation evaluate(
    CustomExercisePoseReference reference,
    CustomPoseFeatures live,
  ) {
    final targetTypes = reference.activeFeatures;
    final deviations = <CustomPoseDeviation>[];
    for (final type in targetTypes) {
      final expected = reference.features[type];
      final current = live[type];
      if (expected == null || current == null) continue;
      final error = CustomPoseFeatureExtractor.angularError(
        type,
        expected,
        current,
      );
      if (!error.isFinite) continue;
      deviations.add(CustomPoseDeviation(
        type: type,
        referenceDegrees: expected,
        liveDegrees: current,
        errorDegrees: error,
      ));
    }

    final required = targetTypes.isEmpty
        ? 0
        : math.max(
            1,
            (targetTypes.length * minimumFeatureCoverage).ceil(),
          );
    if (deviations.length < required) {
      return CustomPoseEvaluation(
        score: 0,
        isMatched: false,
        isAvailable: false,
        feedback: _unavailableFeedback(live.unavailableJoints),
        deviations: const [],
      );
    }

    deviations.sort((a, b) {
      final aNormalized = a.errorDegrees / a.type.toleranceDegrees;
      final bNormalized = b.errorDegrees / b.type.toleranceDegrees;
      return bNormalized.compareTo(aNormalized);
    });
    final similarity = deviations.fold<double>(0, (sum, deviation) {
          final range = deviation.type.toleranceDegrees * 2;
          return sum + (1 - deviation.errorDegrees / range).clamp(0.0, 1.0);
        }) /
        deviations.length;
    final score = (similarity * 100).clamp(0.0, 100.0);
    final withinTolerance = deviations.every(
      (item) => item.errorDegrees <= item.type.toleranceDegrees,
    );
    final matched = score >= matchScoreThreshold && withinTolerance;
    return CustomPoseEvaluation(
      score: score,
      isMatched: matched,
      isAvailable: true,
      feedback: matched ? '很好，請保持目前姿勢' : _correctionFeedback(deviations.first),
      deviations: List.unmodifiable(deviations),
    );
  }

  String _unavailableFeedback(Set<JointType> unavailable) {
    if (unavailable.isEmpty) return '請讓完整身體進入畫面';
    final joint = unavailable.first;
    final label = switch (joint) {
      JointType.leftShoulder => '左肩',
      JointType.rightShoulder => '右肩',
      JointType.leftElbow => '左手肘',
      JointType.rightElbow => '右手肘',
      JointType.leftWrist => '左手腕',
      JointType.rightWrist => '右手腕',
      JointType.leftHip => '左髖',
      JointType.rightHip => '右髖',
      JointType.leftKnee => '左膝',
      JointType.rightKnee => '右膝',
      JointType.leftAnkle => '左腳踝',
      JointType.rightAnkle => '右腳踝',
    };
    return '無法穩定偵測$label，請稍微後退並保持全身入鏡';
  }

  String _correctionFeedback(CustomPoseDeviation deviation) {
    final type = deviation.type;
    if (type == CustomPoseFeatureType.leftElbowFlexion ||
        type == CustomPoseFeatureType.rightElbowFlexion) {
      final side = type == CustomPoseFeatureType.leftElbowFlexion ? '左' : '右';
      return deviation.liveDegrees > deviation.referenceDegrees
          ? '$side手肘再伸直一些'
          : '$side手肘再彎曲一些';
    }
    if (type == CustomPoseFeatureType.leftKneeFlexion ||
        type == CustomPoseFeatureType.rightKneeFlexion) {
      final side = type == CustomPoseFeatureType.leftKneeFlexion ? '左' : '右';
      return deviation.liveDegrees > deviation.referenceDegrees
          ? '$side膝再伸直一些'
          : '$side膝再彎曲一些';
    }
    return '請調整${type.label}';
  }
}

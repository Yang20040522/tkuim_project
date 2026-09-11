import '../../actions/body_rehab_action.dart';

class CompletedBodyTrainingLevel {
  const CompletedBodyTrainingLevel({
    required this.level,
    required this.completedReps,
    required this.targetReps,
  });

  final RehabDifficulty level;
  final int completedReps;
  final int targetReps;
}

/// Keeps one difficulty's counters and its transition boundary atomic.
class BodyTrainingLevelProgress {
  BodyTrainingLevelProgress({
    required this.level,
    required this.targetReps,
  });

  RehabDifficulty level;
  int targetReps;
  int completedReps = 0;
  bool _transitioning = false;
  bool _blockNextPoseFrame = false;

  bool get isTransitioning => _transitioning;

  void recordScoredRep() {
    if (!_transitioning) completedReps++;
  }

  CompletedBodyTrainingLevel? beginTransition() {
    if (_transitioning) return null;
    _transitioning = true;
    return CompletedBodyTrainingLevel(
      level: level,
      completedReps: completedReps,
      targetReps: targetReps,
    );
  }

  void completeTransition({
    required RehabDifficulty nextLevel,
    required int nextTargetReps,
  }) {
    level = nextLevel;
    targetReps = nextTargetReps;
    completedReps = 0;
    _transitioning = false;
    _blockNextPoseFrame = true;
  }

  /// Blocks re-entrant transition work and one already-buffered pose frame.
  bool consumePoseFrameBlock() {
    if (_transitioning) return true;
    if (!_blockNextPoseFrame) return false;
    _blockNextPoseFrame = false;
    return true;
  }
}

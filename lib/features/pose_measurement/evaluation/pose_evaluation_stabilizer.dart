import 'pose_evaluation_result.dart';

/// Debounces only the presented overall state; raw rule results remain intact.
class PoseEvaluationStabilizer {
  PoseEvaluationStabilizer({this.requiredConsecutiveFrames = 3})
      : assert(requiredConsecutiveFrames > 0);

  final int requiredConsecutiveFrames;
  PoseOverallEvaluationStatus _presented =
      PoseOverallEvaluationStatus.unavailable;
  PoseOverallEvaluationStatus? _candidate;
  int _candidateCount = 0;

  PoseOverallEvaluationStatus get presented => _presented;

  PoseOverallEvaluationStatus update(PoseOverallEvaluationStatus raw) {
    if (raw == PoseOverallEvaluationStatus.noRules) {
      _presented = raw;
      _candidate = null;
      _candidateCount = 0;
      return _presented;
    }
    if (raw == _presented) {
      _candidate = null;
      _candidateCount = 0;
      return _presented;
    }
    if (_candidate == raw) {
      _candidateCount++;
    } else {
      _candidate = raw;
      _candidateCount = 1;
    }
    if (_candidateCount >= requiredConsecutiveFrames) {
      _presented = raw;
      _candidate = null;
      _candidateCount = 0;
    }
    return _presented;
  }

  void reset({bool hasRules = true}) {
    _presented = hasRules
        ? PoseOverallEvaluationStatus.unavailable
        : PoseOverallEvaluationStatus.noRules;
    _candidate = null;
    _candidateCount = 0;
  }
}

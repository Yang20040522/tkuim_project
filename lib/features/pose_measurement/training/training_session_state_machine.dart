import '../evaluation/pose_evaluation_result.dart';

enum TrainingSessionPhase {
  ready,
  waitingForCorrect,
  holding,
  waitingForRelease,
  setCompleted,
  completed,
}

class TrainingSessionConfig {
  TrainingSessionConfig({
    required this.targetReps,
    required this.targetSets,
    required this.holdDuration,
    this.dropoutGraceDuration = const Duration(milliseconds: 300),
    this.autoCountEnabled = true,
  })  : assert(targetReps > 0),
        assert(targetSets > 0),
        assert(!holdDuration.isNegative),
        assert(!dropoutGraceDuration.isNegative);

  final int targetReps;
  final int targetSets;
  final Duration holdDuration;
  final Duration dropoutGraceDuration;
  final bool autoCountEnabled;

  int get targetTotalReps => targetReps * targetSets;
}

class TrainingSessionSnapshot {
  const TrainingSessionSnapshot({
    required this.phase,
    required this.currentRep,
    required this.currentSet,
    required this.completedReps,
    required this.targetReps,
    required this.targetSets,
    required this.holdElapsed,
    required this.holdDuration,
    required this.sessionElapsed,
    required this.autoCountEnabled,
  });

  final TrainingSessionPhase phase;
  final int currentRep;
  final int currentSet;
  final int completedReps;
  final int targetReps;
  final int targetSets;
  final Duration holdElapsed;
  final Duration holdDuration;
  final Duration sessionElapsed;
  final bool autoCountEnabled;

  double get holdProgress {
    if (holdDuration == Duration.zero) {
      return phase == TrainingSessionPhase.holding ? 1 : 0;
    }
    return (holdElapsed.inMicroseconds / holdDuration.inMicroseconds)
        .clamp(0.0, 1.0);
  }

  double get score {
    final target = targetReps * targetSets;
    if (target <= 0) return 0;
    return (completedReps / target * 100).clamp(0.0, 100.0);
  }

  bool get isCompleted => phase == TrainingSessionPhase.completed;
}

/// Pure, timestamp-driven rehabilitation training state machine.
///
/// It consumes only the stabilized overall pose status and is deliberately
/// independent from CameraX, MediaPipe, Flutter widgets, and frame sources.
class TrainingSessionStateMachine {
  TrainingSessionStateMachine(this.config) {
    reset();
  }

  final TrainingSessionConfig config;

  TrainingSessionPhase _phase = TrainingSessionPhase.ready;
  int _currentRep = 0;
  int _currentSet = 1;
  int _completedReps = 0;
  Duration _sessionElapsed = Duration.zero;
  Duration? _holdStartedAt;
  Duration? _dropoutStartedAt;
  Duration _excludedDropoutDuration = Duration.zero;

  TrainingSessionSnapshot get snapshot => _snapshot();

  TrainingSessionSnapshot start({Duration elapsed = Duration.zero}) {
    reset();
    _sessionElapsed = _monotonic(elapsed);
    _phase = TrainingSessionPhase.waitingForCorrect;
    return _snapshot();
  }

  TrainingSessionSnapshot update(
    PoseOverallEvaluationStatus status,
    Duration elapsed,
  ) {
    _sessionElapsed = _monotonic(elapsed);
    if (!config.autoCountEnabled ||
        _phase == TrainingSessionPhase.ready ||
        _phase == TrainingSessionPhase.completed ||
        _phase == TrainingSessionPhase.setCompleted) {
      return _snapshot();
    }

    switch (_phase) {
      case TrainingSessionPhase.waitingForCorrect:
        if (status == PoseOverallEvaluationStatus.correct) {
          _beginHold();
          if (config.holdDuration == Duration.zero) _completeRep();
        }
      case TrainingSessionPhase.holding:
        if (status == PoseOverallEvaluationStatus.correct) {
          final dropoutStartedAt = _dropoutStartedAt;
          if (dropoutStartedAt != null) {
            final dropoutDuration = _sessionElapsed - dropoutStartedAt;
            if (dropoutDuration > config.dropoutGraceDuration) {
              _cancelHold();
              break;
            }
            _excludedDropoutDuration += dropoutDuration;
            _dropoutStartedAt = null;
          }
          if (_holdElapsed >= config.holdDuration) _completeRep();
        } else {
          _dropoutStartedAt ??= _sessionElapsed;
          if (_sessionElapsed - _dropoutStartedAt! >
              config.dropoutGraceDuration) {
            _cancelHold();
          }
        }
      case TrainingSessionPhase.waitingForRelease:
        // UNAVAILABLE is not evidence that the patient released the target.
        // Re-arm only after a stable, visible posture outside the valid range.
        if (status == PoseOverallEvaluationStatus.needsAdjustment) {
          _phase = TrainingSessionPhase.waitingForCorrect;
        }
      case TrainingSessionPhase.ready:
      case TrainingSessionPhase.setCompleted:
      case TrainingSessionPhase.completed:
        break;
    }
    return _snapshot();
  }

  TrainingSessionSnapshot beginNextSet() {
    if (_phase != TrainingSessionPhase.setCompleted ||
        _currentSet >= config.targetSets) {
      return _snapshot();
    }
    _currentSet++;
    _currentRep = 0;
    _holdStartedAt = null;
    _dropoutStartedAt = null;
    _excludedDropoutDuration = Duration.zero;
    _phase = TrainingSessionPhase.waitingForRelease;
    return _snapshot();
  }

  TrainingSessionSnapshot reset() {
    _phase = TrainingSessionPhase.ready;
    _currentRep = 0;
    _currentSet = 1;
    _completedReps = 0;
    _sessionElapsed = Duration.zero;
    _holdStartedAt = null;
    _dropoutStartedAt = null;
    _excludedDropoutDuration = Duration.zero;
    return _snapshot();
  }

  void _beginHold() {
    _holdStartedAt = _sessionElapsed;
    _dropoutStartedAt = null;
    _excludedDropoutDuration = Duration.zero;
    _phase = TrainingSessionPhase.holding;
  }

  void _cancelHold() {
    _holdStartedAt = null;
    _dropoutStartedAt = null;
    _excludedDropoutDuration = Duration.zero;
    _phase = TrainingSessionPhase.waitingForCorrect;
  }

  void _completeRep() {
    _holdStartedAt = null;
    _dropoutStartedAt = null;
    _excludedDropoutDuration = Duration.zero;
    _currentRep++;
    _completedReps++;
    if (_currentRep >= config.targetReps) {
      _phase = _currentSet >= config.targetSets
          ? TrainingSessionPhase.completed
          : TrainingSessionPhase.setCompleted;
    } else {
      _phase = TrainingSessionPhase.waitingForRelease;
    }
  }

  Duration get _holdElapsed {
    final started = _holdStartedAt;
    if (started == null) return Duration.zero;
    final effectiveEnd = _dropoutStartedAt ?? _sessionElapsed;
    final value = effectiveEnd - started - _excludedDropoutDuration;
    return value.isNegative ? Duration.zero : value;
  }

  Duration _monotonic(Duration next) =>
      next < _sessionElapsed ? _sessionElapsed : next;

  TrainingSessionSnapshot _snapshot() => TrainingSessionSnapshot(
        phase: _phase,
        currentRep: _currentRep,
        currentSet: _currentSet,
        completedReps: _completedReps,
        targetReps: config.targetReps,
        targetSets: config.targetSets,
        holdElapsed: _holdElapsed,
        holdDuration: config.holdDuration,
        sessionElapsed: _sessionElapsed,
        autoCountEnabled: config.autoCountEnabled,
      );
}

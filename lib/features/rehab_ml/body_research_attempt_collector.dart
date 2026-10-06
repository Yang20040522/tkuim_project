import '../../models/body_pose_observation.dart';
import 'body_research_context.dart';
import 'body_research_feature_extractor.dart';
import 'body_research_sample.dart';

enum BodyCollectorState { disabled, ready, recording, finalizing }

/// Passive research segmentation. Caller reports training counts; this class
/// never owns or modifies rehabilitation state. All durations are monotonic.
class BodyResearchAttemptCollector {
  BodyResearchAttemptCollector(
      {required this.context,
      required this.onSample,
      required this.ownerIsCurrent});
  static const movementConfirmationMs = 200,
      preRollMs = 500,
      returnConfirmationMs = 300,
      trackingLossMs = 500,
      maximumDurationMs = 20000,
      maximumObservations = 200;
  final BodyResearchContext context;
  final void Function(BodyResearchSample) onSample;
  final bool Function() ownerIsCurrent;
  BodyCollectorState state = BodyCollectorState.disabled;
  final List<BodyPoseObservation> _preRoll = [], _recording = [];
  String? _stream;
  int _lastFrame = -1, _lastTime = -1;
  int? _movementSince, _baselineSince, _missingSince;
  int _repsBefore = 0, _repsAfter = 0, _setIndex = 1;

  void setConsent(bool granted) {
    _clear();
    state = granted && ownerIsCurrent()
        ? BodyCollectorState.ready
        : BodyCollectorState.disabled;
  }

  void observe(BodyPoseObservation frame,
      {required bool movementDetected,
      required bool atBaseline,
      required int completedReps,
      required int setIndex}) {
    if (!ownerIsCurrent()) {
      setConsent(false);
      return;
    }
    if (state == BodyCollectorState.disabled ||
        state == BodyCollectorState.finalizing) {
      return;
    }
    if (_stream != null && frame.streamSessionId != _stream) {
      finish(BodyAttemptTermination.interrupted);
      _clear();
    }
    _stream = frame.streamSessionId;
    if (frame.frameId <= _lastFrame || frame.receivedAtMs <= _lastTime) return;
    if (state == BodyCollectorState.ready &&
        _lastTime >= 0 &&
        frame.receivedAtMs - _lastTime >= trackingLossMs) {
      _movementSince = null;
      _preRoll.clear();
    }
    if (state == BodyCollectorState.recording &&
        frame.receivedAtMs - _lastTime >= trackingLossMs) {
      finish(BodyAttemptTermination.trackingLost);
    }
    _lastFrame = frame.frameId;
    _lastTime = frame.receivedAtMs;
    final valid =
        BodyResearchFeatureExtractor.frame(frame, context.movementSide) != null;
    if (state == BodyCollectorState.ready) {
      _preRoll.add(frame);
      _preRoll
          .removeWhere((f) => frame.receivedAtMs - f.receivedAtMs > preRollMs);
      if (_preRoll.length > maximumObservations) _preRoll.removeAt(0);
      if (!valid || !movementDetected) {
        _movementSince = null;
        return;
      }
      _movementSince ??= frame.receivedAtMs;
      if (frame.receivedAtMs - _movementSince! < movementConfirmationMs) return;
      _recording.addAll(_preRoll);
      _preRoll.clear();
      _repsBefore = completedReps;
      _repsAfter = completedReps;
      _setIndex = setIndex;
      state = BodyCollectorState.recording;
      _movementSince = null;
      return;
    }
    if (frame.receivedAtMs - _recording.first.receivedAtMs >
        maximumDurationMs) {
      finish(BodyAttemptTermination.timeout);
      return;
    }
    _recording.add(frame);
    _repsAfter = completedReps;
    if (!valid) {
      _missingSince ??= frame.receivedAtMs;
      _baselineSince = null;
    } else {
      _missingSince = null;
      _baselineSince =
          atBaseline ? (_baselineSince ?? frame.receivedAtMs) : null;
    }
    tick(frame.receivedAtMs);
  }

  /// Also called by a monotonic watchdog when no frames arrive.
  void tick(int nowMs) {
    if (!ownerIsCurrent()) {
      setConsent(false);
      return;
    }
    if (state != BodyCollectorState.recording) return;
    if (nowMs < _lastTime) return;
    if (nowMs - (_missingSince ?? _lastTime) >= trackingLossMs) {
      finish(BodyAttemptTermination.trackingLost);
    } else if (nowMs - _recording.first.receivedAtMs >= maximumDurationMs ||
        _recording.length >= maximumObservations) {
      finish(BodyAttemptTermination.timeout);
    } else if (_baselineSince != null &&
        nowMs - _baselineSince! >= returnConfirmationMs) {
      finish(BodyAttemptTermination.returnedToBaseline);
    }
  }

  void finish(BodyAttemptTermination reason) {
    if (!ownerIsCurrent()) {
      setConsent(false);
      return;
    }
    if (state != BodyCollectorState.recording) {
      _clear();
      return;
    }
    state = BodyCollectorState.finalizing;
    final frames = List<BodyPoseObservation>.of(_recording);
    final before = _repsBefore, after = _repsAfter, set = _setIndex;
    _clear(resetIdentity: false);
    try {
      if (frames.any((f) =>
          BodyResearchFeatureExtractor.frame(f, context.movementSide) !=
          null)) {
        onSample(BodyResearchSample(
            context: context,
            attemptId: newResearchId(),
            observations: frames,
            termination: reason,
            setIndex: set,
            completedRepsBefore: before,
            completedRepsAfter: after,
            intendedRepetition: before + 1));
      }
    } finally {
      state = ownerIsCurrent()
          ? BodyCollectorState.ready
          : BodyCollectorState.disabled;
    }
  }

  void _clear({bool resetIdentity = true}) {
    _preRoll.clear();
    _recording.clear();
    _movementSince = null;
    _baselineSince = null;
    _missingSince = null;
    if (resetIdentity) {
      _stream = null;
      _lastFrame = -1;
      _lastTime = -1;
    }
  }
}

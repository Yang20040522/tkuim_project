import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/body_pose_observation.dart';
import '../account/app_session.dart';
import 'body_research_context.dart';
import 'body_research_attempt_collector.dart';
import 'body_research_feature_extractor.dart';
import 'body_research_sample.dart';
import 'ml_sample_repository.dart';
import 'ml_research_api.dart';
import 'ml_research_sync.dart';
import 'research_owner_scope.dart';

/// Opt-in body research sidecar. Counts supplied by the training screen are
/// read-only snapshots; no classifier or action rules are invoked here.
class BodyResearchSession {
  BodyResearchSession(
      {required String exerciseId,
      required String movementSide,
      MlSampleRepository? repository,
      MlResearchRemote? remote})
      : repository = repository ?? MlSampleRepository(),
        owner = ResearchOwnerScope.capture() {
    collector = BodyResearchAttemptCollector(
        context: BodyResearchContext(
            ownerId: owner.userId,
            accountGeneration: owner.generation,
            exerciseId: exerciseId,
            movementSide: movementSide,
            capturedAt: DateTime.now()),
        onSample: _save,
        ownerIsCurrent: () => !_disposed && owner.isCurrent);
    sync = MlResearchSync(
        remote: remote ?? MlResearchApi(), local: this.repository);
    AppSession.changes.addListener(_accountChanged);
  }
  // Segmentation engineering thresholds, not clinical pass/fail thresholds.
  static const movementHipDeg = 165.0, baselineHipDeg = 172.0;
  final MlSampleRepository repository;
  final ResearchOwnerScope owner;
  late final BodyResearchAttemptCollector collector;
  late final MlResearchSync sync;
  final ValueNotifier<String?> message = ValueNotifier(null);
  final Stopwatch _idle = Stopwatch();
  Timer? _watchdog;
  int _lastReceiveMs = 0, _consentEpoch = 0, _lastRep = 0, _lastSet = 1;
  bool localConsent = false,
      cloudConsent = false,
      foreground = true,
      _disposed = false;
  void setLocalConsent(bool value) {
    owner.check();
    _consentEpoch++;
    localConsent = value;
    collector.setConsent(value);
    if (!value) cloudConsent = false;
    _watchdog?.cancel();
    _watchdog = null;
    if (value) {
      _watchdog = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (foreground && !_disposed && _idle.isRunning) {
          collector.tick(_lastReceiveMs + _idle.elapsedMilliseconds);
        }
      });
    }
  }

  void setCloudConsent(bool value) {
    owner.check();
    _consentEpoch++;
    cloudConsent = value && localConsent;
  }

  void setForeground(bool value) {
    foreground = value;
    if (!value) collector.finish(BodyAttemptTermination.interrupted);
  }

  void observe(BodyPoseObservation frame,
      {required int completedReps, required int setIndex}) {
    if (_disposed || !foreground || !localConsent || !owner.isCurrent) return;
    if (completedReps < _lastRep || setIndex != _lastSet) {
      collector.finish(BodyAttemptTermination.interrupted);
    }
    _lastRep = completedReps;
    _lastSet = setIndex;
    _lastReceiveMs = frame.receivedAtMs;
    _idle
      ..reset()
      ..start();
    final features = BodyResearchFeatureExtractor.frame(
        frame, collector.context.movementSide);
    collector.observe(frame,
        movementDetected: features != null && features.hipDeg < movementHipDeg,
        atBaseline: features != null && features.hipDeg >= baselineHipDeg,
        completedReps: completedReps,
        setIndex: setIndex);
  }

  void interrupt() => collector.finish(BodyAttemptTermination.interrupted);
  void userFinished() => collector.finish(BodyAttemptTermination.userFinished);
  void _save(BodyResearchSample sample) {
    final cloud = cloudConsent, epoch = _consentEpoch;
    unawaited(repository.save(sample).then((_) async {
      if (_disposed || !owner.isCurrent) return;
      message.value = '已保存 Body attempt（含未計次動作）';
      if (cloud && cloudConsent && epoch == _consentEpoch) {
        await sync.enqueue(sample.id);
        await sync.sync();
        if (!_disposed && owner.isCurrent) message.value = 'Body attempt 已同步';
      }
    }).catchError((Object _) {
      if (!_disposed && owner.isCurrent) message.value = '研究保存／同步失敗；復健訓練不受影響';
    }));
  }

  void _accountChanged() {
    if (!owner.isCurrent) {
      localConsent = false;
      cloudConsent = false;
      _consentEpoch++;
      collector.setConsent(false);
      _watchdog?.cancel();
      sync.stop();
      message.value = null;
    }
  }

  void dispose() {
    if (_disposed) return;
    interrupt();
    _disposed = true;
    _watchdog?.cancel();
    _idle.stop();
    sync.stop();
    AppSession.changes.removeListener(_accountChanged);
    message.dispose();
  }
}

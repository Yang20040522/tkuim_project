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
import 'body_ml_advisory_controller.dart';
import 'body_research_action_registry.dart';
import 'body_review_rep_collector.dart';
import 'research_collection_gate.dart';
import 'ml_action_definition.dart';

/// Opt-in body research sidecar. Counts supplied by the training screen are
/// read-only snapshots; no classifier or action rules are invoked here.
class BodyResearchSession {
  BodyResearchSession(
      {required String exerciseId,
      required String movementSide,
      BodyResearchActionContract? actionContract,
      ResearchCollectionGate? collectionGate,
      MlSampleRepository? repository,
      MlResearchRemote? remote})
      : repository = repository ?? MlSampleRepository(),
        owner = ResearchOwnerScope.capture(),
        contract = actionContract ?? BodyResearchActionRegistry.actions.first,
        gate = collectionGate ?? ResearchCollectionGate.instance {
    advisory = BodyMlAdvisoryController();
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
    if (contract.schemaVersion == 4) {
      reviewCollector = BodyReviewRepCollector(
          context: collector.context, contract: contract, onSample: _save);
    }
    gate.addListener(_gateChanged);
    gate.beginSession();
    _gateChanged();
    AppSession.changes.addListener(_accountChanged);
  }
  // Segmentation engineering thresholds, not clinical pass/fail thresholds.
  static const movementHipDeg = 165.0, baselineHipDeg = 172.0;
  final MlSampleRepository repository;
  final ResearchOwnerScope owner;
  final BodyResearchActionContract contract;
  final ResearchCollectionGate gate;
  BodyReviewRepCollector? reviewCollector;
  late final BodyMlAdvisoryController advisory;
  late BodyResearchAttemptCollector collector;
  late final MlResearchSync sync;
  final ValueNotifier<String?> message = ValueNotifier(null);
  final Stopwatch _idle = Stopwatch();
  Future<void> _pendingPersistence = Future.value();

  /// Test/tool completion boundary only; never blocks the camera or counts.
  Future<void> get pendingPersistence => _pendingPersistence;
  String? get resampleOfSampleId => collector.context.resampleOfSampleId;

  /// Only between attempts; existing motion/counters and immutable samples
  /// are never rewritten. Server rechecks ownership/disposition at upload.
  Future<void> selectResample(String? parentId) async {
    owner.check();
    if (_disposed ||
        collector.state == BodyCollectorState.recording ||
        collector.state == BodyCollectorState.finalizing) {
      throw StateError('請先結束目前嘗試，再選擇重採樣');
    }
    if (parentId != null) {
      final detail = await sync.remote.sampleDetail(parentId);
      owner.check();
      final sample = detail['sample'] as Map;
      if (sample['schemaVersion'] != contract.schemaVersion ||
          sample['actionId'] != contract.actionId ||
          sample['disposition'] != 'NEEDS_RESAMPLE' ||
          sample['exerciseId']?.toString() != collector.context.exerciseId ||
          sample['exerciseType'] != collector.context.exerciseType) {
        throw StateError('此樣本不適用目前動作的重採樣');
      }
    }
    if (_disposed ||
        collector.state == BodyCollectorState.recording ||
        collector.state == BodyCollectorState.finalizing) {
      throw StateError('動作已開始，請於下一次嘗試前選擇');
    }
    collector = BodyResearchAttemptCollector(
        context: collector.context.forResample(parentId),
        onSample: _save,
        ownerIsCurrent: () => !_disposed && owner.isCurrent)
      ..setConsent(localConsent);
    reviewCollector = contract.schemaVersion == 4
        ? BodyReviewRepCollector(context: collector.context,
            contract: contract, onSample: _save)
        : null;
    message.value = parentId == null ? '已取消重採樣選擇' : '下一個新嘗試將連結原樣本；不覆寫舊資料';
  }

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
    if (!value) reviewCollector?.clear();
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
    if (!value) interrupt();
  }

  void observe(BodyPoseObservation frame,
      {required int completedReps, required int setIndex,
      bool scored = false, String? movementSide, String? movementMode,
      String? difficulty}) {
    if (_disposed || !foreground || !localConsent || !owner.isCurrent) return;
    if (contract.schemaVersion == 4) {
      reviewCollector?.observe(frame, scored: scored,
          completedReps: completedReps, setIndex: setIndex,
          movementSide: movementSide, movementMode: movementMode,
          difficulty: difficulty);
      return;
    }
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

  void interrupt() {
    collector.finish(BodyAttemptTermination.interrupted);
    reviewCollector?.clear();
  }
  void userFinished() {
    collector.finish(BodyAttemptTermination.userFinished);
    reviewCollector?.clear();
  }
  void _save(MlResearchSample sample) {
    if (sample is BodyResearchSample) unawaited(advisory.finalized(sample));
    final epoch = _consentEpoch;
    final save = Future<void>(() async {
      if (!await gate.canCollect(actionId: contract.actionId) ||
          _disposed || !owner.isCurrent || epoch != _consentEpoch) return;
      await repository.save(sample);
      if (_disposed || !owner.isCurrent) return;
      message.value = contract.schemaVersion == 3
          ? '已保存 Body attempt（含未計次動作）' : '已保存動作審核骨架樣本';
      if (gate.bodyEnabled(contract.actionId) && epoch == _consentEpoch) {
        await sync.enqueue(sample.id);
        await sync.sync();
        if (!_disposed && owner.isCurrent) message.value = 'Body 研究樣本已同步';
      }
    }).catchError((Object _) {
      if (!_disposed && owner.isCurrent) message.value = '研究保存／同步失敗；復健訓練不受影響';
    });
    _pendingPersistence =
        Future.wait<void>([_pendingPersistence, save]).then((_) {});
    unawaited(_pendingPersistence);
  }

  void _gateChanged() {
    if (_disposed || !owner.isCurrent) return;
    final allow = gate.bodyEnabled(contract.actionId);
    if (allow != localConsent || allow != cloudConsent) {
      setLocalConsent(allow);
      setCloudConsent(allow);
    }
  }

  void _accountChanged() {
    if (!owner.isCurrent) {
      localConsent = false;
      cloudConsent = false;
      _consentEpoch++;
      collector.setConsent(false);
      reviewCollector?.clear();
      _watchdog?.cancel();
      sync.stop();
      message.value = null;
    }
  }

  void dispose() {
    if (_disposed) return;
    interrupt();
    _disposed = true;
    unawaited(advisory.dispose());
    _watchdog?.cancel();
    _idle.stop();
    sync.stop();
    gate.removeListener(_gateChanged);
    gate.endSession();
    AppSession.changes.removeListener(_accountChanged);
    message.dispose();
  }
}

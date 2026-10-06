import 'dart:async';
import 'package:flutter/foundation.dart';
import '../account/app_session.dart';
import '../../services/pose_model_interface.dart';
import 'hand_research_sample.dart';
import 'local_ml_model_store.dart';
import 'ml_action_definition.dart';
import 'ml_quality_evaluator.dart';
import 'ml_rep_quality_controller.dart';
import 'ml_research_api.dart';
import 'ml_research_sync.dart';
import 'ml_sample_repository.dart';
import 'research_owner_scope.dart';

/// Auxiliary opt-in research, independent of Action rules and cloud consent.
class HandResearchSession {
  HandResearchSession(this.action,
      {MlSampleRepository? repository,
      MlResearchRemote? remote,
      MlQualityEvaluator? evaluator})
      : repository = repository ?? MlSampleRepository(),
        collector = HandMotionCollector(action),
        quality = MlRepQualityController(
            evaluator ?? CatalogMlQualityEvaluator(action)) {
    sync = MlResearchSync(
        remote: remote ?? MlResearchApi(), local: this.repository);
    AppSession.changes.addListener(_accountChanged);
  }
  final MlActionDefinition action;
  final MlSampleRepository repository;
  final HandMotionCollector collector;
  final MlRepQualityController quality;
  late final MlResearchSync sync;
  final message = ValueNotifier<String?>(null);
  bool localConsent = false, foreground = true;
  bool _cloudConsent = false;
  int _consentEpoch = 0;
  bool get cloudConsent => _cloudConsent;
  set cloudConsent(bool value) {
    if (value != _cloudConsent) _consentEpoch++;
    _cloudConsent = value;
  }

  String? subjectId;
  String cameraView = 'front';
  bool _disposed = false;
  ResearchOwnerScope? _owner;
  void _accountChanged() {
    if (_owner != null && !_owner!.isCurrent) {
      localConsent = false;
      cloudConsent = false;
      subjectId = null;
      reset();
      sync.stop();
      message.value = null;
    }
  }

  int _serial = 0;
  void setLocalConsent(bool consent, String? subject) {
    if (consent) _owner ??= repository.owner;
    _consentEpoch++;
    reset();
    localConsent = consent;
    subjectId = subject;
  }

  void reset() {
    collector.reset();
    quality.reset();
  }

  void observe(PoseFrame frame, int time, int reps, int level, bool ready) {
    if (_disposed) return;
    final sample = collector.observe(
        landmarks: frame.observedHandLandmarks,
        detected: frame.handDetected,
        timestampMs: time,
        repCount: reps,
        level: level,
        consent: localConsent && foreground,
        ready: ready,
        subjectId: subjectId ?? '',
        cameraView: cameraView,
        sampleId: 'hand_${DateTime.now().microsecondsSinceEpoch}_${_serial++}',
        capturedAt: DateTime.now());
    if (sample == null) return;
    unawaited(quality.completed(sample));
    final cloudAtCapture = cloudConsent,
        owner = AppSession.userId,
        consentEpoch = _consentEpoch;
    unawaited(repository.save(sample).then((_) async {
      if (!_disposed &&
          localConsent &&
          cloudAtCapture &&
          cloudConsent &&
          consentEpoch == _consentEpoch &&
          owner != null &&
          owner == AppSession.userId) {
        await sync.enqueue(sample.id);
        await sync.sync();
      }
    }).catchError((Object _) {
      if (!_disposed) message.value = '研究樣本保存或同步失敗；現有復健訓練不受影響。';
    }));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    AppSession.changes.removeListener(_accountChanged);
    sync.stop();
    collector.reset();
    message.dispose();
    await quality.dispose();
  }
}

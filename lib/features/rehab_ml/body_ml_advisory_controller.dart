import 'dart:async';
import 'package:flutter/foundation.dart';
import '../account/app_session.dart';
import 'body_ml_contract.dart';
import 'body_ml_evaluator.dart';
import 'body_research_sample.dart';
import 'research_owner_scope.dart';

/// No training controller reference and no annotation writer. This sidecar owns
/// only advisory presentation and an account-scoped native session.
class BodyMlAdvisoryController {
  BodyMlAdvisoryController({BodyMlEvaluator? evaluator})
      : evaluator = evaluator ?? BodyMlEvaluator.runtime(),
        owner = ResearchOwnerScope.captureIfPresent() {
    AppSession.changes.addListener(_accountChanged);
  }
  final BodyMlEvaluator evaluator;
  final ResearchOwnerScope? owner;
  final latest = ValueNotifier<BodyMlPrediction?>(null);
  bool _disposed = false;
  int _generation = 0;
  bool get _current => !_disposed && owner?.isCurrent == true;
  Future<void> finalized(BodyResearchSample sample) =>
      evaluate(BodyMlInput.fromSample(sample));
  Future<void> evaluate(BodyMlInput input) async {
    if (!_current) return;
    final generation = ++_generation;
    final result = await evaluator.evaluate(input);
    if (_current && generation == _generation) latest.value = result;
  }

  void reset() {
    _generation++;
    if (!_disposed) latest.value = null;
  }

  void _accountChanged() {
    if (!_current && !_disposed) {
      reset();
      unawaited(evaluator.dispose());
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    AppSession.changes.removeListener(_accountChanged);
    await evaluator.dispose();
    latest.dispose();
  }
}

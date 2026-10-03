import 'package:flutter/foundation.dart';
import 'ml_action_definition.dart';
import 'ml_quality_evaluator.dart';

/// Observes an already-completed rep; never controls action/counting or consent.
class MlRepQualityController {
  MlRepQualityController(this.evaluator);
  final MlQualityEvaluator evaluator;
  final latest = ValueNotifier<MlQualityResult>(
      const MlQualityResult.unavailable('研究模型尚未開放。'));
  String? _lastId;
  int _epoch = 0;
  bool _disposed = false;
  bool _busy = false;
  Future<void> completed(MlResearchSample sample) async {
    if (_disposed || sample.id == _lastId) return;
    if (_busy) {
      latest.value =
          const MlQualityResult.unavailable('研究分析忙碌，本次不提供分類；現有計次不受影響。');
      _epoch++; // Do not publish the earlier rep's result as the current rep.
      _lastId = sample.id;
      return;
    }
    _lastId = sample.id;
    final epoch = _epoch;
    _busy = true;
    try {
      final data = sample.toJson();
      if (MlActionRegistry.production.forSample(data) == null) {
        latest.value = const MlQualityResult.unavailable('不支援的研究動作資料。');
        return;
      }
      final result = await evaluator.evaluate((data['features'] as List)
          .map((v) => (v as num).toDouble())
          .toList());
      if (!_disposed && epoch == _epoch) {
        latest.value = result;
      }
    } catch (_) {
      if (!_disposed && epoch == _epoch) {
        latest.value = const MlQualityResult.unavailable('研究分析暫時不可用。');
      }
    } finally {
      _busy = false;
    }
  }

  void reset() {
    _epoch++;
    _lastId = null;
    if (!_disposed) {
      latest.value = const MlQualityResult.unavailable('研究模型尚未開放。');
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    latest.dispose();
    await evaluator.dispose();
  }
}

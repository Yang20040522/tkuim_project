/// Auxiliary research result. This must never control rule-based repetitions.
class MlQualityResult {
  const MlQualityResult.unavailable(this.reason)
      : label = null,
        confidence = null;

  final String? label;
  final double? confidence;
  final String reason;
  bool get available => label != null;
}

abstract class MlQualityEvaluator {
  Future<MlQualityResult> evaluate(List<double> features);
}

/// Until a professionally labeled model is trained, validated and shipped,
/// returning a classification would be scientifically misleading.
class UnavailableMlQualityEvaluator implements MlQualityEvaluator {
  const UnavailableMlQualityEvaluator();

  @override
  Future<MlQualityResult> evaluate(List<double> features) async =>
      const MlQualityResult.unavailable('研究模型等待專業標註資料，現有計次與規則評估不受影響。');
}

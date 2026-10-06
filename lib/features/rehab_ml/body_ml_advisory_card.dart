import 'package:flutter/material.dart';
import 'body_ml_contract.dart';
import 'ml_action_definition.dart';

/// Probability summary is not accuracy, clinical confidence or ground truth.
class BodyMlAdvisoryCard extends StatelessWidget {
  const BodyMlAdvisoryCard(
      {super.key, required this.prediction, this.therapist = false});
  final BodyMlPrediction? prediction;
  final bool therapist;
  @override
  Widget build(BuildContext context) {
    final result = prediction;
    final manifest = result?.manifest;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('動作品質研究輔助（2D 投影）',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (manifest?.synthetic == true)
                const Text(bodyMlEngineeringNotice),
              Text(result?.decisionStatus.wireName ?? 'MODEL_UNAVAILABLE'),
              if (manifest != null)
                Text(
                    '模型 ${manifest.id} · ${manifest.version} · ${manifest.status}'),
              if (result?.label != null)
                Text(MlActionRegistry.standingKneeRaise.labels[result!.label] ??
                    result.label!),
              if (result?.probabilities.isNotEmpty == true)
                Text(
                    '未校準類別機率：${result!.probabilities.map((p) => p.toStringAsFixed(3)).join(' / ')}'),
              Text(therapist
                  ? '獨立於專業標註；不自動填入標籤，也不影響審核。'
                  : '非醫療診斷／正確率；不影響復健計次、組數或保持時間。'),
              if (manifest == null) const Text('研究模型尚未開放，原有訓練與研究收集正常使用。'),
            ])));
  }
}

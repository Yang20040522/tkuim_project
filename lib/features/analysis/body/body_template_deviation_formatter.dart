import '../models/environment_metadata.dart';
import 'body_template_analyzer.dart';

class BodyTemplateDeviationFormatter {
  const BodyTemplateDeviationFormatter._();

  static const double deviationScoreThreshold = 90;

  static List<String> describe(
    BodyTemplateAnalysisResult result, {
    int maximum = 3,
  }) {
    if (!result.valid || maximum <= 0) return const [];
    final messages = <String>[];
    for (final joint in result.biggestDeviations) {
      final score = result.jointScores[joint];
      if (score == null || score >= deviationScoreThreshold) continue;
      final message = _jointMessage(joint);
      if (!messages.contains(message)) messages.add(message);
      if (messages.length == maximum) break;
    }
    return List<String>.unmodifiable(messages);
  }

  static String _jointMessage(int joint) => switch (joint) {
        5 || 6 || 11 || 12 => '軀幹穩定度與標準模板差異較大',
        7 => '左手肘軌跡與標準模板差異較大',
        8 => '右手肘軌跡與標準模板差異較大',
        9 => '左手腕軌跡偏離標準模板',
        10 => '右手腕軌跡偏離標準模板',
        13 => '左膝軌跡與標準模板差異較大',
        14 => '右膝軌跡與標準模板差異較大',
        15 => '左踝軌跡偏離標準模板',
        16 => '右踝軌跡偏離標準模板',
        _ => '本次動作軌跡與標準模板有較大差異',
      };

  static String movementSideLabel(BodySide? side) => switch (side) {
        BodySide.left => '左側',
        BodySide.right => '右側',
        BodySide.both => '雙側',
        BodySide.none || null => '未指定',
      };
}

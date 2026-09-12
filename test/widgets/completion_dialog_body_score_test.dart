import 'package:flutter/material.dart';
import 'package:flutter_body/models/training_action.dart';
import 'package:flutter_body/widgets/completion_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bodyAction = kTrainingActions.firstWhere(
    (action) => action.type == ActionType.wipeBody,
  );

  Widget buildDialog({
    double? averageBodyScore,
    double? templateScore,
    String? templateScoreStatus,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CompletionDialog(
          repCount: 3,
          durationSeconds: 25,
          mistakeLogs: const <String>[],
          currentAction: bodyAction,
          currentDifficulty: bodyAction.difficulties.first,
          averageBodyScore: averageBodyScore,
          templateScore: templateScore,
          templateScoreStatus: templateScoreStatus,
          onRetry: () {},
          onHome: () {},
          onStartNew: (_, __, ___) {},
        ),
      ),
    );
  }

  testWidgets('shows basic and valid template scores separately',
      (tester) async {
    await tester.pumpWidget(
      buildDialog(averageBodyScore: 92.6, templateScore: 87.4),
    );

    expect(find.text('基本動作評分：93 分'), findsOneWidget);
    expect(find.text('模板符合度：87 分'), findsOneWidget);
  });

  testWidgets('invalid template status never renders a zero score',
      (tester) async {
    await tester.pumpWidget(
      buildDialog(
        averageBodyScore: 94,
        templateScoreStatus: '本場沒有有效的模板額外評分',
      ),
    );

    expect(find.text('基本動作評分：94 分'), findsOneWidget);
    expect(find.text('本場沒有有效的模板額外評分'), findsOneWidget);
    expect(find.textContaining('模板符合度：0'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/stats/patient_training_videos_card.dart';
import 'package:flutter_body/models/training_action.dart';

void main() {
  TrainingRecord record({String? videoUrl}) => TrainingRecord(
        id: 123,
        timestamp: '2026-09-09 16:25:44',
        actionName: '伸手舉高訓練',
        difficulty: 2,
        durationSeconds: 9,
        completedReps: 2,
        targetReps: 5,
        mistakeLogs: const ['第1次：側捏動作不夠流暢'],
        videoUrl: videoUrl,
        isSynced: true,
        isVideoSynced: true,
      );

  Widget app(List<TrainingRecord> records) => MaterialApp(
        home: Scaffold(
          body: PatientTrainingVideosCard(records: records),
        ),
      );

  testWidgets('shows a clear empty state when the patient has no videos',
      (tester) async {
    await tester.pumpWidget(app([record()]));

    expect(find.text('患者訓練影片'), findsOneWidget);
    expect(find.text('患者目前沒有已上傳的訓練影片'), findsOneWidget);
    expect(find.byTooltip('播放影片'), findsNothing);
  });

  testWidgets('shows actual completed reps and a play action', (tester) async {
    await tester.pumpWidget(app([
      record(videoUrl: 'https://example.test/api/training-history/123/video'),
    ]));

    expect(find.text('伸手舉高訓練'), findsOneWidget);
    expect(find.textContaining('Lv.2 · 2/5 · 9秒 · 1次失誤'), findsOneWidget);
    expect(find.byTooltip('播放影片'), findsOneWidget);
  });
}

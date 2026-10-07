import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/rehab_ml/ml_sample_repository.dart';
import 'package:flutter_body/features/rehab_ml/ml_sample_sheet.dart';
import 'package:flutter_body/features/rehab_ml/ml_quality_evaluator.dart';
import 'package:flutter_body/features/rehab_ml/ml_research_api.dart';
import 'package:flutter_body/features/rehab_ml/research_collection_gate.dart';
import 'package:flutter_body/features/account/app_session.dart';

class _ConsentRemote extends MlResearchApi {
  bool active = false;
  @override
  Future<MlResearchConsent> getConsent() async => MlResearchConsent(
      active: active, available: true, currentVersion: 'synthetic-v1',
      subjectId: active ? 'server-subject' : null,
      bodyAvailableActions: const ['standing_knee_raise']);
  @override
  Future<MlResearchConsent> setConsent(bool agree, String version) async {
    active = agree;
    return getConsent();
  }
}

class _EmptySampleRepository extends MlSampleRepository {
  @override
  Future<List<Map<String, dynamic>>> list() async => [];
}

void main() {
  testWidgets(
      'research result metadata is separate and unavailable has no fake label',
      (tester) async {
    final result = ValueNotifier<MlQualityResult>(
        const MlQualityResult.unavailable('研究模型尚未開放。'));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MlSampleSheet(
                repository: _EmptySampleRepository(),
                initialConsent: false,
                initialSubjectId: null,
                onConsentChanged: (_, __) {},
                qualityResult: result))));
    await tester.pumpAndSettle();
    expect(find.text('模型狀態：研究模型尚未開放。'), findsOneWidget);
    expect(find.textContaining('模型機率'), findsNothing);
    result.value = const MlQualityResult.prediction(
        label: 'meets_requirement',
        confidence: 0.8,
        modelVersion: 'synthetic-test-only');
    await tester.pump();
    expect(find.textContaining('synthetic-test-only'), findsOneWidget);
    expect(find.textContaining('80.0%'), findsOneWidget);
    expect(find.textContaining('不影響計次'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    result.dispose();
  });

  testWidgets('research collection follows server consent without manual subject code',
      (tester) async {
    AppSession.userId = 'patient';
    AppSession.customExerciseToken = 'synthetic-token';
    AppSession.changes.value++;
    final gate = ResearchCollectionGate(remote: _ConsentRemote());
    addTearDown(() {
      gate.dispose();
      AppSession.userId = null;
      AppSession.customExerciseToken = null;
      AppSession.changes.value++;
    });
    bool consent = false;
    String? subject;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MlSampleSheet(
          repository: _EmptySampleRepository(),
          initialConsent: false,
          initialSubjectId: null,
          collectionGate: gate,
          onConsentChanged: (value, id) {
            consent = value;
            subject = id;
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('模型狀態：等待物理治療師標註及驗證；不顯示 AI 分類。'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(consent, isTrue);
    expect(subject, 'server-subject');
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(consent, isFalse);
    expect(subject, isNull);
  });
}

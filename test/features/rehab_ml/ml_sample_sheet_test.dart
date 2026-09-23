import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/rehab_ml/ml_sample_repository.dart';
import 'package:flutter_body/features/rehab_ml/ml_sample_sheet.dart';

class _EmptySampleRepository extends MlSampleRepository {
  @override
  Future<List<Map<String, dynamic>>> list() async => [];
}

void main() {
  testWidgets('research collection remains off until explicit valid consent',
      (tester) async {
    bool consent = false;
    String? subject;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MlSampleSheet(
          repository: _EmptySampleRepository(),
          initialConsent: false,
          initialSubjectId: null,
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
    await tester.pump();
    expect(consent, isFalse);
    expect(find.textContaining('請輸入研究用匿名代碼'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'subject_01');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(consent, isTrue);
    expect(subject, 'subject_01');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(consent, isFalse);
    expect(subject, isNull);
  });
}

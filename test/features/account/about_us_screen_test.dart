import 'package:flutter/material.dart';
import 'package:flutter_body/features/account/about_us_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('顯示 RehabAssist 正式專題資訊與動態版本', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AboutUsScreen(versionProvider: _FakeVersionProvider()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RehabAssist'), findsWidgets);
    expect(find.text('智慧復健訓練整合平台'), findsWidgets);
    expect(find.text('關於 RehabAssist'), findsOneWidget);

    await _scrollTo(tester, '我們的理念');
    expect(find.text('我們的理念'), findsOneWidget);

    await _scrollTo(tester, '開發團隊');
    expect(find.text('資訊應用組'), findsOneWidget);
    expect(find.text('魏世杰 老師'), findsOneWidget);
    for (final member in ['楊崇佑', '鄭聿廷', '郭宸佑', '張傑羽', '張峰碩', '劉管亮']) {
      expect(find.text(member), findsOneWidget);
    }
    expect(find.text('115 學年度'), findsOneWidget);

    await _scrollTo(tester, '醫療資訊聲明');
    expect(find.text('醫療資訊聲明'), findsOneWidget);

    await _scrollTo(tester, '版本');
    expect(find.text('版本'), findsOneWidget);
    expect(find.text('1.2.3 (45)'), findsOneWidget);
  });

  testWidgets('版本讀取失敗安全顯示 fallback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AboutUsScreen(versionProvider: _FailingVersionProvider()),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollTo(tester, '版本');
    expect(find.byKey(const Key('about-app-version')), findsOneWidget);
    expect(find.text('--'), findsOneWidget);
  });
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

class _FakeVersionProvider implements AppVersionProvider {
  @override
  Future<String> loadVersion() async => '1.2.3 (45)';
}

class _FailingVersionProvider implements AppVersionProvider {
  @override
  Future<String> loadVersion() async => throw Exception('plugin unavailable');
}

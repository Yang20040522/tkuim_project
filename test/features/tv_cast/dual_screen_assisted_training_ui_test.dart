import 'package:flutter/material.dart';
import 'package:flutter_body/features/tv_cast/phone_connection_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('輔助螢幕 IP 連線頁使用新名稱並適應手機尺寸', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: PhoneConnectionScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('連接輔助螢幕'), findsOneWidget);
    expect(find.text('輔助螢幕 IP 位址'), findsOneWidget);
    expect(find.text('開始連線'), findsOneWidget);
    expect(find.textContaining('相同的 Wi-Fi 網路'), findsOneWidget);
    expect(find.textContaining('TV'), findsNothing);

    await tester.tap(find.text('連線詳細資訊'));
    await tester.pumpAndSettle();
    final portField = find.widgetWithText(TextField, '通訊埠');
    expect(portField, findsOneWidget);
    expect(tester.widget<TextField>(portField).controller!.text, '4040');
    expect(tester.takeException(), isNull);
  });

  testWidgets('輔助螢幕 IP 連線頁適應平板尺寸', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: PhoneConnectionScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('連接輔助螢幕'), findsOneWidget);
    expect(find.text('雙螢幕輔助訓練'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

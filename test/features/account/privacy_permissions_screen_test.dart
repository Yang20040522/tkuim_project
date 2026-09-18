import 'package:flutter/material.dart';
import 'package:flutter_body/features/account/privacy_permissions_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('顯示真實權限項目、隱私說明與系統設定入口', (tester) async {
    final service = _FakePermissionService();

    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyPermissionsScreen(permissionService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('隱私權限'), findsOneWidget);
    expect(find.text('你的隱私，由你掌控'), findsOneWidget);
    expect(find.text('相機'), findsOneWidget);
    expect(find.text('麥克風'), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);
    expect(find.text('附近裝置'), findsOneWidget);
    expect(find.text('資料與隱私'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('開啟系統權限設定'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('開啟系統權限設定'), findsOneWidget);
    expect(service.requested, isEmpty);
  });

  testWidgets('只有主動點擊未允許權限才 request 並刷新 badge', (tester) async {
    final service = _FakePermissionService(
      initial: {
        PrivacyPermissionType.camera: PrivacyPermissionState.denied,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyPermissionsScreen(permissionService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.requested, isEmpty);
    await tester.tap(find.text('相機'));
    await tester.pumpAndSettle();

    expect(service.requested, [PrivacyPermissionType.camera]);
    expect(find.text('已允許'), findsWidgets);
  });

  testWidgets('永久拒絕會開啟設定且 resumed 後重新讀取狀態', (tester) async {
    final service = _FakePermissionService(
      initial: {
        PrivacyPermissionType.microphone:
            PrivacyPermissionState.permanentlyDenied,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyPermissionsScreen(permissionService: service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('前往設定'));
    await tester.pump();
    expect(service.openSettingsCount, 1);
    expect(service.requested, isEmpty);

    final statusCallsBeforeResume = service.statusCalls;
    service.states[PrivacyPermissionType.microphone] =
        PrivacyPermissionState.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(service.statusCalls, greaterThan(statusCallsBeforeResume));
  });
}

class _FakePermissionService implements PrivacyPermissionService {
  _FakePermissionService(
      {Map<PrivacyPermissionType, PrivacyPermissionState>? initial})
      : states = {
          for (final type in PrivacyPermissionType.values)
            type: PrivacyPermissionState.granted,
          ...?initial,
        };

  final Map<PrivacyPermissionType, PrivacyPermissionState> states;
  final List<PrivacyPermissionType> requested = [];
  int statusCalls = 0;
  int openSettingsCount = 0;

  @override
  bool isSupported(PrivacyPermissionType type) => true;

  @override
  Future<PrivacyPermissionState> status(PrivacyPermissionType type) async {
    statusCalls++;
    return states[type]!;
  }

  @override
  Future<PrivacyPermissionState> request(PrivacyPermissionType type) async {
    requested.add(type);
    states[type] = PrivacyPermissionState.granted;
    return states[type]!;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCount++;
    return true;
  }
}

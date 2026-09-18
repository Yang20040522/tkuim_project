import 'package:flutter/material.dart';
import 'package:flutter_body/features/account/about_us_screen.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/privacy_permissions_screen.dart';
import 'package:flutter_body/features/account/profile_screen.dart';
import 'package:flutter_body/features/account/user_avatar_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.userId = '12';
    AppSession.email = 'patient@example.com';
    AppSession.name = '王小明';
  });

  testWidgets('個人頁隱私權限入口開啟正式頁面', (tester) async {
    await _pumpProfile(tester);
    await tester.ensureVisible(find.text('隱私權限'));
    await tester.tap(find.text('隱私權限'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPermissionsScreen), findsOneWidget);
    expect(find.text('你的隱私，由你掌控'), findsOneWidget);
  });

  testWidgets('個人頁關於我們入口開啟正式頁面', (tester) async {
    await _pumpProfile(tester);
    await tester.ensureVisible(find.text('關於我們'));
    await tester.tap(find.text('關於我們'));
    await tester.pumpAndSettle();

    expect(find.byType(AboutUsScreen), findsOneWidget);
    expect(find.text('智慧復健訓練整合平台'), findsOneWidget);
  });
}

Future<void> _pumpProfile(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ProfileScreen(avatarRepository: _FakeAvatarRepository()),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeAvatarRepository implements UserAvatarRepository {
  @override
  Future<UserAvatar> load(String ownerKey) async => const UserAvatar();

  @override
  Future<String?> pickAndSaveCustomAvatar(String ownerKey) async => null;

  @override
  Future<void> saveGooglePhotoUrl(String ownerKey, String? photoUrl) async {}
}

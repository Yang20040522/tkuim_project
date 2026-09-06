import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/profile_screen.dart';
import 'package:flutter_body/features/account/user_avatar_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.userId = '12';
    AppSession.accountId = null;
    AppSession.email = 'patient@example.com';
    AppSession.name = '王小明';
  });

  test('custom avatars persist per user and override stored Google URLs',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('rehab-avatar-test');
    addTearDown(() => directory.delete(recursive: true));
    final sourceA = await _writeImage(directory, 'source-a.png');
    final sourceB = await _writeImage(directory, 'source-b.png');

    final repositoryA = LocalUserAvatarRepository(
      directoryProvider: () async => directory,
      picker: () async => sourceA.path,
    );
    await repositoryA.saveGooglePhotoUrl(
      'user_12',
      'https://example.test/google-a.jpg',
    );
    final customA = await repositoryA.pickAndSaveCustomAvatar('user_12');

    final repositoryB = LocalUserAvatarRepository(
      directoryProvider: () async => directory,
      picker: () async => sourceB.path,
    );
    await repositoryB.saveGooglePhotoUrl(
      'user_99',
      'https://example.test/google-b.jpg',
    );
    final customB = await repositoryB.pickAndSaveCustomAvatar('user_99');

    final reloaded = LocalUserAvatarRepository(
      directoryProvider: () async => directory,
    );
    final avatarA = await reloaded.load('user_12');
    final avatarB = await reloaded.load('user_99');
    expect(avatarA.customPath, customA);
    expect(avatarA.googlePhotoUrl, 'https://example.test/google-a.jpg');
    expect(avatarA.source, UserAvatarSource.custom);
    expect(avatarB.customPath, customB);
    expect(avatarB.googlePhotoUrl, 'https://example.test/google-b.jpg');
    expect(avatarA.customPath, isNot(avatarB.customPath));
  });

  test('Google avatar is preferred when no custom avatar exists', () {
    const avatar = UserAvatar(
      googlePhotoUrl: 'https://example.test/google.jpg',
    );
    expect(avatar.source, UserAvatarSource.google);
  });

  testWidgets('profile without an avatar keeps initials fallback',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(avatarRepository: _FakeAvatarRepository()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('profile-avatar-initials')), findsOneWidget);
    expect(find.text('王'), findsOneWidget);
  });

  testWidgets('Google image failure builder returns initials fallback',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    const fallback = SizedBox(key: Key('fallback-initials'));
    final image = buildGoogleProfileAvatarImage(
      'https://example.test/google-avatar.jpg',
      fallback,
    );
    final builtFallback = image.errorBuilder!(
      tester.element(find.byType(SizedBox).first),
      Exception('simulated image failure'),
      null,
    );
    expect(builtFallback, same(fallback));
  });

  testWidgets('tapping profile avatar invokes the current user picker',
      (tester) async {
    final repository = _FakeAvatarRepository();
    await tester.pumpWidget(
      MaterialApp(home: ProfileScreen(avatarRepository: repository)),
    );
    await tester.pump();

    expect(find.byKey(const Key('profile-avatar-edit-badge')), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-avatar-change')));
    await tester.pump();

    expect(repository.lastPickedOwner, 'user_12');
  });
}

Future<File> _writeImage(Directory directory, String name) {
  return File('${directory.path}${Platform.pathSeparator}$name')
      .writeAsBytes(const [1, 2, 3]);
}

class _FakeAvatarRepository implements UserAvatarRepository {
  final UserAvatar avatar = const UserAvatar();
  String? lastPickedOwner;

  @override
  Future<UserAvatar> load(String ownerKey) async => avatar;

  @override
  Future<String?> pickAndSaveCustomAvatar(String ownerKey) async {
    lastPickedOwner = ownerKey;
    return null;
  }

  @override
  Future<void> saveGooglePhotoUrl(String ownerKey, String? photoUrl) async {}
}

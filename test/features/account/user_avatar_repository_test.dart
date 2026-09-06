import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/profile_screen.dart';
import 'package:flutter_body/features/account/remote_user_avatar_repository.dart';
import 'package:flutter_body/features/account/user_avatar_api_client.dart';
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

  test('successive custom replacements use unique paths and clean old files',
      () async {
    final directory = await Directory.systemTemp.createTemp('avatar-replace');
    addTearDown(() => directory.delete(recursive: true));
    final sources = [
      await _writeImage(directory, 'a.png'),
      await _writeImage(directory, 'b.png'),
      await _writeImage(directory, 'c.png'),
    ];
    var pickIndex = 0;
    final repository = LocalUserAvatarRepository(
      directoryProvider: () async => directory,
      picker: () async => sources[pickIndex++].path,
    );

    final pathA = await repository.pickAndSaveCustomAvatar('user_12');
    final pathB = await repository.pickAndSaveCustomAvatar('user_12');
    final pathC = await repository.pickAndSaveCustomAvatar('user_12');

    expect({pathA, pathB, pathC}, hasLength(3));
    expect(await File(pathA!).exists(), isFalse);
    expect(await File(pathB!).exists(), isFalse);
    expect(await File(pathC!).exists(), isTrue);
    expect((await repository.load('user_12')).customPath, pathC);
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

  testWidgets('custom avatar updates locally and uploads remotely',
      (tester) async {
    const imagePath = 'C:\\missing-test-avatar.png';
    final local = _FakeAvatarRepository(pickedPath: imagePath);
    final remote = _FakeRemoteAvatarRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          avatarRepository: local,
          remoteAvatarRepository: remote,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('profile-avatar-change')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('profile-avatar-image')), findsOneWidget);
    expect(remote.uploadedPaths, [imagePath]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    imageCache.clear();
    imageCache.clearLiveImages();
  });

  testWidgets('remote upload failure preserves local avatar and shows warning',
      (tester) async {
    const imagePath = 'C:\\missing-test-avatar.png';
    final local = _FakeAvatarRepository(pickedPath: imagePath);
    final remote = _FakeRemoteAvatarRepository(shouldFail: true);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          avatarRepository: local,
          remoteAvatarRepository: remote,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('profile-avatar-change')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('profile-avatar-image')), findsOneWidget);
    expect(find.textContaining('雲端同步失敗'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    imageCache.clear();
    imageCache.clearLiveImages();
  });

  testWidgets('profile shows A then B then C and uploads every replacement',
      (tester) async {
    const paths = [
      'C:\\missing-avatar-a.png',
      'C:\\missing-avatar-b.png',
      'C:\\missing-avatar-c.png',
    ];
    final local = _FakeAvatarRepository(pickedPaths: paths);
    final remote = _FakeRemoteAvatarRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          avatarRepository: local,
          remoteAvatarRepository: remote,
        ),
      ),
    );
    await tester.pump();

    for (final path in paths) {
      await tester.tap(find.byKey(const Key('profile-avatar-change')));
      await tester.pump();
      await tester.pump();
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('profile-avatar-image')),
          matching: find.byType(Image),
        ),
      );
      expect((image.image as FileImage).file.path, path);
    }
    expect(remote.uploadedPaths, paths);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    imageCache.clear();
    imageCache.clearLiveImages();
  });
}

Future<File> _writeImage(Directory directory, String name) {
  return File('${directory.path}${Platform.pathSeparator}$name').writeAsBytes(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
      'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
}

class _FakeAvatarRepository implements UserAvatarRepository {
  _FakeAvatarRepository({this.pickedPath, this.pickedPaths = const []});

  final UserAvatar avatar = const UserAvatar();
  final String? pickedPath;
  final List<String> pickedPaths;
  int _pickIndex = 0;
  String? lastPickedOwner;

  @override
  Future<UserAvatar> load(String ownerKey) async => avatar;

  @override
  Future<String?> pickAndSaveCustomAvatar(String ownerKey) async {
    lastPickedOwner = ownerKey;
    if (_pickIndex < pickedPaths.length) return pickedPaths[_pickIndex++];
    return pickedPath;
  }

  @override
  Future<void> saveGooglePhotoUrl(String ownerKey, String? photoUrl) async {}
}

class _FakeRemoteAvatarRepository implements RemoteUserAvatarRepository {
  _FakeRemoteAvatarRepository({this.shouldFail = false});

  final bool shouldFail;
  final List<String> uploadedPaths = [];
  final List<String> syncedGoogleUrls = [];

  @override
  Future<void> uploadCurrentUserAvatar(String filePath) async {
    uploadedPaths.add(filePath);
    if (shouldFail) throw Exception('network failed');
  }

  @override
  Future<void> syncGoogleAvatar(String photoUrl) async {
    syncedGoogleUrls.add(photoUrl);
    if (shouldFail) throw Exception('network failed');
  }

  @override
  Future<RemoteUserAvatar?> getUserAvatar(String userId) async => null;
}

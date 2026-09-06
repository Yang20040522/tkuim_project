import 'package:flutter/material.dart';
import 'package:flutter_body/features/account/auth_service.dart';
import 'package:flutter_body/features/account/google_auth_service.dart';
import 'package:flutter_body/features/account/login_screen.dart';
import 'package:flutter_body/features/account/patient_google_auth_button.dart';
import 'package:flutter_body/features/account/remote_user_avatar_repository.dart';
import 'package:flutter_body/features/account/user_avatar_api_client.dart';
import 'package:flutter_body/features/account/register_screen.dart';
import 'package:flutter_body/features/account/therapist_login_screen.dart';
import 'package:flutter_body/features/account/user_avatar_repository.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('patient login shows Traditional Chinese Google option',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen(role: UserRole.patient)),
    );
    expect(find.text('使用 Google 登入'), findsOneWidget);
    expect(find.text('電子郵件或帳號 ID'), findsOneWidget);
  });

  testWidgets('patient register shows Traditional Chinese Google option',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RegisterScreen(role: UserRole.patient)),
    );
    expect(find.text('使用 Google 註冊'), findsOneWidget);
  });

  testWidgets('therapist login never exposes Google authentication',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TherapistLoginScreen()),
    );
    expect(find.textContaining('Google'), findsNothing);
    expect(find.byKey(const Key('patient-google-auth-button')), findsNothing);
    expect(find.text('電子郵件或帳號 ID'), findsOneWidget);
  });

  testWidgets('linking-required flow asks for password and links once',
      (tester) async {
    final backend = UiFakeBackend();
    final coordinator = PatientGoogleAuthCoordinator(
      credentialProvider: const UiFakeCredentialProvider(),
      backend: backend,
    );
    final avatars = UiFakeAvatarRepository();
    final remoteAvatars = UiFakeRemoteAvatarRepository();
    LoginResult? authenticated;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatientGoogleAuthButton(
            label: '使用 Google 登入',
            coordinator: coordinator,
            avatarRepository: avatars,
            remoteAvatarRepository: remoteAvatars,
            onAuthenticated: (result) async => authenticated = result,
          ),
        ),
      ),
    );

    await tester.tap(find.text('使用 Google 登入'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('連結既有帳號'), findsOneWidget);
    expect(find.text('請輸入原帳號密碼以完成連結。'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('google-link-password-field')),
      'correct-password',
    );
    await tester.tap(find.byKey(const Key('google-link-confirm-button')));
    await tester.pumpAndSettle();

    expect(authenticated?.userId, '12');
    expect(backend.linkCalls, 1);
    expect(avatars.ownerKey, 'user_12');
    expect(avatars.photoUrl, 'https://example.test/google-avatar.jpg');
    expect(remoteAvatars.googleUrls, [
      'https://example.test/google-avatar.jpg',
    ]);
    expect(find.text('連結既有帳號'), findsNothing);
  });

  testWidgets('Google avatar cloud failure never blocks successful login',
      (tester) async {
    final coordinator = PatientGoogleAuthCoordinator(
      credentialProvider: const UiFakeCredentialProvider(),
      backend: UiSuccessBackend(),
    );
    final avatars = UiFakeAvatarRepository();
    final remoteAvatars = UiFakeRemoteAvatarRepository(shouldFail: true);
    LoginResult? authenticated;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatientGoogleAuthButton(
            label: '使用 Google 登入',
            coordinator: coordinator,
            avatarRepository: avatars,
            remoteAvatarRepository: remoteAvatars,
            onAuthenticated: (result) async => authenticated = result,
          ),
        ),
      ),
    );

    await tester.tap(find.text('使用 Google 登入'));
    await tester.pumpAndSettle();

    expect(authenticated?.userId, '12');
    expect(avatars.photoUrl, 'https://example.test/google-avatar.jpg');
    expect(remoteAvatars.googleUrls, hasLength(1));
    expect(find.textContaining('登入失敗'), findsNothing);
  });

  testWidgets('Google login without photo URL skips cloud sync',
      (tester) async {
    final remoteAvatars = UiFakeRemoteAvatarRepository();
    LoginResult? authenticated;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatientGoogleAuthButton(
            label: '使用 Google 登入',
            coordinator: PatientGoogleAuthCoordinator(
              credentialProvider:
                  const UiFakeCredentialProvider(photoUrl: null),
              backend: UiSuccessBackend(),
            ),
            avatarRepository: UiFakeAvatarRepository(),
            remoteAvatarRepository: remoteAvatars,
            onAuthenticated: (result) async => authenticated = result,
          ),
        ),
      ),
    );

    await tester.tap(find.text('使用 Google 登入'));
    await tester.pumpAndSettle();

    expect(authenticated?.userId, '12');
    expect(remoteAvatars.googleUrls, isEmpty);
  });
}

class UiFakeCredentialProvider implements PatientGoogleCredentialProvider {
  const UiFakeCredentialProvider({
    this.photoUrl = 'https://example.test/google-avatar.jpg',
  });

  final String? photoUrl;

  @override
  Future<PatientGoogleCredential> authenticate() async {
    return PatientGoogleCredential(
      idToken: 'memory-token',
      photoUrl: photoUrl,
    );
  }
}

class UiFakeAvatarRepository implements UserAvatarRepository {
  String? ownerKey;
  String? photoUrl;

  @override
  Future<UserAvatar> load(String ownerKey) async => const UserAvatar();

  @override
  Future<String?> pickAndSaveCustomAvatar(String ownerKey) async => null;

  @override
  Future<void> saveGooglePhotoUrl(String ownerKey, String? photoUrl) async {
    this.ownerKey = ownerKey;
    this.photoUrl = photoUrl;
  }
}

class UiFakeBackend implements PatientGoogleBackend {
  int linkCalls = 0;

  @override
  Future<LoginResult> login(String idToken) async {
    return LoginResult.failure(
      '需要連結',
      errorCode: 'GOOGLE_LINK_REQUIRED',
    );
  }

  @override
  Future<LoginResult> link(String idToken, String currentPassword) async {
    linkCalls++;
    return LoginResult.success(
      userId: '12',
      name: '王小明',
      email: 'patient@example.com',
      bindingCode: 'ABC12345',
      customExerciseToken: 'hmac-token',
      backendRole: 'PATIENT',
    );
  }
}

class UiSuccessBackend implements PatientGoogleBackend {
  @override
  Future<LoginResult> login(String idToken) async => _patientLoginResult();

  @override
  Future<LoginResult> link(String idToken, String currentPassword) async =>
      _patientLoginResult();
}

LoginResult _patientLoginResult() => LoginResult.success(
      userId: '12',
      name: '王小明',
      email: 'patient@example.com',
      bindingCode: 'ABC12345',
      customExerciseToken: 'hmac-token',
      backendRole: 'PATIENT',
    );

class UiFakeRemoteAvatarRepository implements RemoteUserAvatarRepository {
  UiFakeRemoteAvatarRepository({this.shouldFail = false});

  final bool shouldFail;
  final List<String> googleUrls = [];

  @override
  Future<RemoteUserAvatar?> getUserAvatar(String userId) async => null;

  @override
  Future<void> syncGoogleAvatar(String photoUrl) async {
    googleUrls.add(photoUrl);
    if (shouldFail) throw Exception('cloud failed');
  }

  @override
  Future<void> uploadCurrentUserAvatar(String filePath) async {}
}

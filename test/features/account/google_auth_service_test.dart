import 'package:flutter_body/features/account/auth_service.dart';
import 'package:flutter_body/features/account/google_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful Google backend login returns PATIENT session data',
      () async {
    final backend = FakeGoogleBackend(loginResult: patientResult());
    final coordinator = PatientGoogleAuthCoordinator(
      credentialProvider: FakeCredentialProvider('memory-only-token'),
      backend: backend,
    );

    final result = await coordinator.authenticate();

    expect(result.status, PatientGoogleAuthStatus.success);
    expect(result.loginResult?.userId, '12');
    expect(backend.lastLoginToken, 'memory-only-token');
    expect(coordinator.hasPendingLink, isFalse);
  });

  test('Google profile photo URL stays with successful auth result', () async {
    final coordinator = PatientGoogleAuthCoordinator(
      credentialProvider: FakeCredentialProvider(
        'memory-only-token',
        photoUrl: 'https://example.test/avatar.jpg',
      ),
      backend: FakeGoogleBackend(loginResult: patientResult()),
    );

    final result = await coordinator.authenticate();

    expect(result.googlePhotoUrl, 'https://example.test/avatar.jpg');
  });

  test('backend role must be PATIENT', () async {
    final coordinator = PatientGoogleAuthCoordinator(
      credentialProvider: FakeCredentialProvider('token'),
      backend: FakeGoogleBackend(
        loginResult: LoginResult.success(
          userId: '3',
          name: '治療師',
          email: 'therapist@example.com',
          bindingCode: null,
          customExerciseToken: 'hmac',
          backendRole: 'THERAPIST',
        ),
      ),
    );

    final result = await coordinator.authenticate();
    expect(result.status, PatientGoogleAuthStatus.failure);
    expect(result.message, '此帳號無法使用患者 Google 登入');
  });

  test('linking required keeps token only in coordinator memory', () async {
    final backend = FakeGoogleBackend(
      loginResult: LoginResult.failure(
        '需要連結',
        errorCode: 'GOOGLE_LINK_REQUIRED',
      ),
      linkResult: patientResult(),
    );
    final coordinator = PatientGoogleAuthCoordinator(
      credentialProvider: FakeCredentialProvider('fresh-token'),
      backend: backend,
    );

    expect(
      (await coordinator.authenticate()).status,
      PatientGoogleAuthStatus.linkRequired,
    );
    expect(coordinator.hasPendingLink, isTrue);

    final linked = await coordinator.link('original-password');
    expect(linked.status, PatientGoogleAuthStatus.success);
    expect(backend.lastLinkToken, 'fresh-token');
    expect(backend.lastPassword, 'original-password');
    expect(coordinator.hasPendingLink, isFalse);
  });

  test('failed link remains retryable and cancellation clears token', () async {
    final backend = FakeGoogleBackend(
      loginResult: LoginResult.failure(
        '需要連結',
        errorCode: 'GOOGLE_LINK_REQUIRED',
      ),
      linkResult: LoginResult.failure('帳號或密碼錯誤'),
    );
    final coordinator = PatientGoogleAuthCoordinator(
      credentialProvider: FakeCredentialProvider('fresh-token'),
      backend: backend,
    );
    await coordinator.authenticate();

    final failed = await coordinator.link('wrong-password');
    expect(failed.status, PatientGoogleAuthStatus.failure);
    expect(coordinator.hasPendingLink, isTrue);

    coordinator.cancelPendingLink();
    expect(coordinator.hasPendingLink, isFalse);
  });

  test('Google cancellation is a safe translated result', () async {
    final coordinator = PatientGoogleAuthCoordinator(
      credentialProvider: CancelledCredentialProvider(),
      backend: FakeGoogleBackend(loginResult: patientResult()),
    );

    final result = await coordinator.authenticate();
    expect(result.status, PatientGoogleAuthStatus.cancelled);
    expect(result.message, 'Google 登入已取消');
  });

  test('missing server client ID fails before invoking Google UI', () async {
    final provider = GoogleSignInCredentialProvider(serverClientId: '');
    await expectLater(
      provider.authenticate(),
      throwsA(
        isA<GoogleAuthConfigurationException>().having(
          (error) => error.message,
          'message',
          contains('Google 登入尚未設定'),
        ),
      ),
    );
  });

  test('incomplete backend identity token response is rejected', () async {
    final coordinator = PatientGoogleAuthCoordinator(
      credentialProvider: FakeCredentialProvider('token'),
      backend: FakeGoogleBackend(
        loginResult: LoginResult.success(
          userId: '12',
          name: '患者',
          email: 'patient@example.com',
          bindingCode: 'ABC12345',
          customExerciseToken: null,
          backendRole: 'PATIENT',
        ),
      ),
    );

    final result = await coordinator.authenticate();
    expect(result.status, PatientGoogleAuthStatus.failure);
    expect(result.message, '伺服器登入資料不完整，請稍後再試');
  });
}

LoginResult patientResult() => LoginResult.success(
      userId: '12',
      name: '王小明',
      email: 'patient@example.com',
      bindingCode: 'ABC12345',
      customExerciseToken: 'hmac-token',
      backendRole: 'PATIENT',
    );

class FakeCredentialProvider implements PatientGoogleCredentialProvider {
  FakeCredentialProvider(this.token, {this.photoUrl});

  final String token;
  final String? photoUrl;

  @override
  Future<PatientGoogleCredential> authenticate() async {
    return PatientGoogleCredential(idToken: token, photoUrl: photoUrl);
  }
}

class CancelledCredentialProvider implements PatientGoogleCredentialProvider {
  @override
  Future<PatientGoogleCredential> authenticate() {
    throw const GoogleAuthCancelledException();
  }
}

class FakeGoogleBackend implements PatientGoogleBackend {
  FakeGoogleBackend({required this.loginResult, this.linkResult});

  final LoginResult loginResult;
  final LoginResult? linkResult;
  String? lastLoginToken;
  String? lastLinkToken;
  String? lastPassword;

  @override
  Future<LoginResult> login(String idToken) async {
    lastLoginToken = idToken;
    return loginResult;
  }

  @override
  Future<LoginResult> link(String idToken, String currentPassword) async {
    lastLinkToken = idToken;
    lastPassword = currentPassword;
    return linkResult ?? loginResult;
  }
}

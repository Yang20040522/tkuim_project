import 'package:google_sign_in/google_sign_in.dart';

import '../../core/api_config.dart';
import 'auth_service.dart';

class PatientGoogleCredential {
  const PatientGoogleCredential({required this.idToken, this.photoUrl});

  final String idToken;
  final String? photoUrl;
}

abstract class PatientGoogleCredentialProvider {
  Future<PatientGoogleCredential> authenticate();
}

class GoogleSignInCredentialProvider
    implements PatientGoogleCredentialProvider {
  GoogleSignInCredentialProvider({
    String? serverClientId,
  }) : _serverClientId = serverClientId ?? ApiConfig.googleServerClientId;

  final String _serverClientId;
  static Future<void>? _initialization;
  static String? _initializedClientId;

  @override
  Future<PatientGoogleCredential> authenticate() async {
    if (_serverClientId.trim().isEmpty) {
      throw const GoogleAuthConfigurationException(
        'Google 登入尚未設定，請使用 GOOGLE_SERVER_CLIENT_ID 啟動 App',
      );
    }

    try {
      final configuredClientId = _serverClientId.trim();
      if (_initializedClientId != null &&
          _initializedClientId != configuredClientId) {
        throw const GoogleAuthConfigurationException(
          'Google 登入設定不一致，請重新啟動 App',
        );
      }
      _initializedClientId = configuredClientId;
      _initialization ??= GoogleSignIn.instance.initialize(
        serverClientId: configuredClientId,
      );
      await _initialization;
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleAuthException('Google 未提供可驗證的登入憑證');
      }
      return PatientGoogleCredential(
        idToken: idToken,
        photoUrl: account.photoUrl,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleAuthCancelledException();
      }
      throw const GoogleAuthException('Google 登入失敗，請稍後再試');
    }
  }
}

abstract class PatientGoogleBackend {
  Future<LoginResult> login(String idToken);

  Future<LoginResult> link(String idToken, String currentPassword);
}

class DefaultPatientGoogleBackend implements PatientGoogleBackend {
  @override
  Future<LoginResult> login(String idToken) {
    return AuthService.googleLogin(idToken: idToken);
  }

  @override
  Future<LoginResult> link(String idToken, String currentPassword) {
    return AuthService.linkGoogle(
      idToken: idToken,
      currentPassword: currentPassword,
    );
  }
}

enum PatientGoogleAuthStatus {
  success,
  linkRequired,
  cancelled,
  failure,
}

class PatientGoogleAuthResult {
  const PatientGoogleAuthResult._(
    this.status, {
    this.loginResult,
    this.message,
    this.googlePhotoUrl,
  });

  const PatientGoogleAuthResult.success(
    LoginResult result, {
    String? googlePhotoUrl,
  }) : this._(
          PatientGoogleAuthStatus.success,
          loginResult: result,
          googlePhotoUrl: googlePhotoUrl,
        );

  const PatientGoogleAuthResult.linkRequired()
      : this._(PatientGoogleAuthStatus.linkRequired);

  const PatientGoogleAuthResult.cancelled()
      : this._(
          PatientGoogleAuthStatus.cancelled,
          message: 'Google 登入已取消',
        );

  const PatientGoogleAuthResult.failure(String message)
      : this._(PatientGoogleAuthStatus.failure, message: message);

  final PatientGoogleAuthStatus status;
  final LoginResult? loginResult;
  final String? message;
  final String? googlePhotoUrl;
}

class PatientGoogleAuthCoordinator {
  PatientGoogleAuthCoordinator({
    PatientGoogleCredentialProvider? credentialProvider,
    PatientGoogleBackend? backend,
  })  : _credentialProvider =
            credentialProvider ?? GoogleSignInCredentialProvider(),
        _backend = backend ?? DefaultPatientGoogleBackend();

  final PatientGoogleCredentialProvider _credentialProvider;
  final PatientGoogleBackend _backend;
  String? _pendingIdToken;
  String? _pendingGooglePhotoUrl;

  bool get hasPendingLink => _pendingIdToken != null;

  Future<PatientGoogleAuthResult> authenticate() async {
    _pendingIdToken = null;
    _pendingGooglePhotoUrl = null;
    try {
      final credential = await _credentialProvider.authenticate();
      final result = await _backend.login(credential.idToken);
      if (result.success) {
        return _patientResult(
          result,
          googlePhotoUrl: credential.photoUrl,
        );
      }
      if (result.errorCode == 'GOOGLE_LINK_REQUIRED') {
        // Kept in memory only for the immediately following password proof.
        _pendingIdToken = credential.idToken;
        _pendingGooglePhotoUrl = credential.photoUrl;
        return const PatientGoogleAuthResult.linkRequired();
      }
      return PatientGoogleAuthResult.failure(
        result.message ?? 'Google 登入失敗，請稍後再試',
      );
    } on GoogleAuthCancelledException {
      return const PatientGoogleAuthResult.cancelled();
    } on GoogleAuthException catch (error) {
      return PatientGoogleAuthResult.failure(error.message);
    } catch (_) {
      return const PatientGoogleAuthResult.failure(
        'Google 登入失敗，請稍後再試',
      );
    }
  }

  Future<PatientGoogleAuthResult> link(String currentPassword) async {
    final idToken = _pendingIdToken;
    if (idToken == null) {
      return const PatientGoogleAuthResult.failure(
        'Google 登入憑證已失效，請重新登入',
      );
    }
    try {
      final result = await _backend.link(idToken, currentPassword);
      if (!result.success) {
        return PatientGoogleAuthResult.failure(
          result.message ?? '帳號連結失敗，請稍後再試',
        );
      }
      final patientResult = _patientResult(
        result,
        googlePhotoUrl: _pendingGooglePhotoUrl,
      );
      if (patientResult.status == PatientGoogleAuthStatus.success) {
        _pendingIdToken = null;
        _pendingGooglePhotoUrl = null;
      }
      return patientResult;
    } catch (_) {
      return const PatientGoogleAuthResult.failure(
        '帳號連結失敗，請稍後再試',
      );
    }
  }

  void cancelPendingLink() {
    _pendingIdToken = null;
    _pendingGooglePhotoUrl = null;
  }

  PatientGoogleAuthResult _patientResult(
    LoginResult result, {
    String? googlePhotoUrl,
  }) {
    if (result.backendRole?.toUpperCase() != 'PATIENT') {
      return const PatientGoogleAuthResult.failure(
        '此帳號無法使用患者 Google 登入',
      );
    }
    if ((result.userId ?? '').trim().isEmpty ||
        (result.customExerciseToken ?? '').trim().isEmpty) {
      return const PatientGoogleAuthResult.failure(
        '伺服器登入資料不完整，請稍後再試',
      );
    }
    return PatientGoogleAuthResult.success(
      result,
      googlePhotoUrl: googlePhotoUrl,
    );
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;
}

class GoogleAuthConfigurationException extends GoogleAuthException {
  const GoogleAuthConfigurationException(super.message);
}

class GoogleAuthCancelledException extends GoogleAuthException {
  const GoogleAuthCancelledException() : super('Google 登入已取消');
}

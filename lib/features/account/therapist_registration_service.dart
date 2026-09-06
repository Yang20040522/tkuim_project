import 'auth_service.dart';

abstract interface class TherapistRegistrationGateway {
  Future<LoginResult> register({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  });
}

class TherapistRegistrationService implements TherapistRegistrationGateway {
  const TherapistRegistrationService();

  @override
  Future<LoginResult> register({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) {
    return AuthService.registerTherapist(
      name: name,
      email: email,
      password: password,
      inviteCode: inviteCode,
    );
  }
}

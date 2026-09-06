import 'auth_service.dart';

abstract interface class TherapistRegistrationGateway {
  Future<LoginResult> register({
    required String name,
    required String email,
    required String password,
  });
}

class TherapistRegistrationService implements TherapistRegistrationGateway {
  const TherapistRegistrationService();

  @override
  Future<LoginResult> register({
    required String name,
    required String email,
    required String password,
  }) {
    return AuthService.registerTherapist(
      name: name,
      email: email,
      password: password,
    );
  }
}

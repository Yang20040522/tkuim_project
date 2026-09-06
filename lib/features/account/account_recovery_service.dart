import 'api_service.dart';

class AccountRecoveryResult {
  const AccountRecoveryResult.success(this.message)
      : success = true,
        errorCode = null;

  const AccountRecoveryResult.failure(this.message, {this.errorCode})
      : success = false;

  final bool success;
  final String message;
  final String? errorCode;
}

abstract interface class AccountRecoveryGateway {
  Future<AccountRecoveryResult> requestCode(String identifier);

  Future<AccountRecoveryResult> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  });
}

class AccountRecoveryService implements AccountRecoveryGateway {
  const AccountRecoveryService();

  @override
  Future<AccountRecoveryResult> requestCode(String identifier) async {
    try {
      final response = await ApiService.forgotPassword(identifier: identifier);
      return AccountRecoveryResult.success(
        response['message']?.toString() ?? genericRequestMessage,
      );
    } on AuthApiFailure catch (error) {
      return AccountRecoveryResult.failure(
        error.message,
        errorCode: error.code,
      );
    } catch (_) {
      return const AccountRecoveryResult.failure('無法連線到伺服器，請稍後再試');
    }
  }

  @override
  Future<AccountRecoveryResult> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await ApiService.resetPassword(
        identifier: identifier,
        code: code,
        newPassword: newPassword,
      );
      return AccountRecoveryResult.success(
        response['message']?.toString() ?? '密碼已更新，請使用新密碼登入',
      );
    } on AuthApiFailure catch (error) {
      return AccountRecoveryResult.failure(
        error.message,
        errorCode: error.code,
      );
    } catch (_) {
      return const AccountRecoveryResult.failure('無法連線到伺服器，請稍後再試');
    }
  }

  static const genericRequestMessage = '如果帳號存在，我們已將驗證碼寄送至帳號綁定的 Email。';
}

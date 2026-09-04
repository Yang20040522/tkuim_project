/// Temporary Flutter-only policy used while the Milestone 6B backend cannot be
/// deployed.
class CustomExerciseDevelopmentFallback {
  const CustomExerciseDevelopmentFallback._();

  // TODO(M6B deployment):
  // Remove temporary no-token development fallback after the updated backend is deployed.
  static const bool allowMissingToken = true;

  static const String remoteUnavailableMessage =
      '開發模式：新版伺服器尚未部署，雲端已儲存自訂動作暫時無法使用。';

  static String? normalizeToken(String? token) {
    final normalized = token?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static bool canCompleteTherapistLogin(String? token) {
    return normalizeToken(token) != null || allowMissingToken;
  }

  static bool isActiveFor(String? token) {
    return allowMissingToken && normalizeToken(token) == null;
  }
}

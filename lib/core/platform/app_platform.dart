import 'package:flutter/foundation.dart';

/// Capabilities are selected once at the application entry point, not by routes.
class AppCapabilities {
  final bool isTv;
  const AppCapabilities.tv() : isTv = true;
  const AppCapabilities.mobile() : isTv = false;
  bool get supportsLocalCamera => !isTv;
  bool get supportsNotifications => !isTv;
  bool get supportsGoogleSignIn => !isTv;
  bool get supportsTouchInput => !isTv;
  bool get supportsDpad => isTv;
  bool get supportsVideoCalls => !isTv;
  bool get supportsScreenRecording => !isTv;
}

class AppPlatform {
  static AppCapabilities current = const AppCapabilities.mobile();

  static void configure() {
    current = const bool.fromEnvironment('TV_CLIENT', defaultValue: true)
        ? const AppCapabilities.tv()
        : const AppCapabilities.mobile();
  }
}

/// Optional native services must not prevent basic account access.
Future<void> initializeOptionalNotifications({
  required AppCapabilities capabilities,
  required Future<void> Function() initialize,
}) async {
  if (!capabilities.supportsNotifications) return;
  try {
    await initialize();
  } catch (error, stack) {
    debugPrint('Notification initialization unavailable: $error\n$stack');
  }
}

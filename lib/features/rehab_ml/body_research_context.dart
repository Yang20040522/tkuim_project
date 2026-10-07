import 'dart:math';

/// Immutable owner and assignment captured at session start. Owner is local
/// only: backend identity always comes from authenticated headers.
class BodyResearchContext {
  BodyResearchContext(
      {required this.ownerId,
      required this.accountGeneration,
      required this.exerciseId,
      required this.movementSide,
      required this.capturedAt,
      this.exerciseType = 'DEFAULT',
      this.source = 'tv_pi',
      this.platform = 'android_tv',
      this.cameraView = 'rear',
      this.resampleOfSampleId,
      String? sessionId})
      : sessionId = sessionId ?? newResearchId() {
    if (resampleOfSampleId != null &&
        !RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(resampleOfSampleId!)) {
      throw const FormatException('Invalid resample identifier');
    }
    if (ownerId.trim().isEmpty ||
        exerciseId.isEmpty ||
        !const {'DEFAULT', 'CUSTOM'}.contains(exerciseType) ||
        !const {'left', 'right', 'bilateral'}.contains(movementSide) ||
        !const {'phone', 'tv_pi'}.contains(source) ||
        !const {'android_phone', 'android_tv'}.contains(platform) ||
        !const {'front', 'rear'}.contains(cameraView)) {
      throw const FormatException('Invalid research context');
    }
  }
  final String ownerId, exerciseId, exerciseType, source, platform;
  final String movementSide, sessionId, cameraView;
  final String? resampleOfSampleId;
  final int accountGeneration;
  final DateTime capturedAt;

  BodyResearchContext forResample(String? parentId) => BodyResearchContext(
      ownerId: ownerId,
      accountGeneration: accountGeneration,
      exerciseId: exerciseId,
      exerciseType: exerciseType,
      movementSide: movementSide,
      source: source,
      platform: platform,
      cameraView: cameraView,
      sessionId: sessionId,
      capturedAt: DateTime.now(),
      resampleOfSampleId: parentId);
}

String newResearchId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

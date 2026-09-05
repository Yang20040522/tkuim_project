import 'dart:ui';

import 'models/pose_frame.dart';

/// Applies native CameraX's authoritative transform, never a guessed BoxFit.
class PoseCoordinateTransformer {
  const PoseCoordinateTransformer(this.geometry);

  final PoseGeometry? geometry;

  bool isCompatibleWith(Size viewport) {
    final current = geometry;
    if (current == null ||
        !current.isValid ||
        !viewport.width.isFinite ||
        !viewport.height.isFinite ||
        viewport.width <= 0 ||
        viewport.height <= 0) {
      return false;
    }
    // Native is physical pixels and Flutter is logical pixels. Compare ratio
    // ONLY to suppress stale geometry during layout; it never determines crop.
    final expectedRatio = current.previewWidth / current.previewHeight;
    final actualRatio = viewport.width / viewport.height;
    final relativeError = (actualRatio / expectedRatio - 1).abs();
    final roundingTolerance =
        2 / current.previewWidth + 2 / current.previewHeight;
    return relativeError <= roundingTolerance + 0.001;
  }

  Offset? transform(PoseLandmark landmark, Size viewport) {
    if (!landmark.isFinite || !isCompatibleWith(viewport)) return null;
    final m = geometry!.matrix;
    final divisor = m[6] * landmark.x + m[7] * landmark.y + m[8];
    if (!divisor.isFinite || divisor.abs() <= 1e-12) return null;
    final x = (m[0] * landmark.x + m[1] * landmark.y + m[2]) / divisor;
    final y = (m[3] * landmark.x + m[4] * landmark.y + m[5]) / divisor;
    if (!x.isFinite || !y.isFinite) return null;
    // No additional mirror or rotation, irrespective of geometry's diagnostics.
    return Offset(x * viewport.width, y * viewport.height);
  }
}

/// Geometry captured for this inference frame by the native CameraX pipeline.
///
/// [matrix] is a row-major homogeneous 3x3 transformation from normalized,
/// upright, UNMIRRORED inference coordinates to normalized actual PreviewView
/// coordinates. Native has already composed crop, rotation and preview mirror.
/// Flutter must not reconstruct those transforms from aspect ratios.
class PoseGeometry {
  PoseGeometry({
    required this.imageWidth,
    required this.imageHeight,
    required this.rotationDegrees,
    required this.mirrored,
    required this.previewWidth,
    required this.previewHeight,
    required List<double> matrix,
    required this.revision,
  }) : matrix = List.unmodifiable(matrix);

  /// Upright inference bitmap dimensions, not the raw sensor buffer dimensions.
  final int imageWidth;
  final int imageHeight;
  final int rotationDegrees;
  final bool mirrored;
  final int previewWidth;
  final int previewHeight;
  final List<double> matrix;
  final int revision;

  bool get isValid {
    if (imageWidth <= 0 ||
        imageHeight <= 0 ||
        previewWidth <= 0 ||
        previewHeight <= 0 ||
        !const [0, 90, 180, 270].contains(rotationDegrees) ||
        matrix.length != 9 ||
        matrix.any((value) => !value.isFinite)) {
      return false;
    }
    final m = matrix;
    final determinant = m[0] * (m[4] * m[8] - m[5] * m[7]) -
        m[1] * (m[3] * m[8] - m[5] * m[6]) +
        m[2] * (m[3] * m[7] - m[4] * m[6]);
    return determinant.isFinite && determinant.abs() > 1e-12;
  }

  static PoseGeometry? tryFromPlatform(Object? value) {
    if (value is! Map) return null;
    const integerFields = [
      'imageWidth',
      'imageHeight',
      'rotationDegrees',
      'previewWidth',
      'previewHeight',
      'revision',
    ];
    for (final field in integerFields) {
      final number = value[field];
      if (number is! num || !number.isFinite || number != number.toInt()) {
        return null;
      }
    }
    final matrix = value['matrix'];
    if (matrix is! List ||
        matrix.any((entry) => entry is! num) ||
        value['mirrored'] is! bool) {
      return null;
    }
    final result = PoseGeometry(
      imageWidth: (value['imageWidth'] as num).toInt(),
      imageHeight: (value['imageHeight'] as num).toInt(),
      rotationDegrees: (value['rotationDegrees'] as num).toInt(),
      mirrored: value['mirrored'] as bool,
      previewWidth: (value['previewWidth'] as num).toInt(),
      previewHeight: (value['previewHeight'] as num).toInt(),
      matrix: matrix.map((entry) => (entry as num).toDouble()).toList(),
      revision: (value['revision'] as num).toInt(),
    );
    return result.isValid ? result : null;
  }
}

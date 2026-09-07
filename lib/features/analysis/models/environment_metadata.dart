enum CameraView { front, side, oblique }

enum SupportType { none, chair, wall, walker, other }

enum BodySide { none, left, right, both }

class EnvironmentMetadata {
  const EnvironmentMetadata({
    this.cameraView = CameraView.front,
    this.supportType = SupportType.none,
    this.supportSide = BodySide.none,
    this.movementSide = BodySide.none,
  });

  final CameraView cameraView;
  final SupportType supportType;
  final BodySide supportSide;
  final BodySide movementSide;

  Map<String, dynamic> toJson() => {
        'cameraView': cameraView.name,
        'supportType': supportType.name,
        'supportSide': supportSide.name,
        'movementSide': movementSide.name,
      };

  factory EnvironmentMetadata.fromJson(Map<String, dynamic> json) =>
      EnvironmentMetadata(
        cameraView: _enumValue(
          CameraView.values,
          json['cameraView'],
          CameraView.front,
        ),
        supportType: _enumValue(
          SupportType.values,
          json['supportType'],
          SupportType.none,
        ),
        supportSide: _enumValue(
          BodySide.values,
          json['supportSide'],
          BodySide.none,
        ),
        movementSide: _enumValue(
          BodySide.values,
          json['movementSide'],
          BodySide.none,
        ),
      );
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final value = raw?.toString();
  for (final item in values) {
    if (item.name == value) return item;
  }
  return fallback;
}

extension CameraViewLabel on CameraView {
  String get label => switch (this) {
        CameraView.front => '正面',
        CameraView.side => '側面',
        CameraView.oblique => '斜側面',
      };
}

extension SupportTypeLabel on SupportType {
  String get label => switch (this) {
        SupportType.none => '無',
        SupportType.chair => '椅子',
        SupportType.wall => '牆壁',
        SupportType.walker => '助行器',
        SupportType.other => '其他',
      };
}

extension BodySideLabel on BodySide {
  String get label => switch (this) {
        BodySide.none => '無／不指定',
        BodySide.left => '左側',
        BodySide.right => '右側',
        BodySide.both => '雙側',
      };
}

class JointRotation {
  final double x;
  final double y;
  final double z;

  const JointRotation({this.x = 0, this.y = 0, this.z = 0});

  static const zero = JointRotation();

  JointRotation copyWith({double? x, double? y, double? z}) {
    return JointRotation(x: x ?? this.x, y: y ?? this.y, z: z ?? this.z);
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'z': z};

  factory JointRotation.fromJson(Map<String, dynamic> json) {
    return JointRotation(
      x: _finiteDouble(json['x'], field: 'x'),
      y: _finiteDouble(json['y'], field: 'y'),
      z: _finiteDouble(json['z'], field: 'z'),
    );
  }

  static double _finiteDouble(dynamic value, {required String field}) {
    final number = value is num ? value.toDouble() : null;
    if (number == null || !number.isFinite) {
      throw FormatException('$field 必須是有限數值');
    }
    return number;
  }

  @override
  bool operator ==(Object other) =>
      other is JointRotation && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

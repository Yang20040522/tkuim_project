import 'package:flutter_body/features/pose_measurement/joint_angle_calculator.dart';
import 'package:flutter_body/features/pose_measurement/models/pose_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = JointAngleCalculator();

  test('world three-point angles produce 90, 180 and near zero degrees', () {
    expect(calculator.angleDegrees(point(1, 0), point(0, 0), point(0, 1)),
        closeTo(90, 1e-9));
    expect(calculator.angleDegrees(point(-1, 0), point(0, 0), point(1, 0)),
        closeTo(180, 1e-9));
    expect(calculator.angleDegrees(point(1, 0), point(0, 0), point(1, 1e-8)),
        closeTo(0, 1e-5));
    expect(calculator.angleDegrees(point(1, 0), point(0, 0), point(2, 0)), 0);
  });

  test('z participates in true 3D angle and result is translation invariant',
      () {
    expect(
      calculator.angleDegrees(point(1, 0), point(0, 0), point(0, 0, z: 1)),
      closeTo(90, 1e-9),
    );
    expect(
      calculator.angleDegrees(
        point(11, 20, z: 30),
        point(10, 20, z: 30),
        point(10, 20, z: 31),
      ),
      closeTo(90, 1e-9),
    );
  });

  test(
      'missing, coincident, nonfinite, low or absent confidence is unavailable',
      () {
    final invalid = <PoseLandmark?>[
      null,
      point(0, 0),
      point(double.nan, 1),
      point(1, double.infinity),
      point(1, 1, z: double.negativeInfinity),
      point(1, 1, visibility: 0.49),
      point(1, 1, visibility: null, presence: null),
      point(1, 1, visibility: 0.9, presence: 0.2),
    ];
    for (final a in invalid) {
      expect(calculator.angleDegrees(a, point(0, 0), point(1, 1)), isNull);
    }
    expect(calculator.angleDegrees(point(1, 0), null, point(0, 1)), isNull);
    expect(calculator.angleDegrees(point(1, 0), point(0, 0), null), isNull);
  });

  test('confidence threshold is inclusive and respects presence when available',
      () {
    expect(
      calculator.angleDegrees(
        point(1, 0, visibility: 0.5, presence: null),
        point(0, 0, visibility: null, presence: 0.5),
        point(0, 1),
      ),
      closeTo(90, 1e-9),
    );
  });

  test('existing elbow knee shoulder-body and hip-body angles stay unchanged',
      () {
    final result = calculator.calculate(fullFrame());
    expect(result.timestampMs, 42);
    const legacyMeasurements = [
      JointMeasurementType.leftElbow,
      JointMeasurementType.rightElbow,
      JointMeasurementType.leftKnee,
      JointMeasurementType.rightKnee,
      JointMeasurementType.leftShoulderBodyAngle,
      JointMeasurementType.rightShoulderBodyAngle,
      JointMeasurementType.leftHipBodyAngle,
      JointMeasurementType.rightHipBodyAngle,
    ];
    for (final type in legacyMeasurements) {
      expect(result[type], closeTo(90, 1e-9), reason: type.name);
    }
  });

  test('normalized or preview coordinates never substitute for absent world',
      () {
    final world = fullFrame().worldLandmarks;
    final result = calculator.calculate(PoseFrame(
      timestampMs: 1,
      landmarks: world,
    ));
    expect(result.angles.values, everyElement(isNull));
  });

  test('display mirror and normalized changes cannot change world angle', () {
    final original = fullFrame();
    final mirrored = PoseFrame(
      timestampMs: original.timestampMs,
      worldLandmarks: original.worldLandmarks,
      landmarks: {
        for (final entry in original.worldLandmarks.entries)
          entry.key: point(1 - entry.value.x, entry.value.y * 2),
      },
      geometry: PoseGeometry(
        imageWidth: 480,
        imageHeight: 640,
        rotationDegrees: 90,
        mirrored: true,
        previewWidth: 1080,
        previewHeight: 1920,
        matrix: [-1, 0, 1, 0, 1, 0, 0, 0, 1],
        revision: 1,
      ),
    );
    expect(calculator.calculate(mirrored).angles,
        calculator.calculate(original).angles);
  });

  test('partial pose invalidates only angles relying on unavailable landmarks',
      () {
    final points = Map<PoseLandmarkType, PoseLandmark>.of(
      fullFrame().worldLandmarks,
    )..remove(PoseLandmarkType.leftWrist);
    final result = calculator.calculate(PoseFrame(
      timestampMs: 2,
      worldLandmarks: points,
    ));
    expect(result[JointMeasurementType.leftElbow], isNull);
    expect(result[JointMeasurementType.rightElbow], closeTo(90, 1e-9));
    expect(result[JointMeasurementType.leftKnee], closeTo(90, 1e-9));
  });

  test('geometric shoulder and hip labels do not claim clinical motion axes',
      () {
    expect(JointMeasurementType.leftShoulderBodyAngle.label, '左肩軀幹角');
    expect(JointMeasurementType.rightHipBodyAngle.label, '右髖軀幹角');
  });
}

PoseLandmark point(double x, double y,
        {double z = 0, double? visibility = 0.9, double? presence = 0.9}) =>
    PoseLandmark(
      x: x,
      y: y,
      z: z,
      visibility: visibility,
      presence: presence,
    );

PoseFrame fullFrame() => PoseFrame(timestampMs: 42, worldLandmarks: {
      PoseLandmarkType.leftShoulder: point(-1, 0),
      PoseLandmarkType.leftElbow: point(-2, 0),
      PoseLandmarkType.leftWrist: point(-2, 1),
      PoseLandmarkType.leftHip: point(-1, 1),
      PoseLandmarkType.leftKnee: point(-2, 1),
      PoseLandmarkType.leftAnkle: point(-2, 2),
      PoseLandmarkType.rightShoulder: point(1, 0),
      PoseLandmarkType.rightElbow: point(2, 0),
      PoseLandmarkType.rightWrist: point(2, 1),
      PoseLandmarkType.rightHip: point(1, 1),
      PoseLandmarkType.rightKnee: point(2, 1),
      PoseLandmarkType.rightAnkle: point(2, 2),
    });

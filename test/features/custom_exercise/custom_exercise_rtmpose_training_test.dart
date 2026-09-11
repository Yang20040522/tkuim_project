import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_body/features/custom_exercise/custom_exercise_playback_page.dart';
import 'package:flutter_body/features/custom_exercise/custom_exercise_training_page.dart';
import 'package:flutter_body/features/custom_exercise/training/custom_exercise_pose_evaluator.dart';
import 'package:flutter_body/features/custom_exercise/training/custom_exercise_pose_features.dart';
import 'package:flutter_body/features/custom_exercise/training/custom_exercise_pose_reference.dart';
import 'package:flutter_body/features/custom_exercise/training/custom_exercise_pose_source.dart';
import 'package:flutter_body/features/custom_exercise/training/custom_exercise_training_controller.dart';
import 'package:flutter_body/features/pose_measurement/repositories/training_result_repository.dart';
import 'package:flutter_body/models/custom_rehab_exercise.dart';
import 'package:flutter_body/models/evaluation_rule.dart';
import 'package:flutter_body/models/exercise_keyframe.dart';
import 'package:flutter_body/models/joint_rotation.dart';
import 'package:flutter_body/models/joint_type.dart';
import 'package:flutter_body/models/pose_data.dart';
import 'package:flutter_body/models/training_session_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CUSTOM pose evaluator', () {
    final reference = CustomExercisePoseReference(
      keyframeId: 'target',
      keyframeIndex: 0,
      features: CustomPoseFeatures(values: const {
        CustomPoseFeatureType.rightUpperArmDirection: 20,
        CustomPoseFeatureType.rightElbowFlexion: 35,
      }),
      activeFeatures: const {
        CustomPoseFeatureType.rightUpperArmDirection,
        CustomPoseFeatureType.rightElbowFlexion,
      },
    );
    const evaluator = CustomExercisePoseEvaluator();

    test('exact and small deviations match while a large elbow error does not',
        () {
      final exact = evaluator.evaluate(reference, reference.features);
      final small = evaluator.evaluate(
        reference,
        CustomPoseFeatures(values: const {
          CustomPoseFeatureType.rightUpperArmDirection: 25,
          CustomPoseFeatureType.rightElbowFlexion: 40,
        }),
      );
      final large = evaluator.evaluate(
        reference,
        CustomPoseFeatures(values: const {
          CustomPoseFeatureType.rightUpperArmDirection: 20,
          CustomPoseFeatureType.rightElbowFlexion: 90,
        }),
      );

      expect(exact.score, 100);
      expect(exact.isMatched, isTrue);
      expect(small.isMatched, isTrue);
      expect(large.isMatched, isFalse);
      expect(large.feedback, contains('右手肘'));
    });

    test('missing, NaN and infinite inputs are unavailable without crashing',
        () {
      final unavailable = evaluator.evaluate(
        reference,
        CustomPoseFeatures(
          values: const {
            CustomPoseFeatureType.rightUpperArmDirection: double.nan,
            CustomPoseFeatureType.rightElbowFlexion: double.infinity,
          },
          unavailableJoints: const {JointType.rightElbow},
        ),
      );
      expect(unavailable.isAvailable, isFalse);
      expect(unavailable.isMatched, isFalse);
      expect(unavailable.feedback, contains('右手肘'));
    });

    test('anatomical indices survive visual mirroring without a second swap',
        () {
      const extractor = CustomPoseFeatureExtractor();
      final original = extractor.fromPoseData(_bodyPose());
      final mirrored = extractor.fromPoseData(_bodyPose(mirrored: true));

      for (final type in original.values.keys) {
        if (mirrored[type] != null) {
          expect(mirrored[type], closeTo(original[type]!, 1e-8),
              reason: '$type');
        }
      }
      expect(
        original[CustomPoseFeatureType.leftElbowFlexion],
        isNot(equals(original[CustomPoseFeatureType.rightElbowFlexion])),
      );
    });

    test('low-confidence required landmark is excluded safely', () {
      final pose = _bodyPose(lowConfidenceIndex: 10);
      final live = const CustomPoseFeatureExtractor().fromPoseData(pose);
      final result = evaluator.evaluate(reference, live);
      expect(live.unavailableJoints, contains(JointType.rightWrist));
      expect(result.isMatched, isFalse);
    });
  });

  group('CUSTOM keyframe training', () {
    test('wrong pose and one noisy matching frame do not advance', () {
      final fixture = _fixture();
      final controller = fixture.controller;
      controller.markReady();
      final refs =
          const CustomExercisePoseReferenceBuilder().build(fixture.exercise);
      final wrong = CustomPoseFeatures(values: const {});

      controller.processFeatures(wrong, Duration.zero);
      controller.processFeatures(
          refs.first.features, const Duration(milliseconds: 100));
      expect(controller.snapshot.currentKeyframeIndex, 0);
      controller.processFeatures(wrong, const Duration(milliseconds: 200));
      expect(controller.snapshot.currentKeyframeIndex, 0);
    });

    test('stable ordered keyframes complete one rep and never double count',
        () {
      final fixture = _fixture(holdSeconds: 0.5);
      final controller = fixture.controller..markReady();
      final refs =
          const CustomExercisePoseReferenceBuilder().build(fixture.exercise);

      _stablyMatch(controller, refs[0].features, 0);
      expect(controller.snapshot.currentKeyframeIndex, 1);
      _stablyMatch(controller, refs[1].features, 400);
      controller.processFeatures(
          refs[1].features, const Duration(milliseconds: 1250));
      expect(controller.snapshot.completedReps, 1);

      controller.processFeatures(
          refs[1].features, const Duration(milliseconds: 1800));
      expect(controller.snapshot.completedReps, 1);
    });

    test('release, rest, repetitions and sets follow saved settings', () {
      final fixture = _fixture(
        repetitions: 1,
        sets: 2,
        holdSeconds: 0.5,
        restSeconds: 0.2,
      );
      final controller = fixture.controller..markReady();
      final refs =
          const CustomExercisePoseReferenceBuilder().build(fixture.exercise);

      _completeRep(controller, refs, startMs: 0);
      expect(controller.snapshot.completedReps, 1);
      expect(controller.snapshot.phase, CustomExerciseTrainingPhase.resting);

      controller.processFeatures(
          refs[0].features, const Duration(milliseconds: 1500));
      _stablyMatch(controller, refs[0].features, 1600);
      _stablyMatch(controller, refs[1].features, 2000);
      controller.processFeatures(
          refs[1].features, const Duration(milliseconds: 2850));

      expect(controller.snapshot.currentSet, 2);
      expect(controller.snapshot.completedReps, 2);
      expect(controller.snapshot.phase, CustomExerciseTrainingPhase.completed);
      expect(fixture.repository.saved, hasLength(1));
    });

    test('hold duration is enforced and camera switch cannot increment a rep',
        () {
      final fixture = _fixture(holdSeconds: 1);
      final controller = fixture.controller..markReady();
      final refs =
          const CustomExercisePoseReferenceBuilder().build(fixture.exercise);
      _stablyMatch(controller, refs[0].features, 0);
      _stablyMatch(controller, refs[1].features, 400);
      controller.processFeatures(
          refs[1].features, const Duration(milliseconds: 1200));
      expect(controller.snapshot.completedReps, 0);

      controller.beginCameraSwitch();
      controller.processFeatures(
          refs[1].features, const Duration(milliseconds: 3000));
      expect(controller.snapshot.completedReps, 0);
      expect(controller.snapshot.currentKeyframeIndex, 1);
      controller.finishCameraSwitch(success: true);
    });
  });

  testWidgets('playback starts RTMPose CUSTOM page instead of PoseTrainingPage',
      (tester) async {
    final exercise = _exercise();
    final source = _FakePoseSource();
    final repository = _FakeResultRepository();
    await tester.pumpWidget(MaterialApp(
      home: CustomExercisePlaybackPage(
        exercise: exercise,
        trainingBuilder: (_, custom) => CustomExerciseTrainingPage(
          exercise: custom,
          poseSource: source,
          resultRepository: repository,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('start-custom-pose-training'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CustomExerciseTrainingPage), findsOneWidget);
    expect(
        find.byKey(const Key('custom-training-switch-camera')), findsOneWidget);
  });

  testWidgets(
      'camera switch preserves progress, pauses evaluation and disposes',
      (tester) async {
    final exercise = _exercise();
    final source = _FakePoseSource(blockSwitch: true);
    final repository = _FakeResultRepository();
    final controller = CustomExerciseTrainingController(
      exercise: exercise,
      repository: repository,
    );
    await tester.pumpWidget(MaterialApp(
      home: CustomExerciseTrainingPage(
        exercise: exercise,
        poseSource: source,
        trainingController: controller,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final refs = const CustomExercisePoseReferenceBuilder().build(exercise);
    _stablyMatch(controller, refs.first.features, 0);
    final before = controller.snapshot;

    await tester.tap(find.byKey(const Key('custom-training-switch-camera')));
    await tester.pump();
    expect(source.switchCalls, 1);
    expect(
      controller.snapshot.phase,
      CustomExerciseTrainingPhase.switchingCamera,
    );
    source.emit(_bodyPose());
    await tester.pump();
    expect(controller.snapshot.completedReps, before.completedReps);
    expect(
        controller.snapshot.currentKeyframeIndex, before.currentKeyframeIndex);

    source.completeSwitch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(source.isFrontCamera, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(source.disposed, isTrue);
  });
}

void _stablyMatch(
  CustomExerciseTrainingController controller,
  CustomPoseFeatures features,
  int startMs,
) {
  controller.processFeatures(features, Duration(milliseconds: startMs));
  controller.processFeatures(features, Duration(milliseconds: startMs + 350));
}

void _completeRep(
  CustomExerciseTrainingController controller,
  List<CustomExercisePoseReference> references, {
  required int startMs,
}) {
  _stablyMatch(controller, references[0].features, startMs);
  _stablyMatch(controller, references[1].features, startMs + 400);
  controller.processFeatures(
      references[1].features, Duration(milliseconds: startMs + 1250));
}

PoseData _bodyPose({bool mirrored = false, int? lowConfidenceIndex}) {
  final points = List<Offset>.filled(133, const Offset(.5, .5));
  final scores = List<double>.filled(133, 1);
  void put(int index, double x, double y) {
    points[index] = Offset(mirrored ? 1 - x : x, y);
  }

  put(5, .62, .28);
  put(6, .38, .28);
  put(7, .70, .46);
  put(8, .31, .45);
  put(9, .78, .60);
  put(10, .28, .35);
  put(11, .57, .56);
  put(12, .43, .56);
  put(13, .58, .75);
  put(14, .42, .73);
  put(15, .59, .94);
  put(16, .43, .91);
  put(91, .78, .60);
  put(100, .83, .66);
  put(112, .28, .35);
  put(121, .23, .30);
  if (lowConfidenceIndex != null) scores[lowConfidenceIndex] = 0;
  return PoseData(points, scores);
}

({
  CustomRehabExercise exercise,
  CustomExerciseTrainingController controller,
  _FakeResultRepository repository,
}) _fixture({
  int repetitions = 2,
  int sets = 1,
  double holdSeconds = 0.5,
  double restSeconds = 0,
}) {
  final exercise = _exercise(
    repetitions: repetitions,
    sets: sets,
    holdSeconds: holdSeconds,
    restSeconds: restSeconds,
  );
  final repository = _FakeResultRepository();
  return (
    exercise: exercise,
    controller: CustomExerciseTrainingController(
      exercise: exercise,
      repository: repository,
      sessionIdFactory: () => '00000000-0000-4000-8000-000000000001',
    ),
    repository: repository,
  );
}

CustomRehabExercise _exercise({
  int repetitions = 2,
  int sets = 1,
  double holdSeconds = 0.5,
  double restSeconds = 0,
}) {
  final now = DateTime.utc(2026, 9, 11);
  return CustomRehabExercise(
    id: 'custom-rtmpose',
    name: 'RTMPose 自訂訓練',
    description: '',
    createdAt: now,
    updatedAt: now,
    repetitions: repetitions,
    sets: sets,
    holdSeconds: holdSeconds,
    restSeconds: restSeconds,
    duration: 1,
    keyframes: [
      ExerciseKeyframe(
        id: 'k0',
        time: 0,
        jointRotations: const {},
      ),
      ExerciseKeyframe(
        id: 'k1',
        time: 1,
        jointRotations: const {
          JointType.rightShoulder: JointRotation(z: 65),
          JointType.rightElbow: JointRotation(z: 55),
        },
      ),
    ],
    evaluationRules: const <EvaluationRule>[],
  );
}

class _FakeResultRepository implements TrainingResultRepository {
  final List<TrainingSessionResult> saved = [];

  @override
  Future<TrainingSessionResult> save(TrainingSessionResult result) async {
    saved.add(result);
    return result;
  }

  @override
  Future<List<TrainingSessionResult>> getMyResults() async => const [];

  @override
  Future<List<TrainingSessionResult>> getPatientResults(
          String patientId) async =>
      const [];
}

class _FakePoseSource implements CustomExercisePoseSource {
  _FakePoseSource({this.blockSwitch = false});

  final bool blockSwitch;
  final ValueNotifier<PoseData> _pose = ValueNotifier(PoseData.empty());
  final ValueNotifier<bool> _ready = ValueNotifier(false);
  Completer<void>? _switchCompleter;
  bool disposed = false;
  int switchCalls = 0;

  @override
  ValueListenable<PoseData> get pose => _pose;

  @override
  ValueListenable<bool> get cameraReady => _ready;

  @override
  CameraController? get cameraController => null;

  @override
  bool isFrontCamera = true;

  @override
  Future<void> initialize() async => _ready.value = true;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> switchCamera() async {
    switchCalls++;
    if (blockSwitch) {
      _switchCompleter = Completer<void>();
      await _switchCompleter!.future;
    }
    isFrontCamera = !isFrontCamera;
  }

  void completeSwitch() => _switchCompleter?.complete();

  void emit(PoseData value) => _pose.value = value;

  @override
  Future<void> dispose() async {
    disposed = true;
    _pose.dispose();
    _ready.dispose();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_body/features/custom_exercise/patient_assigned_exercise_list_page.dart';
import 'package:flutter_body/features/custom_exercise/repositories/unified_exercise_assignment_repository.dart';
import 'package:flutter_body/features/pose_measurement/pose_camera_controller.dart';
import 'package:flutter_body/features/pose_measurement/pose_detector_platform.dart';
import 'package:flutter_body/features/pose_measurement/pose_training_page.dart';
import 'package:flutter_body/models/assignable_exercise.dart';
import 'package:flutter_body/models/custom_exercise_assignment.dart';
import 'package:flutter_body/models/custom_rehab_exercise.dart';
import 'package:flutter_test/flutter_test.dart';

const _exercise = AssignableExercise(
  id: '1',
  name: '測試動作',
  description: '',
  type: AssignableExerciseType.defaultExercise,
  assigned: true,
);

void main() {
  testWidgets('shows states and world angles without recreating preview',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final platform = _Platform();
    var previewBuilds = 0;
    await tester.pumpWidget(MaterialApp(
      home: PoseTrainingPage(
        exercise: _exercise,
        controller: _controller(platform),
        previewBuilder: (_, onCreated) {
          previewBuilds++;
          return _Preview(onCreated: onCreated);
        },
      ),
    ));
    await tester.pumpAndSettle();
    final initialBuilds = previewBuilds;
    expect(platform.starts, 1);
    platform.emit({'type': 'state', 'state': 'loadingModel'});
    await tester.pump();
    expect(find.text('正在載入人體姿勢模型…'), findsOneWidget);
    platform.emit(_frame(hasPose: false));
    await tester.pump();
    expect(find.textContaining('尚未偵測到人體'), findsOneWidget);
    platform.emit(_frame());
    await tester.pump();
    expect(find.text('已偵測到人體'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('pose-angle-leftElbow'))).data,
      contains('90°'),
    );
    platform.emit(_frame(reliable: false));
    await tester.pump();
    expect(find.text('已偵測到人體'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('pose-angle-leftElbow'))).data,
      contains('--'),
    );
    expect(previewBuilds, initialBuilds);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(platform.stops, greaterThan(0));
    await platform.close();
  });

  testWidgets('background and route coverage stop; return resumes pipeline',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final platform = _Platform();
    await tester.pumpWidget(MaterialApp(
      home: PoseTrainingPage(
        exercise: _exercise,
        controller: _controller(platform),
        previewBuilder: (_, onCreated) => _Preview(onCreated: onCreated),
      ),
    ));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(platform.stops, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(platform.starts, 2);
    final navigator =
        Navigator.of(tester.element(find.byType(PoseTrainingPage)));
    unawaited(navigator.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('覆蓋頁面')),
    )));
    await tester.pumpAndSettle();
    expect(platform.stops, 2);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(platform.starts, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(platform.stops, 3);
    await platform.close();
  });

  testWidgets('denied permission is actionable without opening camera',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final platform = _Platform();
    await tester.pumpWidget(MaterialApp(
      home: PoseTrainingPage(
        exercise: _exercise,
        controller: PoseCameraController(
          platformFactory: (_) => platform,
          requestPermission: () async => PoseCameraPermission.permanentlyDenied,
        ),
        previewBuilder: (_, onCreated) => _Preview(onCreated: onCreated),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('開啟系統設定'), findsOneWidget);
    expect(platform.starts, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await platform.close();
  });

  testWidgets('landscape and enlarged text leave camera and scrollable readout',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize = const Size(680, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final platform = _Platform();
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data:
            MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.8)),
        child: child!,
      ),
      home: PoseTrainingPage(
        exercise: _exercise,
        controller: _controller(platform),
        previewBuilder: (_, onCreated) => _Preview(onCreated: onCreated),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(_Preview)).height, greaterThan(40));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await platform.close();
  });

  testWidgets(
      'both exercise types have independent measurement entry and guard',
      (tester) async {
    final repository = _Repository();
    final destinations = <AssignableExercise>[];
    await tester.pumpWidget(MaterialApp(
      home: PatientAssignedExerciseListPage(
        repository: repository,
        poseMeasurementBuilder: (exercise) {
          destinations.add(exercise);
          return Scaffold(body: Text('量測 ${exercise.identityKey}'));
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('姿勢量測'), findsNWidgets(2));
    final firstButton = tester.widget<TextButton>(
      find.byKey(const Key('patient-pose-measurement-DEFAULT:1')),
    );
    firstButton.onPressed!();
    firstButton.onPressed!();
    await tester.pumpAndSettle();
    expect(destinations.length, 1);
    expect(destinations.first, same(repository.exercises.first));
    Navigator.of(tester.element(find.text('量測 DEFAULT:1'))).pop();
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const Key('patient-pose-measurement-CUSTOM:2')));
    await tester.pumpAndSettle();
    expect(find.text('量測 CUSTOM:2'), findsOneWidget);
    expect(repository.detailReads, 0);
    expect(destinations.last, same(repository.exercises.last));
  });
}

PoseCameraController _controller(_Platform platform) => PoseCameraController(
      platformFactory: (_) => platform,
      requestPermission: () async => PoseCameraPermission.granted,
    );

Map<String, dynamic> _frame({bool hasPose = true, bool reliable = true}) {
  final landmarks = hasPose
      ? List.generate(
          33,
          (_) => <String, double>{
                'x': .5,
                'y': .5,
                'z': 0,
                'visibility': reliable ? 1 : .1,
                'presence': reliable ? 1 : .1,
              })
      : <Map<String, double>>[];
  final world = landmarks.map((item) => {...item}).toList();
  if (hasPose) {
    world[11].addAll({'x': 1, 'y': 0, 'z': 0});
    world[13].addAll({'x': 0, 'y': 0, 'z': 0});
    world[15].addAll({'x': 0, 'y': 1, 'z': 0});
  }
  return {
    'type': 'frame',
    'timestampMs': 200,
    'landmarks': landmarks,
    'worldLandmarks': world,
    'inferenceMs': 12.0,
  };
}

class _Preview extends StatefulWidget {
  const _Preview({required this.onCreated});
  final ValueChanged<int> onCreated;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCreated(1);
    });
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}

class _Platform implements PoseDetectorPlatform {
  final _events = StreamController<Map<dynamic, dynamic>>.broadcast(sync: true);
  int starts = 0;
  int stops = 0;
  void emit(Map<dynamic, dynamic> event) => _events.add(event);
  Future<void> close() => _events.close();

  @override
  Stream<Map<dynamic, dynamic>> get events => _events.stream;
  @override
  Future<void> start() async => starts++;
  @override
  Future<void> stop() async => stops++;
}

class _Repository implements UnifiedExerciseAssignmentRepository {
  final exercises = const [
    _exercise,
    AssignableExercise(
      id: '2',
      name: '自訂動作',
      description: '自訂',
      type: AssignableExerciseType.custom,
      assigned: true,
    ),
  ];
  int detailReads = 0;

  @override
  Future<List<AssignableExercise>> getPatientAssignedExercises() async =>
      exercises;

  @override
  Future<CustomRehabExercise?> getPatientCustomExercise(
      String exerciseId) async {
    detailReads++;
    return null;
  }

  @override
  Future<List<AssignablePatient>> getAssignablePatients() async => [];
  @override
  Future<List<AssignableExercise>> getAssignableExercises(
          String patientId) async =>
      [];
  @override
  Future<AssignableExercise> assign(
    AssignableExercise exercise,
    String patientId,
  ) async =>
      exercise;
  @override
  Future<void> unassign(AssignableExercise exercise, String patientId) async {}
}

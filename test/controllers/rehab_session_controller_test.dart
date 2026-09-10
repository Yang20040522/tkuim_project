import 'dart:async';

import 'package:flutter_body/controllers/rehab_session_controller.dart';
import 'package:flutter_body/models/training_action.dart';
import 'package:flutter_body/services/mediapipe_service.dart';
import 'package:flutter_body/services/pose_model_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('level transition clears the previous level mistake snapshot', () {
    final action = kTrainingActions.first;
    final controller = RehabSessionController(
      model: _FakePoseModel(),
      action: action,
      difficulty: action.difficulties.first,
    );

    controller.onTrainingComplete(
      repCount: 3,
      durationSeconds: 8,
      mistakeLogs: const ['上一階錯誤'],
    );
    expect(controller.currentState.mistakeLogs, ['上一階錯誤']);

    controller.onLevelUp(
      newLevel: 2,
      levelLabel: 'Level 2',
      newTargetReps: 8,
    );
    expect(controller.currentState.mistakeLogs, isEmpty);
    expect(controller.currentState.repCount, 0);

    controller.dispose();
  });
}

class _FakePoseModel implements IPoseModel {
  final _frames = StreamController<PoseFrame>.broadcast();
  final _training = StreamController<TrainingUpdate>.broadcast();

  @override
  void dispose() {
    _frames.close();
    _training.close();
  }

  @override
  Future<void> flipCamera() async {}

  @override
  Stream<PoseFrame> get frameStream => _frames.stream;

  @override
  Future<void> start(PoseModelConfig config) async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<TrainingUpdate> get trainingStream => _training.stream;
}

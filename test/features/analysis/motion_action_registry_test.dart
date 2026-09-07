import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_body/features/analysis/models/motion_action_registry.dart';
import 'package:flutter_body/models/training_action.dart';

void main() {
  test('every registered TrainingAction has one stable unique actionId', () {
    final actionIds = <String>{};
    for (final action in kTrainingActions) {
      final capability = MotionActionRegistry.forActionType(action.type);
      expect(capability.displayName, action.name);
      expect(actionIds.add(capability.actionId), isTrue);
    }
  });

  test('legacy standing knee raise aliases resolve to the canonical id', () {
    for (final alias in [
      'standing_knee_raise',
      'wipeBody',
      '站姿抬腳',
      '站姿抬腳式訓練',
    ]) {
      expect(
        MotionActionRegistry.resolve(alias)?.actionId,
        'standing_knee_raise',
      );
    }
  });

  test('registry keeps Body and Hand capabilities separate', () {
    expect(
      MotionActionRegistry.forActionType(ActionType.wipeBody).modelType,
      MotionTemplateModelType.body,
    );
    expect(
      MotionActionRegistry.forActionType(ActionType.turnPalm).modelType,
      MotionTemplateModelType.hand,
    );
    expect(
      MotionActionRegistry.resolve(
        'turnPalm',
        modelType: MotionTemplateModelType.body,
      ),
      isNull,
    );
  });
}

import '../../models/training_action.dart';

const Set<ActionType> kTvUnsupportedActionTypes = {
  ActionType.turnPalm,
  ActionType.sidePinch,
  ActionType.wristExtension,
  ActionType.wristSideBend,
};

bool isTvSupportedTrainingAction(ActionType type) =>
    !kTvUnsupportedActionTypes.contains(type);

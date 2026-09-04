import 'package:flutter/material.dart';

import '../../models/assignable_exercise.dart';
import '../../models/training_action.dart';
import '../training/action_list_screen.dart';

TrainingAction? findTrainingActionForAssignedExercise(String exerciseName) {
  final normalizedName = exerciseName.replaceAll(RegExp(r'\s+'), '');
  for (final action in kTrainingActions) {
    if (action.name.replaceAll(RegExp(r'\s+'), '') == normalizedName) {
      return action;
    }
  }
  return null;
}

class AssignedDefaultExercisePage extends StatelessWidget {
  final AssignableExercise exercise;

  const AssignedDefaultExercisePage({
    super.key,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    final action = findTrainingActionForAssignedExercise(exercise.name);
    if (action != null) {
      return ActionListScreen(initialActionType: action.type);
    }
    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline,
                  size: 48, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 12),
              Text(
                exercise.description.isEmpty
                    ? '此預設動作尚未連結到 App 內的訓練流程。'
                    : exercise.description,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/custom_rehab_exercise.dart';
import 'custom_exercise_repository.dart';

/// 使用專案既有 SharedPreferences 保存完整 exercise JSON。
class LocalCustomExerciseRepository implements CustomExerciseRepository {
  static const storageKey = 'custom_rehab_exercises_v1';

  final Future<SharedPreferences> Function() _preferencesFactory;

  LocalCustomExerciseRepository({
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _preferencesFactory =
            preferencesFactory ?? SharedPreferences.getInstance;

  @override
  Future<void> saveExercise(CustomRehabExercise exercise) async {
    final exercises = await _readExercises();
    final index = exercises.indexWhere((item) => item.id == exercise.id);
    if (index < 0) {
      exercises.add(exercise);
    } else {
      exercises[index] = exercise;
    }
    await _writeExercises(exercises);
  }

  @override
  Future<CustomRehabExercise?> getExercise(String id) async {
    final exercises = await _readExercises();
    for (final exercise in exercises) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  @override
  Future<List<CustomRehabExercise>> getAllExercises() async {
    final exercises = await _readExercises()
      ..sort((a, b) {
        final updatedComparison = b.updatedAt.compareTo(a.updatedAt);
        return updatedComparison != 0
            ? updatedComparison
            : a.id.compareTo(b.id);
      });
    return List.unmodifiable(exercises);
  }

  @override
  Future<void> updateExercise(CustomRehabExercise exercise) =>
      saveExercise(exercise);

  @override
  Future<void> deleteExercise(String id) async {
    final exercises = await _readExercises();
    exercises.removeWhere((item) => item.id == id);
    await _writeExercises(exercises);
  }

  Future<List<CustomRehabExercise>> _readExercises() async {
    final preferences = await _preferencesFactory();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('自訂動作本機資料格式錯誤');
    }

    return decoded.map((item) {
      if (item is! Map) {
        throw const FormatException('自訂動作項目格式錯誤');
      }
      return CustomRehabExercise.fromJson(
        Map<String, dynamic>.from(item),
      );
    }).toList();
  }

  Future<void> _writeExercises(List<CustomRehabExercise> exercises) async {
    final preferences = await _preferencesFactory();
    final raw = jsonEncode(
      exercises.map((exercise) => exercise.toJson()).toList(),
    );
    final didSave = await preferences.setString(storageKey, raw);
    if (!didSave) {
      throw StateError('自訂動作寫入本機儲存失敗');
    }
  }
}

final CustomExerciseRepository customExerciseRepository =
    LocalCustomExerciseRepository();

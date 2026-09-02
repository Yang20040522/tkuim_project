import '../../../models/custom_rehab_exercise.dart';

/// 自訂復健動作的儲存邊界。
///
/// Editor 與清單只依賴這個介面；後續若改接遠端資料庫，不需要改寫
/// Keyframe Editor 的資料處理。
abstract class CustomExerciseRepository {
  /// 依 exercise.id 新增或覆寫既有資料（upsert）。
  Future<void> saveExercise(CustomRehabExercise exercise);

  Future<CustomRehabExercise?> getExercise(String id);

  Future<List<CustomRehabExercise>> getAllExercises();

  /// 明確的更新 API；本機實作與 [saveExercise] 同樣依 ID upsert。
  Future<void> updateExercise(CustomRehabExercise exercise);

  Future<void> deleteExercise(String id);
}

import 'exercise.dart';
import 'plan_api_repository.dart';
import 'rehab_plan.dart';

abstract class PlanRepository {
  Future<RehabPlan?> getPlanByDate({
    required String patientId,
    required DateTime date,
  });
  Future<void> savePlan(RehabPlan plan);
  Future<void> updatePlanItem({
    required String patientId,
    required String planId,
    required PlanItem item,
  });

  /// 骨折專用：系統提供固定範本("差不多模式")，因為骨折時程相對固定(約3個月)
  RehabPlan buildFractureTemplate(
    String patientId,
    String planId,
    DateTime date,
  );

  /// 中風：不提供任何自動推薦邏輯，回傳完整11個動作，
  /// 由治療師依病患個別狀況自己勾選、排序、決定組數
  List<Exercise> allExercisesForManualSelection();
}

/// ============ 現在先用的版本：記憶體暫存(demo用) ============
class InMemoryPlanRepository implements PlanRepository {
  final Map<String, RehabPlan> _cache = {}; // key: patientId|yyyy-MM-dd

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _cacheKey(String patientId, DateTime date) =>
      '$patientId|${_dateKey(date)}';

  @override
  Future<RehabPlan?> getPlanByDate({
    required String patientId,
    required DateTime date,
  }) async {
    return _cache[_cacheKey(patientId, date)];
  }

  @override
  Future<void> savePlan(RehabPlan plan) async {
    _cache[_cacheKey(plan.patientId, plan.date)] = plan;
  }

  @override
  Future<void> updatePlanItem({
    required String patientId,
    required String planId,
    required PlanItem item,
  }) async {
    for (final plan in _cache.values) {
      if (plan.patientId != patientId || plan.planId != planId) continue;
      final index =
          plan.items.indexWhere((i) => i.exerciseId == item.exerciseId);
      if (index != -1) plan.items[index] = item;
      return;
    }
  }

  /// 骨折的固定範本，依漸進邏輯排序(先手部基礎，再進入全身動作)
  /// 這份範本內容之後建議直接請治療師確認/調整，目前是暫定的合理順序
  @override
  RehabPlan buildFractureTemplate(
    String patientId,
    String planId,
    DateTime date,
  ) {
    return RehabPlan(
      patientId: patientId,
      planId: planId,
      createdBy: 'therapist',
      date: date,
      condition: PatientCondition.fracture,
      items: [
        PlanItem(exerciseId: 'ex01', order: 0), // 翻掌訓練
        PlanItem(exerciseId: 'ex03', order: 1), // 翹手腕式
        PlanItem(exerciseId: 'ex04', order: 2), // 左右彎手腕式
        PlanItem(exerciseId: 'ex09', order: 3), // 手肘屈伸訓練
        PlanItem(exerciseId: 'ex07', order: 4), // 雙手抬舉式
      ],
    );
  }

  /// 中風：刻意不做推薦演算法，回傳完整動作庫讓治療師自己選
  @override
  List<Exercise> allExercisesForManualSelection() => exerciseLibrary;
}

String buildPlanId({required String patientId, required DateTime date}) {
  final safePatientId = patientId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final datePart = '${date.year}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
  return 'plan_${safePatientId}_$datePart';
}

/// Production uses the persisted backend implementation. Tests and demos can
/// continue injecting [InMemoryPlanRepository] through the existing widgets.
final PlanRepository planRepository = PlanApiRepository();

/// 訓練完成後呼叫:如果「今天的計畫」裡剛好有這個動作,標記為完成
/// 找不到今天的計畫、或計畫裡沒有這個動作、或已經是完成狀態,就什麼都不做
Future<void> markPlanItemDoneByActionName({
  required String patientId,
  required String actionName,
  PlanRepository? repository,
}) async {
  if (patientId.trim().isEmpty) return;
  final scopedRepository = repository ?? planRepository;
  final plan = await scopedRepository.getPlanByDate(
    patientId: patientId,
    date: DateTime.now(),
  );
  if (plan == null) return;

  Exercise? exercise;
  for (final e in exerciseLibrary) {
    if (e.name == actionName) {
      exercise = e;
      break;
    }
  }
  if (exercise == null) return;

  PlanItem? item;
  for (final i in plan.items) {
    if (i.exerciseId == exercise.id) {
      item = i;
      break;
    }
  }
  if (item == null || item.done) return;

  final updated = PlanItem(
    exerciseId: item.exerciseId,
    order: item.order,
    sets: item.sets,
    repsPerSet: item.repsPerSet,
    done: true, // ✅ 標記完成
  );
  await scopedRepository.updatePlanItem(
    patientId: patientId,
    planId: plan.planId,
    item: updated,
  );
}

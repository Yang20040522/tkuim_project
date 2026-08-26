// lib/features/plan/plan_api_repository.dart
//
// 真正連接後端資料庫的 PlanRepository 實作。
// API 規格對照文件: plan_api_spec.md(給後端組員參考實作用)
//
// 使用方式:
//   之前 plan_repository.dart 最下面是:
//     final PlanRepository planRepository = InMemoryPlanRepository();
//   等後端把對應的 API 做好之後,把上面那行換成:
//     final PlanRepository planRepository = PlanApiRepository();
//   plan_screen.dart / plan_builder_screen.dart 完全不用改,
//   因為畫面都是透過 PlanRepository 這個抽象介面在操作。
//
// 目前後端尚未提供這組 API,在後端做好之前,呼叫這裡的方法會直接連線失敗
// (拋出例外),屬於正常現象,不是程式寫錯。

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import 'exercise.dart';
import 'rehab_plan.dart';
import 'plan_repository.dart';

class PlanApiRepository implements PlanRepository {
  static String get _baseUrl => ApiConfig.baseUrl;

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 依日期查詢計畫。
  /// 對應後端: GET /api/plans?date=yyyy-MM-dd
  /// 找不到該日期的計畫時,後端應回傳 404,這裡會轉換成 null(代表這天還沒有計畫)
  @override
  Future<RehabPlan?> getPlanByDate(DateTime date) async {
    final uri = Uri.parse('$_baseUrl/api/plans')
        .replace(queryParameters: {'date': _dateKey(date)});

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) {
      return null; // 這天還沒有計畫,不是錯誤
    }

    if (response.statusCode != 200) {
      throw Exception('取得計畫失敗(狀態碼 ${response.statusCode})');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return RehabPlan.fromJson(data);
  }

  /// 新增或覆蓋整份計畫。
  /// 對應後端: POST /api/plans
  @override
  Future<void> savePlan(RehabPlan plan) async {
    final uri = Uri.parse('$_baseUrl/api/plans');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(plan.toJson()),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('儲存計畫失敗(狀態碼 ${response.statusCode})');
    }
  }

  /// 更新單一動作項目(例如訓練完成後標記 done)。
  /// 對應後端: PATCH /api/plans/{planId}/items/{exerciseId}
  @override
  Future<void> updatePlanItem(String planId, PlanItem item) async {
    final uri = Uri.parse(
      '$_baseUrl/api/plans/$planId/items/${item.exerciseId}',
    );

    final response = await http
        .patch(
          uri,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(item.toJson()),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('更新動作項目失敗(狀態碼 ${response.statusCode})');
    }
  }

  // ── 以下兩個維持跟 InMemoryPlanRepository 一樣的靜態邏輯 ──
  // 骨折範本、可勾選動作庫都是前端固定資料,不需要打 API

  @override
  RehabPlan buildFractureTemplate(String planId, DateTime date) {
    return RehabPlan(
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

  @override
  List<Exercise> allExercisesForManualSelection() => exerciseLibrary;
}

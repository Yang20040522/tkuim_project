import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../account/app_session.dart';
import 'ml_research_api.dart' show MlResearchException;

/// Immutable identity snapshot; generation also detects A -> B -> A races.
class ResearchOwnerScope {
  static ResearchOwnerScope? captureIfPresent() =>
      AppSession.userId?.trim().isNotEmpty == true
          ? ResearchOwnerScope.capture()
          : null;
  ResearchOwnerScope.capture()
      : userId = AppSession.userId?.trim() ?? '',
        token = AppSession.customExerciseToken?.trim(),
        generation = AppSession.changes.value {
    if (userId.isEmpty) throw const MlResearchException('請先登入，才能管理研究資料。');
  }
  final String userId;
  final String? token;
  final int generation;
  String get storageKey => sha256.convert(utf8.encode(userId)).toString();
  bool get isCurrent =>
      userId == AppSession.userId?.trim() &&
      generation == AppSession.changes.value &&
      token == AppSession.customExerciseToken?.trim();
  void check({bool requireToken = false}) {
    if (!isCurrent || (requireToken && (token == null || token!.isEmpty))) {
      throw const MlResearchException('登入狀態已變更，請重新開啟研究頁面。',
          statusCode: 401, code: 'RESEARCH_AUTH_REQUIRED');
    }
  }
}

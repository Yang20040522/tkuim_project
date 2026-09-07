import 'package:flutter/foundation.dart';

import '../storage/local_motion_template_repository.dart';
import 'body_motion_template.dart';

/// Typed Body view over the shared Phase 1 local JSON storage.
class BodyMotionTemplateRepository {
  BodyMotionTemplateRepository({LocalMotionTemplateRepository? storage})
      : _storage = storage ?? LocalMotionTemplateRepository();

  final LocalMotionTemplateRepository _storage;

  Future<List<BodyMotionTemplate>> loadTemplates() async {
    final jsonTemplates = await _storage.listTemplateJson();
    final templates = <BodyMotionTemplate>[];
    for (final json in jsonTemplates) {
      if ((json['modelType'] ?? BodyMotionTemplate.modelType).toString() !=
          BodyMotionTemplate.modelType) {
        continue;
      }
      try {
        final template = BodyMotionTemplate.fromJson(json);
        if (template.normalizedTrajectory.length >= 2) {
          templates.add(template);
        }
      } catch (error) {
        debugPrint('解析 BodyMotionTemplate 失敗：$error');
      }
    }
    return templates;
  }
}

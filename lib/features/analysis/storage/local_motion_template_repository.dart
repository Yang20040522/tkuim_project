import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

typedef MotionTemplateDirectoryProvider = Future<Directory> Function();

/// Local-only storage shared by template preparation and passive analysis.
///
/// The repository deliberately stores the existing JSON unchanged. It does
/// not add account, backend, database, or synchronization behavior.
class LocalMotionTemplateRepository {
  LocalMotionTemplateRepository({
    MotionTemplateDirectoryProvider? directoryProvider,
  }) : _directoryProvider = directoryProvider ?? _defaultDirectory;

  final MotionTemplateDirectoryProvider _directoryProvider;

  static Future<Directory> _defaultDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/templates');
  }

  Future<File> saveTemplateJson(Map<String, dynamic> templateJson) async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final file = File('${directory.path}/template_$timestamp.json');
    await file.writeAsString(jsonEncode(templateJson));
    return file;
  }

  Future<List<Map<String, dynamic>>> listTemplateJson() async {
    try {
      final directory = await _directoryProvider();
      if (!await directory.exists()) return [];

      final files = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort(
          (left, right) =>
              right.statSync().modified.compareTo(left.statSync().modified),
        );

      final templates = <Map<String, dynamic>>[];
      for (final file in files) {
        try {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is! Map) continue;
          final json = Map<String, dynamic>.from(decoded);
          json['_filePath'] = file.path;
          templates.add(json);
        } catch (error) {
          debugPrint('讀取模板失敗：${file.path} - $error');
        }
      }
      return templates;
    } catch (error) {
      debugPrint('列出模板失敗：$error');
      return [];
    }
  }

  Future<void> deleteTemplate(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('刪除模板失敗：$error');
    }
  }
}

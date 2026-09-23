import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'standing_knee_raise_sample.dart';

typedef MlSampleDirectoryProvider = Future<Directory> Function();

/// Explicitly local research storage; no account IDs, images or network calls.
class MlSampleRepository {
  MlSampleRepository({MlSampleDirectoryProvider? directoryProvider})
      : _directoryProvider = directoryProvider ?? _defaultDirectory;

  final MlSampleDirectoryProvider _directoryProvider;

  static Future<Directory> _defaultDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/rehab_ml_samples');
  }

  Future<File> save(StandingKneeRaiseSample sample) async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final file = File('${directory.path}/${sample.id}.json');
    await file.writeAsString(jsonEncode(sample.toJson()), flush: true);
    return file;
  }

  Future<List<Map<String, dynamic>>> list() async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) return [];
    final result = <Map<String, dynamic>>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final value = jsonDecode(await entity.readAsString());
      if (value is Map<String, dynamic> &&
          value['actionId'] == StandingKneeRaiseSample.actionId) {
        result.add(value);
      }
    }
    result.sort((a, b) =>
        (b['capturedAt'] as String).compareTo(a['capturedAt'] as String));
    return result;
  }

  Future<void> delete(String sampleId) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(sampleId)) {
      throw const FormatException('Invalid sample ID');
    }
    final directory = await _directoryProvider();
    final file = File('${directory.path}/$sampleId.json');
    if (await file.exists()) await file.delete();
  }

  /// Returns validated JSON bytes for explicit user-directed export.
  Future<List<int>> exportJson(String sampleId) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(sampleId)) {
      throw const FormatException('Invalid sample ID');
    }
    final directory = await _directoryProvider();
    return File('${directory.path}/$sampleId.json').readAsBytes();
  }
}

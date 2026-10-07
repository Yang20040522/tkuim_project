import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'ml_action_definition.dart';
import 'research_owner_scope.dart';
import 'body_research_sample.dart';
import 'body_review_rep_collector.dart';

typedef MlSampleDirectoryProvider = Future<Directory> Function();

/// Owner-bound local research storage. Never stores tokens or camera images.
class MlSampleRepository {
  MlSampleRepository(
      {MlSampleDirectoryProvider? directoryProvider, MlActionRegistry? actions})
      : _directoryProvider = directoryProvider ?? _defaultDirectory,
        _actions = actions ?? MlActionRegistry.production,
        _owner = ResearchOwnerScope.captureIfPresent();

  final MlSampleDirectoryProvider _directoryProvider;
  final MlActionRegistry _actions;
  ResearchOwnerScope? _owner;
  ResearchOwnerScope get owner => _owner ??= ResearchOwnerScope.capture();
  // Serialize saves across repository instances so a duplicate ID cannot race
  // the existence check and overwrite a different payload in this isolate.
  static Future<void> _writes = Future<void>.value();

  Future<Directory> _ownedDirectory() async {
    final scope = owner;
    scope.check();
    final root = await _directoryProvider();
    scope.check();
    // Unowned legacy files at root are quarantined in place, never reassigned.
    return Directory('${root.path}/owners/${scope.storageKey}');
  }

  static Future<Directory> _defaultDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/rehab_ml_samples');
  }

  Future<File> save(MlResearchSample sample) async {
    final payload = sample.toJson();
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(sample.id) ||
        payload['sampleId'] != sample.id ||
        _actions.forSample(Map<String, dynamic>.from(payload)) == null) {
      throw const FormatException('Unsupported research action contract');
    }
    final scope = owner;
    scope.check();
    final result = _writes.then((_) => _save(sample));
    _writes = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<File> _save(MlResearchSample sample) async {
    final payload = sample.toJson();
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(sample.id) ||
        payload['sampleId'] != sample.id ||
        _actions.forSample(Map<String, dynamic>.from(payload)) == null) {
      throw const FormatException('Unsupported research action contract');
    }
    final directory = await _ownedDirectory();
    await directory.create(recursive: true);
    owner.check();
    final file = File('${directory.path}/${sample.id}.json');
    final envelope =
        jsonEncode({'ownerKey': owner.storageKey, 'sample': payload});
    if (sample is BodyResearchSample &&
        (sample.context.ownerId != owner.userId ||
            sample.context.accountGeneration != owner.generation)) {
      throw const FormatException('Research sample owner changed');
    }
    if (sample is BodyReviewSample &&
        (sample.context.ownerId != owner.userId ||
            sample.context.accountGeneration != owner.generation)) {
      throw const FormatException('Research sample owner changed');
    }
    if (await file.exists()) {
      owner.check();
      if (await file.readAsString() != envelope) {
        throw const FormatException('Research sample ID conflict');
      }
      owner.check();
      return file;
    }
    owner.check();
    await file.writeAsString(envelope, flush: true);
    owner.check();
    return file;
  }

  Future<List<Map<String, dynamic>>> list() async {
    final directory = await _ownedDirectory();
    if (!await directory.exists()) return [];
    final result = <Map<String, dynamic>>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final dynamic envelope;
      try {
        envelope = jsonDecode(await entity.readAsString());
      } on FormatException {
        continue;
      }
      owner.check();
      if (envelope is! Map || envelope['ownerKey'] != owner.storageKey) {
        continue;
      }
      final value = envelope['sample'];
      if (value is Map<String, dynamic> && _actions.forSample(value) != null) {
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
    final directory = await _ownedDirectory();
    final file = File('${directory.path}/$sampleId.json');
    if (await file.exists()) {
      owner.check();
      await file.delete();
      owner.check();
    }
  }

  /// Returns validated JSON bytes for explicit user-directed export.
  Future<List<int>> exportJson(String sampleId) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(sampleId)) {
      throw const FormatException('Invalid sample ID');
    }
    final directory = await _ownedDirectory();
    final envelope = jsonDecode(
        await File('${directory.path}/$sampleId.json').readAsString());
    owner.check();
    if (envelope is! Map ||
        envelope['ownerKey'] != owner.storageKey ||
        envelope['sample'] is! Map<String, dynamic> ||
        _actions.forSample(envelope['sample'] as Map<String, dynamic>) ==
            null) {
      throw const FormatException('Unowned or invalid research sample');
    }
    return utf8.encode(jsonEncode(envelope['sample']));
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'ml_action_definition.dart';
import 'ml_quality_evaluator.dart';
import 'onnx_ml_quality_evaluator.dart';
import 'body_ml_contract.dart';

/// Controlled local tooling only, no patient-facing approval toggle or OTA.
/// Integrity is not a source signature. Requires a trusted app-private directory.
class LocalMlModelStore {
  LocalMlModelStore({Future<Directory> Function()? directoryProvider})
      : _directory = directoryProvider ?? _defaultDirectory;
  final Future<Directory> Function() _directory;
  Future<void> _tail = Future.value();
  static Future<Directory> _defaultDirectory() async => Directory(
      '${(await getApplicationDocumentsDirectory()).path}/rehab_ml_models');
  String _safe(String value) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(value)) {
      throw const FormatException('模型識別碼無效');
    }
    return value;
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<Map<String, dynamic>> _index(Directory dir) async {
    final f = File('${dir.path}/index.json');
    return await f.exists()
        ? Map<String, dynamic>.from(jsonDecode(await f.readAsString()) as Map)
        : {};
  }

  Future<void> _saveIndex(Directory dir, Map<String, dynamic> index) async {
    final temporary = File('${dir.path}/index.json.tmp');
    await temporary.writeAsString(jsonEncode(index), flush: true);
    await temporary.rename('${dir.path}/index.json');
  }

  void _record(Map<String, dynamic> entry, String operation, String? version) {
    final events = List<Object>.from(entry['events'] as List? ?? []);
    events.add({
      'operation': operation,
      'version': version,
      'at': DateTime.now().toUtc().toIso8601String()
    });
    // Small local operation history, not a clinical/governance audit service.
    entry['events'] =
        events.skip(events.length > 100 ? events.length - 100 : 0).toList();
  }

  Future<Directory> _candidate(
          Directory dir, MlActionDefinition a, String version) async =>
      Directory('${dir.path}/${_safe(a.actionId)}/${_safe(version)}');
  Future<String> register(MlActionDefinition action,
          Map<String, dynamic> manifest, Uint8List bytes) =>
      _serial(() async {
        final validated = MlModelManifest.validate(manifest, bytes,
            definition: action, requireApproval: false);
        final dir = await _directory(),
            candidate = await _candidate(dir, action, validated.version);
        if (await candidate.exists()) {
          throw const FormatException('模型版本已登錄，不能覆寫');
        }
        await candidate.create(recursive: true);
        await File('${candidate.path}/model.onnx')
            .writeAsBytes(bytes, flush: true);
        await File('${candidate.path}/manifest.json')
            .writeAsString(jsonEncode(manifest), flush: true);
        await File('${candidate.path}/validation.json').writeAsString(
            jsonEncode({
              'status': 'contract_integrity_pass',
              'registeredAt': DateTime.now().toUtc().toIso8601String(),
              'medicalValidation': false
            }),
            flush: true);
        return validated.version;
      });
  bool _approved(Map<String, dynamic> evidence) =>
      evidence['professionalDefinitionsApproved'] == true &&
      evidence['realDataReviewed'] == true &&
      evidence['androidValidated'] == true &&
      ['approvedBy', 'approvedAt', 'approvalReference'].every((k) =>
          evidence[k] is String && (evidence[k] as String).trim().isNotEmpty) &&
      DateTime.tryParse(evidence['approvedAt'] as String) != null;
  Future<void> approveAndActivate(MlActionDefinition action, String version,
          Map<String, dynamic> evidence) =>
      _serial(() async {
        if (!_approved(evidence)) {
          throw const FormatException('缺少正式資料、真機及人工核准證據');
        }
        final dir = await _directory(),
            c = await _candidate(dir, action, version);
        final meta = Map<String, dynamic>.from(
            jsonDecode(await File('${c.path}/manifest.json').readAsString())
                as Map);
        final bytes = await File('${c.path}/model.onnx').readAsBytes();
        MlModelManifest.validate(meta, bytes,
            definition: action, requireApproval: false);
        if (meta['modelVersion'] != version ||
            evidence['modelSha256'] != meta['modelSha256']) {
          throw const FormatException('核准證據與模型不符');
        }
        final index = await _index(dir),
            entry =
                Map<String, dynamic>.from(index[action.actionId] as Map? ?? {});
        final disabled = List<String>.from(entry['disabled'] as List? ?? []);
        if (disabled.contains(version)) {
          throw const FormatException('已停用版本不能重新啟用');
        }
        await File('${c.path}/approval.json')
            .writeAsString(jsonEncode(evidence), flush: true);
        if (entry['active'] != version) {
          entry['previous'] = entry['active'];
        }
        entry['active'] = version;
        entry['disabled'] = disabled;
        _record(entry, 'activate', version);
        index[action.actionId] = entry;
        await _saveIndex(dir, index);
      });
  Future<String?> activeVersion(MlActionDefinition action) async {
    try {
      final index = await _index(await _directory()),
          entry = index[action.actionId] as Map?;
      final id = entry?['active'];
      return id is String && !(entry?['disabled'] as List? ?? []).contains(id)
          ? _safe(id)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> disable(MlActionDefinition action) => _serial(() async {
        final dir = await _directory(),
            index = await _index(dir),
            entry =
                Map<String, dynamic>.from(index[action.actionId] as Map? ?? {});
        final disabled = List<String>.from(entry['disabled'] as List? ?? []);
        if (entry['active'] is String && !disabled.contains(entry['active'])) {
          disabled.add(entry['active'] as String);
        }
        entry['disabled'] = disabled;
        _record(entry, 'disable', entry['active'] as String?);
        entry['active'] = null;
        index[action.actionId] = entry;
        await dir.create(recursive: true);
        await _saveIndex(dir, index);
      });
  Future<void> rollback(MlActionDefinition action) => _serial(() async {
        final dir = await _directory(),
            index = await _index(dir),
            entry =
                Map<String, dynamic>.from(index[action.actionId] as Map? ?? {});
        final previous = entry['previous'];
        if (previous is! String ||
            (entry['disabled'] as List? ?? []).contains(previous)) {
          throw const FormatException('沒有可回滾的有效核准版本');
        }
        final loaded = await load(action, previous);
        if (loaded == null) {
          throw const FormatException('上一版本完整性或核准失效');
        }
        entry['active'] = previous;
        entry['previous'] = null;
        _record(entry, 'rollback', previous);
        index[action.actionId] = entry;
        await _saveIndex(dir, index);
      });
  // Same catalog/index and operation history, with a namespace for body v3.
  // Never route v3 through the legacy v1/hand approval path.
  Future<Directory> _bodyCandidate(Directory dir, String version) async =>
      Directory('${dir.path}/${BodyMlContract.storeKey}/${_safe(version)}');
  Future<String> registerBody(BodyMlBundle bundle) => _serial(() async {
        // Registration validates, but never changes lifecycle or approves.
        final manifest = bundle.validate(requireActivation: false);
        final version = _safe(manifest.version);
        final dir = await _directory(),
            candidate = await _bodyCandidate(dir, version);
        if (await candidate.exists()) {
          throw const FormatException('模型版本已登錄，不能覆寫');
        }
        await candidate.create(recursive: true);
        for (final entry in bundle.files.entries) {
          await File('${candidate.path}/${entry.key}')
              .writeAsBytes(entry.value, flush: true);
        }
        await File('${candidate.path}/checksums.json')
            .writeAsString(jsonEncode(bundle.checksums), flush: true);
        return version;
      });
  Future<BodyMlBundle?> loadBody(String version,
      {bool candidate = false}) async {
    try {
      final dir = await _directory(), index = await _index(dir);
      final entry = index[BodyMlContract.storeKey] as Map? ?? {};
      if ((entry['disabled'] as List? ?? []).contains(version)) return null;
      final c = await _bodyCandidate(dir, version);
      final bundle = BodyMlBundle(
          manifest: await File('${c.path}/manifest.json').readAsBytes(),
          model: await File('${c.path}/model.onnx').readAsBytes(),
          featureSchema:
              await File('${c.path}/feature_schema.json').readAsBytes(),
          labelMapping:
              await File('${c.path}/label_mapping.json').readAsBytes(),
          checksums: Map<String, String>.from(
              jsonDecode(await File('${c.path}/checksums.json').readAsString())
                  as Map));
      if (!candidate) {
        final manifest = bundle.validate();
        final proof = Map<String, dynamic>.from(
            jsonDecode(await File('${c.path}/approval.json').readAsString())
                as Map);
        if (!_approved(proof) ||
            proof['modelSha256'] != manifest.json['modelHash'] ||
            proof['manifestSha256'] != BodyMlBundle.hash(bundle.manifest) ||
            proof['sourceDomain'] != manifest.domain ||
            proof['runtimeValidated'] != true) {
          return null;
        }
      }
      return bundle;
    } catch (_) {
      return null;
    }
  }

  Future<String?> activeBodyVersion() async {
    try {
      final entry =
          (await _index(await _directory()))[BodyMlContract.storeKey] as Map?;
      final version = entry?['active'];
      return version is String &&
              !(entry?['disabled'] as List? ?? []).contains(version)
          ? _safe(version)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> activateBody(String version, Map<String, dynamic> evidence,
          {required String sourceDomain,
          required Future<bool> Function(BodyMlBundle) runtimeCheck}) =>
      _serial(() async {
        final bundle = await loadBody(version, candidate: true);
        if (bundle == null) throw const FormatException('模型不可用');
        final manifest = bundle
            .validate(); // synthetic/candidate/retired NEVER auto-promoted
        if (manifest.domain != sourceDomain ||
            !_approved(evidence) ||
            evidence['runtimeValidated'] != true ||
            evidence['sourceDomain'] != sourceDomain ||
            evidence['modelSha256'] != manifest.json['modelHash'] ||
            evidence['manifestSha256'] != BodyMlBundle.hash(bundle.manifest) ||
            !await runtimeCheck(bundle)) {
          throw const FormatException(
              'Body activation evidence/runtime/domain mismatch');
        }
        final dir = await _directory(), index = await _index(dir);
        final entry = Map<String, dynamic>.from(
            index[BodyMlContract.storeKey] as Map? ?? {});
        if ((entry['disabled'] as List? ?? []).contains(version)) {
          throw const FormatException('模型已停用');
        }
        final c = await _bodyCandidate(dir, version);
        await File('${c.path}/approval.json')
            .writeAsString(jsonEncode(evidence), flush: true);
        if (entry['active'] != version) entry['previous'] = entry['active'];
        entry['active'] = version;
        _record(entry, 'activate', version);
        index[BodyMlContract.storeKey] = entry;
        await _saveIndex(dir, index);
      });
  Future<void> disableBody() => _serial(() async {
        final dir = await _directory(), index = await _index(dir);
        final entry = Map<String, dynamic>.from(
            index[BodyMlContract.storeKey] as Map? ?? {});
        entry['disabled'] = {
          ...List<String>.from(entry['disabled'] as List? ?? []),
          if (entry['active'] is String) entry['active'] as String
        }.toList();
        _record(entry, 'disable', entry['active'] as String?);
        entry['active'] = null;
        index[BodyMlContract.storeKey] = entry;
        await dir.create(recursive: true);
        await _saveIndex(dir, index);
      });
  Future<void> rollbackBody() => _serial(() async {
        final dir = await _directory(), index = await _index(dir);
        final entry = Map<String, dynamic>.from(
            index[BodyMlContract.storeKey] as Map? ?? {});
        final previous = entry['previous'];
        if (previous is! String || await loadBody(previous) == null) {
          throw const FormatException('沒有可回滾的核准 Body 模型');
        }
        _record(entry, 'rollback', previous);
        entry['active'] = previous;
        entry['previous'] = null;
        index[BodyMlContract.storeKey] = entry;
        await _saveIndex(dir, index);
      });
  Future<({Map<String, dynamic> manifest, Uint8List bytes})?> load(
      MlActionDefinition action, String version) async {
    try {
      final dir = await _directory(), index = await _index(dir);
      final entry = index[action.actionId] as Map?;
      if ((entry?['disabled'] as List? ?? []).contains(version)) return null;
      final c = await _candidate(dir, action, version);
      final meta = Map<String, dynamic>.from(
          jsonDecode(await File('${c.path}/manifest.json').readAsString())
              as Map);
      final proof = Map<String, dynamic>.from(
          jsonDecode(await File('${c.path}/approval.json').readAsString())
              as Map);
      if (!_approved(proof) ||
          proof['modelSha256'] != meta['modelSha256'] ||
          meta['modelVersion'] != version) {
        return null;
      }
      final approved = {
        ...meta,
        'validationStatus': 'approved_research',
        'deploymentApproved': true
      };
      final bytes = await File('${c.path}/model.onnx').readAsBytes();
      MlModelManifest.validate(approved, bytes, definition: action);
      return (manifest: approved, bytes: bytes);
    } catch (_) {
      return null;
    }
  }
}

/// Checks local active/disabled state per completed rep; lazy single-action session.
class CatalogMlQualityEvaluator extends MlQualityEvaluator {
  CatalogMlQualityEvaluator(this.action,
      {LocalMlModelStore? store, this.sessionFactory})
      : store = store ?? LocalMlModelStore();
  final MlActionDefinition action;
  final LocalMlModelStore store;
  final MlSessionFactory? sessionFactory;
  MlQualityEvaluator? _evaluator;
  String? _version;
  bool _disposed = false;
  Future<MlQualityResult>? _pending;
  @override
  Future<MlQualityResult> evaluate(List<double> features) {
    if (_disposed || _pending != null) {
      return Future.value(const MlQualityResult.unavailable('研究分析暫時不可用。'));
    }
    final pending = _evaluate(features);
    _pending = pending;
    return pending.whenComplete(() => _pending = null);
  }

  Future<MlQualityResult> _evaluate(List<double> features) async {
    if (_disposed) return const MlQualityResult.unavailable('研究分析已結束。');
    try {
      final version = await store.activeVersion(action);
      if (_disposed) return const MlQualityResult.unavailable('研究分析已結束。');
      if (version != _version) {
        await _evaluator?.dispose();
        _evaluator = null;
        _version = version;
      }
      if (version == null) {
        return const MlQualityResult.unavailable('研究模型尚未開放。');
      }
      if (_evaluator == null) {
        final data = await store.load(action, version);
        if (data == null || _disposed) {
          return const MlQualityResult.unavailable('研究模型驗證失敗。');
        }
        final evaluator = await OnnxMlQualityEvaluator.load(
            definition: action,
            manifestLoader: () async =>
                Uint8List.fromList(utf8.encode(jsonEncode(data.manifest))),
            modelLoader: () async => data.bytes,
            sessionFactory: sessionFactory);
        if (_disposed) {
          await evaluator.dispose();
          return const MlQualityResult.unavailable('研究分析已結束。');
        }
        _evaluator = evaluator;
      }
      final result = await _evaluator!.evaluate(features);
      if (_disposed || await store.activeVersion(action) != version) {
        return const MlQualityResult.unavailable('模型版本已停用或變更。');
      }
      return result;
    } catch (_) {
      return const MlQualityResult.unavailable('研究模型目前不可用。');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _pending;
    await _evaluator?.dispose();
  }
}

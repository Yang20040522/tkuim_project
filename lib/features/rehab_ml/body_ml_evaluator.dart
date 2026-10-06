import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'body_ml_contract.dart';
import 'local_ml_model_store.dart';

class BodyMlOutput {
  const BodyMlOutput(this.classId, this.probabilities);
  final int classId;
  final List<double> probabilities;
}

abstract interface class BodyMlOnnxSession {
  Future<BodyMlOutput> infer(Float32List features);
  Future<void> close();
}

typedef BodyMlSessionFactory = Future<BodyMlOnnxSession> Function(
    Uint8List model, BodyMlManifest manifest);

/// Typed numeric-class v3 wrapper over the project's existing ORT package.
/// No OrtEnv release: RTMPose owns other sessions in the same process.
class NativeBodyMlSession implements BodyMlOnnxSession {
  NativeBodyMlSession._(this.session);
  final OrtSession session;
  static Future<BodyMlOnnxSession> open(
      Uint8List model, BodyMlManifest manifest) async {
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(1)
      ..setInterOpNumThreads(1);
    OrtSession? session;
    try {
      session = OrtSession.fromBuffer(model, options);
      if (!listEquals(session.inputNames, ['features']) ||
          session.outputCount != 2 ||
          !session.outputNames
              .toSet()
              .containsAll(['label', 'probabilities'])) {
        throw const FormatException('Body model I/O contract mismatch');
      }
      return NativeBodyMlSession._(session);
    } catch (_) {
      session?.release();
      rethrow;
    } finally {
      options.release();
    }
  }

  @override
  Future<BodyMlOutput> infer(Float32List features) async {
    final tensor = OrtValueTensor.createTensorWithDataList(features, [1, 5]);
    final options = OrtRunOptions();
    List<OrtValue?>? output;
    try {
      output = await session
          .runAsync(options, {'features': tensor}, ['label', 'probabilities']);
      final label = output?[0]?.value, probability = output?[1]?.value;
      if (label is! List ||
          label.length != 1 ||
          label.single is! int ||
          probability is! List ||
          probability.length != 1 ||
          probability.single is! List) {
        throw const FormatException('Body model output shape mismatch');
      }
      return BodyMlOutput(
          label.single as int,
          (probability.single as List)
              .map((v) => (v as num).toDouble())
              .toList());
    } finally {
      for (final v in output ?? <OrtValue?>[]) {
        v?.release();
      }
      tensor.release();
      options.release();
    }
  }

  @override
  Future<void> close() async {
    await session.killAllIsolates();
    session.release();
  }
}

/// Scoped lazy cache. The active revision is rechecked after inference, so
/// disable/rollback/version changes cannot publish a result from stale weights.
class BodyMlEvaluator {
  factory BodyMlEvaluator.runtime({LocalMlModelStore? store}) {
    const fixture = String.fromEnvironment('BODY_ML_ENGINEERING_BUNDLE');
    if (bodyMlEngineeringValidation && fixture.isNotEmpty) {
      BodyMlBundle? bundle;
      return BodyMlEvaluator(
          engineering: true,
          revision: () async => 'r5-engineering-fixture-v1',
          bundleLoader: (_) async =>
              bundle ??= BodyMlBundle.decodeFixture(fixture));
    }
    return BodyMlEvaluator.catalog(store: store);
  }
  BodyMlEvaluator(
      {required this.bundleLoader,
      required this.revision,
      this.engineering = false,
      this.sessionFactory = NativeBodyMlSession.open});
  factory BodyMlEvaluator.catalog({LocalMlModelStore? store}) {
    final catalog = store ?? LocalMlModelStore();
    return BodyMlEvaluator(
        revision: catalog.activeBodyVersion,
        bundleLoader: (version) => catalog.loadBody(version));
  }
  final Future<BodyMlBundle?> Function(String revision) bundleLoader;
  final Future<String?> Function() revision;
  final BodyMlSessionFactory sessionFactory;
  final bool engineering;
  BodyMlOnnxSession? _session;
  BodyMlManifest? _manifest;
  String? _revision;
  BodyMlDecision? _loadFailure;
  bool _disposed = false;
  Future<void> _tail = Future.value();
  final Map<String, Future<BodyMlPrediction>> _cache = {};

  Future<BodyMlPrediction> evaluate(BodyMlInput input) async {
    BodyMlPrediction fail(BodyMlDecision status) => BodyMlPrediction(
        decisionStatus: status, input: input, manifest: _manifest);
    if (_disposed) return fail(BodyMlDecision.disabled);
    if (input.problem case final problem?) return fail(problem);
    String? current;
    try {
      current = await revision();
    } catch (_) {
      return fail(BodyMlDecision.modelUnavailable);
    }
    if (_disposed) return fail(BodyMlDecision.disabled);
    if (current == null) {
      await _serialize(() async {
        await _clear();
        _revision = null;
      });
      return fail(BodyMlDecision.modelUnavailable);
    }
    final key = '${input.attemptId}/$current';
    if (_cache[key] case final cached?) return cached;
    final pending = _serialize(() => _evaluate(input, current!));
    _cache[key] = pending;
    if (_cache.length > 128) _cache.remove(_cache.keys.first);
    return pending;
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<BodyMlPrediction> _evaluate(BodyMlInput input, String current) async {
    BodyMlPrediction result(BodyMlDecision status,
            {String? label,
            double? confidence,
            List<double> probabilities = const []}) =>
        BodyMlPrediction(
            decisionStatus: status,
            input: input,
            manifest: _manifest,
            label: label,
            confidence: confidence,
            probabilities: probabilities);
    if (_disposed) return result(BodyMlDecision.disabled);
    try {
      if (await revision() != current) return result(BodyMlDecision.disabled);
      if (_revision != current) {
        await _clear();
        _revision = current;
      }
      if (_loadFailure != null) return result(_loadFailure!);
      if (_manifest == null) {
        final bundle = await bundleLoader(current);
        if (_disposed) return result(BodyMlDecision.disabled);
        if (bundle == null) return result(BodyMlDecision.modelUnavailable);
        _manifest = bundle.validate(engineering: engineering);
        if (_manifest!.version != current) {
          throw const BodyMlContractFailure(BodyMlDecision.modelIncompatible);
        }
        // Validate domain before even constructing a native session.
        if (_manifest!.domain != input.source) {
          return result(BodyMlDecision.domainMismatch);
        }
        _session = await sessionFactory(bundle.model, _manifest!);
      }
      if (_manifest!.domain != input.source) {
        return result(BodyMlDecision.domainMismatch);
      }
      if (_session == null) {
        // A first attempt from another domain has validated metadata only.
        final bundle = await bundleLoader(current);
        if (bundle == null) return result(BodyMlDecision.modelUnavailable);
        _manifest = bundle.validate(engineering: engineering);
        _session = await sessionFactory(bundle.model, _manifest!);
      }
      if (_disposed) return result(BodyMlDecision.disabled);
      final output = await _session!
          .infer(Float32List.fromList(input.features.cast<double>()));
      if (_disposed || await revision() != current) {
        return result(BodyMlDecision.disabled);
      }
      final probabilities = output.probabilities;
      if (output.classId < 0 ||
          output.classId > 2 ||
          probabilities.length != 3 ||
          probabilities.any((p) => !p.isFinite || p < 0 || p > 1) ||
          (probabilities.fold<double>(0, (a, b) => a + b) - 1).abs() > 1e-4 ||
          probabilities.any((p) => p > probabilities[output.classId] + 1e-6)) {
        return result(BodyMlDecision.inferenceError);
      }
      final confidence = probabilities[output.classId];
      final manifest = _manifest!;
      final abstain = (!engineering &&
              (!manifest.calibrated || manifest.threshold == null)) ||
          (manifest.threshold != null && confidence < manifest.threshold!);
      return result(
          abstain ? BodyMlDecision.lowConfidence : BodyMlDecision.predicted,
          label: abstain ? null : BodyMlContract.classes[output.classId],
          confidence: confidence,
          probabilities: probabilities);
    } on BodyMlContractFailure catch (e) {
      _loadFailure = e.status;
      return result(e.status);
    } catch (_) {
      _loadFailure = BodyMlDecision.inferenceError;
      return result(BodyMlDecision.inferenceError);
    }
  }

  Future<void> _clear() async {
    final session = _session;
    _session = null;
    _manifest = null;
    _loadFailure = null;
    try {
      await session?.close();
    } catch (_) {/* Advisory cleanup only. */}
    // Dedupe keys include model revision; do not discard in-flight entries here.
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _tail;
    await _clear();
    _cache.clear();
  }
}

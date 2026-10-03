import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

import 'ml_action_definition.dart';
import 'ml_quality_evaluator.dart';

const mlPreprocessing = 'rtmpose17-normalized-2d-v1;features-identity;float32';

/// Trusted build-time manifest, not a downloaded/self-authorizing model.
class MlModelManifest {
  MlModelManifest._(this.json, this.definition);
  final Map<String, dynamic> json;
  final MlActionDefinition definition;
  String get version => json['modelVersion'] as String;
  List<String> get classes => List<String>.from(json['classes'] as List);
  String get inputName => json['inputName'] as String;
  List<String> get outputNames => [
        json['labelOutputName'] as String,
        json['probabilityOutputName'] as String
      ];
  double? get threshold => (json['confidenceThreshold'] as num?)?.toDouble();

  static MlModelManifest validate(
    Map<String, dynamic> json,
    Uint8List bytes, {
    MlActionDefinition definition = MlActionRegistry.standingKneeRaise,
    bool requireApproval = true,
  }) {
    final classes = json['classes'];
    final parity = json['onnxParity'];
    final threshold = json['confidenceThreshold'];
    if ((definition.isHand &&
            (json['landmarkSource'] != 'mediapipe_hand_21' ||
                json['extractorVersion'] != 'hand-image-proxy-v1' ||
                json['modelInputVersion'] != 'hand-features-v1')) ||
        json['manifestVersion'] != 1 ||
        json['actionId'] != definition.actionId ||
        json['schemaVersion'] != definition.schemaVersion ||
        json['actionDefinitionVersion'] != definition.version ||
        json['labelVersion'] != definition.labelVersion ||
        !listEquals(
            json['featureNames'] is List ? json['featureNames'] as List : null,
            definition.featureNames) ||
        json['inputDimension'] != definition.featureNames.length ||
        !listEquals(
            json['inputShape'] is List ? json['inputShape'] as List : null,
            [null, definition.featureNames.length]) ||
        json['inputDtype'] != 'float32' ||
        json['preprocessing'] != definition.preprocessing ||
        json['dataOrigin'] != 'reviewed_export' ||
        json['disabled'] == true ||
        (requireApproval &&
            (json['validationStatus'] != 'approved_research' ||
                json['deploymentApproved'] != true)) ||
        (!requireApproval &&
            !const {'parity_verified', 'approved_research'}
                .contains(json['validationStatus'])) ||
        classes is! List ||
        classes.length != 3 ||
        classes.toSet().length != 3 ||
        !classes.toSet().containsAll(
            definition.labels.keys.where((k) => k != 'unassessable')) ||
        parity is! Map ||
        parity['status'] != 'PASS' ||
        parity['absoluteTolerance'] is! num ||
        !(parity['absoluteTolerance'] as num).isFinite ||
        (parity['absoluteTolerance'] as num) <= 0 ||
        (parity['absoluteTolerance'] as num) > 1e-5 ||
        parity['maxAbsoluteError'] is! num ||
        !(parity['maxAbsoluteError'] as num).isFinite ||
        (parity['maxAbsoluteError'] as num) < 0 ||
        (parity['maxAbsoluteError'] as num) >
            (parity['absoluteTolerance'] as num) ||
        parity['rows'] is! int ||
        (parity['rows'] as int) < 1 ||
        ![
          'modelVersion',
          'inputName',
          'labelOutputName',
          'probabilityOutputName'
        ].every((k) =>
            json[k] is String && (json[k] as String).trim().isNotEmpty) ||
        json['labelOutputName'] == json['probabilityOutputName'] ||
        bytes.isEmpty ||
        json['modelSha256'] != sha256.convert(bytes).toString() ||
        (threshold != null &&
            (threshold is! num ||
                !threshold.isFinite ||
                threshold < 0 ||
                threshold > 1 ||
                json['confidenceThresholdValidated'] != true))) {
      throw const FormatException('研究模型契約或核准狀態不符');
    }
    return MlModelManifest._(Map.unmodifiable(json), definition);
  }
}

class MlModelOutput {
  const MlModelOutput(this.label, this.probabilities);
  final String label;
  final List<double> probabilities;
}

abstract interface class MlOnnxSession {
  Future<MlModelOutput> infer(Float32List features);
  Future<void> close();
}

typedef MlSessionFactory = Future<MlOnnxSession> Function(
    Uint8List bytes, MlModelManifest manifest);

class _NativeMlSession implements MlOnnxSession {
  _NativeMlSession(this.session, this.manifest);
  final OrtSession session;
  final MlModelManifest manifest;
  static Future<MlOnnxSession> open(
      Uint8List bytes, MlModelManifest manifest) async {
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(1)
      ..setInterOpNumThreads(1);
    OrtSession? session;
    try {
      session = OrtSession.fromBuffer(bytes, options);
      if (!listEquals(session.inputNames, [manifest.inputName]) ||
          !session.outputNames.toSet().containsAll(manifest.outputNames) ||
          session.outputCount != 2) {
        throw const FormatException('模型輸入輸出名稱不符');
      }
      return _NativeMlSession(session, manifest);
    } catch (_) {
      session?.release();
      rethrow;
    } finally {
      options.release();
    }
  }

  @override
  Future<MlModelOutput> infer(Float32List features) async {
    final input = OrtValueTensor.createTensorWithDataList(
        features, [1, manifest.definition.featureNames.length]);
    final options = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = await session.runAsync(
          options, {manifest.inputName: input}, manifest.outputNames);
      if (outputs == null || outputs.length != 2) {
        throw const FormatException('模型輸出不可用');
      }
      final labels = outputs[0]?.value;
      final probabilities = outputs[1]?.value;
      if (labels is! List ||
          labels.length != 1 ||
          labels.single is! String ||
          probabilities is! List ||
          probabilities.length != 1 ||
          probabilities.single is! List) {
        throw const FormatException('模型輸出形狀不符');
      }
      return MlModelOutput(
          labels.single as String,
          (probabilities.single as List)
              .map((v) => (v as num).toDouble())
              .toList());
    } finally {
      for (final output in outputs ?? <OrtValue?>[]) {
        output?.release();
      }
      input.release();
      options.release();
    }
  }

  @override
  Future<void> close() async {
    await session.killAllIsolates();
    session.release(); // Do not release the shared OrtEnv used by RTMPose.
  }
}

class OnnxMlQualityEvaluator extends MlQualityEvaluator {
  OnnxMlQualityEvaluator._(this._session, this.manifest);
  final MlOnnxSession _session;
  final MlModelManifest manifest;
  Future<MlQualityResult>? _pending;
  bool _disposed = false;

  static Future<MlQualityEvaluator> load({
    Future<Uint8List> Function()? manifestLoader,
    Future<Uint8List> Function()? modelLoader,
    MlSessionFactory? sessionFactory,
    MlActionDefinition definition = MlActionRegistry.standingKneeRaise,
  }) async {
    try {
      Future<Uint8List> asset(String path) async {
        final data = await rootBundle.load(path);
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      }

      final base = definition.isHand
          ? 'assets/models/rehab_ml/${definition.actionId}'
          : 'assets/models/rehab_ml';
      final metadata =
          await (manifestLoader ?? () => asset('$base/model_manifest.json'))();
      final bytes = await (modelLoader ?? () => asset('$base/model.onnx'))();
      final manifest = MlModelManifest.validate(
          jsonDecode(utf8.decode(metadata)) as Map<String, dynamic>, bytes,
          definition: definition);
      final session =
          await (sessionFactory ?? _NativeMlSession.open)(bytes, manifest);
      return OnnxMlQualityEvaluator._(session, manifest);
    } catch (_) {
      return const UnavailableMlQualityEvaluator(); // No raw model/native/sample error logs.
    }
  }

  @override
  Future<MlQualityResult> evaluate(List<double> features) async {
    if (_disposed || _pending != null) {
      return const MlQualityResult.unavailable('研究模型目前不可用。');
    }
    if (features.length != manifest.definition.featureNames.length ||
        features.any((v) => !v.isFinite) ||
        (manifest.definition.isHand
            ? (features.any((v) => v.abs() > 360) ||
                features.last < 0.3 ||
                features.last > 20)
            : (features[0].abs() > 60 ||
                features[1] < 0 ||
                features[1] > 180 ||
                features[2] < 0 ||
                features[2] > 180 ||
                features[3] < 0 ||
                features[3] > 180 ||
                features[4] < 0.3 ||
                features[4] > 8))) {
      return const MlQualityResult.unavailable('本次動作資料不足或特徵無效。');
    }
    final tensor = Float32List.fromList(features);
    if (tensor.any((v) => !v.isFinite)) {
      return const MlQualityResult.unavailable('本次動作特徵無效。');
    }
    _pending = _run(tensor);
    try {
      return await _pending!;
    } finally {
      _pending = null;
    }
  }

  Future<MlQualityResult> _run(Float32List features) async {
    try {
      final output = await _session.infer(features);
      final probabilities = output.probabilities;
      if (_disposed ||
          probabilities.length != manifest.classes.length ||
          probabilities.any((p) => !p.isFinite || p < 0 || p > 1) ||
          (probabilities.fold<double>(0, (a, b) => a + b) - 1).abs() > 1e-4) {
        return const MlQualityResult.unavailable('研究模型輸出無效。');
      }
      var best = 0;
      for (var i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > probabilities[best]) best = i;
      }
      if (manifest.classes[best] != output.label) {
        return const MlQualityResult.unavailable('研究模型類別順序不符。');
      }
      if (manifest.threshold != null &&
          probabilities[best] < manifest.threshold!) {
        return const MlQualityResult.unavailable('研究模型信心不足，暫不提供分類。');
      }
      return MlQualityResult.prediction(
          label: output.label,
          confidence: probabilities[best],
          modelVersion: manifest.version);
    } catch (_) {
      return const MlQualityResult.unavailable('研究模型推論暫時不可用。');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _pending;
    try {
      await _session.close();
    } catch (_) {
      // Auxiliary cleanup must not interrupt the camera/training lifecycle.
    }
  }
}

/// Lazy model loading: no native session is created while there is no model.
class LazyMlQualityEvaluator extends MlQualityEvaluator {
  LazyMlQualityEvaluator({this.loader = OnnxMlQualityEvaluator.load});
  final Future<MlQualityEvaluator> Function() loader;
  Future<MlQualityEvaluator>? _loaded;
  bool _disposed = false;
  @override
  Future<MlQualityResult> evaluate(List<double> features) async {
    if (_disposed) return const MlQualityResult.unavailable('研究分析已結束。');
    try {
      final evaluator = await (_loaded ??= loader());
      if (_disposed) return const MlQualityResult.unavailable('研究分析已結束。');
      return await evaluator.evaluate(features);
    } catch (_) {
      return const MlQualityResult.unavailable('研究模型目前不可用。');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final loaded = _loaded;
    if (loaded != null) {
      try {
        await (await loaded).dispose();
      } catch (_) {/* Failed load owns no native resources. */}
    }
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/rehab_ml/body_ml_contract.dart';
import 'package:flutter_body/features/rehab_ml/body_ml_evaluator.dart';
import '../test/features/rehab_ml/body_ml_test_support.dart';

/// Executes the REAL onnxruntime_v2 FFI library, not a fake session. Run with
/// BODY_ML_ENGINEERING_VALIDATION=true and existing ORT DLL directory on PATH.
void main() {
  test('all 56 R4 Python native/ONNX vectors match Flutter ONNX <=1e-5',
      () async {
    expect(bodyMlEngineeringValidation, isTrue,
        reason: 'Explicit validation build flag required');
    final parity = fixtureJson['parity'] as Map;
    final vectors = parity['input'] as List,
        labels = parity['nativeLabels'] as List,
        probabilities = parity['nativeProbabilities'] as List;
    expect(vectors.length, 56);
    final load = Stopwatch()..start();
    final bundle = fixtureBundle();
    final session = await NativeBodyMlSession.open(
        bundle.model, bundle.validate(engineering: true));
    load.stop();
    final loadUs = load.elapsedMicroseconds;
    final latencies = <int>[];
    var maxError = 0.0;
    final memoryBefore = ProcessInfo.currentRss;
    for (var i = 0; i < vectors.length; i++) {
      final watch = Stopwatch()..start();
      // R4 includes deliberate zero/boundary vectors. The higher-level adapter
      // separately rejects unavailable zero-duration attempts before inference.
      final prediction = await session.infer(Float32List.fromList(
          (vectors[i] as List).map((v) => (v as num).toDouble()).toList()));
      watch.stop();
      latencies.add(watch.elapsedMicroseconds);
      expect(prediction.classId, labels[i] as int, reason: 'vector $i');
      for (var c = 0; c < 3; c++) {
        final e = (prediction.probabilities[c] -
                (probabilities[i][c] as num).toDouble())
            .abs();
        if (e > maxError) maxError = e;
        expect(e, lessThanOrEqualTo(1e-5));
      }
    }
    final memoryAfter = ProcessInfo.currentRss;
    latencies.sort();
    // Engineering diagnostics only. Host process RSS includes Flutter/FFI.
    // ignore-free ordinary test output: no pose, account, token or patient data.
    // Test runner records all values as evidence in the validation log.
    // Flutter label/probability parity is asserted above rather than log-only.
    stdout.writeln(
        'BODY_R5_NATIVE_PARITY PASS rows=56 maxError=$maxError loadUs=$loadUs p50Us=${latencies[28]} p95Us=${latencies[53]} hostRssDelta=${memoryAfter - memoryBefore}');
    await session.close();
  });
}

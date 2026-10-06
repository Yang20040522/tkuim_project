import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_body/features/rehab_ml/body_ml_contract.dart';
import 'package:flutter_body/features/rehab_ml/body_ml_evaluator.dart';

/// Isolated fixture-only entry point; never contacts backend/camera or loads
/// patient sessions. Normal main.dart and pubspec assets remain unchanged.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _Smoke()));
}

class _Smoke extends StatefulWidget {
  const _Smoke();
  @override
  State<_Smoke> createState() => _SmokeState();
}

class _SmokeState extends State<_Smoke> {
  String status = 'MODEL_UNAVAILABLE · DEFAULT OFF';
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    const fixtureFile = String.fromEnvironment('BODY_ML_ENGINEERING_FILE');
    if (!bodyMlEngineeringValidation || fixtureFile.isEmpty) {
      debugPrint('BODY_R5_SMOKE DEFAULT_OFF PASS');
      return;
    }
    BodyMlOnnxSession? session;
    BodyMlEvaluator? evaluator;
    try {
      final content = await File(fixtureFile).readAsString();
      final json = jsonDecode(content) as Map;
      final parity = json['parity'] as Map;
      final bundle = BodyMlBundle.fromFixtureJson(content);
      final memory = ProcessInfo.currentRss;
      final load = Stopwatch()..start();
      session = await NativeBodyMlSession.open(
          bundle.model, bundle.validate(engineering: true));
      load.stop();
      final times = <int>[];
      var maxError = 0.0;
      for (var i = 0; i < 56; i++) {
        final watch = Stopwatch()..start();
        final result = await session.infer(Float32List.fromList(
            (parity['input'][i] as List)
                .map((v) => (v as num).toDouble())
                .toList()));
        watch.stop();
        times.add(watch.elapsedMicroseconds);
        if (result.classId != parity['nativeLabels'][i]) {
          throw const FormatException('Label parity failure');
        }
        for (var c = 0; c < 3; c++) {
          final error = (result.probabilities[c] -
                  (parity['nativeProbabilities'][i][c] as num).toDouble())
              .abs();
          if (error > maxError) maxError = error;
          if (!error.isFinite || error > 1e-5) {
            throw const FormatException('Probability parity failure');
          }
        }
      }
      // Also exercise the typed runtime/compile-flag path with a valid finalized
      // attempt, rather than claiming lower-level parity proves all integration.
      evaluator = BodyMlEvaluator.runtime();
      final advisory = await evaluator.evaluate(BodyMlInput(
          attemptId: 'fixture-only',
          source: 'tv_pi',
          features: [0.3, 90, 90, 8, 1]));
      if (advisory.decisionStatus != BodyMlDecision.predicted) {
        throw const FormatException('Typed runtime failure');
      }
      final firstUs = times.first;
      times.sort();
      final summary =
          'BODY_R5_SMOKE PASS rows=56 maxError=$maxError loadUs=${load.elapsedMicroseconds} firstUs=$firstUs p50Us=${times[28]} p95Us=${times[53]} rssDelta=${ProcessInfo.currentRss - memory} typed=PREDICTED';
      debugPrint(summary);
      if (mounted) {
        setState(() => status = '$bodyMlEngineeringNotice\n$summary');
      }
    } catch (e) {
      debugPrint('BODY_R5_SMOKE FAIL type=${e.runtimeType}');
      if (mounted) {
        setState(() => status = 'ENGINEERING ONLY · FAIL ${e.runtimeType}');
      }
    } finally {
      await evaluator?.dispose();
      await session?.close();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child:
              Padding(padding: const EdgeInsets.all(24), child: Text(status))));
}

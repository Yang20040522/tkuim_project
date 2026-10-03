# G4 Validation

Baseline: Flutter `a8fb0c96486f0d8af8f5997051f25cb5d45b4c2f`, backend `7c55d1c7527d94ca0e23c50213f68f7e4f973d7a` (clean local/remote).

Stage A static audit PASS; actual approved dataset/consent/retention/professional definition verification **NOT READY** (not supplied). No real model/accuracy exists. No backend modification, SQL, export API call, secret access or research enablement.

Subsequent results must be appended only after commands actually execute. Real Android / Render acceptance NOT RUN. Seven baseline Flutter failures are documented in G35_VALIDATION.md and CHAT_REALTIME_VALIDATION.md; G4 must rerun and classify rather than assume no regression.

## Stage B/C

` .dart_tool/g4-python/Scripts/python.exe -m unittest discover -s ml/tests -v`: **PASS 16/16**, 0 skip. Evidence `.dart_tool/g4-python-tests.log` (ignored). Temporary synthetic RF exported and compared in real Python ORT; no formal accuracy/F1 reported. Repeated grouped run produces identical report. Non-finite/wrong-dimension inputs rejected; insufficient dataset writes no output; duplicate IDs/governance/version tests PASS.

Python env: 3.12.14, numpy2.2.6, sklearn1.7.2, skl2onnx1.19.1, onnx1.19.1, ORT1.23.2, protobuf5.29.5. Initial protobuf7 conversion TypeError and old waiting-data wording test failure corrected, not hidden/skipped.

## Stage D / E focused

- `flutter test test/features/rehab_ml test/features/rehab test/features/analysis/body_normalization_test.dart test/features/analysis/body_rep_trajectory_collector_test.dart test/features/analysis/body_template_analyzer_test.dart --reporter expanded`: **PASS 68/68**, 0 skip; `.dart_tool/g4-flutter-regression.log`.
- `flutter analyze lib/features/rehab_ml test/features/rehab_ml`: **PASS 0 issues**, `.dart_tool/g4-analyze-final.log`. BodyTrainingScreen still has its two baseline info diagnostics (unnecessary dart:ui import, unrelated async-context use); not suppressed/refactored.
- `flutter pub get`: PASS. crypto3.0.7 is now direct, not upgraded; ONNX/native/dependency versions unchanged.
- Python rerun after hash-version/deterministic graph naming: **PASS 16/16**, `.dart_tool/g4-python-tests.log`.
- Fake session verifies tensor order, missing/model-load failures, contract/hash/approval rejection, malformed probabilities, optional validated-only threshold, dispose waiting, single completed rep and stale/busy handling. Widget test verifies no fake label when unavailable and separate research metadata.
- ADB lists an authorized attached device, ABI arm64-v8a. **Actual qualified-model inference NOT RUN**: no approved real-data model. No install/runtime/latency/memory claim.

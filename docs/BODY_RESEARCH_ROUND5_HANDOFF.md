# Body Research Round 5 Handoff

Read progress and git diff first. Continue on existing master/TV/main only; no new branches or wholesale merges.

Round 4 synthetic engineering artifact is ignored at ml/artifacts/standing_knee_raise/r4-synthetic-20261007-40145b3. Contains model.onnx, parity_vectors.json (56), feature_schema.json, label_mapping.json and artifact_manifest.json. Reuse only as a clearly isolated test fixture, not a production runtime path.

Runtime: existing onnxruntime_v2 1.23.2+2. Windows native DLL in the existing pub package windows directory. Flutter C:/development/flutter/bin/flutter.bat; Python .dart_tool/g4-python/Scripts/python.exe.

LocalMlModelStore owns the existing candidate/activation/rollback index. Body v3 must be namespaced because legacy v1 uses the same action ID but different geometry. Normal build must never approve/load synthetic fixtures. Use BODY_ML_ENGINEERING_VALIDATION compile flag, default OFF, for engineering validation only.

Phone currently collects legacy v1 completed reps; TV uses BodyResearchSession finalized v3 attempts. Preserve upload schema and consent; derived advisory must not be ground truth or mutate counters.

Current implementation: body_ml_contract/evaluator/advisory_controller/card, shared LocalMlModelStore body methods, BodyResearchSession callback and therapist v3 detail card. Frozen math/payloads/counters untouched. Actual current stage/test results/next actions: see progress. Stop before Round 6.

Reproducible native validation: add existing onnxruntime_v2 windows directory to PATH, then `flutter test --dart-define=BODY_ML_ENGINEERING_VALIDATION=true tools/body_ml_native_parity_test.dart test/features/rehab_ml/body_ml_runtime_test.dart` (41 PASS; all56 vector parity).
Use `python tools/prepare_body_ml_validation.py` for ignored .dart_tool/body-r5/validation-defines.json. `tools/body_ml_validation_smoke.dart` is a separate fixture-only entry point; no camera/backend/session requests. Normal builds DO NOT use this entry or define file.

Phone's live v1 completed-rep collector lacks immutable pixel-aspect v3 observations. Deliberately do not mislabel/reinterpret its v1 vectors as v3. Phone preserves v1 behavior; v3 available through shared finalized BodyResearchSession / therapist v3 sample consumer. Document this boundary in final report.

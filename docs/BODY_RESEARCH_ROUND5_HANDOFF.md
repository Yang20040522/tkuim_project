# Body Research Round 5 Handoff

Read progress and git diff first. Continue on existing master/TV/main only; no new branches or wholesale merges.

Round 4 synthetic engineering artifact is ignored at ml/artifacts/standing_knee_raise/r4-synthetic-20261007-40145b3. Contains model.onnx, parity_vectors.json (56), feature_schema.json, label_mapping.json and artifact_manifest.json. Reuse only as a clearly isolated test fixture, not a production runtime path.

Runtime: existing onnxruntime_v2 1.23.2+2. Windows native DLL in the existing pub package windows directory. Flutter C:/development/flutter/bin/flutter.bat; Python .dart_tool/g4-python/Scripts/python.exe.

LocalMlModelStore owns the existing candidate/activation/rollback index. Body v3 must be namespaced because legacy v1 uses the same action ID but different geometry. Normal build must never approve/load synthetic fixtures. Use BODY_ML_ENGINEERING_VALIDATION compile flag, default OFF, for engineering validation only.

Phone currently collects legacy v1 completed reps; TV uses BodyResearchSession finalized v3 attempts. Preserve upload schema and consent; derived advisory must not be ground truth or mutate counters.

Current implementation: body_ml_contract/evaluator/advisory_controller/card, shared LocalMlModelStore body methods, BodyResearchSession callback and therapist v3 detail card. Frozen math/payloads/counters untouched. Actual current stage/test results/next actions: see progress. Stop before Round 6.

Reproducible native validation: add existing onnxruntime_v2 windows directory to PATH, then `flutter test --dart-define=BODY_ML_ENGINEERING_VALIDATION=true tools/body_ml_native_parity_test.dart test/features/rehab_ml/body_ml_runtime_test.dart` (final45 PASS;44 state tests plus actual56-vector parity).
Use `python tools/prepare_body_ml_validation.py` for ignored .dart_tool/body-r5/validation-defines.json. `tools/body_ml_validation_smoke.dart` is a separate fixture-only entry point; no camera/backend/session requests. Normal builds DO NOT use this entry or define file.

Phone's live v1 completed-rep collector lacks immutable pixel-aspect v3 observations. Deliberately do not mislabel/reinterpret its v1 vectors as v3. Phone preserves v1 behavior; v3 available through shared finalized BodyResearchSession / therapist v3 sample consumer. Document this boundary in final report.

## Final validation and safety

Read BODY_RESEARCH_ROUND5_REPORT.md for all35 requested items, exact commands/results, build hashes and limitations. Default-OFF core64/64, TV50/50, engineering45/45; Python73/73; full suite once596 PASS/7 known Round4 failures, not all green. Four later tests were run focused. Master/TV scoped analyze0issues. Do not rerun entire suite merely to change counts or retrain R4 artifact.

Actual isolated Android x86_64 Release ONNX ran all56 vectors <=1e-5 (max1.9868214962137642e-8), typed evaluator PREDICTED, default-OFF smoke launched. Emulator was separate fresh userdata, stopped after validation; physical phone unchanged. PathAccessException was test-directory permissions, not a runtime/R8 source issue. Windows large embedded define transport exceeded command limit; use compile-gated file instead. No production fixture asset.

For repeatable emulator-only validation, `python tools/prepare_body_ml_validation.py`; explicit `android/gradlew.bat assembleRelease -PrehabValidationApplicationId=com.rehabassist.bodyml.r5validation -Ptarget-platform=android-x64 -Ptarget=tools/body_ml_validation_smoke.dart -Psplit-per-abi=true -Pdart-defines=<base64-encoded NAME=VALUE defines>` after Flutter Release preparation. Validate APK app ID with aapt BEFORE installing; never install this task harness over real App. Push test/fixtures/body_ml_engineering_bundle.json to the compile-defined emulator test-app file; shell-created test directories need755 traversal. Do not expose patient files or modify real device. Fixture-loader flag is defaultOFF in normal main.dart builds.

Master implementation commits c3f70e9 and0f8f0fc; TV20291d1 and34bc367. Final task-only docs commit in each branch recorded by git log/completion response. Backend main unchanged9871f96; no DB access/Maven needed this round. Preserve TV's seven existing generated desktop edits. Only master and codex/android-tv-client used; no branch creation/push/deploy.

TV final documentation commit43901d0ae1269d162446b924e6570b27cd70fc9d. Normal final master Debug/Release PASS29.4s/96.2s; TV Debug PASS26.6s. Main normal Release SHA256679741BFD36CB777A2C22CC096C49C2CFC77CFB378FD2AB25C88AA9556136AB2, path build/app/outputs/flutter-apk/app-release.apk. This is NOT the standalone fixture harness. Earlier snapshot hash39AA4B... superseded; isolated test APKs ignored in .dart_tool/body-r5 only.

REAL_MODEL_AVAILABLE/VALIDATED/DEPLOYED=NO; PRODUCTION_MODEL=NONE. Framework ready, real data/calibration/approval/distribution remain future work. Stop before Round6; do not enable collection or ask physical motion.

# Body Research Round 5 — Runtime Integration Report

Date: 2026-10-07. **Round 5 Engineering Gate: PASS.** This is NOT clinical ML validation.

```
MODEL_RUNTIME_ENGINEERING = PASS
REAL_DATASET = DATA_INSUFFICIENT
REAL_MODEL_AVAILABLE = NO
REAL_MODEL_VALIDATED = NO
REAL_MODEL_DEPLOYED = NO
PRODUCTION_MODEL = NONE
```

Baselines: Flutter master `18865d99f13798d7365c7502bb451030203727fc`; existing TV branch `18b5fb17fce608ebb62fd2e27c1692dc91c6c9b3`; backend main `9871f96a4f55db498ceea6895d28daf02d518eab` (unchanged).

## 1. Implementation Summary — PASS

Typed body-v3 advisory runtime, integrity/compatibility checks, actual Flutter ONNX inference, same-store activation/rollback, account isolation, finalized-attempt and therapist-detail consumers. No backend/DB/native/dependency/pose-math changes. No new branch, push, deployment, lab access or Pi change.

## 2. Runtime Architecture — PASS

Existing RTMPose observations → existing finalized BodyResearchSample → frozen five-feature extractor → BodyMlInput → scoped BodyMlEvaluator → existing onnxruntime_v2 → BodyMlPrediction → advisory card. RehabSessionController remains a separate authoritative counter path. Inference is outside the camera frame hot loop; inference is not a backend request.

## 3. Model Bundle Contract — PASS

Bundle contains manifest.json, model.onnx, feature_schema.json, label_mapping.json and checksums.json. Requires model ID/version/status, body/schema3/standing_knee_raise, action `standing-knee-raise-body-v2`, extractor `standing-knee-raise-aspect-2d-v2`, input `body-attempt-features-v1`, feature schema `body-aspect-baseline-v1`, labels `body-attempt-label-v1`, pose `rtmpose-wholebody-133-v1`, names/order/dtype/shape/classes/domain/deployment metadata. No input format guessed from filename or vector dimension.

## 4. Integrity Validation — PASS

SHA256 checks model, manifest, feature schema and labels before native session creation. Manifest modelHash and artifactHash must match. artifactHash = SHA256 of UTF-8 `model.onnx:HASH\nfeature_schema.json:HASH\nlabel_mapping.json:HASH`, in that exact order; manifest hash is separate to avoid circular hashing. Mismatch returns MODEL_INTEGRITY_FAILED. Checksums establish integrity, NOT provenance/signatures; trust remains in controlled tooling/app-private model store.

## 5. Feature Adapter — PASS

Uses frozen extractor values, not new feature math. Order: peak_leg_height, minimum_hip_angle_deg, minimum_knee_angle_deg, peak_abs_trunk_lean_deg, duration_seconds. Null/NaN/Inf/float32 overflow/dimension mismatch/unavailable/zero-duration input fails closed without imputation. No clinical ROM claim.

## 6. Flutter ONNX Runtime — PASS

Existing onnxruntime_v2 1.23.2+2; float32 [1,5], explicitly named features/label/probabilities, int64 class0/1/2 mapping. One intra/inter-op thread; scoped session reuse; releases tensors/run options/sessions/isolates, never global OrtEnv shared with RTMPose. Package exposes I/O names/count, not public shape metadata; actual shape/type are verified by inference/runtime-check probe, exceptions fail closed.

## 7. Python / Flutter Parity — PASS

All56 fixed Round4 vectors: class agreement and every probability <=1e-5. Actual Flutter Windows FFI AND Android x86_64 Release FFI executed. Maximum absolute error `1.9868214962137642e-8`. Python verifier rechecked the saved native references against Python ORT. No retraining or clinical metric generated.

## 8. Structured Prediction Contract — PASS

Prediction carries action, model ID/version/status, label/confidence/probabilities, feature/extractor/input/label versions, source domain, input quality, UTC inference timestamp and decisionStatus. Includes PREDICTED, LOW_CONFIDENCE, INPUT_UNAVAILABLE, MODEL_UNAVAILABLE, MODEL_INCOMPATIBLE, MODEL_INTEGRITY_FAILED, INFERENCE_ERROR, DISABLED, MODEL_NOT_APPLICABLE, DOMAIN_MISMATCH. JSON identifies derived_advisory_NOT_GROUND_TRUTH.

## 9. Confidence / Abstention — PASS

Probabilities are NOT accuracy or calibrated clinical confidence. Without documented calibration/threshold production abstains (LOW_CONFIDENCE), retains descriptive probabilities but no predicted label. Configurable threshold is exercised only with explicit engineering flag. Synthetic card says SYNTHETIC MODEL / ENGINEERING ONLY / NOT FOR CLINICAL USE. No clinical threshold invented.

## 10. Action Compatibility — PASS

Only DEFAULT standing_knee_raise/body/schema3. Other body actions, hand and CUSTOM return MODEL_NOT_APPLICABLE; legacy body v1 is incompatible, not silently converted.

## 11. Domain Compatibility — PASS

Manifest domain must exactly match phone or tv_pi input. Mismatch is rejected before native init; no unvalidated multi-domain claim. Synthetic fixture domain is tv_pi. Phone↔TV generalization: DATA_INSUFFICIENT.

## 12. Body / Hand Isolation — PASS

Concrete BodyMlEvaluator only consumes body-v3 inputs. Legacy phone body-v1 and hand-v2 paths remain unchanged. TV only gains body consumers; PiHandSource stays legacy/out-of-scope. Shared model-store support files copied into TV do not invoke hand inference or add hand research.

## 13. Model Lifecycle — PASS

Extends existing LocalMlModelStore and index/history using body-v3-standing_knee_raise namespace, not a second registry. Registration validates immutable version bundles, NEVER promotes EXPERIMENTAL/CANDIDATE/RETIRED. Explicit approval/governance remains controlled local tooling, not public patient/admin toggle.

## 14. Activation Rules — PASS

Production requires APPROVED + deploymentApproved=true + REVIEWED_REAL, exact contracts/hashes/domain, approval evidence (professional definitions, reviewed real data, Android validation, approver/time/reference), runtimeValidated and passing supplied runtimeCheck. Activation tests use dummy NON-MODEL bytes/fake sessions and UNIT-ONLY evidence; actual synthetic ONNX is never relabeled real/approved. Actual real model activation: NOT RUN / no real model.

## 15. Rollback — PASS

Failed candidate leaves current active model intact. Explicit rollback loads/verifies prior approved non-disabled bundle and proof. Synthetic cannot be a production rollback target. Evaluator rechecks revision around inference and reloads weights after version change; no automatic unsafe promotion/fallback.

## 16. No-Model Behavior — PASS

Default compile flag is OFF, fixture is not a pubspec asset, empty production catalog yields MODEL_UNAVAILABLE. Existing collection/count/session tests and advisory widget preserve normal training/annotation behavior. Independent default-OFF Android Release smoke launch PASS. That launch tests compile flag/UI; actual catalog no-model execution is tested by deterministic unit tests, not physical motion.

## 17. Failure Safety — PASS

Missing/corrupt/incompatible bundle, invalid inputs/output probabilities, ORT initialization/inference failure become structured unavailable/error statuses, not training exceptions. Unsupported native model failure follows the same catch boundary. Synthetic runtime is reachable only by compile-time flag plus fixture; preferences cannot enable it.

## 18. Concurrency / Stale Result — PASS

Serialized inference; attemptId/modelVersion dedupe; pending result cannot overwrite newer attempt, account or disabled/changed model result. Deterministic tests cover pending disable/logout/new attempt. New pendingPersistence boundary replaces fixed filesystem sleeps in six session tests, preserving all original assertions and nonblocking camera handling.

## 19. Cache / Account Isolation — PASS

Lazy scoped session; bounded128 attempt cache; active revision checked each call and after inference. Version change/disable/rollback prevents stale publication and clears old session on next evaluation; logout/account change explicitly resets advisory UI and disposes pending session safely. No shared account prediction state.

## 20. Therapist UI Integration — PASS

Existing v3 sample details show separate advisory status/model/version/probability card alongside existing skeleton/review UI. Controller disposed with page and scoped to account. No annotation autofill, approval rewrite or independent review change. Engineering/model-unavailable states explicitly distinguished from professional labels.

## 21. Research Metadata Integration — PASS

Advisory is currently ephemeral UI state; structured toJson available for a future consumer. It is NOT written into uploaded sample JSON, backend annotations, approved exports or clinical history. Backend metadata/storage API changes: NOT APPLICABLE this round.

## 22. Counter Independence — PASS

Controller/evaluator have no authoritative counter writer. Sample/features and annotation immutability tested; original session/consent tests pass. No rep/set/hold/completion/plan/difficulty changes. Physical increment/accuracy validation: NOT RUN / explicitly not required.

## 23. Debug Build — PASS

Normal master final `flutter build apk --debug` PASS (29.4s, 593802012 bytes). Existing TV initial Debug PASS (33.2s); final shared hardening source Debug PASS (26.6s). APKs in each worktree's build/app/outputs/flutter-apk/app-debug.apk. No Android source/dependency/keep rule changes.

## 24. Release Build — PASS

Normal master final `flutter build apk --release` PASS (96.2s, latest hardening source, normal main.dart/default-OFF). APK at `build/app/outputs/flutter-apk/app-release.apk`, 490151035 bytes, applicationId com.example.flutter_body, SHA256 `679741BFD36CB777A2C22CC096C49C2CFC77CFB378FD2AB25C88AA9556136AB2`. Earlier normal snapshot hash39AA4B... is not the final APK. Existing ai.onnxruntime keep survives mapping (OrtSession not renamed); ORT JNI/libs for arm64-v8a, armeabi-v7a, x86_64 and pose/hand assets rechecked in final APK; fixture not included in normal assets.

Actual separate Release smoke IDs: com.rehabassist.bodyml.r5validation (engineering) and com.rehabassist.bodyml.r5offvalidation (OFF), installed only on disposable emulator. Runtime launch/inference PASS, not merely BUILD SUCCESS. TV Release: NOT RUN. Physical phone/TV: NOT RUN / not required; physical phone untouched.

Intermediate build failures retained: --no-pub/direct Gradle after analyze/pub used stale dev-only flutter_native_splash registration; normal Flutter Release preparation regenerated plugin metadata and build passed without source/dependency fix. Large fixture dart-define exceeded Windows command length; changed validation-only transport to compile-gated file. Emulator fixture PathAccessException was shell-created directory mode770; exact test directories changed755 and unchanged app passed.

## 25. Runtime Benchmark — PASS (ENGINEERING ONLY)

| Environment | Load | First inference | p50 | p95 | Process RSS delta |
|---|---:|---:|---:|---:|---:|
| Windows Flutter FFI | 87.040ms | NOT RECORDED | 0.248ms | 0.411ms | 4538368 bytes |
| Android x86_64 Release emulator | 111.334ms | 91.069ms | 1.068ms | 8.244ms | 33394688 bytes |

56 fixture calls; timings include isolate initialization, OS scheduling and async overhead, not camera FPS. Windows RSS starts after native load; Android RSS starts before load and includes Flutter/FFI plus two native sessions (parity session + typed evaluator). NOT model allocator-only RAM; measurements are not directly comparable, not real-device benchmark/clinical performance.

Actual logcat evidence:
```
BODY_R5_SMOKE PASS rows=56 maxError=1.9868214962137642e-8 loadUs=111334 firstUs=91069 p50Us=1068 p95Us=8244 rssDelta=33394688 typed=PREDICTED
BODY_R5_SMOKE DEFAULT_OFF PASS
```

## 26. Tests — PASS focused / FAIL full baseline

| Executed command / scope | Result | Ignored local evidence |
|---|---|---|
| flutter test --no-pub test/features/rehab_ml (default OFF, initial focused) | 162/162 PASS | .dart_tool/body-r5/focused.log |
| flutter test --no-pub test/features/rehab_ml/body_ml_runtime_test.dart test/features/rehab_ml/body_research_session_test.dart test/features/rehab_ml/body_review_ui_test.dart | 64/64 PASS (final) | .dart_tool/body-r5/core-final3.log |
| flutter test --no-pub --dart-define=BODY_ML_ENGINEERING_VALIDATION=true tools/body_ml_native_parity_test.dart test/features/rehab_ml/body_ml_runtime_test.dart | 45/45 PASS, including actual56-vector FFI parity | .dart_tool/body-r5/engineering-final.log |
| TV flutter test --no-pub test/features/rehab_ml/body_ml_runtime_test.dart test/features/rehab_ml/body_research_session_test.dart | 50/50 PASS | TV .dart_tool/body-r5-final2.log |
| flutter test --no-pub --machine (full suite ONCE) | 596 PASS / 7 FAIL | .dart_tool/body-r5/full-flutter.jsonl |
| python -m unittest discover -s ml/tests -q | 73/73 PASS | .dart_tool/body-r5/python-tests.log |
| python tools/verify_body_ml_fixture.py | all56 Python ORT vectors PASS | stdout; max error as above |
| master scoped analyze --no-pub lib/features/rehab_ml test/features/rehab_ml tools/body_ml_native_parity_test.dart tools/body_ml_validation_smoke.dart | 0 issues | .dart_tool/body-r5/analyze-final.log |
| TV scoped analyze (9 changed runtime/UI/test paths) | 0 issues | TV .dart_tool/body-r5-analyze-final.log |
| final normal Debug / Release; final TV Debug | PASS | debug-build-final.log / release-build-final.log; TV body-r5-tv-debug-final.log |
| isolated engineering / default-OFF Gradle assembleRelease | PASS | validation-direct-gradle.log / default-off-release-build-retry.log |
| Android isolated Release launch/parity | PASS | .dart_tool/body-r5/android-release-smoke.log |

Four safety tests added after the full suite were run focused, not a second whole-suite run. Do not add focused counts to596 and claim a later full result. Dart format applied to changed Dart sources/tests/tools. Final git diff --check PASS in master and TV; existing TV LF/CRLF warnings are not whitespace failures.

## 27. Existing Regressions — FAIL (seven retained)

Same seven tests explicitly recorded in Round4, not assumed resolved:
1. account_info_screen_test: Google state/email/account ID display — ZEGO pending800ms timer.
2. account_info_screen_test: account ID validation/update — same timer.
3. account_recovery_therapist_registration_test: successful therapist registration saves session — same timer.
4. friend_management_screen_test: account API resolves binding code — same timer.
5. training_result_history_page_test: selected patient only — invalid/non-numeric selected-patient fixture.
6. patient_training_videos_card_test: completed reps/play action — expected wording differs.
7. dual_screen_assisted_training_ui_test: assisted screen IP page — ambiguous text-field finder.

No tests deleted/skipped/relaxed; no unrelated repairs. Whole-repository tests are NOT all green.

## 28. New Regressions — PASS final focused; no remaining identified new failure

Initial test manually changed AppSession.userId without its change notifier; corrected fixture. Two session tests using60ms IO sleeps failed under concurrent build load; actual persistence completion boundary and exact waits fixed them without weakened assertions. Intermediate analyze wrong nonexistent path corrected to actual rehab_ml directory. Intermediate build/fixture failures described above. Final new tests/build/runtime checks pass; not a claim of exhaustive hardware regression.

## 29. Files Added — PASS

master:
- docs/BODY_RESEARCH_ROUND5_PROGRESS.md
- docs/BODY_RESEARCH_ROUND5_HANDOFF.md
- docs/BODY_RESEARCH_ROUND5_REPORT.md
- lib/features/rehab_ml/body_ml_contract.dart
- lib/features/rehab_ml/body_ml_evaluator.dart
- lib/features/rehab_ml/body_ml_advisory_controller.dart
- lib/features/rehab_ml/body_ml_advisory_card.dart
- test/features/rehab_ml/body_ml_runtime_test.dart
- test/features/rehab_ml/body_ml_test_support.dart
- test/fixtures/body_ml_engineering_bundle.json (35162 bytes, model18694 bytes, no patient data)
- tools/body_ml_native_parity_test.dart
- tools/body_ml_validation_smoke.dart
- tools/package_body_ml_fixture.py
- tools/prepare_body_ml_validation.py
- tools/verify_body_ml_fixture.py

TV: four body_ml_* shared files, local_ml_model_store.dart, ml_quality_evaluator.dart, onnx_ml_quality_evaluator.dart, two body_ml_* test files, engineering fixture and docs/BODY_RESEARCH_ROUND5_RUNTIME.md. No TV hand/Pi camera change.

## 30. Files Modified — PASS

master:
- lib/features/rehab_ml/local_ml_model_store.dart
- lib/features/rehab_ml/body_research_session.dart
- lib/features/rehab_ml/body_research_settings_page.dart
- lib/features/rehab_ml/therapist_research_samples_page.dart
- test/features/rehab_ml/body_research_session_test.dart

TV: body_research_session.dart, body_research_settings_page.dart, body_research_session_test.dart only. Backend: NONE. Seven TV generated desktop modifications predated this round and were preserved, not included in task commits.

## 31. Git Commits — PASS

master implementation: c3f70e9e25ab72faec96af4aff93e134c293bb7e; hardening: 0f8f0fc13f2a72bd99df6f514d71a3d37f95169d. TV implementation: 20291d16c48e8650332de2abbaf2dd7d16dfd2c5; hardening: 34bc367ed09ba62c9cbdf7026c998db76dde0e38; final documentation43901d0ae1269d162446b924e6570b27cd70fc9d. This report/progress/handoff receive a task-only master documentation commit; final SHA is in completion response / git log. Backend unchanged9871f96. No branch created or push/merge/deploy.

## 32. Git Status — PASS task preservation

master intended clean after final documentation commit; verify at completion. Backend main clean unchanged. TV retains exactly its seven pre-existing generated files: linux/flutter/generated_plugin_registrant.cc, .h, generated_plugins.cmake; macos/Flutter/GeneratedPluginRegistrant.swift; windows/flutter/generated_plugin_registrant.cc, .h, generated_plugins.cmake. Ignored builds/venv/artifacts/emulator userdata stay local; no private records/models committed as production assets.

## 33. Known Limitations — DATA_INSUFFICIENT / NOT RUN

- No reviewed real dataset, model, calibration or clinical validation. Synthetic cannot activate or rollback in production.
- master live phone collector remains legacy body-v1; it lacks immutable v3 pixel-aspect observations. No fake v1→v3 conversion. Shared finalized-v3 runtime and phone therapist v3 detail consumer work; live phone-v3 capture is NOT implemented this round.
- Features are 2D projected geometry, not clinical ROM; domain generalization unvalidated.
- Real approved activation/provenance and Android real-model/device performance: NOT RUN. Local controlled registry is not a signed remote governance service.
- Physical camera/motion/Pi/TV tests deliberately NOT RUN, not required; TV Release NOT RUN. No backend/database/deployment tests this round because unchanged/no access.
- Predictions ephemeral; no backend prediction persistence or managed model download added.

## 34. Technical Debt — NOT RUN future work

Reviewed real subject-grouped data, source-specific validation/calibration, signed/trusted distribution, actual deployment approval evidence, durable advisory metadata if required, safe phone-v3 observation migration and device-level performance. Resolve seven baseline tests separately; never silently call full suite PASS. Windows and Android RSS measurements should be replaced by comparable repeated profiling for a real approved artifact.

## 35. Round 6 Readiness — PASS engineering framework / DATA_INSUFFICIENT production

Framework and engineering parity/build gates ready for next explicitly authorized round; production model NONE. Do not start Round6 automatically. No research enablement, Lab MySQL, production deployment, Pi modifications or physical motion request. Disposable emulator stopped, original AVD and physical phone untouched.

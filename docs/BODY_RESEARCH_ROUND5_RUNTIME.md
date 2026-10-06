# TV shared Body ML runtime — Round 5

Existing branch codex/android-tv-client only; baseline18b5fb17fce608ebb62fd2e27c1692dc91c6c9b3. No new branch or whole master merge.

Implementation commits20291d16c48e8650332de2abbaf2dd7d16dfd2c5 and34bc367ed09ba62c9cbdf7026c998db76dde0e38. Corresponding masterc3f70e9 and0f8f0fc; backend main9871f96 unchanged. Full35-topic report lives on master at docs/BODY_RESEARCH_ROUND5_REPORT.md.

## What changed

- Added shared body_ml_contract/evaluator/advisory_controller/card; explicit body/schema3/standing_knee_raise five-feature typed runtime and strict tv_pi domain.
- Existing finalized BodyResearchSession schedules advisory outside camera hot loop; settings page shows advisory card; counts/hold/features/payload/consent/sync unchanged.
- Extended same model-store index. Store and legacy support abstractions were absent in TV; added local_ml_model_store, ml_quality_evaluator, onnx_ml_quality_evaluator dependencies so the shared typed catalog compiles. They do not start hand inference. PiHandSource remains legacy/out-of-scope, untouched.
- Test fixture18,694-byte ONNX only in test/fixtures JSON; no production asset. Engineering compile flag defaultOFF. Actual synthetic model cannot activate/rollback in production.
- Deterministic session pendingPersistence completion replaces fixed60ms waits with all previous assertions unchanged.

## Changed files

Added:
lib/features/rehab_ml/body_ml_contract.dart
lib/features/rehab_ml/body_ml_evaluator.dart
lib/features/rehab_ml/body_ml_advisory_controller.dart
lib/features/rehab_ml/body_ml_advisory_card.dart
lib/features/rehab_ml/local_ml_model_store.dart
lib/features/rehab_ml/ml_quality_evaluator.dart
lib/features/rehab_ml/onnx_ml_quality_evaluator.dart
test/features/rehab_ml/body_ml_runtime_test.dart
test/features/rehab_ml/body_ml_test_support.dart
test/fixtures/body_ml_engineering_bundle.json
docs/BODY_RESEARCH_ROUND5_RUNTIME.md

Modified:
lib/features/rehab_ml/body_research_session.dart
lib/features/rehab_ml/body_research_settings_page.dart
test/features/rehab_ml/body_research_session_test.dart

## Validation

- flutter test --no-pub test/features/rehab_ml/body_ml_runtime_test.dart test/features/rehab_ml/body_research_session_test.dart:50/50 PASS; .dart_tool/body-r5-final2.log.
- flutter analyze --no-pub on seven changed shared runtime/UI files and two test files:0issues; .dart_tool/body-r5-analyze-final.log.
- flutter build apk --debug:PASS; .dart_tool/body-r5-tv-debug.log (initial shared implementation). Final shared hardening source refreshed:PASS26.6s; .dart_tool/body-r5-tv-debug-final.log.
- TV Release/physical TV/Pi motions:NOT RUN, not required by Round5. Shared ONNX actual56-vector Windows and Android x86_64 Release parity on masterPASS, max error1.9868214962137642e-8. Not claimed as physical TV inference.
- git diff --check:PASS; pre-existing LF/CRLF conversion warnings only.

## Preserved existing working-tree changes

Seven generated desktop modifications predate this task and remain uncommitted:
linux/flutter/generated_plugin_registrant.cc
linux/flutter/generated_plugin_registrant.h
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugin_registrant.h
windows/flutter/generated_plugins.cmake

They were not restored, overwritten or included in task commits. TV/Pi camera, DPAD, navigation and body source architecture unchanged. Backend/DB/lab/Pi/production untouched. No push/deploy. No REAL_MODEL_AVAILABLE/VALIDATED/DEPLOYED; PRODUCTION_MODEL=NONE. Stop before Round6.

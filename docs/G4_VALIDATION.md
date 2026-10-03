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

## Stage E final automated validation (2026-10-03)

| Command / inspection | Actual result | Local evidence |
|---|---|---|
| `flutter test --reporter expanded` (once) | **FAIL overall: 469 PASS / 7 FAIL** | `.dart_tool/g4-full-flutter.log` |
| `flutter analyze` | **47 existing diagnostics: 44 info, 3 warnings, 0 errors** | `.dart_tool/g4-full-analyze.log` |
| `flutter build apk --debug` | **PASS**, assembleDebug 35.8 s | `.dart_tool/g4-debug-build.log` |
| `flutter build apk --release` | **PASS**, assembleRelease 123.0 s, minification retained | `.dart_tool/g4-release-build.log` |
| `git diff --check` | **PASS** | final command exit 0 |
| Backend branch/HEAD/status | **PASS**, clean main `7c55d1c7527d94ca0e23c50213f68f7e4f973d7a`, no changes | read-only Git checks |

Logs/build outputs are ignored local evidence, not private datasets or shipped research artifacts. Python 16/16 and Flutter focused 68/68 results above remain current; no full-suite rerun was needed for this final documentation update.

### Seven failures: reproduced, not hidden

| Test / case | Actual failure and baseline comparison |
|---|---|
| `account_info_screen_test`: 帳號資訊顯示 Google 狀態、Google Email 與帳號 ID | pending 800 ms AppSession ZEGO timer at teardown |
| `account_info_screen_test`: 帳號 ID 前端驗證且成功更新 | same pending timer |
| `account_recovery_therapist_registration_test`: successful therapist registration saves existing session | same pending timer |
| `friend_management_screen_test`: AppSession 無代碼時由 account API 取得並同步 | same pending timer |
| `training_result_history_page_test`: therapist history requests selected patient only | expected legacy repository request `15`, actual null from current REST path |
| `patient_training_videos_card_test`: shows actual completed reps and a play action | old `1次失誤` text assertion, current `1項訓練修正紀錄` |
| `dual_screen_assisted_training_ui_test`: 輔助螢幕 IP 連線頁使用新名稱並適應手機尺寸 | searches TextField ancestor of independent `通訊埠` label |

These exact cases/causes match CHAT_REALTIME_VALIDATION.md (458/7) and the independently reproduced earlier baseline in G35_VALIDATION.md. G4 adds eleven Flutter tests, yielding 469/7. A passing full suite is **not** claimed. All 47 analyzer diagnostics are outside the new research implementation; BodyTrainingScreen's two unchanged info diagnostics remain. Three warnings remain in history_screen.dart, home_screen.dart and mediapipe_service.dart.

### Actual APK and R8 inspection

Root: `C:/Users/kuoja/Documents/GitHub/tkuim_project/`

| APK | Size (bytes) | SHA-256 |
|---|---:|---|
| `build/app/outputs/flutter-apk/app-debug.apk` | 620509686 | `E49069E1FBCB1FEE3451F1513DEDDA282897A2616B3F55005758205BE31492AC` |
| `build/app/outputs/flutter-apk/app-release.apk` | 489512059 | `CACA921CE28F92ADE488EA203B89046A99CF261FC0BD7F1B074BFBE503A9AB2F` |

Zip inspected: original `assets/flutter_assets/assets/rtmdet.onnx` (20283006 bytes), `rtmpose_wholebody.onnx` (33531475 bytes), Android `assets/hand_landmarker.task` (7819105 bytes) remain packaged. ONNX Runtime + JNI present for arm64-v8a, armeabi-v7a and x86_64; MediaPipe Tasks vision JNI present for arm64-v8a and armeabi-v7a. No `assets/models/rehab_ml/model.onnx` or manifest bundled.

Release `configuration.txt` retains `-keep class ai.onnxruntime.** { *; }` and the existing MediaPipe GeneratedMessageLite field rule. `mapping.txt` retains original OrtSession/OrtEnvironment/OnnxTensor class names. No new R8 rule/dependency/native change. This proves packaging/build, **not** execution of a real RF model on Android; Python ORT success does not establish Android kernel/runtime compatibility.

## Release gates / manual acceptance (NOT RUN)

1. Supply professionally approved action/labels plus a fresh authorized export with valid independent review, consent, retention and adequate distinct participants. Do not put private exports/approval files into Git.
2. Run the documented Python training CLI; inspect real per-class counts, subject separation, precision/recall/F1/confusion matrix and numerical parity. Synthetic test metrics are not formal accuracy.
3. With the real candidate, verify Android Debug **and Release** model loading/output/class order, completed-rep-only classification, offline execution, measured latency/memory and background/dispose. The existing counter/plans must remain rule-based and independent of ML.
4. Verify missing/rejected model keeps existing skeleton and counting operational and displays unavailable rather than an AI label. Verify anatomical side semantics and local/cloud consent separation on device. No installation or hardware acceptance was performed this round despite an attached arm64 device.
5. Record human model-release approval before adding model assets. Threshold, if introduced, requires held-out validation; predicted probabilities are uncalibrated, not clinical reliability. Do not bypass this gate by editing approval flags alone.

Formal model/data readiness: **NOT READY**. Real-data training/metrics, device inference/performance, real patient end-to-end and deployment: **NOT RUN / BLOCKED by missing approved dataset/governance**. No backend tests required (backend read-only), no SQL/Render changes, no G5 started.

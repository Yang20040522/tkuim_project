# Round 3 Device Runtime Progress

## Baseline / scope
- master ab99571bf801f9671a5d37684052fec0672d5a47; TV 0d5f96b2a14f9c2f967e7f144a19f8b2a5f0663b; backend main c0b409e59e4588c7132f8d3449c0be5da1c73b8f.
- Existing branches only; no push/deploy/laboratory access/Pi changes. Local MySQL 12/12 PASS remains complete.
- Remaining only real runtime/E2E, not ML training/Round 4.

## Discovery
- RMX3371 Android 14 arm64 phone connected by adb d698e1fa; production app installed, do not overwrite/delete its data.
- No physical TV in adb. Existing Television_1080p AVD is x86_64 Android TV API 36; launched headless without modifying AVD config.
- Pi eth0 192.168.137.186 ports 22 and 8765 reachable. Batch SSH lacks authorized credentials (no guessing).
- Camera WebSocket PASS: three binary JPEG frames decoded in memory, 640x480, ~14KB each. No JPEG persisted.

## Isolation prerequisites
- Existing ApiConfig hardcoded production. Minimal API_BASE_URL compile-time override added on both branches; production default unchanged.
- Optional Gradle rehabValidationApplicationId added on both branches; normal application ID unchanged.
- Validation IDs: com.example.flutter_body.round3phone / com.example.flutter_body.round3tv.
- Build define API_BASE_URL=http://127.0.0.1:18083. Device adb reverse will map this to local host only.
- Temporary backend bound 127.0.0.1:18083, exact rehab_body_r3_validation, Hibernate validate. Test-only process research=true/synthetic consent version; not production activation.
- Backend exec session 49282 was stopped at cleanup; log target/body-r3-device-runtime.log is historical. No current test backend or reverse mapping remains.
- All validation build sessions finished. Do not run Flutter tests/builds concurrently in the same worktree.

## Files changed
- Both branches lib/core/api_config.dart, android/app/build.gradle.kts.
- master test/core/api_config_validation_test.dart.
- This checkpoint; subsequent evidence/report as runtime proceeds.
- TV preexisting seven generated desktop line-ending-only changes preserved.

## Remaining / cleanup
### Latest actual Release evidence
- 15 actual TV/Pi body v3 samples uploaded. Five fresh samples point to the original NEEDS_RESAMPLE sample; original remains immutable. Two sessions have different streamSessionIds, each sampled frame agrees with its sample stream metadata. TV second result shows 1 official rep.
- Phone independent review UI APPROVE and NEEDS_RESAMPLE PASS; real HTTP RETURN/REJECT PASS. Stale revision 409 and patient annotation 403 PASS. First ad-hoc test used a non-contract label and correctly got INVALID_RESEARCH_LABEL/400; reran only after reading unassessable from registry.
- Isolated DB: 12 annotation revision rows, 15 SAMPLE_UPLOADED audits, 4 drafts/submissions and one each APPROVED/RETURN/REJECT/NEEDS_RESAMPLE. Zero extra users outside the four captured fake accounts.
- Phone Release hand initialization: CameraX frame, native LIVE_STREAM Hand Landmarker/model/JNI and landmark EventChannel PASS. UI shows a real 61-degree side-pinch result and feedback. Completion screen has 0 reps/0:00, so full hand rep acceptance is NOT yet PASS. Requested explicit user confirmation; legacy training EventChannel MissingPluginException is nonfatal and not the Dart side-pinch counter source.
- Phone test package reset/reinstalled ONLY com.example.flutter_body.round3phone to change fake sessions (long synthetic reviewer name overflows existing logout hit area). OS denied pm clear, normal uninstall/reinstall succeeded; original com.example.flutter_body untouched. No UI fix hidden in this runtime scope.
- Release APK hashes: phone AF009118172B00D5158EE6B3200E0DD9C5FD36F0431443046439E0F1CB9DF7AE; TV 10FA79038C50E2E3AC98885C06FCB06D378AA4BE965471FF9A25053471963016.
- Both APKs include RTMDet/RTMPose assets and arm64/armv7/x86_64 ONNX. Phone includes hand model and ARM MediaPipe JNI. Existing TV hand assets are inherited legacy, not a formal TV research path.
- Read-only device clock check: TV emulator September 8 vs phone/host October 6. No clock change. Body capturedAt is context/session start; monotonic frame intervals remain meaningful; server expiry starts at uploadedAt.
- User final acceptance: phone body camera/skeleton and hand bone/voice/count questions answered "正常，不用再測試了". No more runtime testing after this instruction. User-observed acceptance is recorded separately from automatic rep screenshots (0-rep completion was observed once).
- CLEANUP COMPLETE: apps force-stopped, exact fixture Cleanup succeeded; all 29 original tables remain and all 29 row counts are zero. Temporary backend process/listener stopped; own tcp:18083 reverse mappings removed; validation packages uninstalled; original phone package still installed. Owned TV emulator stopped. Only named diagnostic screenshots/UI dumps removed; no Pi service/network change.
- Remaining: document/commit owned isolation changes; physical TV, strong stale-generation injection, timeout and positive counted-rep-inside-sample evidence remain NOT RUN. No Round 4/push/deploy.
- Following user assistance, TV Release result shows 1 official rep. 10 actual uploaded samples now include RETURNED_TO_BASELINE/features available and valid non-counted attempts. Sample source remains tv_pi/body/v3.
- Phone Release skeleton PLAY really advances to frame 26/26; inspected visible skeleton (unavailable edges omitted), not just a JSON response.
- Phone AUTHOR unable-to-assess draft revision 1 -> submit revision 2 -> different REVIEWER needs-resample/LOW_QUALITY revision 3, actual UI PASS.
- Actual available-feature TV sample: real HTTP AUTHOR draft/submit (explicit synthetic workflow annotation, NOT clinical); self-review 403. Different REVIEWER phone UI approval revision 3 PASS.
- Manager real HTTP export inspected in memory: manifest sampleCount=1, only the approved available-feature sample; needs-resample and unlabeled samples excluded. No training or saved export file.
- TV new session shows original needs-resample entry from backend; selected next-attempt linkage in UI, local/cloud re-enabled, real Pi reconnected. Waiting for a fresh attempt; link not yet verified.
- TV Release background/home/return preserves page and reconnects UI without crash. Strong stale-publication/timeout proofs still NOT RUN; do not infer from this alone.
- TV Release connects to the real Pi stream; screenshot inspection confirms RTMPose skeleton on the visible frame. Only lower body visible in current view; do not claim a complete standing-motion sample.
- CURRENT TV Release session local/cloud checkboxes both true; 6 local samples, pending 0, UI says synced. Backend really contains 6 body v3/tv_pi samples (no hand pipeline on TV).
- Phone Release fake AUTHOR refresh lists the uploaded samples, opens detail with 17-point player and actual schema/extractor/model/source/termination metadata.
- First sample TRACKING_LOST/features unavailable/official reps 0 -> 0; marked unable-to-assess via phone UI, draft revision 1 saved, submitted. No fabricated successful label or export.
- Requested full body (shoulders through ankles) for another standing attempt; awaiting user movement. TV clock is September 8 while host task date October 6: capturedAt follows device, server-created retention unaffected; record this discrepancy, do not silently change device clock.
- Switching phone validation package to independent fake REVIEWER; original production package untouched.
### Runtime checkpoint
- Phone Debug login/binding/research authority/list UI PASS. Initial research requests blocked by existing HTTPS-only client; added default-off `RESEARCH_LOCAL_VALIDATION` allowing ONLY the explicitly compiled http://127.0.0.1:18083 endpoint, never LAN/remote. Normal HTTPS policy unchanged.
- Compile-time API/security tests 2/2 in default mode and 2/2 in validation mode on BOTH branches; master cloud/errors/security focused tests 22/22 PASS. Scoped analyze both branches 0 issues.
- TV Debug real Pi stream connected and training completed 4 reps, 633 seconds (actual UI). Initial collection remained OFF, so no claim of sample upload yet.
- Local/cloud opt-in performed in fake TV patient research UI after starting another session. Release isolation builds successful, installing to validation packages only; final native builds use explicit Gradle -P application ID and comma-separated base64 dart-defines.
- Existing root release APK copies and production-installed phone package unchanged. Production/lab DB untouched.
- Debug isolated packages built and installed on phone/TV emulator. Flutter did not propagate the environment-only applicationId property; explicit Gradle `-PrehabValidationApplicationId=...` succeeded, verified by APK metadata before installation.
- Temporary backend started with Hibernate validate, localhost:18083; fixtures created through real HTTP registration/binding/assignment APIs plus isolated manager bootstrap SQL only.
- Baseline users/samples/policies = 0. Four fake accounts and one test-only retention policy tracked in backend ignored `.local/body-r3-device.credential.xml` (Windows DPAPI). No consent automatically enabled; no samples seeded.
- Fixture tool `tools/body-round3-device-fixtures.ps1` supports exact Cleanup, no table clear.
- TV Debug login actual UI PASS: `ROUND3 SYNTHETIC PATIENT`. Both validation adb reverse mappings now tcp:18083.
- Phone/TV isolated Release build sessions 66321 / 41414; preserve Debug APKs under ignored `.dart_tool/body-r3-device/`.

1. Read BODY_RESEARCH_ROUND3_DEVICE_REPORT.md first. Preserve completed upload/label/review/export/resample evidence; do not recreate these modules.
2. User requested no more testing now. Future authorized manual acceptance: physical TV, controlled stale/timeout behavior, counted-rep-inside-sample evidence, phone Debug motion/independent positive hand count if required.
3. Backend fixture checkpoint is Cleaned=true; guarded Setup may create new fake accounts only after exact empty-schema guards. Current accounts were deleted. No migration rerun.
4. No Round 4, push, lab database access or production deployment. Keep the three environment statuses separate.

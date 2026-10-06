# Round 3 TV Device Runtime

Status: PARTIAL. User requested no more testing; remaining items not relabeled PASS.

## Actual environment / baseline
- Existing codex/android-tv-client baseline 0d5f96b2a14f9c2f967e7f144a19f8b2a5f0663b; no new branch, push or deployment.
- Android TV API36/x86_64 emulator, not physical TV. Real Pi ws://192.168.137.186:8765, JPEG 640x480.
- Local backend ONLY localhost:18083 / rehab_body_r3_validation, Hibernate validate. Laboratory NOT VALIDATED; production NOT DEPLOYED.

## PASS evidence
- Debug login/navigation, real Pi stream, skeleton/feedback and 4 official reps. Research was OFF in this first session.
- Release fake-patient login, Pi stream/RTMPose and opt-in local/cloud collection, 15 actual body/v3/tv_pi test-motion uploads (not fake generated landmarks).
- Two Release result screens each showed 1 rep. Valid uncounted attempts and tracking-loss/unavailable-feature attempts retained honestly.
- Real phone master AUTHOR draft/submit -> separate REVIEWER approval/needs-resample -> manager approved export sampleCount=1.
- TV needs-resample selector -> fresh Pi attempt -> 5 uploads linked to original sample, no overwrite.
- Inspected frames share one stream ID per sample; new connection/session changes streamSessionId. Background/return did not crash.
- No formal TV hand research/PiHandSource integration; inherited hand assets remain legacy.

## Limits
- Physical TV, controlled timeout, stale-generation injection and positive rep increment inside an uploaded sample: NOT RUN.
- Emulator clock September 8 vs host/phone October 6; no clock change. Monotonic frame intervals still used; server expiry uploadedAt.
- No clinical annotation/model accuracy claim. Test-only labels and accounts were removed.

## Minimal isolation changes
- API_BASE_URL compile-time override, production default unchanged.
- RESEARCH_LOCAL_VALIDATION default false; only explicit http://127.0.0.1:18083 allowed through research transport, never LAN/remote HTTP.
- Optional Gradle rehabValidationApplicationId; default package unchanged. Separate round3tv validation package verified before install.
- test/core/api_config_validation_test.dart: 2/2 in default mode, 2/2 in local validation mode. Scoped analyze 0 issues.
- Debug and Release builds PASS; no inference/native/R8 changes. No full suite rerun this runtime-only phase. Previous full suite 545 PASS/7 FAIL retained, not claimed all-pass.
- Explicit Gradle -P application ID needed; environment-only property not propagated. Standard pub generation needed before final release (stale --no-pub registrant otherwise).

## Cleanup
- Exact four-account local fixture cleanup succeeded. All 29 existing tables remain, all row counts zero.
- Temporary backend, own reverse tcp:18083, validation packages and owned emulator stopped/removed. Original phone app and Pi server/network untouched.
- Seven prior generated desktop line-ending-only modifications preserved unstaged; no restore/reset/discard.
- Full cross-repository 21-section report: mobile master docs/BODY_RESEARCH_ROUND3_DEVICE_REPORT.md and backend same path.
- Do not start Round 4. Minimal remaining hardware steps are in that report.

## Artifact
TV loopback validation APK retained ignored at mobile .dart_tool/body-r3-device/tv-release.apk.
SHA-256 10FA79038C50E2E3AC98885C06FCB06D378AA4BE965471FF9A25053471963016.
Not a production APK; existing release/ copies unchanged.

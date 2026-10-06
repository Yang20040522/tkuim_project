# Body Research Round 3 TV Progress

## Branch and checkpoints
- Existing codex/android-tv-client branch only; Round 2 checkpoint 2a0b10b95e95b5e7c29ff41f2815c258bf26d84d.
- Verified Round 3 implementation 968d8a4be92c4a9696db7944001b4d187ce33ad4; compatible mobile master 1326472811298223182d009c252645e1da5a9610 and backend main 6048bf32e6bccb6ae694297e68a57a600d41157b.
- No new branch, whole-branch merge, push, deploy, native or Pi changes.
- Worktree relocated to .worktrees/round2-tv; pub get refreshed stale tool paths.

## Completed
- Patient settings refresh current NEEDS_RESAMPLE body v3 records for the assigned DEFAULT exercise only.
- Show reason and read authorized review detail (note, reviewer, time, revision).
- Explicit selection between attempts; fresh collector/context preserves training counters and session grouping.
- New sample/attempt IDs carry resampleOfSampleId; old files/payload never overwritten.
- Both local and cloud opt-in remain separate. Backend rechecks owner/binding/disposition/consent.
- PiHandSource remains legacy, not part of formal research. No TV hand integration.

## Tests
- Focused body tests PASS 35/35 (including 2 new resample tests).
- Scoped analyze PASS, 0 issues. Debug and Release builds PASS.
- Final focused recheck after review-note UI changes PASS 35/35.
- Release APK build/app/outputs/flutter-apk/app-release.apk: 497865175 bytes; SHA256 5476953729725CFAFF4FF98F5BDE15C2A59358FEC48ECF1928F751F0EF83F1C5.
- APK RTMDet/RTMPose assets and ONNX native libraries verified. Native/Gradle/R8/pubspec/lock unchanged. Legacy hand assets are not formal TV hand research.
- git diff --check PASS. Only owned research files included in local checkpoint.
- Round 2 historical Debug PASS; do not substitute for current build.

## Environments
- Local Windows rehab_body_r3_validation: owner V005 complete; actual 29 tables/257 columns/34 FK, Hibernate and 12/12 real MySQL cases PASS on 2026-10-06. All 29 tables empty after fixture cleanup.
- Laboratory MySQL NOT RUN/NOT VALIDATED; production NOT DEPLOYED. Do not connect either environment.
- Pi TCP endpoint reachable; actual Pi->TV inference/collector and TV hardware NOT RUN.

## Remaining
1. Real Pi/TV synthetic E2E and release runtime still require hardware and explicitly isolated API configuration.
2. Capture hardware acceptance in master docs/BODY_RESEARCH_ROUND3_REPORT.md; stop before Round 4.
3. Backend local validation evidence: docs/BODY_RESEARCH_ROUND3_MYSQL_VALIDATION.md. Laboratory NOT VALIDATED, production NOT DEPLOYED; do not conflate with local PASS.

## Existing changes to preserve
Generated desktop plugin files had line-ending-only status before Round 3. Do not restore/stage unrelated artifacts.
Do not redo Round 2 or start Round 4.

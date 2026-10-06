# Round 3 Device Runtime Acceptance

## 1. Device Inventory

- Actual phone: RMX3371, Android 14, arm64, adb d698e1fa.
- Android TV: existing Television_1080p emulator, API 36/x86_64. No physical TV available.
- Real Raspberry Pi camera endpoint: 192.168.137.186:8765. Network/service unchanged.
- Original phone package com.example.flutter_body retained. Separate validation packages round3phone/round3tv used, then uninstalled.

## 2. Pi Connectivity

TCP 22/8765 reachable. SSH authentication NOT RUN (no authorized key; no password guessing).
No changes to eth0, wlan0, hotspot, dnsmasq, ICS or camera_server.py.

## 3. Pi Camera Runtime

PASS: real binary WebSocket JPEG, three frames decoded in memory at 640x480, then used by TV live camera.
Camera server PID/IMX500 identity not independently confirmed by SSH. No JPEG/video in research payload.
Temporary UI diagnostic screenshots were removed after inspection; no original camera data committed.

## 4. TV Debug Runtime

PASS on emulator with real Pi: fake patient login, navigation, camera, RTMPose overlay/feedback and 4 official reps.
Research was OFF during the first training; no claim that these four reps were uploaded.

## 5. TV Release Runtime

PASS on emulator with real Pi: login, Pi camera/RTMPose, research opt-in and upload; two completed training result screens each showed 1 official rep.
Physical TV Release runtime: NOT RUN. Existing minify/shrink settings unchanged.

## 6. RTMPose Runtime

Visible real skeleton aligned to the displayed legs; body feedback changed with the live pose.
Partial framing initially caused tracking-loss/unavailable features, correctly retained as such.
No new model/session pipeline, no MediaPipe Hand research on TV, no PiHandSource integration.
Both APKs contain RTMDet/RTMPose assets and arm64/armv7/x86_64 ONNX libraries.

## 7. Observation / Frame Pairing

Actual inspected samples contain frame IDs, timestamps, 640x480 image size, validity, scores and streamSessionId.
Inspected available sample has frameId 7542..7636; inspected five resamples each have one internally consistent stream ID.
Two separate live camera sessions have different stream IDs. Visual overlay alignment checked.
Injected delayed/stale-generation publication and exact pixel-to-frame instrumentation: NOT RUN; prior deterministic tests are not substituted for runtime proof.
TV emulator clock was September 8 while phone/host were October 6; not changed. capturedAt follows session context, frame timing is monotonic, server retention expiry uses uploadedAt.

## 8. Attempt Collector Runtime

15 actual Pi-camera test-motion samples, all body/v3/tv_pi, using four fake local accounts; not random/generated landmark fixtures.
TRACKING_LOST and RETURNED_TO_BASELINE samples observed; valid attempts without an increment also observed.
Some features unavailable, others available (example valid ratio 0.857, duration 5.542s).
Official counters remain independent. Screens show a positive rep, but an uploaded sample with completedRepsAfter > completedRepsBefore was NOT independently captured.
Timeout termination: NOT RUN. User asked to stop further testing.

## 9. Upload Result

PASS: TV local list initially 6 / pending 0 / synced; backend really received them, eventually 15 samples.
Only localhost:18083 + adb reverse + rehab_body_r3_validation used.
Independent local/cloud consent remained explicit and session-scoped. No consent/model enabled in production.

## 10. Therapist Phone Runtime

PASS: actual master phone Release fake AUTHOR lists TV + Pi body samples, opens details and version/feature summaries.
Skeleton player really advanced to frame 26/26; visible bones inspected. Invalid points omitted, not invented.
Phone Debug login/binding/authority/list UI also passed.
Source/modality shown correctly; source-filter selection and artificially injected timing-gap display not separately exercised on device.

## 11. Annotation Result

PASS actual phone UI: low-quality sample unassessable draft revision 1, submit revision 2.
Another available-feature sample used a real HTTP draft/submit with an explicit synthetic workflow note and insufficient_range label; NOT a clinical assessment.
No professional labels or model training claimed.
Actual isolated DB contained 12 immutable revision rows and matching draft/submit audits.

## 12. Independent Review Result

PASS actual different fake REVIEWER phone UI: NEEDS_RESAMPLE/LOW_QUALITY revision 3 and APPROVE revision 3.
PASS real HTTP: RETURN and REJECT revision 3; self-review 403, patient annotation 403, stale revision 409.
An ad-hoc request first used an invalid label and got 400 INVALID_RESEARCH_LABEL; corrected to the existing unassessable contract, no application change or weakened validator.
All four review actions have actual audit records. Return/Reject UI buttons were not separately tapped.

## 13. Needs Resample Result

PASS: phone review -> TV shows original sample/reason -> explicit next-attempt selection -> new Pi attempts -> real backend upload.
Five new samples link to the original NEEDS_RESAMPLE ID; old sample not overwritten.
Available and unavailable resamples retained honestly; they were not automatically approved.

## 14. Approved Export Result

PASS real manager HTTP export, inspected in memory: manifest sampleCount=1, only the approved available-feature body/tv_pi sample.
Needs-resample and unreviewed samples excluded. Later REJECT persisted; no additional export after user stopped testing.
Consent-revoked export exclusion remains PASS in the earlier 12/12 real-MySQL suite, not rerun on this runtime dataset.
No file published, no model trained, test labels/data not formal clinical evidence.

## 15. Phone Debug Runtime

PASS: separate package login, therapist binding and research authority/list UI.
Phone Debug body/hand motion acceptance: NOT RUN this device round; do not substitute Release results.

## 16. Phone Release Runtime

PASS: actual patient/therapist login, review/list/player, native hand LIVE_STREAM/model/JNI/CameraX/landmark-channel initialization.
Side-pinch UI showed real angle 61 degrees and pinch feedback. User final body-camera/skeleton and hand bone/voice/count questions answered: "正常，不用再測試了".
User acceptance recorded; automatic completion capture once showed 0 reps/0:00, so no independently recorded positive hand count is claimed.
Nonfatal existing MissingPluginException on com.rehabassist/training recorded. Side-pinch/turn-palm counters use Dart landmark actions, not that legacy stream. No unrelated fix added.
Phone R8 rules and inference dependencies unchanged; release contains hand_landmarker.task and ARM MediaPipe JNI.

## 17. Isolated DB Cleanup

PASS: exact four-account fixture manifest guards, transaction cleanup, no table clear or migration replay.
All 29 existing tables retained, all 29 row counts zero. 15 samples, labels/revisions/audits/test policy/accounts removed.
Temporary localhost backend stopped, validation apps uninstalled, own reverse mappings removed, owned emulator stopped.
Pi service and original phone app retained. Laboratory MySQL NOT VALIDATED; production NOT DEPLOYED.

## 18. Git / implementation scope

Baselines: master ab99571bf801f9671a5d37684052fec0672d5a47; TV 0d5f96b2a14f9c2f967e7f144a19f8b2a5f0663b; backend main c0b409e59e4588c7132f8d3449c0be5da1c73b8f.
Both Flutter branches: compile-time API_BASE_URL; default-off loopback-only RESEARCH_LOCAL_VALIDATION; optional validation application ID; two focused security tests.
master also adds runtime UI helper/checkpoint/report. Backend adds guarded synthetic account fixture Setup/Status/Cleanup tool and runtime report.
No new branch, push, deploy, business/schema/inference/R8 edits. Existing TV seven generated desktop line-ending-only modifications remain uncommitted/preserved.

## 19. Test / acceptance matrix

| Item | Actual result |
|---|---|
| Existing local MySQL suite | 12/12 PASS; 29 tables, 257 columns, 34 FK |
| Existing backend suite/package | 298 PASS / 33 skipped / 0 failed; package PASS; not rerun this runtime-only round |
| master cloud/errors/API config tests | 22/22 PASS |
| Config tests, each branch default and local mode | 2/2 per invocation, four invocations PASS |
| Scoped analyze, both branches | 0 issues |
| Debug/Release isolated builds, both branches | PASS; actual separate IDs checked before install |
| Existing complete Flutter suite | 545 PASS / 7 FAIL; not rerun or misreported as all-pass |
| Pi JPEG -> TV Release -> body sample -> phone label/review -> export | PASS on TV emulator + physical phone + real Pi |
| Needs-resample new-device-attempt linkage | PASS |
| Physical Android TV | NOT RUN |
| Injected stale-generation, timeout, counted-rep-in-sample proof | NOT RUN |
| Phone positive hand rep, independent instrumentation | NOT RUN; user reports normal |
| Phone body/hand Debug motion | NOT RUN |
| Laboratory / production | NOT VALIDATED / NOT DEPLOYED |
| Three repository diff checks / helper parsers | PASS |

Seven prior Flutter failures remain fully recorded in BODY_RESEARCH_ROUND3_REPORT.md (ZEGO timers, patient-ID fixture, history wording, IP-field finder); no tests skipped/deleted to disguise them.

## 20. Round 3 Final Status

PARTIAL: key actual device-to-backend-to-review/export and resampling paths pass, but physical TV and the explicitly unexecuted runtime acceptance items above remain open.
No production readiness, clinical accuracy or formal model claim.

## 21. Round 4 Readiness / next session

Do not start Round 4 automatically. Preserve completed work; do not rerun MySQL migrations or recreate modules.
Minimal remaining manual acceptance: physical TV with Pi framed shoulders-to-ankles; capture a rep-increment sample; controlled stale/timeout behavior; phone Debug body/hand and independent positive hand-count evidence if still required.
User requested no more testing in this session. Future test accounts must be newly generated by guarded setup; current ones were deleted, no credentials in this report.

## Reproducible isolated install

Normal builds retain the production endpoint and application ID. Validation ONLY:

1. Guarded backend fixture tool in rehab_body_r3_validation; DPAPI app credential already local. Temporary server localhost:18083/Hibernate validate, random process secrets, synthetic consent and test-only policy. Never change Render/lab.
2. Flutter build with `--dart-define=API_BASE_URL=http://127.0.0.1:18083 --dart-define=RESEARCH_LOCAL_VALIDATION=true` (normal pub generation; no stale --no-pub release plugin registrant).
3. Final native Gradle assembleDebug/assembleRelease with `-PrehabValidationApplicationId=com.example.flutter_body.round3phone` or round3tv, and base64 comma-joined `-Pdart-defines`. Environment-only ORG_GRADLE_PROJECT was not propagated here; always check aapt package before install.
4. Own adb reverse tcp:18083, fake accounts only, explicit session opt-in, then exact cleanup and stop.

Preserved ignored artifacts: .dart_tool/body-r3-device/phone-release.apk and tv-release.apk.
SHA-256 phone: AF009118172B00D5158EE6B3200E0DD9C5FD36F0431443046439E0F1CB9DF7AE.
SHA-256 TV: 10FA79038C50E2E3AC98885C06FCB06D378AA4BE965471FF9A25053471963016.
These are LOCAL LOOPBACK VALIDATION APKs, not production replacements. Existing release/ APK copies unchanged.

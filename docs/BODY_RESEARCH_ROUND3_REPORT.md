# Body Research Round 3 — Implementation and Validation

Status: PARTIAL. Core implementation, mock/widget and real local isolated MySQL validation complete;
Pi/TV device E2E and release runtime acceptance remain NOT RUN. Not Round 4 ready.

## 1. Round 2 Validation Gate

Round 2 local checkpoint commits: master `3e6d013184104898596e82e2a580006145c1b05d`,
TV `2a0b10b95e95b5e7c29ff41f2815c258bf26d84d`, backend `45c7bbb0fc3b4aa09d22a212bf7b92c764e9f36c`.
V001–V004 local migration/metadata PASS: MySQL 8.4.11, 29 tables, 253 columns.
Do not replay these migrations. V005 was subsequently applied by owner; 2026-10-06 actual metadata and Hibernate PASS: 29 tables/257 columns/34 FK.
Earlier V005 absence/NOT RUN checkpoint is preserved in backend continuation evidence; it is no longer the current gate.

## 2. Implementation Summary

Existing therapist mobile UI, REST research API, consent/binding/authority, owner-isolated
repository and body collector reused. No duplicate player, research app, pose engine or notification service.
TV/Pi full-body RTMPose only; phone MediaPipe hand unchanged. No classifier training/deployment.

## 3. Therapist UI Changes

Existing list supports modality/source/anonymous participant/exercise/session/annotation/disposition filters.
Labels distinguish Phone Body, Phone Hand and TV + Pi Body. Explicit load/refresh, no new polling.
Both sample and review queue pages fetched up to 500 records; larger studies require future server filters/paging UI.
Body detail includes 2D RTMPose, schema/action/extractor/model versions, timing origin, termination,
tracking quality and set/rep snapshot. Five features display units and unavailable (never zero-filled).
Playback uses actual observation intervals, skips invalid/null/nonfinite points, marks >=500ms gaps,
keeps image aspect ratio and does not interpolate missing joints. Background/logout stops playback and clears cached detail.

## 4. Review State Machine Result

Mock/widget tests PASS: UNLABELED -> DRAFT -> SUBMITTED; RETURNED -> DRAFT.
APPROVE = APPROVED + ACTIVE; RETURN = RETURNED + ACTIVE;
REJECT = RETURNED + REJECTED; NEEDS_RESAMPLE = RETURNED + NEEDS_RESAMPLE.
Valid insufficient_range labels can be approved. Rejection means unsuitable data, not poor rehabilitation performance.
v3 writes require expectedRevision and labelVersion body-attempt-label-v1; reviewer/note/reason/time/revision/audit snapshot recorded.

## 5. Needs Resample Result

Mock/widget PASS. Patient/TV settings manually refresh authorized matching NEEDS_RESAMPLE rows,
show reason and review detail, and select a parent only between attempts.
New attempt/sample IDs carry resampleOfSampleId; parent payload stays immutable; counters unchanged.
Selection is explicit and cancellable, not automatic recording/consent. Server rechecks owner,
same exercise/type, active current consent and nonexpired parent disposition.
Actual local MySQL linked sample lifecycle PASS, including immutable parent, new child and separate review.

## 6. Authorization Result

Backend focused tests PASS: unauthorized/unbound 403, self-review 403 (also managers), stale revision 409,
locked approved annotation 409. UI visibility is not authorization. Existing HMAC/grant/binding logic preserved.
v3 upload serializes on consent row with READ_COMMITTED; edits lock sample before first annotation insert.
Real local MySQL concurrent duplicate retry and first-draft revision race PASS.

## 7. Export Result

Seven new backend export tests PASS. v3 requires explicit source phone or tv_pi; no implicit pooling.
Only independent APPROVED + ACTIVE, current consent, nonexpired, valid schema/features/version/label,
non-DEMO data accepted. Invalid JSON/validator failures skipped. unassessable excluded.
Manifest retains schema/action/extractor/input/model/source and pseudonymous subject/session/attempt groups.
No names/email/raw patientId/therapistId/auth token; resample parent ID omitted. Legacy exports remain separate.
Management UI exposes v3 source selector. Actual local MySQL approved source-specific export,
RETURN/REJECT/NEEDS_RESAMPLE exclusions and consent-revoked exclusion PASS.

## 8. MySQL Migration Validation

| Environment | Actual status |
|---|---|
| Local Windows rehab_body_r3_validation | V001–V005 metadata/Hibernate/CRUD/API/concurrency PASS (12/12 real MySQL cases) |
| Laboratory MySQL (actual future project database) | NOT RUN / NOT VALIDATED; not connected |
| Production / Render | NOT DEPLOYED; no settings/data changed |

V005 adds nullable resample parent/reason/revision disposition and self FK ON DELETE SET NULL.
Measured after owner V005: MySQL 8.4.11, 29 tables / 257 columns / 34 FK.
V004 development-only CHECK adds REJECTED; V001–V003 unchanged.
No data collection enabled, no actual participants/consent/policy seeded by this round.

## 9. Pi / TV Hardware Validation

Pi TCP 192.168.137.186:8765 reachable (connectivity only).
Real JPEG->TV->RTMPose->observation->collector, camera disconnect/reconnect/background,
same-frame runtime and TV Release launch NOT RUN. Only an Android phone appears in adb, no TV.
Network/Hotspot/eth0/camera_server/Pi packages untouched; PiHandSource not formally integrated.

## 10. Fake E2E Result

Layered synthetic Flutter widget/API and backend service tests PASS, not an end-to-end hardware PASS.
Actual local MySQL tests cover metadata, duplicate/conflict/attempt uniqueness,
v1 body/v2 hand nullable compatibility, authenticated upload->independent review->export,
immutable resample->new lifecycle, revoked/unrelated isolation, concurrent upload/first draft.
PASS 12/12 expanded cases. Authenticated controller requests use MockMvc backed by actual MySQL;
this is not Android/Pi/TV UI or external-network E2E. Normal collection bean remains false;
test-only primary synthetic bean permits fake fixtures. Transactional tests rollback;
concurrent test commits ephemeral fixtures then cleans only exact generated IDs in finally.
Post-test exact row counts: all 29 tables zero. No schema/data clear or automatic collection activation.

## 11. Phone Debug / Release Build

PASS both builds. Release path: build/app/outputs/flutter-apk/app-release.apk, 489954427 bytes.
SHA256 AAB25C5E54EE1E754B934DB27E81287DFBD249422B70EF49ECAA7619DE67CD5F.
APK inspected: RTMDet, RTMPose, hand_landmarker.task and ARM MediaPipe/ONNX native libraries present.
R8/native/Gradle/pubspec/lock unchanged. Release initially failed with --no-pub because stale
registrant referenced dev-only flutter_native_splash; full flutter build apk --release regenerates correctly and PASS.
Do not use stale debug/test registrant for release. Phone Release actual runtime NOT RUN (no production-connected app installed/launched).

## 12. TV Debug / Release Build

Debug PASS; Release PASS. Final focused TV recheck after review-note UI changes: 35/35 PASS.
TV APK: .worktrees/round2-tv/build/app/outputs/flutter-apk/app-release.apk, 497865175 bytes.
SHA256 5476953729725CFAFF4FF98F5BDE15C2A59358FEC48ECF1928F751F0EF83F1C5.
APK inspected: RTMDet/RTMPose and ARM/x86_64 ONNX native libraries present.
Native/Gradle/R8/pubspec/lock unchanged. Legacy hand asset presence is not formal TV hand integration.
Runtime NOT RUN. No formal hand research route added.

## 13. Backend Test Result

Focused 58/58 PASS. Latest full mvn test: 328 discovered, 298 PASS, 30 skipped,
0 failures/errors. Skips: 22 old MySQL tests, 7 new local MySQL tests, one gated activation test.
Maven package -DskipTests PASS. H2 chat tests are not MySQL evidence.
Historical artifacts: backend target/body-r3-full-maven.log, target/body-r3-package.log and Surefire XML.
After V005 continuation: real MySQL 12/12 PASS; latest full Maven 331 discovered/298 PASS/33 skipped/0 errors,
package PASS. Full run omits DB_URL intentionally (10 Body test methods gated; separate MySQL run exercises 12 invocations).
Evidence: backend docs/BODY_RESEARCH_ROUND3_MYSQL_VALIDATION.md, target/body-r3-mysql-validation.log,
target/body-r3-post-v005-full-maven.log, target/body-r3-post-v005-package.log.

## 14. Flutter Test Result

master focused 61/61 PASS; TV final focused 35/35 PASS, including last note-display changes.
Full master flutter test once: 545 PASS / 7 FAIL. Later small owner/note changes received focused tests,
not another full suite. master/TV scoped analyze 0 issues. Full JSON artifact .dart_tool/body-r3-full-test.jsonl.
Initial synthetic lifecycle transition test failed paused->resumed; corrected realistic hidden/inactive transition and passed.

## 15. Pre-existing Failures

Same seven names/failing assertions as Round 2; affected source/tests not modified:
- Account info Google status and account-ID update (2 tests): AppSession ZEGO 800ms pending timer.
- Successful therapist registration: same timer.
- Friend-code AppSession account lookup: same timer.
- Therapist training history: selected patientId fixture mismatch (15/null).
- Patient video history: old 1 次失誤 wording vs 1 項訓練修正紀錄.
- Dual-screen IP page: TextField ancestor finder vs labelText decoration.
No tests deleted/skipped/relaxed to hide these. Historical Round 2 524/7 retained, not replaced with current 545/7.

## 16. New Regressions

No new failures in executed functional tests. Release generated-plugin build failure resolved without code/config changes.
Expanded MySQL test first run failed duplicate-grant fixture and exact ZIP charset assertion;
test fixture/MIME semantic check corrected and 12/12 passed. Failure evidence preserved, not a business regression.
Unexecuted hardware gates cannot be described as regression-free.

## 17. Files Added / Modified

master:
- lib/features/rehab_ml/body_research_context.dart
- lib/features/rehab_ml/body_research_contract.dart
- lib/features/rehab_ml/body_research_sample.dart
- lib/features/rehab_ml/body_research_session.dart
- lib/features/rehab_ml/body_research_settings_page.dart
- lib/features/rehab_ml/ml_action_definition.dart
- lib/features/rehab_ml/ml_research_api.dart
- lib/features/rehab_ml/research_management_page.dart
- lib/features/rehab_ml/therapist_research_samples_page.dart
- lib/features/rehab_ml/research_sample_presentation.dart (new)
- test/features/rehab_ml/body_research_session_test.dart
- test/features/rehab_ml/ml_research_cloud_test.dart (fake inheritance only)
- test/features/rehab_ml/body_review_ui_test.dart (new)
- docs/BODY_RESEARCH_ROUND3_PROGRESS.md, docs/BODY_RESEARCH_ROUND3_REPORT.md (new)

TV: equivalent five body context/contract/sample/session/settings files, body session test,
docs/BODY_RESEARCH_ROUND3_PROGRESS.md. Existing generated desktop line-ending-only changes not part of this round.
Backend complete manifest: backend docs/BODY_RESEARCH_ROUND3_REPORT.md and git show --stat of Round 3 checkpoint.
V005 continuation additionally modifies backend BodyRound3MySqlIntegrationTest and adds
backend docs/BODY_RESEARCH_ROUND3_MYSQL_VALIDATION.md; both repositories update existing progress/report documents only.

Exact validation commands (run in the corresponding existing worktree):
- master: flutter test test/features/rehab_ml/body_review_ui_test.dart test/features/rehab_ml/ml_research_cloud_test.dart test/features/rehab_ml/body_research_session_test.dart test/features/rehab_ml/body_research_foundation_test.dart test/features/rehab_ml/body_research_owner_test.dart test/features/rehab_ml/body_research_contract_test.dart test/features/rehab_ml/pi_body_observation_test.dart --no-pub
- master full: flutter test --machine (one run; artifact .dart_tool/body-r3-full-test.jsonl)
- master: flutter analyze lib/features/rehab_ml test/features/rehab_ml/body_review_ui_test.dart test/features/rehab_ml/body_research_session_test.dart --no-pub
- TV: flutter test test/features/rehab_ml/body_research_foundation_test.dart test/features/rehab_ml/body_research_contract_test.dart test/features/rehab_ml/body_research_owner_test.dart test/features/rehab_ml/body_research_session_test.dart test/features/rehab_ml/pi_body_observation_test.dart --no-pub
- TV: flutter analyze lib/features/rehab_ml/body_research_context.dart lib/features/rehab_ml/body_research_contract.dart lib/features/rehab_ml/body_research_sample.dart lib/features/rehab_ml/body_research_session.dart lib/features/rehab_ml/body_research_settings_page.dart test/features/rehab_ml/body_research_session_test.dart --no-pub
- Both Flutter worktrees: flutter build apk --debug; flutter build apk --release; git diff --check (PASS).
- Backend: mvn -Dtest=ResearchBodyReviewTest,ResearchBodyAttemptTest,ResearchBodyMigrationTest,ResearchDataServiceTest,ResearchManagementServiceTest,ResearchHandContractTest,ResearchBodyExportTest test; mvn test; mvn package -DskipTests; git diff --check (PASS).

## 18. Git Commits

Only existing master / codex/android-tv-client / main; no new branches, wholesale merge, push or deployment.
Round 2 SHA listed above. Verified Round 3 implementation checkpoints:
- master: 1326472811298223182d009c252645e1da5a9610 (15 files).
- codex/android-tv-client: 968d8a4be92c4a9696db7944001b4d187ce33ad4 (7 files).
- backend main: 6048bf32e6bccb6ae694297e68a57a600d41157b (23 files).
Later documentation-only checkpoint records these hashes; final HEAD reported separately.
Do not mistake implementation commits for completed MySQL or hardware acceptance.
master/backend worktrees clean after implementation commit. TV preserves seven existing
generated desktop line-ending-only files unstaged; no unrelated changes restored or committed.

## 19. Technical Debt

V005 owner application is complete locally. Local-only runner still requires 4/4-column preflight; never replay migrations.
Review list capped at 500; export capped at 500 approved candidates / 20 MB (existing bounds).
2D projected features are not clinical 3D ROM; no trained model or accuracy claim.
ARM phone assets present; MediaPipe x86_64 JNI absent in existing dependency, not a TV hand feature.
Isolated API/device configuration and actual Pi/TV device required before hardware E2E.

## 20. Round 4 Readiness / Continue

NOT READY for overall Round 4. Owner already applied V005 locally; do not rerun setup/V001..V005.
Local Hibernate, metadata, CRUD/API/concurrency and cleanup are now PASS. To reproduce, execute
tools/body-round3-mysql-test.ps1: DPAPI app credential, localhost/schema/V005 preflight,
temporary random test keys, normal RESEARCH_COLLECTION_ENABLED=false, exact fake cleanup/rollback.
Complete Pi/TV isolated synthetic hardware acceptance. Laboratory requires new authorization/access;
production remains undeployed. Do not start Round 4 or silently mark NOT RUN as PASS.

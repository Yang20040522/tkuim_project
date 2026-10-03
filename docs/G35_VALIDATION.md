# G3.5 local acceptance evidence (2026-10-03)

## Status

Implementation/local checks A–D completed; overall PARTIAL pending clean-tree local merge and manual Render/device acceptance. No push/deploy/real collection/model training.

## Versions

- Start Flutter feature: `429f200cefe085cbb72c8d612146cd296ec16045`; local master: `a413cd806f82d372bcf56f412b4cb439784cd5dd`.
- A commits: Flutter `b44670b`, backend `fd82b4f`.
- B commits: Flutter `e7949ce`, backend `1ff28fb`.
- Backend final verified checkpoint: `07f5e3b082c953fae5703880d4abf8b7fbac4f3f` (MySQL/HTTP acceptance); backend working tree clean.
- Backend branch `codex/g35-research-integration` from main `5394f735a461476ee692bf44350aafb0f6888648`. Backend main has NOT been modified/merged this round.
- Final checkpoint hashes: consult `git log -1` in each repository (a document cannot contain its own commit hash). Backend and frontend contracts are additive; old clients still default to standing exports. Prefer backend feature deployment before the new client, after explicit approval.

## Consent diagnosis

Confirmed UI root cause: `_setCloudConsent` previously collapsed availability/auth/version/network failures into one catch message. Availability requires all three gates: collection flag true, nonblank current consent version, approved effective retention policy. PUT opt-in checks the same gates and version; HMAC identity is reloaded from DB. GET now adds safe `unavailableReason`; frontend refreshes before opt-in and distinguishes safe whitelist codes, 401, 403, HTTP/proxy errors, timeout/network and bad JSON.

The precise failing gate in Render is NOT VERIFIED. General Android/MySQL connection success does not prove research availability. No production access or flag change was performed. Runtime default remains closed; never enable collection just to remove this message.

## Executed checks

| Check | Result | Evidence |
|---|---|---|
| Flutter consent-focused tests | PASS 18/18 | `build/g35/focused-a.log` |
| Flutter all research tests | PASS 26/26 (including final contract-driven angle display) | `build/g35/focused-final.log` |
| Research scoped analyze | PASS, 0 issues | `build/g35/analyze-final.log` |
| Python `python -m unittest discover -s ml/tests -v` | PASS 8/8; synthetic fixtures only, no training | console / action tests |
| `flutter test --reporter json` | FAIL: 449 PASS / 7 FAIL | `build/g35/full-tests.jsonl` |
| `flutter analyze` | 47 existing diagnostics: 44 info, 3 warnings, 0 errors | `build/g35/full-analyze.log` |
| Master snapshot six affected test files | Same seven failures; 26 PASS / 7 FAIL | temp baseline described below |
| Master snapshot full analyze | 48 diagnostics: same 3 warnings, 45 info | temp baseline analyze |
| Android `flutter build apk --debug` | PASS; rerun after final angle-display wiring | `build/g35/apk-debug-final.log` |
| Release build | NOT RUN: no native, inference dependency, R8 or packaging configuration changes | final device acceptance still required |
| Backend focused ResearchData/Management/Authority/Retention | PASS 36/36 | `target/g35-b.log` / Surefire |
| Backend helper `run-local.ps1 -Action FullTest` | PASS 258/258, 0 skipped, includes actual MySQL 21/21 | `target/g35-mysql-full.log` |
| MySQL tests after consent HTTP assertions | PASS 21/21 | `target/g35-mysql-focused.log` |
| `run-local.ps1 -Action Package` | PASS | `target/g35-package.log` |
| `run-local.ps1 -Action Metadata` | PASS, 29 tables, 241 columns (existing V003), 33 FK, 16 CHECK, 75 indexes | `target/g35-metadata.log` |
| `git diff --check` both repositories | PASS | console |
| Physical Android / Render authenticated research E2E | NOT RUN | no production credentials/device access used |

Final APK: `C:/Users/kuoja/Documents/GitHub/tkuim_project/build/app/outputs/flutter-apk/app-debug.apk`; SHA-256 `8145ECC653906D39B7620B724FB60EF84C6EC0307C5A8A64EDA6F61534E94948`. It is a local build artifact, not committed or remotely deployed.

Full Flutter suite preceded the final small contract-driven angle-label wiring; that final change was separately tested with all 26 research tests/scoped analyze and included in the final APK. No failed tests were deleted, skipped or weakened. Intermediate new const/annotation/test-I/O errors were fixed before checkpoints; backend final HTTP tests were rerun after a test method-name compile correction.

## Seven failures: actual master comparison, not assumptions

Master `a413cd8` was exported with `git archive` into `C:/Users/kuoja/AppData/Local/Temp/g35-master-4057dd956fbb4282ad40b6db4bb74653` without switching the working branch. Same Flutter SDK and offline dependencies; exact six files rerun. JSON logs prove the same seven failed names and reasons:

| File / case | Root cause | Classification |
|---|---|---|
| account_info_screen_test: Google/account ID display | AppSession.save schedules ZEGO 800 ms Timer left pending at widget teardown | Reproduced pre-existing lifecycle/test isolation problem |
| account_info_screen_test: account ID update | Same ZEGO pending Timer | Same |
| account_recovery_therapist_registration_test: successful registration | Same ZEGO pending Timer | Same |
| friend_management_screen_test: API friend-code refresh | Same ZEGO pending Timer | Same |
| training_result_history_page_test: selected patient | Test expects injected legacy repository call; current therapist path uses ExerciseApiService.fetchTrainingHistory instead | Reproduced pre-existing contract/test drift; live therapist history NOT independently verified here |
| patient_training_videos_card_test: reps/play | Expected old text `1次失誤`; current UI uses `1項訓練修正紀錄` | Reproduced pre-existing wording assertion drift |
| dual_screen_assisted_training_ui_test: phone port | Test searches TextField containing label; current label is a separate Text sibling | Reproduced pre-existing widget structure assertion drift |

No new G3.5 regression identified. Do not claim full suite PASS. No unrelated ZEGO/history/TV code was changed. These should be resolved in a separately scoped task; no G4 work started. Analyzer comparison normalized only line numbers: no new diagnostics; the old standing action missing-override info is already fixed in the feature baseline before G3.5.

## Real MySQL/API scope

Server MySQL **8.4.11**, localhost `rehab_r2_validation`, existing restricted `rehab_app` DPAPI credential. Hibernate validate passed for all 29 entities; app booted in SpringBootTest. No V001/V002/V003 execution, schema changes, new policies outside rollback fixtures or Render access.

Actual service/repository tests cover consent, synthetic 17-point upload and retry deduplication, binding/grants, independent review prohibition, approved-only export, mismatched action/version exclusion, withdrawal and retention repeatability. Added MockMvc checks against real MySQL: consent GET 200 with closed reason, bad HMAC 401, therapist 403, opt-in 503 with no consent creation. Production service remained collection-disabled even during synthetic test-local collectors.

Metadata validator reports the same seven `UNEXPECTED_INDEX_REVIEW` entries as prior R2.5: InnoDB-created FK support indexes, not new discrepancies (68 declared + 7 automatic = 75). Final read-only counts: fictional `@example.invalid` accounts 0, research samples 0, research policies 0. Test rollback retained existing catalog/schema. Flutter real-network → Render end-to-end was NOT RUN; Flutter HTTP boundaries were mock tested, backend MySQL/API tested locally.

## Merge gate

Fast-forward ancestry verified. Existing dirty `android/build/reports/problems/problems-report.html` was present before task and remains uncommitted. It is a generated artifact, not task code. Asked owner to authorize external backup + restoring only this artifact; absent response, do not overwrite/stash/commit it to manufacture a clean tree. E is pending; local master remains at `a413cd8`. Feature branches retained. Do not push/deploy automatically.

## Manual acceptance / next steps

1. Review paired feature commits. Authorize the existing generated-report handling, then recheck clean trees/master ancestry before local `git switch master` + `git merge --ff-only feat/rehab-ml-poc`. Do not force merge if master changed.
2. With explicit deployment approval, integrate backend feature, preserve MySQL/validate/Tailscale configuration, deploy backend before Flutter. No new SQL is needed.
3. Obtain authenticated consent GET on Android: note HTTP status + safe reason only, never token/subject/sample content. Check collection flag, current consent version and effective approved policy. Keep real collection OFF until necessary research approval and retention policy exist.
4. In an isolated/synthetic environment: patient login/local opt-in/cloud opt-in → upload duplicate → bound/granted therapist 17-point playback/draft/submit → different granted reviewer approval → manager single-action export → withdrawal blocks export. Local-only refusal must still allow rehab and local sample management.
5. Confirm physical RTMPose skeleton/counting, Google patient restriction, session switching/logout, camera release and existing phone/TV flow. No hardware result claimed.
6. Do not start G4 training until professional labels, reviewed action definitions, independent approvals, retention governance and grouped validation prerequisites are actually met.

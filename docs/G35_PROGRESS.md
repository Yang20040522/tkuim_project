# G3.5 Progress / Handoff

## Baselines (2026-10-03)

- Flutter: `feat/rehab-ml-poc` / `429f200cefe085cbb72c8d612146cd296ec16045`.
- Local master: `a413cd806f82d372bcf56f412b4cb439784cd5dd`.
- Original existing change: `android/build/reports/problems/problems-report.html`; excluded from task commits. Owner subsequently authorized an external verified backup and single-file restore; resolved in Stage E below.
- Backend: clean `main` / `5394f735a461476ee692bf44350aafb0f6888648`. Backend changes will use a small feature branch, not redo main integration.
- Read R2.5/R3/Tailscale reports and ML handoffs. Old SQL Server handoff entries are historical; current MySQL V001/V002/V003 and `validate` are authoritative. No migration replay.

## Stage A — implemented and focused-tested

- Confirmed GET consent requires DB-reloaded PATIENT + existing HMAC identity. It returns `active`, `subjectId`, `consentVersion`, `currentVersion`, `available`.
- `available` requires collection flag true, nonblank consent version, and an approved policy effective now. Missing any gate is intentional, not evidence of networking failure.
- PUT agree enforces the same gates (503), then exact consent version (400). Identity failures are 401; wrong role 403. Withdrawal remains possible when collection is closed.
- Backend adds `unavailableReason`; Flutter whitelists safe localized messages, separates 401/403/HTTP/network and refreshes consent before opt-in. No sensitive logging, no change to collection gates.
- Actual Render gate causing the Android symptom is NOT VERIFIED; no authenticated production response or secret access is available.

## Remaining (in order)

1. No remaining local integration work. Verify final documentation checkpoint with `git log -1` / `git status`; do not redo the completed merge or A–D implementation.
2. Remote push/backend integration/Render deployment require separate owner review and authorization. Manual Render/device acceptance remains NOT RUN.
3. Preserve all seven full-suite failures and research governance prerequisites; do not start G4/G5 or enable real collection.

## Tests executed this round

- Backend: `mvn -q -Dtest=ResearchDataServiceTest,ResearchRetentionServiceTest test`: 23 PASS.
- Flutter: consent errors/cloud tests: 18 PASS. Initial new widget test hung on asynchronous file I/O in fake clock; fixed using tester.runAsync (not production logic).
- Scoped analyze initially found 2 new curly-brace infos; corrected, rerun pending.

## Stage B implementation

- Dart sample interface/action registry shared by storage and therapist labeling; standing collector/math unchanged, adds explicit definition version. Legacy v1 readable.
- Java injected action contracts validate shared 17-point payloads and dispatch feature recomputation; annotation version must match sample. Export selects exactly one action, manifest preserves features/version. Existing DB JSON stores metadata; NO migration.
- Python registered extractors and explicit --action prevent mixed-action/definition training. No model training performed.
- Synthetic second contract is test-only; covers local storage/export/queue/API, backend upload/dedup/label/export and Python extractor/dataset grouping.
- Flutter research tests: 26 PASS after fixing a new const-expression compile issue (central constant list). Python unittest: 8 PASS. Backend focused research suites: 36 PASS after updating fixture version to still exercise annotator ownership instead of an earlier version rejection.
- Scoped B analyze reported 2 new missing @override infos; corrected, rerun pending. Full suite/analyze/APK and real MySQL NOT RUN yet.
- Scoped B rerun: No issues found. Stage B ready for checkpoint.

## Stages C/D — local validation completed

- See `docs/G35_VALIDATION.md` for exact commands, evidence, seven failure classifications and manual requirements.
- Full Flutter 449 PASS / 7 FAIL. Same seven reproduced in isolated master snapshot (26 PASS/7 FAIL across six files). No new G3.5 regression identified; full suite NOT PASS.
- Full analyze 47 diagnostics (44 info, 3 warnings, no errors); master 48, no added diagnostics. Final scoped research analyze clean; final research tests 26 PASS, Python 8 PASS.
- Debug APK built, including final contract-driven angle names. Release NOT RUN (no native/R8/model/dependency change).
- Backend full tests against actual MySQL 8.4.11: 258 PASS / 0 FAIL / 0 SKIP; MySQL 21 PASS. HTTP consent assertions added and MySQL suite rerun: 21 PASS. Package PASS.
- Metadata existing29 tables/241 columns/33 FK/16 CHECK/75 indexes. No migration. Synthetic account/sample/policy final counts 0; production collection flag remained false.
- Both diff-checks PASS. At the C/D checkpoint the original generated report remained dirty; the later authorized Stage E procedure resolved this gate.
- Backend final checkpoint `07f5e3b082c953fae5703880d4abf8b7fbac4f3f`, clean tree. Frontend final code/docs checkpoint follows; consult git log, do not repeat completed A–D work.

## Stage E — completed local integration

- Owner authorization received; verified only dirty file was a generated Gradle report. Backed up complete 147,151-byte file outside repository and compared source/backup SHA-256 before restore.
- Backup: `C:/Users/kuoja/AppData/Local/Temp/RehabAssist-G35-report-backup-9164787e2d5a43d3bf9d5d32f3420895/problems-report.html`; SHA-256 `893303AFBBBE0F35C6A63DE09ACCAE064B325B9542600BA695ED44677E4046AA`.
- Restored only `android/build/reports/problems/problems-report.html` using the specifically authorized git command. No other unknown changes touched. Feature working tree clean and G3.5 checkpoint intact.
- master before: `a413cd806f82d372bcf56f412b4cb439784cd5dd`; source feature: `20103f139b20b3ec9c68867d4e962195198673df`; master after ff-only merge: `20103f139b20b3ec9c68867d4e962195198673df`. Ancestry rechecked (0 ahead/13 behind before merge), feature branch preserved.
- On merged master: necessary Flutter regression **93 PASS**, scoped analyze **0 issues**, Python **8 PASS**, clean tree/diff-check PASS. Exact commands/logs in G35_VALIDATION.md. Original full suite **449 PASS / 7 FAIL** remains documented; not represented as all-pass.
- Final documentation-only checkpoint updates these two G35 files on master. Read `git log -1` for final SHA; no runtime code/tests changed in this continuation.
- No push/force push/deploy/backend work/SQL/branch deletion/model training; stop before G4.

## Safety / Do not redo

- Preserve RTMPose, counting, shared login, Google patient restriction, local/cloud consent separation, existing review/authority/export/retention.
- Do not modify TV, V001/V002/V003, Render secrets or production research flag.
- No model training, fake clinical labels, real samples or secret logs.
- Do not force merge with unresolved regressions/unknown dirty files. Feature branches remain; push/deploy require later owner confirmation.

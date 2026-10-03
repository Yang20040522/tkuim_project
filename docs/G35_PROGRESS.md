# G3.5 Progress / Handoff

## Baselines (2026-10-03)

- Flutter: `feat/rehab-ml-poc` / `429f200cefe085cbb72c8d612146cd296ec16045`.
- Local master: `a413cd806f82d372bcf56f412b4cb439784cd5dd`.
- Existing change: `android/build/reports/problems/problems-report.html`; preserve, exclude from task commits. This dirty artifact is a final merge gate until safely resolved with owner direction.
- Backend: clean `main` / `5394f735a461476ee692bf44350aafb0f6888648`. Backend changes will use a small feature branch, not redo main integration.
- Read R2.5/R3/Tailscale reports and ML handoffs. Old SQL Server handoff entries are historical; current MySQL V001/V002/V003 and `validate` are authoritative. No migration replay.

## Stage A — implemented and focused-tested

- Confirmed GET consent requires DB-reloaded PATIENT + existing HMAC identity. It returns `active`, `subjectId`, `consentVersion`, `currentVersion`, `available`.
- `available` requires collection flag true, nonblank consent version, and an approved policy effective now. Missing any gate is intentional, not evidence of networking failure.
- PUT agree enforces the same gates (503), then exact consent version (400). Identity failures are 401; wrong role 403. Withdrawal remains possible when collection is closed.
- Backend adds `unavailableReason`; Flutter whitelists safe localized messages, separates 401/403/HTTP/network and refreshes consent before opt-in. No sensitive logging, no change to collection gates.
- Actual Render gate causing the Android symptom is NOT VERIFIED; no authenticated production response or secret access is available.

## Remaining (in order)

1. A: checkpoint commits after scoped analyze.
2. B: register versioned action contracts in Dart/Java/Python; retain v1 standing-knee-raise samples, test a nonproduction synthetic second action through shared validation/storage/export.
3. C: focused and full Flutter tests, classify failures against master evidence, analyze, debug APK.
4. D: real local MySQL synthetic integration via existing ignored credential/helper; no schema rebuild or real participants. Record version compatibility and limits.
5. E: only if tests/working-tree gates pass, local ff-only master merge; never push/deploy.

## Tests executed this round

- Backend: `mvn -q -Dtest=ResearchDataServiceTest,ResearchRetentionServiceTest test`: 23 PASS.
- Flutter: consent errors/cloud tests: 18 PASS. Initial new widget test hung on asynchronous file I/O in fake clock; fixed using tester.runAsync (not production logic).
- Scoped analyze initially found 2 new curly-brace infos; corrected, rerun pending.

## Safety / Do not redo

- Preserve RTMPose, counting, shared login, Google patient restriction, local/cloud consent separation, existing review/authority/export/retention.
- Do not modify TV, V001/V002/V003, Render secrets or production research flag.
- No model training, fake clinical labels, real samples or secret logs.
- Do not force merge with unresolved regressions/unknown dirty files. Feature branches remain; push/deploy require later owner confirmation.

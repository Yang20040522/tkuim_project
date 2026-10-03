# Development Demo Progress

## Current status (read this before older chronological entries)
- Global research consent/upload and Android patient/therapist/independent-review acceptance PASS. Backend final code c5fa9eb6243f14923fc0b3f0cefce5db254d5a67 committed and pushed non-force to main; actual Render final deployment verified Deploy succeeded/Live. Post-deploy consent available=true/handAvailable=true and001/002/003 statuses rechecked/PASS. Initial-manager environment keys remain absent.
- Five actual handset acceptance samples uploaded by fake253; three synthetic DEMO-HAND fixtures.001 remains UNLABELED for manual screenshots,002 DRAFT,003 APPROVED. Do not delete or overwrite unrelated accounts/research rows.
- Final tests49 focused PASS;294 full PASS/1 opt-in setup skip/0 failures,22 real local MySQL tests PASS; Maven package PASS. Do not rerun full suites or rebuild the unchanged Flutter App.
- Generated disposable passwords are in backend ignored DPAPI credential store. Operator may run tools/research-demo-logins.ps1 locally. Do not include credential values, raw landmarks or images in Git.
- Global export download was blocked/not performed; manager UI screenshot NOT RUN. Neither formal ethics approval nor a trained model is claimed.

## Complete task file list
Flutter (documentation only):
- docs/DEVELOPMENT_DEMO_PROGRESS.md

Backend (relative to trianing-system; changes since G5 baseline38c6ba8):
- docs/RESEARCH_ACTIVATION.md
- src/main/java/com/example/trainingsystems/config/ResearchManagerInitializationRunner.java
- src/main/java/com/example/trainingsystems/service/DemoHandSampleFactory.java
- src/main/java/com/example/trainingsystems/service/ResearchAuthorityService.java
- src/main/java/com/example/trainingsystems/service/ResearchManagementService.java
- src/main/java/com/example/trainingsystems/service/ResearchManagerInitializationService.java
- src/test/java/com/example/trainingsystems/service/DemoHandSampleFactoryTest.java
- src/test/java/com/example/trainingsystems/service/MySqlMigrationIntegrationTest.java
- src/test/java/com/example/trainingsystems/service/ResearchActivationSetupTest.java
- src/test/java/com/example/trainingsystems/service/ResearchAuthorityServiceTest.java
- src/test/java/com/example/trainingsystems/service/ResearchManagementServiceTest.java
- src/test/java/com/example/trainingsystems/service/ResearchManagerInitializationServiceTest.java
- tools/research-activation.ps1
- tools/research-demo-logins.ps1
- tools/research-remote-accounts.ps1
- tools/research-remote-configure.ps1
- tools/research-remote-reset.ps1
- tools/research-runtime-check.ps1

No Flutter source/model/native/build changes; no schema migrations; no real credentials, study payloads or screenshots committed. Screenshots are ignored build/research-acceptance/ artifacts, not application code.

## Baselines
- Flutter master283c36f10338489ed4c40d3f901d95ac1dd046bf, backend main38c6ba875c11b9b1199f73f8a92bc24f9a337dc7; both clean at start.
- Latest user instruction authorizes GLOBAL research activation and required Render deployment on the existing service/database. Do not implement account allowlists or a separate Demo database. Individual patient consent, authentication, binding, grants, validator and independent review remain required.

## Plan / Remaining
1. Verify deployed Render/GitHub version and existing retention policy. Obtain explicitly chosen retention duration/version/reference before creating a GLOBAL policy; never reuse a fictitious Demo retention duration.
2. Generate DEMO-HAND-001 sidePinch21-point open→pinch→return with G5 extractor and validator. Seed statuses through original services; keep001 unlabeled.
3. Current Android App uses the actual Render API. Publish compatible G5 backend after validation; configure global collection and matching hand/current consent versions. Verify actual authenticated API and phone flow.
4. Focused tests, local actual API round trip, APK/install/user screenshot acceptance, docs and local commits only.

## Decisions / Do Not Redo
- Render/environment/database writes are now expressly authorized within this task; no authentication/consent/review bypass or fictitious clinical/model approval.
- Previous experimental Demo whitelist/profile additions were removed with targeted patches (only our own additions). ResearchDataService uses the original global settings without account restrictions.
- Existing local DPAPI app credential supplies CRUD; no root password requested, no database/table recreation.
- DEMO data must be excluded from exports/training, not just labeled in UI. No real camera recording or participants needed for screenshot data.

## Tests
NOT RUN for this task yet; prior G5 tests are not evidence of new Demo validation.

## Actual deployment inspection (2026-10-03)
- Render service srv-dad76non74is73dj1blg is Live at GitHub main 7c55d1c7527d94ca0e23c50213f68f7e4f973d7a, not G5 38c6ba875c11b9b1199f73f8a92bc24f9a337dc7.
- Local main includes remote main as an ancestor and is ahead by the three G5 commits. No divergent remote changes; no push/deployment performed yet.
- Render environment displayed keys do not yet include research settings; remaining entries still to inspect. Secrets remain masked.
- G5 requires RESEARCH_HAND_CONSENT_VERSION equal to RESEARCH_CONSENT_VERSION for schema2 hand upload and handAvailable=true.
- No DB writes, account creation, policy creation or sample insertion have occurred for this Demo task.
- Need user-selected global policy duration/version/reference and consent version. A real active retention policy is required, not just RESEARCH_COLLECTION_ENABLED=true.

## Global activation continuation
- User supplied90 days, hand-research-consent-v1, hand-retention-v1, OWNER-AUTH-20261003-G5 (internal, not IRB), and confirmed immediate Render save/deploy.
- Actual MySQL setup created four fake accounts, bindings/grants, owner policy and DEMO-HAND-001 through original services. Initial state had none. Seed executed twice/PASS/idempotent. No new schema/auth bypass.
- Backend focused43 PASS. Full MySQL suite final284 PASS/1 opt-in setup skip (285 discovered), no failure/error; first-run2 environment-assumption failures fixed in tests without deleting policies. Package PASS.
- Render research keys saved only; code deployment/runtime API/Android acceptance pending.
- Experimental whitelist/profile files removed (our own unfinished additions only); no separate Demo UI/build/allowlist.
- Backend details: docs/RESEARCH_ACTIVATION.md; tools/research-activation.ps1. Fake credentials ignored/DPAPI, never in Git/docs.

## Actual Render deployment / corrected database target
- Backend d2f06877d6e857ab06e6f45ab27b4ccaa3e0979f pushed (non-force) to main and Render Live verified. Three research settings saved/applied per explicit confirmation.
- Important: local127.0.0.1 MySQL is NOT the Render laboratory100.94.202.58 instance. Same schema name did not mean same data. Local Seed is not actual Render validation.
- Remote fake accounts created through original registration/login APIs: patient253, therapist254, reviewer255, manager256; emails demo_<role>@demo.invalid, roles original PATIENT/THERAPIST. All research grants initially false. No remote passwords/tokens in this document.
- Actual Render consent: currentVersion hand-research-consent-v1; active=false; available=false; handAvailable=false; reason RESEARCH_RETENTION_UNSET. Do NOT report cloud enabled/complete.
- Local host cannot reach lab MySQL port3306; no local Tailscale CLI. No access to lab DB secrets was attempted. Existing authenticated policy API needs a manager.
- Proposed controlled first-manager initializer was rejected by automated safety review (no file changes applied): persistent management authority requires exact target/environment confirmation. Asked user to authorize remote verified demo_manager@demo.invalid/user256 specifically, default-off/no public endpoint/id+email+role verification/audit/idempotence; no new branch or Demo patient allowlist.
- Pending: explicit manager initialization approval; implement/test/deploy it if approved, then use original APIs for lab policy/bindings/grants/upload and Android acceptance. Do not treat local policies/samples as cloud rows.
- Phone user confirmed unlocked; device d698e1fa connected, original Release still installed. No UI验收 performed for new cloud flow yet.
- Uncommitted backend tools: research-remote-accounts.ps1 and research-runtime-check.ps1. Preserve them; runtime check currently cannot pass until actual remote policy/grants/sample exist.
- Additional research-remote-configure.ps1 prepared; all3 scripts pass syntax check. Four actual remote fake accounts and all3 fake therapist bindings executed/PASS. Actual manager256 still has no authority; remote policy/sample/annotation/review NOT RUN. No initializer code applied after automated safety rejection.
- No new frontend code/build, no model availability fabrication or additional research entry. Resume ONLY after explicit approval for actual target256; preserve Live d2f0687 and original G5 code. Read both checkpoints first.

## Explicit bootstrap approval received / current continuation
- User explicitly authorized actual Render demo_manager@demo.invalid/user256/THERAPIST as first manager, identity checks/no public API/audit/default-off; stop if another manager exists. Remove bootstrap environment settings after success.
- Added operator-only initializer/runner and focused tests; verification/deployment pending. No public patient allowlist or role replacement.

## Actual runtime verified (2026-10-03 continuation)
- Backend e769a5dae129ddd489f819acd84baa544f9c6fec committed/pushed non-force; Render Live verified. First manager256 granted with identity check/audit. All3 RESEARCH_INITIAL_MANAGER_* environment variables then removed; environment-updated deployment Live at same SHA.
- Focused23/23 PASS including8 initializer tests. New full MySQL-enabled Maven293 discovered/292 PASS/1 opt-in setup skip/0 errors/failures;22 actual MySQL integration PASS. Package PASS.
- Actual Render hand-retention-v1 policy created90 days/internal owner reference; no previous policy. Configure rerun preserved current policy/grants/sample (PASS/idempotent). Script empty-array parsing corrected; initial attempt did not create policy.
- Actual HTTP available=true/handAvailable=true; voluntary fake patient253 consent persisted; upload/dedup/41 frames21 points and bound therapist254 detail PASS. Self-review403 PASS; independent reviewer255 approved synthetic003 PASS.001 remains UNLABELED.
- Actual installed Android Release logged into fake therapist254, sample list shows001 pending and003 approved. Detail visibly renders21-point skeleton, slider changed to21/41 pinch frame. Screenshots in ignored build/research-acceptance/. Patient UI consent/upload and reviewer UI remaining; do not claim them complete yet.
- Added synthetic002 through original upload API for actual UI annotation. Android saved DRAFT with explicit DEMO-not-clinical note; submission/reviewer UI in progress.
- Actual global approved-export download was blocked by automated safety review because it could transmit unrelated sensitive research rows to a local file. No download executed; do not bypass. Synthetic exclusion is covered by passing unit tests; cloud export verification NOT RUN unless narrowly authorized after scope checks.
- Android independent reviewer255 opened review mode/002 SUBMITTED controls, added DEMO-only note and approved; APPROVED visibly verified/captured.001 still unlabeled. Remote reset tool executed on002/PASS, snapshots that synthetic row only, original DELETE/re-upload; audits preserved/new server UUID.
- Patient login sequence did not reliably land in the fake patient: current UI is an existing personal patient account. Did NOT modify its consent/upload/delete; paused device input and asked user to temporarily stop interaction for safe fake-patient verification. Do not claim patient Android cloud capture/upload PASS yet.
- Remaining: fake patient Android consent/capture/sync, final statuses/credentials instructions/screenshots, final documentation/commits. Runtime frontend code unchanged; no new APK needed for backend activation.
- User paused phone interaction. Verified DEMO PATIENT on home; opened sidePinch via existing action flow. Anonymous DEV-SUBJECT-001 entered, explicit local and cloud switches both ON verified; cloud UUID matches actual fake253 consent. No unavailable/approval error; model still unavailable. Patient consent UI PASS. Physical valid cycles/actual handset upload pending.
- Remote002 reset executed twice/PASS, exactly one row after repetitions; restored DRAFT via normal label API. Final fixture states:001 UNLABELED,002 DRAFT,003 APPROVED.001 server IDabc0630d-eb29-4cc9-b67a-6996eb761c1c;002 newID583afafa-2854-4eca-af64-5d4281a8f269;003 ID6a0ed278-d74b-495a-b37b-f9fc4870b4da.

## Final device / test evidence
- User reports5 samples; actual phone shows cloud consent active/pending0/synced5. Actual Render verified5 handset samples plus3 synthetic fixtures. Fake patient253 only; no personal patient consent changed.
- Phone hand skeleton, existing feedback and reps operate. Bound therapist read actual handset sample18 frames/all21 landmarks; unassessable annotation submitted and independently approved255 with explicit non-clinical DEMO note. These five captures are actual device acceptance data, NOT synthetic landmarks or professional labels. All disposable DEMO account samples must be excluded from formal export.
- Added backend export-only dataset hygiene for both DEMO-name/reserved demo.invalid email markers. No account allowlist, patient upload restriction, model availability change, new research entry or Flutter source change.
- Final focused49/49 PASS; full Maven295 discovered/294 PASS/1 opt-in setup skip/0 failures/errors,22 local actual MySQL integration PASS; package PASS. No new frontend suite/build needed because only backend/tooling/docs changed; original installed G5 Release actually verified.
- Screenshots available in ignored build/research-acceptance/. Patient synced5, therapist001 skeleton/pinch, draft/submitted002, independent reviewer-approved002 all captured. Manager API verified; manager UI screenshot NOT RUN. Global research export BLOCKED/not downloaded due possible unrelated sensitive data; do not bypass.
- Current remaining: commit/push only final backend export hygiene/tools/docs; verify actual Render Live SHA and consent still available. Save final Git SHAs in this checkpoint and report screenshot paths/logins/reset command. Do not restart implementation or rerun full suites.

## Completion (supersedes earlier pending records)
- Final backend main/origin/main: c5fa9eb6243f14923fc0b3f0cefce5db254d5a67; working tree clean. Render deploy dep-db0gfdbm8hqs73d2k0lg Live, source c5fa9eb, original API URL unchanged.
- Post-deployment read-only checks PASS: hand/current consent availability and voluntary fake opt-in; five handset samples retained;001 UNLABELED/002 DRAFT/003 APPROVED,41 frames each. One actual handset sample18 frames21 points was independently approved as unassessable workflow evidence only.
- Post-deployment manager authority and exactly one hand-retention-v1/90-day policy PASS. Full final API check exited0. Retention remains measured from uploaded_at; owner reference is internal authorization, not IRB. Formal human-subject study readiness is not asserted.
- Environment UI confirms RESEARCH_COLLECTION_ENABLED/RESEARCH_CONSENT_VERSION/RESEARCH_HAND_CONSENT_VERSION present and no RESEARCH_INITIAL_MANAGER_* keys. No persistent bootstrap, new branch, fake model, schema recreation or forced push.
- Deployment screenshot: ignored build/research-acceptance/render-final-live.jpg. Screenshots and generated test credentials remain untracked/ignored, not published in Git.
- Operator next action: use disposable accounts via backend tools/research-demo-logins.ps1, patient flask screen or therapist research annotation screen; manual001 annotation/review remains available. Reset only explicit synthetic fixture through research-remote-reset.ps1. Do NOT start a new milestone or download global research exports without scoped authorization.

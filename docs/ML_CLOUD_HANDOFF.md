# ML Cloud Handoff

## Third-round final handoff / next session (2026-09-23)

- Flutter HEAD before this docs-only checkpoint: `13e954a`; backend HEAD `e905fe6`. Both branches correct and clean. Read `docs/ML_CLOUD_PROGRESS.md` and backend `ML_CLOUD_HANDOFF.md` before continuing; do not redo Stages B–F.
- Implemented and committed: scoped grants/controlled manager bootstrap; draft-submit-independent review with revision snapshots; approved anonymous Python-compatible ZIP export and audit; explicit versioned retention/expiry processing; in-app research management; one shared login routed by backend PATIENT/THERAPIST role. No production SQL, push, merge, PR or deploy.
- Tests: focused green, Android Debug build green. Full Flutter 436 pass/7 fail; full Maven 227 pass/2 auth-security fail; backend package PASS. Do not mark full regression PASS. Two Flutter account-info failures involve pending ZEGO timers; identify the remaining five with failure-only capture before deciding whether caused by this round.
- SQL execution order after backup/review in isolated SQL Server first: base `sqlserver_migration_ml_research.sql` → `sqlserver_migration_ml_research_authority.sql` → `sqlserver_migration_ml_research_review.sql` → `sqlserver_migration_ml_research_export.sql` → `sqlserver_migration_ml_research_retention.sql`. The controlled bootstrap SQL is separate and must have an explicitly verified existing user ID; do not save a filled copy. Production migration/deploy requires user approval. `RESEARCH_COLLECTION_ENABLED` defaults false; do not set true until ethics/consent/retention approvals and device/backend E2E.
- Real Android/SQL Server/Render E2E and any human-subject research are BLOCKED/NOT RUN. Next session: classify Flutter failures and verify Spring context with a safe test database, review SQL Server migration in isolated test DB, then plan manual Android/device and Render acceptance. If owner/teacher has no eligible existing account, do not fake PATIENT/THERAPIST; controlled internal-account provisioning remains a gap.

## Third-round Stage F shared-login handoff (2026-09-23)

- `RoleSelectScreen` remains the splash/logout route for compatibility but now directly displays the single `LoginScreen`. Backend-authenticated PATIENT/THERAPIST role routes to the old respective home. No user-selected manager role, no research permissions saved in Session; Google remains limited to the existing patient-only backend flow. The registration sheet opens the existing patient/therapist forms.
- Focused common-login 4/4 and combined Google/common UI 10/10 PASS; account-deletion return-to-login test PASS. Scoped analyzer 0 issues. Whole `account_info_screen_test.dart` has two ZEGO pending-timer failures on other unchanged test paths; investigate baseline separately, do not claim pre-existing without proof.
- Backend compatible HEAD after retention: `59e1efd`; later small security/validator changes may be uncommitted. Next: commit shared-login Flutter, run full regression/build, update exact SHAs and remaining blockers. No deploy/SQL/real-subject research.

## Third-round Stage E retention handoff (2026-09-23)

- Backend added `ResearchRetentionService`, policy/event entities, sample expiry columns and `sqlserver_migration_ml_research_retention.sql`; no policy or SQL migration executed. No policy -> research consent/upload unavailable, but existing local-only collection remains independent. Export excludes expired/policy-less samples. Batch deletes are auditable and retry-safe for already-deleted rows.
- Flutter `ResearchManagementPage` adds an explicit policy form/history and manual expired-batch action. No duration default and no automatic real-person collection. Backend requires manager authority, but true governance/backup/export file handling must still be approved and manually verified.
- Stage E backend checkpoint commit `59e1efd`; Flutter 8/8 focused tests and scoped analyze 0 issues. Next: Flutter commit, shared login, final regression/build. No SQL Server, Render or Android E2E yet.

## Third-round Stage D handoff (2026-09-23)

- Backend compatible commit `4882f4e` (preceded by `904163d`, `c234af2`) provides per-study manager stats and approved ZIP export. SQL Server migrations remain unexecuted and backend undeployed. ZIP contains sanitized `samples/*.json` + `labels.csv` for `ml/train.py`, no server file; audit records actor/study/schema/count.
- Flutter `ResearchManagementPage` is a small in-app page. `TherapistHomeScreen` fetches backend authority to show its entry only when `canManage`; page rechecks authority. It manages reviewer requests, scoped grants, counts and export via `file_picker`. Existing patient/therapist business pages remain unchanged.
- 7/7 focused Flutter tests and scoped analyzer 0 issues. No full suite, APK, actual SQL Server, Android device or Render validation yet. Next Stage E retention policy, then Stage F shared login and final validation. Do not redo completed authorization/review/export stages.

## Third-round Stage C handoff (2026-09-23)

- Backend at `c234af2` (prior `904163d`) adds research grants/reviewer requests and DRAFT → SUBMITTED → APPROVED/RETURNED workflow. The existing annotation row plus revision snapshots preserve history; approved data cannot be overwritten. Required new SQL scripts are `sqlserver_migration_ml_research_authority.sql` and `sqlserver_migration_ml_research_review.sql`, after second-round `sqlserver_migration_ml_research.sql`. None executed. Manual first-manager bootstrap template is `sqlserver_bootstrap_first_research_manager.sql`.
- Flutter API and `TherapistResearchSamplesPage`/detail now use authority, request, review queue, submit and review endpoints. Research review mode is a UI switch only and all operations require backend grants. Existing 17-point skeleton player reused. 6/6 focused tests pass; scoped analyze has 0 issues. This checkpoint is not deployed.
- Next exact files: `lib/features/rehab_ml/ml_research_api.dart`, `therapist_research_samples_page.dart`, backend `ResearchDataService.java`, `ResearchAuthorityService.java`, `ML_CLOUD_HANDOFF.md`. Continue with approved export + minimal manager UI, then retention and unified login; do not redo the completed authorization/review work.

## Third-round start

- On 2026-09-23, Flutter `feat/rehab-ml-poc` HEAD `0b25cc52c29b6ed7da4c5fb092212a6b48e00fc5` and backend `feat/rehab-ml-cloud-label` HEAD `8d743794e4d14d9ed914226e26ce090dfc9a7662` were both clean.
- Third-round requested order: additive research grant and controlled bootstrap; therapist review; approved export/minimal management; retention; shared login; focused tests/Android build. No public manager registration or separate manager app.
- Current login remains role-selection first. Backend `User.role` is a single string and Google login is patient-only; do not treat UI mode as authority or replace PATIENT/THERAPIST roles.
- Continue with precise backend auth/research inspection, then small tested commits. Do not redo rounds 1–2.

## Starting state

- Flutter branch/commit: `feat/rehab-ml-poc` / `ad1f0bf13b3ebb6828aa69cb9f62b8bd7cfee546`.
- Backend branch/base: `feat/rehab-ml-cloud-label` / `94132993d7d32ffc4b090ec429975fa3543275f5`.
- Backend compatible stage commit: `f6caf96781884f5809222396cdc834128da63bc2`.
- Flutter compatible feature commits: `99bb607ce5fd4a12c9b248d79e3093414ec2c37d` and `d7b8015127e78ecf5b9b16e87ccd199b72a3b912` (current functionality).
- Both working trees were clean before this round.
- First-round collection schema is in `lib/features/rehab_ml/standing_knee_raise_sample.dart`; training contract is in `ml/feature_schema.py` and `ml/train.py`.

## Current architecture/decisions

- Flutter uses RTMPose once in `BodyTrainingScreen`; local samples are stored via `MlSampleRepository` only after route-scoped explicit consent.
- Backend has HMAC identity validation via `CustomExerciseIdentityService`, `User` roles and `UserBinding` therapist–patient relationships. Reuse these; do not trust body user IDs.
- SQL Server via Spring JPA `ddl-auto=update`; schema migration must be additive and reviewed before production use.
- Cloud consent must be independently recorded server-side before upload. Sample UUID must be stable/idempotent across phone retries. No research-manager role is assumed until designed and authorized.
- No genuine labels or trained classifier exist.
- Flutter client uses HTTPS `ApiConfig.baseUrl` and existing HMAC headers. Endpoint contract and SQL migration details are in backend `ML_CLOUD_HANDOFF.md` at `f6caf96`.
- Patient `MlSampleSheet` has two separate opt-ins: original local research collection and new server cloud consent. The route starts both OFF. Local samples can still be collected offline; only samples created while the cloud switch was explicitly ON enter the per-account upload queue. Failed IDs remain for manual retry or retry when sheet opens. Do not upload old pre-cloud or local-only samples silently.
- Therapist entry `TherapistHomeScreen` → `TherapistResearchSamplesPage` → `ResearchSampleDetailPage` is backed by authenticated server list/detail. 17-point skeleton playback uses stored JSON only; label options are preliminary and need PT sign-off.

## Known issues/tests

- First-round full Flutter run: 423 passed, 7 failed in account/video/TV tests, without baseline verification. Do not call these proven pre-existing.
- Backend: focused 12 research + 14 account tests and package passed; full backend suite not run.
- Flutter: 9 focused research tests + 6 body-score regression tests passed; new feature analyze 0 issues. Debug APK built before the local-only preservation follow-up, not rebuilt after. Full Flutter suite/Android E2E not run. `body_training_screen.dart` has two existing analyze info items (unnecessary import and BuildContext async gap); this task did not change those lines.
- Known gaps: no reviewer/manager authority, approval workflow, approved export or management statistics. No real data/model. Native/Render/SQL Server E2E not verified. App-start/connectivity-triggered retry absent; queue retries on new sample, sheet open or manual action. Backup deletion and retention policy unresolved.

## Next exact actions

1. Run focused research tests and Android debug build on current `d7b8015` after any continuation; do not reimplement the finished local/remote consent split.
2. Before real collection, review ethics/consent/retention/label definitions; review and manually execute backend SQL migration, deploy backend `f6caf96`, set `RESEARCH_COLLECTION_ENABLED` and `RESEARCH_CONSENT_VERSION` only when approved.
3. Android test: patient consent → standing knee raise valid rep → local and cloud status → bound therapist sample detail/player/label; verify withdrawal and network retry.
4. Implement separate authorized research manager/reviewer scope (not the therapist role by assumption), review and approved export to existing Python schema, stats, deletion policy, tests.
5. If continuing here: inspect `lib/features/rehab_ml/ml_research_api.dart`, `ml_research_sync.dart`, `ml_sample_sheet.dart`, `therapist_research_samples_page.dart`, and backend handoff first. Then run scoped tests instead of redoing collection.

## Do not redo

- Do not recreate first-round RTMPose collection, Python training or branch.
- Do not fabricate samples, labels, ethics approval, model accuracy or admin authority.
# G3.5 checkpoint (2026-10-03)

Compatible backend final feature SHA: `07f5e3b082c953fae5703880d4abf8b7fbac4f3f` on `codex/g35-research-integration` (clean). Frontend final own SHA must be read with `git log -1`. No master merge yet; retained generated-report change prevents the requested clean-tree gate. Final APK location/hash in G35_VALIDATION. Continuation should handle only the merge gate/manual deployment/device checks, not rerun A/B implementation.

Local C/D acceptance completed; see `docs/G35_VALIDATION.md`. Full Flutter449PASS/7FAIL; all seven reproduced against isolated master baseline (no tests weakened). Final research26PASS/analyze0issues/Python8PASS/debugAPKPASS. Full analyze47existingdiagnostics (master48). Actual MySQL backend258PASS/0skip, then MySQL21PASS after HTTP contract assertions; package/metadata/diff-checkPASS. No migration/model training/real collection. E local merge still pending because pre-existing generated Gradle report is dirty; owner handling authorization requested. Do not redo implementation/full builds; inspect final commits and remaining merge gate/manual checks only.

Stage B contract: see `docs/G35_ACTION_CONTRACT.md`. Legacy schema1 remains readable; new standing samples have definition version. Shared storage/queue/17-point viewer are reused. Backend label version is now sample-bound; export actionId defaults standing and never mixes actions; Python training selects --action with grouped subjects. Tests: Flutter research 26 PASS, Python 8 PASS, scoped analyze clean; backend focused 36 PASS. Next: full regression classification/debug APK and real MySQL (no migrations), then conditional local merge.

Stage A consent diagnostics implemented. See `docs/G35_PROGRESS.md` for current baselines, tests and next actions. Backend compatible branch: `codex/g35-research-integration` (additive consent unavailableReason). No real collection enabled; actual Render availability reason needs authenticated manual verification. Historical sections below remain unchanged.

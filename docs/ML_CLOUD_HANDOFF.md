# ML Cloud Handoff

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

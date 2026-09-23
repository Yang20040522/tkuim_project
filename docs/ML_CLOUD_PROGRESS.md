# ML Cloud Progress

## Third-round Stage C Flutter checkpoint (2026-09-23)

- Backend compatible commits: `904163d` (per-study authority/controlled bootstrap) and `c234af2` (annotation draft, submit, independent review); no SQL script run and no deployment.
- Flutter research API now calls authority, review request/queue, submit and review using existing HMAC headers. Therapist research page shows a backend-gated review-mode switch; sample details save draft, submit, or approve/return according to state without a second skeleton player. Toggle controls visibility only; backend authorizes every operation.
- Focused `flutter test test/features/rehab_ml/ml_research_cloud_test.dart`: 6/6 PASS. `flutter analyze lib/features/rehab_ml test/features/rehab_ml`: 0 issues. Full Flutter suite/APK/SQL Server/Android E2E NOT RUN.
- Next: commit this Flutter checkpoint, then approved export/minimal manager UI, retention, common login and final validation. Do not redo rounds 1–2 or backend Stage B/C.

## Third-round checkpoint (2026-09-23)

- Starting Flutter branch/HEAD: `feat/rehab-ml-poc` / `0b25cc52c29b6ed7da4c5fb092212a6b48e00fc5`; working tree clean.
- Backend branch/HEAD: `feat/rehab-ml-cloud-label` / `8d743794e4d14d9ed914226e26ce090dfc9a7662`; working tree clean. The backend branch is local and must not be recreated from remote `main`.
- Read all four Flutter progress/handoff documents and backend `ML_CLOUD_HANDOFF.md`.
- Phase A in progress: confirmed backend `User.role` is a single PATIENT/THERAPIST string; `/api/auth/login` issues existing HMAC token. Flutter starts at role selection; patient and therapist have separate login screens and session guards. Extra research authority must be server-side and additive, not a role replacement.
- Next: inspect backend research entities/API, auth response and existing account lifecycle; implement a narrow per-study research grant and controlled first-manager bootstrap, with focused tests before any UI change.
- Historical Stage A note; later third-round implementation is recorded above. No migration, push, merge or deployment performed.

## Current stage

Stage 2 minimal end-to-end Flutter slice implemented; not deployed or Android-accepted.

## Git baseline

- Flutter: `feat/rehab-ml-poc` at `ad1f0bf13b3ebb6828aa69cb9f62b8bd7cfee546`; clean at start.
- Backend: `feat/rehab-ml-cloud-label`, created from clean `main` at `94132993d7d32ffc4b090ec429975fa3543275f5`.
- Backend checkout: `C:\Users\kuoja\Documents\GitHub\trianing-system`.
- Backend compatible commit: `f6caf96781884f5809222396cdc834128da63bc2`.
- Flutter first cloud slice commit: `99bb607ce5fd4a12c9b248d79e3093414ec2c37d`; local-only preservation fix: `d7b8015127e78ecf5b9b16e87ccd199b72a3b912`.
- No push, merge or PR.

## Completed

- Located both repositories; no clone or directory overwrite needed.
- Read first-round `ML_PROGRESS.md` and `ML_HANDOFF.md`.
- Inspected backend authentication, role and schema entry points at high level. Existing roles include PATIENT and THERAPIST; research-manager authorization is not yet defined.
- Backend HMAC-authenticated consent/sample/therapist-label API, additive migration and 26 focused tests; committed as `f6caf96`.
- Flutter HTTPS research client, per-user durable pending-ID retry queue, explicit server consent and withdrawal in existing sample sheet, upload after local save outside inference callback, bound-therapist list/detail/2D skeleton playback/seek/label UI.
- Local rehabilitation scoring and RTMPose collection remain unchanged. Existing local sample files are retained after upload failure.
- Follow-up safety fix: first-round local research capture remains available when cloud is unavailable; a separate explicit cloud switch is required before any new sample enters the upload queue.

## Tests

- Flutter: 9 focused research tests passed; 6 body score regression tests passed.
- `flutter analyze lib/features/rehab_ml lib/features/account/therapist_home_screen.dart`: 0 issues.
- `flutter build apk --debug`: passed before local-only preservation follow-up; not rerun after it.
- `git diff --check`: passed for both Flutter stage commits.
- Full Flutter suite, APK build, Android/Render/SQL Server E2E not run in this stage.

## Remaining

1. After governance review, manually execute SQL migration and deploy compatible backend `f6caf96` plus Flutter `d7b8015`; research env defaults OFF.
2. Verify on Android/Render/SQL Server; no real-subject research collection before ethics/consent/retention approval.
3. Add authorized reviewer/manager role, approval state, training export compatible with `ml/train.py`, stats and retention policy; then tests and separate commits.
4. Add connectivity-triggered retry and app-start retry if needed; current retry occurs on sample save, sheet reopen or explicit button.

## Safety

Do not submit real samples, patient identifiers, credentials or keys to Git. No ethical approval or participant consent has been claimed. No model has been trained.

# ML Cloud Progress

## Current stage

Stage 2 minimal end-to-end Flutter slice implemented; not deployed or Android-accepted.

## Git baseline

- Flutter: `feat/rehab-ml-poc` at `ad1f0bf13b3ebb6828aa69cb9f62b8bd7cfee546`; clean at start.
- Backend: `feat/rehab-ml-cloud-label`, created from clean `main` at `94132993d7d32ffc4b090ec429975fa3543275f5`.
- Backend checkout: `C:\Users\kuoja\Documents\GitHub\trianing-system`.
- Backend compatible commit: `f6caf96781884f5809222396cdc834128da63bc2`.
- Flutter first cloud slice commit: `99bb607ce5fd4a12c9b248d79e3093414ec2c37d`; local-only preservation fix commit pending.
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
- `git diff --check`: passed before documentation update; rerun before commit.
- Full Flutter suite, APK build, Android/Render/SQL Server E2E not run in this stage.

## Remaining

1. Commit Flutter stage, record SHA and paired backend SHA in both handoffs.
2. Verify on Android + deployed backend after SQL migration and explicit governance approval; research env defaults OFF.
3. Add authorized reviewer/manager role, approval state, training export compatible with `ml/train.py`, stats and retention policy; then tests and separate commits.
4. Add connectivity-triggered retry and app-start retry if needed; current retry occurs on sample save, sheet reopen or explicit button.

## Safety

Do not submit real samples, patient identifiers, credentials or keys to Git. No ethical approval or participant consent has been claimed. No model has been trained.

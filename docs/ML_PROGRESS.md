# Rehabilitation ML POC Progress

## Current stage

Collection and training-pipeline POC implemented and validated with focused tests plus Android debug packaging. Scope: standing knee raise only. No professionally labeled data, trained model, accuracy claim or device-side classifier is present. Android real-device collection remains unverified.

## Baseline

- Branch: `feat/rehab-ml-poc`
- Starting commit: `a413cd806f82d372bcf56f412b4cb439784cd5dd`
- Starting working tree: clean

## Completed

- Confirmed the existing RTMPose pipeline, body motion template and pose evaluation files exist.
- Created the isolated feature branch from the clean baseline.
- Created continuation documents before implementation.
- Committed this verified POC stage as `0a41d83e10e6e4ee81a3cab63671fdb2d96a95f2`.
- Added opt-in local collection from the existing RTMPose stream and existing rule-based `scored` repetition boundary. The 17 body points are normalized with `BodyNormalization`; missing/low-confidence/non-finite/incomplete data is discarded.
- Added local JSON review/export/delete UI, an anonymous researcher-provided subject code, camera side and segment metadata. Consent lasts only for the current training route.
- Added a versioned Flutter/Python five-feature schema and an unavailable ML evaluation interface. Current repetition scoring remains authoritative.
- Added a Python Random Forest training/export script, subject-grouped holdout, metrics/confusion-matrix output, label provenance, labeling template and minimum-data guard. No model has been trained.

## Files changed

- `docs/ML_PROGRESS.md`
- `docs/ML_HANDOFF.md`
- `.gitignore`
- `lib/actions/standing_knee_raise_action.dart`
- `lib/features/rehab/body_training_screen.dart`
- `lib/features/rehab_ml/` (4 files)
- `ml/` (schema, training script, requirements, label docs/template, tests)
- `test/features/rehab_ml/standing_knee_raise_sample_test.dart`

## Tests run

- `flutter test test/features/rehab_ml/standing_knee_raise_sample_test.dart`: 4/4 passed.
- `flutter test test/features/rehab_ml/ml_sample_sheet_test.dart`: 1/1 passed (explicit consent UI).
- Five existing body/analysis/rehab test files: 31/31 passed.
- `flutter analyze lib/features/rehab_ml test/features/rehab_ml lib/actions/standing_knee_raise_action.dart`: 0 issues.
- Python `unittest discover -s ml/tests -v`: 5/5 passed.
- Scoped analyze including `body_training_screen.dart`: 2 pre-existing info lints (`dart:ui` import, `BuildContext` async gap); no new ML lint.
- Full `flutter test`: 423 passed, 7 failed in untouched account-info, patient-video-card and TV-cast tests; baseline run was not available, so these are *unrelated to the ML diff*, not independently proven pre-existing failures.
- Full `flutter analyze`: 47 existing warnings/info across unrelated files; zero findings in new ML files. Existing body training screen has the two info lints above.
- `flutter build apk --debug`: succeeded at `build/app/outputs/flutter-apk/app-debug.apk`.
- Empty-label training invocation exits 2, creates no output directory/model/metrics.
- `git diff --check`: passed.

## Remaining

1. Human Android test: consent, actual standing-knee-raise capture, export/delete and no collection without consent.
2. Collect and professionally label adequate real samples, then install `ml/requirements.txt`, run grouped training and verify ONNX parity on-device before optional classifier deployment.

## Privacy

Do not commit exported participant samples, names, images, videos or trained model artifacts without verified provenance and validation. Existing training screen recording is a separate pre-existing feature and is explicitly disclosed in the consent sheet; this ML repository does not store pixels.

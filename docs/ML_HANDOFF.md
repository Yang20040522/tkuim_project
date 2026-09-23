# Rehabilitation ML POC Handoff

## Git state

- Branch: `feat/rehab-ml-poc`
- Base commit: `a413cd806f82d372bcf56f412b4cb439784cd5dd`. Last verified implementation commit: `0a41d83e10e6e4ee81a3cab63671fdb2d96a95f2`. Use `git log -1 --oneline` for the latest docs/checkpoint commit.
- Check `git status --short` and `git log -1 --oneline` before continuing.

## Scope and status

Standing knee raise only. Opt-in research sample collection and Python training pipeline are implemented; device/runtime acceptance is not yet done. No professional labeled dataset has been confirmed, so no model, accuracy or deployed classifier exists. Do not invent these artifacts.

## Existing architecture found

- RTMPose: `lib/services/body_pose_engine.dart` and `lib/features/rehab/body_training_screen.dart`.
- Motion templates: `lib/features/analysis/body/`.
- Standing knee raise rules: `lib/actions/standing_knee_raise_action.dart`.
- Separate MediaPipe pose evaluation: `lib/features/pose_measurement/evaluation/`; verify interfaces before reuse.
- Collection path: `BodyTrainingScreen._onPoseUpdate` observes `BodyPoseEngine.poseNotifier`; `BodyRepTrajectoryCollector` samples existing RTMPose points and `RehabFeedback.scored` terminates one repetition. This does not alter counting.
- ML sample schema/repository/UI: `lib/features/rehab_ml/`. Python feature parity/training: `ml/`.

## Data/design decisions

- Use the existing RTMPose output stream and existing segmentation/normalization where compatible.
- ML output is auxiliary and must not drive repetitions, difficulty or prescription changes.
- Capture requires explicit consent. Store skeleton data only. Training/test splits must group by anonymous subject.
- No model predictions until a professionally labeled, validated model exists.
- Only 17 body points, normalized 2D, confidence/angles/timing are saved. No Pi collection in v1; phone front/rear only. Camera mirror is display-only.
- The five features and order are fixed in both `StandingKneeRaiseSample.featureNames` and `ml/feature_schema.py`. Python recomputes from JSON and rejects mismatch before training.
- Label template requires annotator/version/action-definition provenance. Group split uses `subjectId`; per-class minimum is 10 samples and 5 subjects.

## Known failures

- Focused Flutter: 4 collection + 1 consent widget tests passed. Existing body/analysis regressions: 31/31 passed. Python stdlib tests: 5/5 passed. ML module/action scoped analyze: 0 issues.
- Including `body_training_screen.dart` in analyze exposes two existing info lints (`dart:ui` import and async BuildContext usage); no ML error/warning.
- Full Flutter suite: 423 passed, 7 failed in untouched account-info/video-card/TV-cast tests. Not independently confirmed on baseline; do not call them proven pre-existing. Full analyze: 47 unrelated warnings/info and the two body-screen info lints.
- Android debug APK built successfully. No Android native/Gradle/R8 change was made; real device validation remains outstanding.
- Empty label template causes training exit 2 and no model artifact, as intended.
- `scikit-learn` is not installed in the bundled Python runtime, and no labeled data exists. Real train/evaluation/ONNX export has not run.

## Next files and commands

1. Android real-device acceptance: verify consent defaults off, valid knee-raise save, review/export/delete and no Pi/TV regression. Never claim runtime PASS without a device.
2. Obtain physiotherapist-reviewed labels and versioned action definition. Install `ml/requirements.txt`, run `python ml/train.py --samples <private-dir> --labels <private-csv> --output <private-dir>`. Never train on synthetic test fixtures.
3. If grouped metrics are adequate, verify ONNX input/output parity, app-side model load and release/R8 behavior before ever enabling ML predictions.

## Do not redo

- Do not recreate the feature branch or overwrite completed stages.
- Do not retrain on synthetic or unlabeled samples.

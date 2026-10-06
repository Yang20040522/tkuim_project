# Round 4 — Approved Body Dataset + Baseline ML Training Pipeline

Date: 2026-10-07. Round 4 Engineering Gate **PASS**. **NO VALIDATED REAL MODEL YET**.
Round 3 Development Gate accepted; no further physical motions required or requested.
Local isolated MySQL: Round 3 PASS retained / Round 4 NOT RUN. Laboratory: NOT VALIDATED, not accessed. Production: Round 4 NOT DEPLOYED, untouched.

## 1. Implementation Summary — PASS

Actual approved-export consumer -> deterministic dataset/QC -> independent feature parity -> grouped split -> finite RF/XGB/SVM comparison -> winner-only final evaluation -> ONNX/parity/benchmark -> immutable artifact. No rehab runtime or parallel backend changes. Existing master/main only; TV unchanged.
Baselines: master a65dd0cfa50de97a53a175a65c6c297dfb2d6a41; main 496327cfe860290c6987d40dc40ac098a3a4e43c.

## 2. Dataset Builder — PASS

`ml/train_body.py build`, `ml/body_v3/dataset.py`. Bounded approved ZIP, exact payload hashes, unique filenames/label/group IDs, monotonic geometry, deterministic sample/feature/label order. Version/hash includes canonical accepted rows, feature contract, exclusion records, builder version and exact source export hash. Same export rebuilds identical data; changed content/snapshot creates a new version. Exclusive save prevents overwrite.

## 3. Dataset Eligibility Rules — PASS

APPROVED independent review; ACTIVE disposition; active current consent/expiry; non-DEMO, undeleted; body3/action/version/extractor/input/model exact; available recomputed features; >=80% valid observations, no >1000ms gap, complete termination. All draft/submitted/returned/rejected/resample/unassessable/unavailable/expired/revoked/hand/legacy/version mismatches excluded. Rules/rep counts never create real ground truth. Backend authority and retention remain authoritative.
Qualification is not inferred from a backend permission: fresh real export + separate governed professional attestation required. Offline eligibility cannot promise future withdrawal handling; re-export immediately before real training. Backend filter reasons are aggregate counts; Python records candidate exclusion IDs/reasons without private fields.

## 4. Dataset Statistics — PASS (SYNTHETIC ONLY)

72 synthetic attempts; 12 artificial subject groups; 12 sessions; 24 samples / 12 artificial subjects per class; tv_pi72, phone0; no accepted-row exclusions. No names/images/patient records. Dataset version `body-v3-a17c5a616f5f46db`; SHA256 `a17c5a616f5f46db7f847ea3032c5cd759e9340bfa355876b829540cebd8e23f`.

## 5. Real Dataset Availability — DATA_INSUFFICIENT

REAL_DATASET=NONE supplied locally; REAL_DATA_TRAINING=DATA_INSUFFICIENT. Did not query production/laboratory for counts. Round 3 fake/test-motion records were not reused. No real performance claimed.

## 6. Label Contract — PASS

Existing Registry `body-attempt-label-v1`: 0 meets_requirement, 1 insufficient_range, 2 trunk_compensation. unassessable/unable_to_evaluate never classifier classes. No new correct/unstable label or undocumented binary merge. Store revision, anonymous author/reviewer aliases, reviewed time and label version; real qualification requires human governance.

## 7. Feature Schema — PASS

Schema3/body; action standing-knee-raise-body-v2; extractor standing-knee-raise-aspect-2d-v2; input body-attempt-features-v1; pose rtmpose-wholebody-133-v1. Baseline schema body-aspect-baseline-v1, ordered float32 features with units/ranges/null policy in feature_schema.json. No imputation or zero-filling unavailable attempts.

## 8. Dart / Python Feature Parity — PASS

Eight shared actual Dart-output fixtures: valid, insufficient geometry, missing, gap, partial, unavailable, aspect edge, mirror/rotation metadata. Baseline and all three extended features agree; max absolute error 2.842170943040401e-14, tolerance1e-5. Versions/order/units/nulls checked. Training requires PASS receipt from actual Dart fixture output.

## 9. Coordinate / Geometry Handling — PASS

RTMPose anatomical indices; normalized research x/y multiplied by original image width/height; no UI display/mirror coordinate or second semantic swap. 640x480 vs192x256 aspect tested explicitly. SimCC confidence is uncalibrated and may exceed1; missing/NaN/Inf/zero-length torso handled safely. Angles are **2D projected**, not 3D clinical ROM. Original counters untouched.

## 10. Baseline Feature Set — PASS

peak_leg_height (torso ratio), minimum_hip_angle_deg, minimum_knee_angle_deg, peak_abs_trunk_lean_deg, duration_seconds. Math/unit definitions in ml/BODY_V3_README.md. Dimension5.

## 11. Extended Feature Set — PASS (offline-only)

Three explicit extensions: hip_range_deg, trunk_lean_std_deg (population SD), time_to_peak_seconds. Dart/Python parity PASS. body-aspect-extended-v1 / body-attempt-features-extended-v1 (8D). Baseline preserved; no sample upload/TV/counter activation.

## 12. Feature Ablation — PASS (SYNTHETIC ENGINEERING ONLY)

Sixteen actual configurations (8 baseline/8 extended). All validation Macro-F1=1.0 on trivial engineered data. RF/SVM grouped-CV1.0; XGB baseline0.88148, extended best0.94074. No incremental winner benefit; selected baseline. This says nothing about real movement quality.

## 13. Split Strategy — PASS

Seed42; train6/validation3/test3 artificial subjects =36/18/18 attempts. Train-only GroupKFold3; grouped two-fold sigmoid calibration. Bounded20 partition candidates for class coverage, no sample/frame split fallback. Winner frozen before final holdout, one evaluation.

## 14. Leakage Validation — PASS

Subject/session/attempt/content retry/duplicate sample/resample/augmentation guards tested. Scaling inside calibration-fold estimator, never prefit on validation/test. Real final-test ledger rejects repeated pristine use; explicit debug replay is NON-PRISTINE. Ledger is local governance evidence, not tamper-proof distributed security.

## 15. Source Domain Handling — PASS / DATA_INSUFFICIENT

Single-source training enforced. overall and tv_pi engineering metrics available; phone DATA_INSUFFICIENT. No mixed-domain assumption or cross-device generalization claim. Subject grouping includes all sessions/attempts of a person.

## 16. Random Forest Result — PASS (SYNTHETIC ONLY)

RF64/depth4/min-leaf2/sqrt/balanced selected. Train-CV and validation Macro-F1=1.0 on synthetic geometry only; native57105bytes. RF128 also tested. Finite configs/fit time/validation/model size/software latency recorded. No real result.

## 17. XGBoost Result — PASS (SYNTHETIC ONLY)

Pinned XGBoost2.1.4 + onnxmltools1.14.0 installed only in ignored Python venv. Two finite configs actually fitted/exported/parity-checked for each feature set. Baseline CV0.88148; best extendedCV0.94074; validation1.0. No technical conversion failure. No real result.

## 18. SVM Result — PASS (SYNTHETIC ONLY)

Linear/RBF finite C/gamma configurations; all train-CV/validation Macro-F11.0. Scale fit INSIDE each grouped sigmoid calibration fold. Raw decision function is never presented as probability. Calibrated pipeline actually exported and parity-checked; Brier/log-loss diagnostics, not proven clinical calibration.

## 19. Model Comparison — PASS (engineering)

Selection: validation Macro-F1 -> grouped-CV -> balanced accuracy -> worst recall (0.01 tie bands), then simpler baseline/stable family and size/latency. Baseline RF retained for stable near-tie. Final test not used for model or feature selection. All16 models ONNX compatible. Per-class metrics/error analysis/calibration/importance included; importance explicitly noncausal.

## 20. Real Final Test Result — NOT RUN / DATA_INSUFFICIENT

No real approved dataset; no clinical accuracy, calibration, ROM/repetition validity or cross-device generalization. Synthetic test is not pristine real holdout.

## 21. Synthetic Engineering Result — PASS

Actual persisted smoke, 18 attempts/3 artificial test groups, engineering macro/weightedF1/balanced accuracy1.0; confusion diagonal6/6/6. **SYNTHETIC / ENGINEERING_ONLY; not patient performance**. No production candidate or approved model.

## 22. Small Dataset Guard — PASS

10 attempts/5 subjects per class and10 overall subjects are execution minima only. Insufficient class/group/calibration coverage => DATA_INSUFFICIENT, no fabricated test/model. Subject-bootstrap implemented (1000 grouped draws) but current holdout3 subjects => DATA_INSUFFICIENT; no frame-based statistics or clinical power claim.

## 23. ONNX Export — PASS

All16 configurations actually converted. Selected input `features` float32[None,5]; outputs `label`,`probabilities`; class order0/1/2. Main opset15/ai.onnx.ml1. Feature/label/action/extractor/input/model versions and EXPERIMENTAL metadata embedded plus sidecar. skl2onnx1.19.1/onnx1.19.1/ORT1.23.2 recorded.

## 24. ONNX Parity — PASS

56 fixed train/validation/boundary/mean vectors, all three predicted classes represented. Exact class agreement; max probability error1.9868214962137642e-08 <=1e-5. Native/ONNX input wrappers reject null/NaN/Inf/shape mismatch before inference (not a claim raw ORT rejects missing values). Fixed vectors/native predictions/probabilities saved.

## 25. Inference Benchmark — PASS (Windows CPU only)

Separate-process ORT CPU, warmup10 +500 runs: load8.6747ms, p500.0100ms, p950.01482ms. Final ONNX18694bytes. Working set145530880 ->151126016bytes, delta5595136bytes (~5.34MiB); total includes Python/NumPy/ORT, not exact model allocator. Device benchmark NOT RUN / not required for this gate.

## 26. Artifact Structure — PASS

Ignored private path `ml/artifacts/standing_knee_raise/r4-synthetic-20261007-40145b3/`.
39 files: required dataset/hash/split/feature/label/config/environment/metrics/report/confusion/ablation/native/ONNX/parity/log/card; plus selection/errors/importance/Dart parity/vectors/benchmark and per-config native models. Artifact index validates SHA256 of38 companion files (self excluded). Exclusive creation/no overwrite; failed runs retain sanitized failure evidence. No patient data/models committed or assets added.

## 27. Model Status — PASS

EXPERIMENTAL / SYNTHETIC_ENGINEERING_ONLY / deploymentApproved=false. No CANDIDATE production, APPROVED, activation or ML effect on reps/plans. **NO VALIDATED REAL MODEL YET**.

## 28. Pilot Data Collection Recommendation — PASS (document only)

docs/BODY_RESEARCH_ROUND4_PILOT_PLAN.md: exploratory single-domain60 subject planning target,2 sessions,6–10 safe attempts/session; label balance across people, clinician-defined errors/independent review, separate holdout/domain. Not statistical power/clinical sufficiency or instruction to collect now; no additional hardware motions requested.

## 29. Tests — PASS for Round 4 engineering; full Flutter FAIL retained

| Actual command | Result |
|---|---|
| flutter test --no-pub test/features/rehab_ml/body_v3_ml_parity_test.dart | 8/8 PASS, final rerun |
| python -m unittest discover -s ml/tests -p test_body_round4.py -q | 53/53 PASS, final hardening |
| python -m unittest discover -s ml/tests -q | 73/73 PASS (53new+20legacy) |
| python ml/check_body_export_fixture.py ../trianing-system/target/body-r4-approved-test-export.zip | PASS, actual Java mock ZIP -> Python codec |
| flutter test --no-pub test/features/rehab_ml test/features/analysis/body_template_analyzer_test.dart test/features/analysis/body_motion_template_repository_test.dart | 137/137 PASS |
| flutter test --no-pub test/features/analysis/body_rep_trajectory_collector_test.dart test/features/rehab/body_training_score_tracker_test.dart test/features/custom_exercise/custom_exercise_rtmpose_training_test.dart | 18/18 PASS |
| flutter test --no-pub --machine (once) | 556 PASS /7 FAIL; .dart_tool/body-r4/full_flutter.jsonl |
| flutter analyze --no-pub lib/features/rehab_ml test/features/rehab_ml | 0issues PASS after fixing2 new test lint infos |
| flutter analyze --no-pub lib/features/rehab_ml/body_research_extended_features.dart test/features/rehab_ml/body_v3_ml_parity_test.dart | final0issues PASS |
| mvn -q -Dtest=ResearchManagementServiceTest test | 10/10 PASS |
| mvn -q test | total333, 300PASS /33gated skips /0failure/errors |
| CLI synthetic -> build -> train (seed42) | PASS, persisted artifact above |
| artifact companion SHA verification | 38/38 PASS |
| git diff --check (both repositories) | PASS |

Python: `.dart_tool/g4-python/Scripts/python.exe`; Flutter: `C:/development/flutter/bin/flutter.bat`; Maven: `C:/Program Files/apache-maven-3.9.16/bin/mvn.cmd`. No Android/R8/native/packaging changes: APK build NOT RUN, not needed for software-only gate. No database tests opt-in this round; 33 skipped tests remain NOT RUN, not MySQL PASS.

## 30. Existing Regressions — FAIL retained

Actual full suite seven failures in unchanged source/tests, matching existing categories:
1–2 account_info_screen_test (ZEGO pending timer); 3 account_recovery_therapist_registration_test (same); 4 friend_management_screen_test (same); 5 training_result_history_page_test (selected-patient fixture); 6 patient_training_videos_card_test (wording); 7 dual_screen_assisted_training_ui_test (ambiguous IP field finder). No tests deleted/skipped/relaxed. Historical R3 545/7 remains history, not overwritten by this run556/7.

## 31. New Regressions — PASS (none in executed tests)

New Round 4 tests pass; initial two lint infos corrected. No change to existing runtime/UI/auth/hand/TV code. Unexecuted hardware/domain/real-data behavior not described as verified.

## 32. Files Added

Flutter master:
- docs/BODY_RESEARCH_ROUND4_PROGRESS.md
- docs/BODY_RESEARCH_ROUND4_HANDOFF.md
- docs/BODY_RESEARCH_ROUND4_REPORT.md
- docs/BODY_RESEARCH_ROUND4_PILOT_PLAN.md
- lib/features/rehab_ml/body_research_extended_features.dart
- ml/BODY_V3_README.md
- ml/requirements-body.txt
- ml/train_body.py
- ml/check_body_export_fixture.py
- ml/body_v3/__init__.py
- ml/body_v3/features.py
- ml/body_v3/dataset.py
- ml/body_v3/parity.py
- ml/body_v3/split.py
- ml/body_v3/models.py
- ml/body_v3/training.py
- ml/body_v3/benchmark.py
- ml/body_v3/synthetic.py
- ml/tests/test_body_round4.py
- test/features/rehab_ml/body_v3_ml_parity_test.dart
- test/fixtures/body_v3_parity.json

Backend main: docs/BODY_RESEARCH_ROUND4_HANDOFF.md, docs/BODY_RESEARCH_ROUND4_REPORT.md.

## 33. Files Modified

Flutter .gitignore (private datasets/artifacts excluded). Backend src/main/java/com/example/trainingsystems/service/ResearchManagementService.java; src/test/java/com/example/trainingsystems/service/ResearchManagementServiceTest.java. No SQL/entity/controller/Flutter runtime changes. Newly added files subsequently hardened across commits are still additions relative to baseline.

## 34. Git Commits

master: c3fc4029d5f800fca9bf2963c3141d61ca519473 (pipeline), 40145b34e5179709438fcbb0459ac7e08ec967d4 (hardening; artifact implementation SHA).
main: c5f45f7622fe299fcbd801ae12a25b49996ed49e (export), 53e170fa63cafa3af4410ff027580f87dc57701d (interop/regressions).
Final documentation-only commits are reported in completion message / `git log`; do not confuse future doc SHA with recorded model source SHA. Local only, no push/new branch.

## 35. Git Status

After documentation commit: master/main intended clean, verified in completion message. Ignored data/artifacts remain local. TV unchanged HEAD18b5fb17fce608ebb62fd2e27c1692dc91c6c9b3; **seven pre-existing modified generated desktop files preserved**, not reverted or committed. No wholesale master/TV merge.

## 36. Known Limitations

No real approved dataset/model; no real clinical/domain/final-test result. Professional qualifications/approval/source authenticity require governance, not unsigned local JSON. Snapshot cannot track later withdrawals; copy inventory must be managed. Export retains existing500-approved-annotation /20MB cap. Local final-test ledger is not distributed/tamper-proof. CPU memory includes runtime; not device benchmark. Long gaps/2D occlusion/pose errors may exclude clinically meaningful data; no3D reconstruction. CI insufficient on this smoke. Source-specific manifests/runtime integration require future explicit work.

## 37. Technical Debt

Seven existing Flutter failures; domain-specific professional definition/cohort/uncertainty/calibration; secure external export provenance and artifact copy governance; pagination for larger approved datasets; source-shared subject pseudonym consistency across future pooled studies; future App adapter/activation validation. Not addressed by refactoring unrelated features.

## 38. Round 5 Readiness

**Round 4 Engineering Gate PASS**: actual body dataset/parity/grouped baseline/ONNX/artifact pipeline works. **REAL_MODEL readiness DATA_INSUFFICIENT; NO VALIDATED REAL MODEL YET**. Round 5 not started. No lab access, production settings/deploy, real collection, Pi changes, hardware repetition requests, App model activation or remote push.

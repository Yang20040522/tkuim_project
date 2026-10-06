# Body v3 downstream ML — Round 4

Engineering pipeline implemented. **NO VALIDATED REAL MODEL YET.** Existing `train.py` remains body v1/hand v2. This CLI never controls rehabilitation completion, rep/set/hold or patient plans.

## Environment / repeatable commands (PowerShell, repository root)

Use Python 3.12; current ignored interpreter is `.dart_tool/g4-python/Scripts/python.exe`. Install only Python tooling:

```powershell
& .dart_tool/g4-python/Scripts/python.exe -m pip install -r ml/requirements-body.txt
& C:/development/flutter/bin/flutter.bat test --no-pub test/features/rehab_ml/body_v3_ml_parity_test.dart
& .dart_tool/g4-python/Scripts/python.exe -m unittest discover -s ml/tests -v
```

The Dart test generates `.dart_tool/body-r4/dart_parity.json`. Python compares independent math against those **actual Dart values**, not a copied Python golden. Training fails without passing fixture/version/order/units/availability/numeric parity.

Synthetic smoke (choose NEW output path/run ID each execution; immutable directories are deliberately not overwritten):

```powershell
& .dart_tool/g4-python/Scripts/python.exe ml/train_body.py synthetic --output .dart_tool/body-r4/my-synthetic-export.zip
& .dart_tool/g4-python/Scripts/python.exe ml/train_body.py build --export .dart_tool/body-r4/my-synthetic-export.zip --datasets ml/datasets --engineering
# Use the printed dataset version path:
& .dart_tool/g4-python/Scripts/python.exe ml/train_body.py train --dataset ml/datasets/<version>/dataset_manifest.json --output ml/artifacts --run-id <new-run-id> --dart-parity .dart_tool/body-r4/dart_parity.json --seed 42
```

Exact Round 4 persisted run: `ml/artifacts/standing_knee_raise/r4-synthetic-20261007-40145b3/`.
It contains 72 engineered attempts / 12 artificial subjects; none represents a real participant or qualified clinical annotation. Its final holdout is an engineering code exercise, not a real validation test.

## Real data intake

1. Obtain a **fresh authorized body-v3 approved export** from the existing Research Management UI/API, explicitly selecting `phone` OR `tv_pi`. No second backend, anonymous endpoint or permissions bypass.
2. Backend must include the additive `body-approved-export-v1` manifest from main commit `c5f45f7622fe299fcbd801ae12a25b49996ed49e` or later. Old manifests fail closed; re-export rather than fabricating eligibility.
3. A designated qualified reviewer/governance owner must check annotation meaning/qualifications, export provenance and current consent/retention. Create a PRIVATE, ignored attestation JSON (never patient names or credentials):

```json
{
  "exportSha256": "SHA256_OF_EXACT_AUTHORIZED_ZIP",
  "professionallyReviewed": true,
  "currentConsentRechecked": true,
  "governanceReference": "YOUR_NONIDENTIFYING_APPROVAL_RECORD"
}
```

This is an operator/governance assertion, **not** an authentication credential, IRB approval or proof that someone is a clinician. Never assert it for mocks/synthetic data. File possession does not grant server access. Verify receipt over an authorized channel. Do not fill a real approval reference with a fabricated example.

```powershell
& .dart_tool/g4-python/Scripts/python.exe ml/train_body.py build --export ml/data/<authorized-export>.zip --datasets ml/datasets --attestation ml/data/<attestation>.json
```

Do not pass `--engineering` for real research. Fresh eligibility snapshot (<24h) and unexpired rows are rechecked before real training. **Offline snapshots cannot detect a later withdrawal automatically**: re-export immediately before training; remove governed copies on withdrawal. Private artifacts/exports are excluded from Git; no public default storage. Use access-controlled local folders. No real export was accessed in this round.

## Frozen contract / eligibility

- schemaVersion `3`; modality `body`; action `standing_knee_raise`.
- actionDefinitionVersion `standing-knee-raise-body-v2`.
- extractorVersion `standing-knee-raise-aspect-2d-v2`.
- modelInputVersion `body-attempt-features-v1`.
- poseModelVersion `rtmpose-wholebody-133-v1`.
- coordinateTransformVersion `rtmpose-image-normalized-v1`.
- labelMappingVersion `body-attempt-label-v1`.
- Classes in numeric order: `0 meets_requirement`, `1 insufficient_range`, `2 trunk_compensation` (existing Registry labels, never rules/rep success).
- `unassessable`/`unable_to_evaluate`, all non-APPROVED annotations, non-ACTIVE dispositions, expired/deleted/revoked/DEMO, v1/hand2, mismatched versions or unavailable features are excluded.
- Engineering quality policy: >=80% valid projected-feature observations, no gap >1000ms, complete RETURNED_TO_BASELINE/USER_FINISHED termination. Existing extractor availability (>=4 valid, >=60%, positive duration) is unchanged; dataset QC is deliberately stricter. These are engineering thresholds, not clinical validity.
- Verify exact payload SHA, monotonic timestamps/frame IDs, score mask, saved/recomputed angles/features, finite normalized points, original ID/group context and label/reviewer revision provenance.
- Dataset includes anonymous IDs, aliases, resample IDs, source/domain/platform, version/unit/schema, eligibility snapshot, aggregate backend exclusion counts, per-export candidate exclusion reasons and content hash. It excludes names/emails/raw account IDs/tokens/images/video/free-text notes.
- Backend filter reasons are aggregate-only (do not leak IDs of inaccessible/excluded patients). Draft/submitted samples are never queried by approved export.

## Geometry / features

Landmarks are anatomical RTMPose 17 body points. Side indices L=5/11/13/15, R=6/12/14/16; bilateral shoulders/hips define torso. Input x/y in [0,1] multiplied by **original observation width/height**, not square-normalized or UI-transformed coordinates. Lens mirror/rotation are display metadata, not a second anatomical correction. Scores are uncalibrated SimCC peaks; >=0.3 is a validity gate, scores >1 are allowed. Missing/invalid points never become (0,0).

Baseline `body-aspect-baseline-v1`, float32 model input, ordered:

| Feature | Definition | Unit / range |
|---|---|---|
| peak_leg_height | max(max(0, hipY-kneeY)/torso pixel length) | ratio, finite >=0 |
| minimum_hip_angle_deg | min projected shoulder-hip-knee angle | degrees, 0..180 |
| minimum_knee_angle_deg | min projected hip-knee-ankle angle | degrees, 0..180 |
| peak_abs_trunk_lean_deg | max(abs(atan2(shoulderMidX-hipMidX,hipMidY-shoulderMidY))) | degrees, 0..180 |
| duration_seconds | last-first monotonic receipt timestamp | seconds, >0..20 |

These are **2D projected angles, NOT clinical 3D ROM**. Existing pose/counter behavior is untouched.
Optional offline ablation `body-aspect-extended-v1` adds only: hip range (max-min, deg), signed trunk-lean population SD (deg), time-to-first-peak leg height (seconds). Extended input is explicitly `body-attempt-features-extended-v1` (8D), not baseline 5D. It is not uploaded, activated or enabled in TV runtime. Dart/Python extensions share fixtures/parity. Missing attempt => all null and rejected; no imputer/zero-fill.

## Split / models / evaluation

- Seed 42, nominal 60/20/20 **subject** grouping. 20 bounded candidate partition seeds only to obtain class coverage. No frame/sample shuffle fallback.
- GroupKFold3 on TRAIN only; holdout validation used for selection; final subject holdout used once after selection. Subject/session/attempt/resample/retry/content fingerprint/augmentation linkage guards.
- At least 10 attempts / 5 subjects per class and 10 subjects total are engineering execution minima only. Lack of class coverage/grouped calibration/final holdout => DATA_INSUFFICIENT, no fabricated final test.
- A local `.final_holdout_ledger/<datasetHash>.json` reserves the real final test. Subsequent official use fails; explicit `--debug-replay` is labeled NON-PRISTINE. Do not delete/move ledgers to evade governance; they are not a distributed anti-tamper system.
- Eight finite configurations per feature set: RF64/depth4 and RF128/depth8; XGB40/depth2/lr0.1 and XGB60/depth3/lr0.05; SVM linear C1/C4 and RBF C1/scale or C4/0.1. No massive search or GPU requirement.
- SVM uses StandardScaler INSIDE estimator, sigmoid calibration with subject-grouped two folds; all fitting only on training groups. No SVC internal random-sample probability calibration, no raw decision scores presented as probabilities. RF votes/XGB soft probabilities are not proven calibrated; Brier/log-loss diagnostics reported.
- Compare validation Macro-F1, train-CV Macro-F1, balanced accuracy and worst class recall with explicit 0.01 tie tolerance; prefer baseline/stable RF for near ties, then model size/latency. No final test-based selection/ablation.
- Metrics: report/confusion/errors per attempt, overall/phone/tv_pi, eligible-sample coverage, Brier/log-loss, counts. Unsupported/underpowered domain => DATA_INSUFFICIENT. Optional exploratory 1000-repeat subject-cluster CI requires >=20 holdout subjects / >=5 per class; no frame-based CI or power claim.
- Actual ONNX checks every configuration before final selection; fixed train/validation + boundary/mean vectors, class order and every probability error <=1e-5. Null/NaN/Inf rejected by BOTH native/ONNX caller wrappers before inference (not a claim raw ORT rejects NaN).
- Model status always EXPERIMENTAL; deploymentApproved=false. No auto-CANDIDATE/APPROVED or App integration. Real patient generalization remains unvalidated.

## Artifact / audit

Exclusive run folder creation: no overwrite, even failed runs retained with sanitized exception type. Save manifests/hash/schema/labels/split/config/environment, all comparisons/ablation/errors, classification/confusion, model.joblib/model.onnx, fixed parity vectors/receipt, CPU benchmark, importance (noncausal), model card/log and SHA256 artifact index. Git SHA recorded is the actual committed implementation used, not a future report commit. CPU memory is separate-process working-set approximation INCLUDING Python/NumPy/ORT, not exact allocator model memory.

Legacy body v1 / MediaPipe hand v2, runtime counters, BodyPoseEngine, camera, R8/Android dependencies and TV/Pi pipeline were not altered.

Cross-repository codec test (mock data only): run backend `mvn -q -Dtest=ResearchManagementServiceTest test`, then:

```powershell
& .dart_tool/g4-python/Scripts/python.exe ml/check_body_export_fixture.py ../trianing-system/target/body-r4-approved-test-export.zip
```

This verifies real Java export code -> Python consumer, **not MySQL / HTTP / clinical E2E**.

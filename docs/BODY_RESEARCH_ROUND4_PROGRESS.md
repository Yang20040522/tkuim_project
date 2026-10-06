# Body Research Round 4 Progress

## Baseline / scope
- Flutter master: a65dd0cfa50de97a53a175a65c6c297dfb2d6a41 (clean).
- Backend main: 496327cfe860290c6987d40dc40ac098a3a4e43c (clean).
- TV: unchanged; seven pre-existing generated desktop file modifications must be preserved.
- Round 3 Development Gate accepted. No additional physical motion acceptance required.
- No supplied real professionally approved export. REAL_DATASET=NONE; REAL_DATA_TRAINING=DATA_INSUFFICIENT.
- No production/laboratory database access, push, deployment, new branch or Round 5.

## Completed
- Read Round 4 request, body v3 extractor, observation, backend validator/registry/export and existing Python pipeline.
- Confirmed baseline five features use pixel-aspect-correct 2D projection; v1 body / v2 hand remain separate.
- Existing isolated Python environment has sklearn/skl2onnx/ONNX Runtime; XGBoost/converter not installed.
- Added body-only export eligibility/hash metadata (backend), Python dataset/split/model/artifact pipeline and shared fixture parity.
- Added offline-only Dart extended features (hip range, trunk SD, time-to-peak); upload/counter schema unchanged.
- Installed Python-only XGBoost 2.1.4 and onnxmltools 1.14.0 in ignored venv; all three families actually converted to ONNX.

## Remaining
- No remaining Round 4 implementation or validation action.
- Final report/README/pilot committed at a0b028455d770f5d174de0e63ee96015f1500dc0; backend documentation9871f96a4f55db498ceea6895d28daf02d518eab.
- Both master/main working trees verified clean; seven pre-existing TV changes preserved. Final checkpoint receipt commit is available via git log.
- Stop before Round 5. Real training is DATA_INSUFFICIENT until a fresh qualified approved dataset is supplied.

## Decisions
- Labels: existing meets_requirement / insufficient_range / trunk_compensation. unassessable never trained.
- Snapshot eligibility is not permanent consent: fresh authorized export and separate professional/governance attestation required for real training.
- Synthetic artifacts must stay EXPERIMENTAL / ENGINEERING_ONLY, never packaged or activated in App.
- Do not alter runtime feature extraction, counters, camera, hand inference or TV architecture.

## Tests
- flutter test test/features/rehab_ml/body_v3_ml_parity_test.dart: 8/8 PASS.
- Python actual Dart/Python parity: 8 cases PASS; max absolute error 2.842170943040401e-14 (tolerance 1e-5).
- python -m unittest discover -s ml/tests -p test_body_round4.py -v: 46/46 PASS before final hardening.
- mvn -q -Dtest=ResearchManagementServiceTest test: 10/10 PASS.
- Synthetic builder: 72 attempts / 12 artificial subjects / 24 per label, tv_pi only; never real data.
- python -m unittest discover -s ml/tests -q: 73/73 PASS (53 Round 4 + 20 existing v1/hand).
- Actual Maven mock-only approved ZIP -> Python builder codec smoke: PASS (not database or clinical E2E).
- Flutter research + two body analyzer test files: 137/137 PASS.
- Full flutter test --no-pub --machine, once: 556 PASS / 7 FAIL. Same seven existing unrelated files/assertions as R3; no deletion/skip/relaxed assertions.
- Scoped flutter analyze lib/features/rehab_ml test/features/rehab_ml: initially 2 new test lint infos; fixed, rerun 0 issues PASS.
- Backend full mvn -q test: 300 PASS / 33 conditional skips / 0 failures/errors. No MySQL opt-in; NOT new MySQL evidence.
- Initial feature-stage commits: master c3fc4029d5f800fca9bf2963c3141d61ca519473; main c5f45f7622fe299fcbd801ae12a25b49996ed49e.
- Hardened implementation: master40145b34e5179709438fcbb0459ac7e08ec967d4; main53e170fa63cafa3af4410ff027580f87dc57701d.
- Actual CLI synthetic/build/train PASS, artifact ml/artifacts/standing_knee_raise/r4-synthetic-20261007-40145b3 (ignored).
- Dataset a17c5a616f5f46db7f847ea3032c5cd759e9340bfa355876b829540cebd8e23f; train/validation/test artificial subjects6/3/3.
- All16 model conversions/parity PASS; baseline rf-small selected; winner56 parity vectors max probability error1.9868214962137642e-08.
- Windows CPU benchmark PASS: load8.6747ms, p500.0100ms, p950.01482ms, ONNX18694bytes; process working-set delta5595136bytes (not exact model allocator memory).
- Artifact companion SHA256 checks38/38 PASS; status EXPERIMENTAL / SYNTHETIC_ENGINEERING_ONLY / deploymentApproved=false.
- Additional body trajectory/score/CUSTOM RTMPose regression18/18 PASS; final changed-file analyze0 issues.
- New docs: ml/BODY_V3_README.md, docs/BODY_RESEARCH_ROUND4_PILOT_PLAN.md, docs/BODY_RESEARCH_ROUND4_REPORT.md (all38 requested topics).

## Gate
- Round 4 Engineering Gate PASS. No validated real model. Full app suite FAIL with seven preserved unrelated failures.
- Laboratory NOT VALIDATED / not accessed; Production Round4 NOT DEPLOYED / untouched. No DB operation or collection enabled.

## Existing failures retained
- Account info x2, therapist registration, friend-code lookup: ZEGO pending timers.
- Therapist training history selected patient: fixture uses nonnumeric patient ID.
- Patient videos: wording assertion.
- Dual-screen setup: ambiguous IP TextField finder.
- Full Flutter machine evidence: .dart_tool/body-r4/full_flutter.jsonl. All new parity cases passed.

## Do not redo
- Round 3 MySQL / device verification and fixture cleanup.
- Existing hand/v1 training or deployment gate.

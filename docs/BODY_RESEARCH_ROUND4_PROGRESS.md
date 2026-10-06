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
1. Save final hardened code and regenerate persisted SYNTHETIC artifact with that commit as provenance.
2. Pilot plan / exact commands / 38-topic report, artifact inventory and final Git checks.

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

## Existing failures retained
- Account info x2, therapist registration, friend-code lookup: ZEGO pending timers.
- Therapist training history selected patient: fixture uses nonnumeric patient ID.
- Patient videos: wording assertion.
- Dual-screen setup: ambiguous IP TextField finder.
- Full Flutter machine evidence: .dart_tool/body-r4/full_flutter.jsonl. All new parity cases passed.

## Do not redo
- Round 3 MySQL / device verification and fixture cleanup.
- Existing hand/v1 training or deployment gate.

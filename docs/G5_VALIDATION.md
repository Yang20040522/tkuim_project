# G5 Validation

Results appended only after execution. Baseline G4 full Flutter 469 PASS /7 FAIL, full analyze47 existing diagnostics. Do not delete/skip baseline failures.

Initial Git/read-only architecture checks PASS. No professional hand dataset, approval or formal model: NOT READY. Formal training/accuracy/ONNX/device release approval NOT RUN.

Synthetic tests are contract/infrastructure checks only, never model-quality evidence. Backend/MySQL and hardware acceptance must distinguish actual execution from mocks/static checks.

## A/B
- `flutter test test/features/rehab_ml/hand_research_sample_test.dart test/features/rehab_ml/ml_action_contract_test.dart --reporter expanded`: PASS11/11. Four independent collectors, first-count anchoring, complete boundaries, reset/invalid/loss/disabled/no-confidence and synthetic Python/Dart feature golden.
- `.dart_tool/g4-python/Scripts/python.exe -m unittest discover -s ml/tests -v`: PASS18/18, 0 skips. Existing G4 actual synthetic sklearn/ONNX parity preserved; new four-action golden/invalid contracts pass.
- Evidence in ignored `.dart_tool/g5-contract-tests.log` and `g5-python-tests.log`. No formal model.

## C/D/E
- Backend focused40/40 PASS; full281/281 PASS including22 actual localhost MySQL integration tests. Schema remains29 tables/241 columns, no migration. All four hand action insert/read/dedup/label/self-review rejection/approved-only scoped export/withdrawal tested with rollback fixtures. See backend docs/G5_HAND_RESEARCH.md.
- Flutter research suite65/65 PASS. New standalone runtime/model store subset12/12 PASS. Original four action count/completion/level regression and raw-channel-isolation tests passed. Synthetic inputs/approvals are test-only and do not produce clinical accuracy.
- Scoped analyze:0errors/0warnings/6existing training_screen infos; new modules/tests clean.
- Python20/20 PASS,0skips; real Python sklearn→ONNX execution for each independent synthetic hand pipeline. Artifacts only in temporary test directories, all deploymentApproved=false/dataOrigin=synthetic_fixture; not bundled/shipped patient models.
- Initial development failures: hand session fixture omitted initial rep0 (six failures, fixed fixture); test used nonexistent controller.state (compile failure, corrected to existing currentState); wrist rule fixture changed amplitude60° to avoid initial-neutral calibration; new widget filesystem await hung under fake clock (replaced repository boundary with deterministic fake, cancelled only that test session). No deleted/skipped/relaxed existing tests.

Final full Flutter, APK and hardware results pending; append actual execution only.

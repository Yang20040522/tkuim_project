# G5 Validation

Results appended only after execution. Baseline G4 full Flutter 469 PASS /7 FAIL, full analyze47 existing diagnostics. Do not delete/skip baseline failures.

Initial Git/read-only architecture checks PASS. No professional hand dataset, approval or formal model: NOT READY. Formal training/accuracy/ONNX/device release approval NOT RUN.

Synthetic tests are contract/infrastructure checks only, never model-quality evidence. Backend/MySQL and hardware acceptance must distinguish actual execution from mocks/static checks.

## A/B
- `flutter test test/features/rehab_ml/hand_research_sample_test.dart test/features/rehab_ml/ml_action_contract_test.dart --reporter expanded`: PASS11/11. Four independent collectors, first-count anchoring, complete boundaries, reset/invalid/loss/disabled/no-confidence and synthetic Python/Dart feature golden.
- `.dart_tool/g4-python/Scripts/python.exe -m unittest discover -s ml/tests -v`: PASS18/18, 0 skips. Existing G4 actual synthetic sklearn/ONNX parity preserved; new four-action golden/invalid contracts pass.
- Evidence in ignored `.dart_tool/g5-contract-tests.log` and `g5-python-tests.log`. No formal model.

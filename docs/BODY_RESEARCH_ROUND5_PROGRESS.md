# Body Research Round 5 Progress

## Baselines
- Flutter master: 18865d99f13798d7365c7502bb451030203727fc (clean).
- Backend main: 9871f96a4f55db498ceea6895d28daf02d518eab (clean).
- Existing TV worktree: 18b5fb17fce608ebb62fd2e27c1692dc91c6c9b3; seven existing generated desktop changes preserved.

## Completed
- Read Round 5 request and Round 4 handoff; inspected actual model store, ONNX wrapper, v3 extractor/session, v1 phone collector, therapist details and Android keep rules.
- Implemented typed v3 contract/bundle/integrity, ONNX numeric-class evaluator, same-store activation/rollback and scoped advisory consumers.
- Finalized BodyResearchSession and therapist v3 detail consumers wired; annotation/payload/counters unchanged.
- Added explicit compile-time fixture-only validation path and committed 18,694-byte SYNTHETIC test model encoded in test/fixtures (not app assets).

## Decisions
- Extend LocalMlModelStore, not a second registry; namespace v3 separately from legacy v1 with the same action ID.
- Frozen 5D v3 features only. No geometry/counters/annotation changes.
- Synthetic fixture only; compile-time engineering flag default false. No production asset or model approval.
- No backend/database access required for local advisory inference. No lab/production access, push/deploy, Pi changes or physical motion requests.

## Remaining
1. Synchronize necessary shared runtime with existing TV branch; preserve all platform code and existing generated changes.
2. Finish focused regressions/analyze, Release build and emulator validation smoke/benchmark. Debug build already PASS.
3. Full suite once, R4 Python regression, report/handoff and task-only commits. Preserve known failures without claiming them passed.

## Tests
- Default-OFF research focused regression: 162/162 PASS.
- Engineering flag focused + actual Flutter Windows ONNX parity: 41/41 PASS (40 state tests + 1 test covering all 56 vectors).
- Native max probability error 1.9868214962137642e-8. Host ORT load 82,604 us; inference p50 219 us/p95 330 us; host process RSS delta 4,427,776 bytes (not Android benchmark).
- Normal Debug APK build PASS; Release build in progress. Android physical tests NOT REQUIRED. Phone emulator started for automated fixture smoke only.
- First focused run had one test fixture notifier error (test manually changed userId without production changes notifier); corrected fixture and rerun passed. Initial analyze errors during implementation resolved; final analyze pending.
- Real dataset/training: DATA_INSUFFICIENT. Real model available/validated/deployed: NO.

## Do Not Redo
- Do not retrain Round 4 synthetic model or alter frozen feature mathematics.
- Do not modify backend or TV generated-file changes.

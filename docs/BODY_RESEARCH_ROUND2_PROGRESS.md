# Body Research Round 2 Progress

## Baselines and branch safety
- Flutter master: 91fdd2ba1b7406b83406bbd45af76ff1ebd91584; initially clean.
- Flutter TV: codex/android-tv-client, 2f3b67e544475ba3b35de129c8964f1ec3042635.
- Backend main: c5fa9eb6243f14923fc0b3f0cefce5db254d5a67; initially clean.
- Changes uncommitted on existing branches; no push/deploy/production SQL.
- Empty codex/body-research-foundation branches were created before workflow correction, contain baseline only. No additional branches after correction.
- TV worktree moved from .dart_tool/round2-tv to .worktrees/round2-tv after builds; Gradle stopped to release Windows lock. Root .gitignore protects it from accidental tracking. Do not delete this uncommitted worktree.
- No wholesale merges/resets/restoration/dropping work.

## Completed
- Immutable observation; aspect-correct 2D features; v3 context/sample/contract.
- Independent collector: movement 200ms, pre-roll 500ms, baseline 300ms, loss 500ms, maximum 20s/200 observations.
- Pi atomic JPEG/overlay/research packet; serial throttled inference, isolate decode, generation guards.
- Owner-isolated storage/queue/ACK, immutable identity/await guards, legacy unowned samples quarantined.
- TV existing body screen opt-in sidecar, actual assignment ID, local/cloud settings/lifecycle.
- Backend v3 validation/feature recomputation/assignment/idempotency; additive V004/review/audit metadata.
- Shared synthetic Dart/Java fixture; phone body v1/hand v2 preserved, PiHandSource unchanged.
- Complete report/file lists: BODY_RESEARCH_ROUND2_REPORT.md.

## Final validation
- PASS: master focused 9-file tests 58/58.
- PASS: TV flutter test test/features/rehab_ml test/features/tv --no-pub, 57/57.
- PASS: scoped Flutter analyze, 0 issues in both branches.
- FAIL: master full flutter test --no-pub --reporter expanded, 524 passed / 7 failed, matching G4/G5 cases/causes listed in report. Run once before six final added tests and final owner/UI guards; latest focused tests cover final changes.
- PASS: final backend focused ResearchBodyAttemptTest,ResearchBodyMigrationTest,ResearchDataServiceTest,ResearchHandContractTest, 33/33.
- PASS: full mvn test, 303 run / 0 failures/errors / 23 skipped (280 passed). Before one final shared-fixture test; final focused includes it.
- PASS: mvn package -DskipTests.
- PASS: final phone debug APK 31.5s; final TV debug APK 65.6s.
- PASS: final git diff --check in all three worktrees.
- Evidence: .dart_tool/round2-full-flutter.log; backend target/round2-full-test.log/Surefire.
- Initial nullable-call/SDK, format-validation priority and settings-test timing failures resolved.

## Remaining
1. Human review of uncommitted master/TV/main diffs. No new commits.
2. Isolated MySQL: review/apply V004 only, Hibernate/existing-row verification. DB_URL unavailable; V004 NOT EXECUTED.
3. Real Pi -> TV skeleton/sample/upload and phone hand/body camera acceptance.
4. Round 3 modality-aware therapist v3 UI/export; no old classifier/export mixing.
5. Trusted CUSTOM action-definition mapping remains unavailable; DEFAULT standing_knee_raise only, CUSTOM fails closed.

## Decisions / Do Not Redo
- captureTimestamp=null; timestampOrigin=tv_receive_monotonic, not sensor time.
- Invalid points null; raw SimCC not probabilities; 2D only, no world/3D ROM or extra LR swap.
- Research never changes authoritative counters/hold/set/action algorithms.
- Local/cloud consent independent; logout stops collection/sync and clears UI, not another owner's files.
- Preserve phone MediaPipe/R8 and TV isolate/login/DPAD/manifest differences.
- TV body only; PiHandSource legacy, no Pi network/server changes.
- No production activation/deployment/model training; do not begin Round 3.

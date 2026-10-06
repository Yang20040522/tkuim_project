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
- Synced only necessary shared runtime to existing TV branch; no whole-branch merge. Master core64/64, TV50/50, engineering45/45 and actual Windows/Android56-vector parity PASS.
- Normal Debug/Release and isolated engineering/default-OFF Release builds PASS; emulator launch/inference PASS. Disposable emulator stopped; original AVD/physical phone untouched.

## Decisions
- Extend LocalMlModelStore, not a second registry; namespace v3 separately from legacy v1 with the same action ID.
- Frozen 5D v3 features only. No geometry/counters/annotation changes.
- Synthetic fixture only; compile-time engineering flag default false. No production asset or model approval.
- No backend/database access required for local advisory inference. No lab/production access, push/deploy, Pi changes or physical motion requests.

## Remaining
- No implementation or engineering validation work remains. Final task-only documentation commits and Git verification recorded in completion response.
- Stop before Round 6. Real dataset/calibration/model approval/deployment remain unavailable, not silently inferred.

## Tests
- Default-OFF research focused regression: 162/162 PASS.
- Engineering flag focused + actual Flutter Windows ONNX parity: 41/41 PASS (40 state tests + 1 test covering all 56 vectors).
- Native max probability error 1.9868214962137642e-8. Host ORT load 82,604 us; inference p50 219 us/p95 330 us; host process RSS delta 4,427,776 bytes (not Android benchmark).
- Normal Debug and Release APK builds PASS. First release --no-pub hit stale dev-only flutter_native_splash registrant; normal build regenerated plugin metadata and succeeded, no source/dependency change.
- Full Flutter suite once: 596 PASS / 7 FAIL, matching Round4's seven baseline failures. Later four added safety tests pass focused; full suite was not repeated merely to change counts.
- Python 73/73 PASS. Engineering final focused+real parity 45/45 PASS (44 state tests + 56-vector parity).
- TV focused46/46 PASS; scoped analyze0issues (before final file-loader refinement).
- Engineering Release fixture APK PASS, distinct ID com.rehabassist.bodyml.r5validation. Initial embedding via large dart-define exceeded Windows command length; replaced by compile-gated app-owned fixture file path, normal assets unchanged.
- Physical-phone install blocked by auto-review (no clear phone mutation authority). Phone untouched. Original emulator has insufficient space; investigating disposable userdata, not deleting/wiping original AVD.
- Disposable emulator now boots with fresh userdata (4.4GiB free), original AVD untouched. Validation APK application ID confirmed via aapt before install; direct Gradle -P was required because ORG_GRADLE_PROJECT environment variable did not apply through Flutter build invocation.
- Release fixture app installs/launches, stays alive, but fixture file access failed with PathAccessException; actual Android inference/benchmark NOT PASS yet. Diagnose only fixture transport; production sources unchanged.
- Two existing session tests exposed fixed60ms filesystem-wait flakiness under concurrent Gradle work. Added pendingPersistence completion boundary and replaced sleeps with exact waits (same assertions). Final core64/64 and TV50/50 PASS; no weakened assertions.
- First focused run had one test fixture notifier error (test manually changed userId without production changes notifier); corrected fixture and rerun passed. Initial analyze errors during implementation resolved; final analyze pending.
- Real dataset/training: DATA_INSUFFICIENT. Real model available/validated/deployed: NO.
- Shared runtime synchronized to existing TV branch; final TV focused50/50 PASS. Seven pre-existing generated desktop edits remain untouched.
- Final master and TV scoped analyze: 0 issues. One initial analyze invocation used a wrong model-store path; corrected to actual rehab_ml directory, not a source defect.
- Android x86_64 Release engineering runtime PASS on disposable emulator: all56 vectors, maxError1.9868214962137642e-8, typed=PREDICTED. load111334us, first91069us, p501068us, p958244us, processRSSdelta33394688bytes (includes Flutter/FFI and two sessions, not model-only RAM).
- PathAccessException resolved by chmod755 of exactly the shell-created isolated test-app fixture directories; production code unchanged. Physical phone untouched.
- Default-OFF direct Gradle smoke initially hit the same stale dev-only splash registrant after analyze/pub; retry through Flutter Release preparation in progress. No dependency, native or keep-rule changes.
- Default-OFF retry completed: Flutter preparation + explicit existing Gradle validation applicationId; Release build/isolated emulator launch PASS, logcat DEFAULT_OFF PASS. Engineering56-vector logs retained. This smoke checks flag/UI; catalog no-model behavior tested by unit tests.
- Final normal main.dart builds after0f8f0fc: Debug29.4s/Release96.2s PASS. Release490151035bytes; SHA256679741BFD36CB777A2C22CC096C49C2CFC77CFB378FD2AB25C88AA9556136AB2. Final APK ABI/pose/hand assets and unchanged ORT keep/mapping checked; no fixture asset.
- Final TV Debug after34bc367 PASS26.6s. Both branch diff --check against task baselines PASS; full7 baseline failures preserved. Untracked zero-byte Kotlin compiler session cache from this build archived into ignored .dart_tool/body-r5, not deleted/committed.

## Completion status
- MODEL_RUNTIME_ENGINEERING=PASS; REAL_MODEL_AVAILABLE/VALIDATED/DEPLOYED=NO; PRODUCTION_MODEL=NONE.
- Complete report: BODY_RESEARCH_ROUND5_REPORT.md. No production/push/lab/Pi/physical motion operations. Original AVD preserved; temporary validation emulator stopped.
- Implementation commits masterc3f70e9/0f8f0fc; TV20291d1/34bc367 plus final docs43901d0ae1269d162446b924e6570b27cd70fc9d. Final master documentation SHA in completion response/git log; backend9871f96 unchanged.

## Do Not Redo
- Do not retrain Round 4 synthetic model or alter frozen feature mathematics.
- Do not modify backend or TV generated-file changes.

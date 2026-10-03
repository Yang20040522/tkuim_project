# G5 Progress / Handoff

## Baseline (2026-10-03)
- Flutter master `0c9dec45f7b174ede2be7f089c689cb4fdcca98a`; Backend main `7c55d1c7527d94ca0e23c50213f68f7e4f973d7a`. Both clean. Fetch completed: local/remote 0/0 divergence for both (remote now contains G4). No branch/push/deploy.
- Read G4 docs, G35 contract, existing Python training/extractor, hand model/service/controller/actions and research validator/export/storage. No approved hand data or formal models supplied.
- MediaPipeModel passes predicted landmarks to existing frame consumers. G5 must add a separate original-observation field and leave existing display/action behavior intact.
- Existing research_samples LONGTEXT payload + movement_side VARCHAR(8) can represent unknown side with `unknown`; no migration required. No DB/schema operations.

## Stages / Remaining
1. A/B: 21-point schema2, four independent feature contracts/extractors and rule-boundary collectors; raw observation only, opt-in, quality/lifecycle gates; focused/golden tests.
2. C: backend schema2 validator/recomputation, hand-specific consent gate, existing annotation/export reuse and hand skeleton rendering; real MySQL regression if local environment available.
3. D/E: generalize G4 ONNX to explicit per-action contract; lazy loading and local candidate approval/disable/rollback without OTA; tests.
4. F/G: full Python/Flutter tests, scoped analyze, debug/release builds, available hardware checks, final docs and stage commits.

## Decisions / Do not redo
- Four actions: turnPalm, sidePinch, wristExtension, wristSideBend; no TV/Pi/native rewrite, no standing feature substitution.
- Image-normalized 21 xyz points are NOT world coordinates; no fabricated confidence or anatomical handedness. Native channels lack reliable handedness, use unknown.
- First counted repetition after start/reset is a segmentation anchor, not a saved sample; only subsequent complete rule-boundary-to-boundary cycles can be collected. Tracking loss discards the active interval and requires a new anchor. Existing count unaffected.
- Draft features/labels are engineering candidates, not clinical approval. Formal model unavailable until authorized data, independent review, subject grouping, parity/device and human approval.
- Keep local and cloud consent separate; new hand cloud uploads must require an explicitly configured new approved consent version, never silently inherit standing consent.
- No secrets/private data/images/models in Git. Commit small tested stages on existing main/master only.

## Validation
- Branch/status/fetch and static inspection PASS. Professional definitions/data/formal models NOT READY; device/runtime NOT RUN.

## A/B contract checkpoint
- Added four schema2 action definitions and separate21-point extractors/collector. Dart/Python use shared synthetic motion recipe with independently fixed expected features.
- Focused Flutter11/11 PASS (`g5-contract-tests.log`); full Python18/18 PASS (`g5-python-tests.log`), zero skips. Existing standing contract/parity remains passing.
- Native bridge observations are already low-pass filtered and front X-corrected; research records these real channel observations, not unsmoothed sensor data or Dart 0.4-frame extrapolation. No second mirror correction or anatomical-side guess.
- Remaining: raw field/controller/UI runtime wiring, backend schema2/consent/export/player, generic ONNX/local release management, final regression/build/device checks. Do not reimplement contract module.

## C/D/E implementation checkpoint
- Backend schema2 recomputation, hand-specific consent/label gates, existing review/action export complete. Focused40 PASS; full281 PASS including22 actual localhost MySQL tests, four-action round trip/review/withdrawal. No schema/env change. Backend docs/G5_HAND_RESEARCH.md records evidence.
- Flutter raw observation field leaves original predicted/action frames unchanged; optional controller observer/reset callbacks isolated; phone research sheet, hand player/export selection, cloud handAvailable gate implemented.
- Generic per-action ONNX manifest/source/feature contracts, local candidate registration/approval/disable/rollback and lazy single-action evaluator implemented. No formal models/assets added.
- Python20 PASS including actual synthetic RF/ONNX parity for each action (not accuracy evidence). Runtime/model store focused12 PASS after fixing first-anchor test fixture; initial six failures were test input starting at rep1 without prior rep0, not hidden/skipped.
- Remaining in order: four original Action/controller regression + player/export tests; scoped analyze fix new diagnostics; research focused rerun; stage commits; full Flutter once; debug/release builds; available Android/device acceptance (cannot claim model runtime absent approved model); final report/docs/commits.

## Runtime/release checkpoint
- Research focused **65/65 PASS** including all four original Action counting/turnPalm+sidePinch manual difficulty, observer failure isolation, channel observations vs predicted frames, 21-point player/hand label version, hand consent denied without writing inherited scope, per-action management export, candidate approval/disable/rollback/hash tamper/inference disposal. Evidence `.dart_tool/g5-research-focused-final.log`.
- Scoped analyze: **0 errors,0 warnings,6 pre-existing training_screen info** (unnecessary import, two async BuildContext, three withOpacity); new G5 files0 issues. `.dart_tool/g5-analyze-final.log`.
- Python20/20 PASS after final bounded-feature consistency. Backend C commit `3ffd5e6` (281/281 PASS incl22MySQL); final bound hardening requires targeted rerun before next backend commit.
- Connected real phone RMX3371 arm64; user agrees to assist after builds. Hardware currently NOT RUN. No formal model, so clinical/formal ONNX runtime/performance cannot be claimed.
- Remaining: full Flutter once, final bounds focused test, backend bound test/checkpoint, Android debug+release build/packaging check, install Release and user-assisted four-action acceptance, final docs/table/commits. Do not redo completed modules or train formal models.

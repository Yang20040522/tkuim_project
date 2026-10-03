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

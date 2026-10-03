# G5 Mobile Release Gates

No hand models are approved, trained on qualified real data or bundled. Four models must remain unavailable. No push/deploy/collection enabled. Android TV/Pi deferred.

Before formal release: professional per-action definitions/labels, new approved hand consent and retention scope, authorized independent-reviewed data, sufficient distinct participants, grouped evaluation, actual sklearn/ONNX parity, Android debug/release inference/offline/latency/memory/lifecycle, human model approval. SHA-256 is integrity, not source signature. Trusted local approval is not evidence of clinician credentials or clinical reliability.

Minimum phone acceptance: run each existing hand action without research consent; verify21-point skeleton, original count/level/voice/history. Explicitly opt into local research, perform anchor then complete cycles, inspect/export/delete anonymous samples, pause/flip/level-change/background clears active interval. Refuse cloud consent and verify local capture still works. Missing/rejected/disabled model must show unavailable without disturbing training. Approved test-environment models must never enter formal patient Release as synthetic substitutes.

All hardware/model-performance steps initially NOT RUN. No formal model accuracy or clinical claims.

## Current device gate
- Debug and minified Release built successfully. Initial Release installed on RMX3371; hand training **FAIL** (MediaPipe Graph/Flogger initialization crash). Automated collector/count tests do not override this failed device gate.
- R8 mapping/bytecode investigation and a single factory-boundary keep rule are in progress; final phone retest required before stating that the21-point skeleton, voice or counting works on Release.
- Formal model inference latency/memory **NOT RUN**: no qualified approved model exists. Do not substitute synthetic test artifacts in the patient APK.
- Latest corrective Release installed: `build/app/outputs/flutter-apk/app-release.apk`, 489659515 bytes, SHA256 `9F63F7DC0BAF71069D4DFC2EF387C4B87F781C01802FE7EEC47C2571F7F71F64`. Packaging-only R8 fix keeps Flogger factory/caller-finder boundaries and protobuf.Any; minification and original algorithms retained. Phone retest pending. Earlier factory-only attempt failed; subsequent two-method attempt removed fatal crash but exposed Any initialization failure, both retained in G5_VALIDATION.md.

| Action | Collector / contract tests | Professional labels / real data | Formal training / ONNX | Flutter interface | Phone acceptance | Formal enablement |
|---|---|---|---|---|---|---|
| turnPalm | PASS | NOT READY | NOT RUN (synthetic parity PASS only) | PASS with fakes | FAIL at initialization; retest pending | NO |
| sidePinch | PASS | NOT READY | NOT RUN (synthetic parity PASS only) | PASS with fakes | NOT RUN; shared initialization blocker | NO |
| wristExtension | PASS | NOT READY | NOT RUN (synthetic parity PASS only) | PASS with fakes | NOT RUN; shared initialization blocker | NO |
| wristSideBend | PASS | NOT READY | NOT RUN (synthetic parity PASS only) | PASS with fakes | NOT RUN; shared initialization blocker | NO |

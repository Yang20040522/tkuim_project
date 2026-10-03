# G5 Mobile Release Gates

No hand models are approved, trained on qualified real data or bundled. Four models must remain unavailable. No push/deploy/collection enabled. Android TV/Pi deferred.

Before formal release: professional per-action definitions/labels, new approved hand consent and retention scope, authorized independent-reviewed data, sufficient distinct participants, grouped evaluation, actual sklearn/ONNX parity, Android debug/release inference/offline/latency/memory/lifecycle, human model approval. SHA-256 is integrity, not source signature. Trusted local approval is not evidence of clinician credentials or clinical reliability.

Minimum phone acceptance: run each existing hand action without research consent; verify21-point skeleton, original count/level/voice/history. Explicitly opt into local research, perform anchor then complete cycles, inspect/export/delete anonymous samples, pause/flip/level-change/background clears active interval. Refuse cloud consent and verify local capture still works. Missing/rejected/disabled model must show unavailable without disturbing training. Approved test-environment models must never enter formal patient Release as synthetic substitutes.

All hardware/model-performance steps initially NOT RUN. No formal model accuracy or clinical claims.

## Initial device failure and resolved packaging gate
- Debug and minified Release built successfully. Initial Release installed on RMX3371; hand training **FAIL** (MediaPipe Graph/Flogger initialization crash). Automated collector/count tests do not override this failed device gate.
- R8 mapping/bytecode investigation and successive minimal fixes are fully recorded in G5_VALIDATION.md. Final phone retest now confirms skeleton/voice/count; earlier failures are retained as history, not current failures.
- Formal model inference latency/memory **NOT RUN**: no qualified approved model exists. Do not substitute synthetic test artifacts in the patient APK.
- Latest corrective Release installed: `build/app/outputs/flutter-apk/app-release.apk`, 489659515 bytes, SHA256 `9F63F7DC0BAF71069D4DFC2EF387C4B87F781C01802FE7EEC47C2571F7F71F64`. Packaging-only R8 fix keeps Flogger factory/caller-finder boundaries and protobuf.Any; minification and original algorithms retained. User-assisted phone training checks PASS. Earlier factory-only attempt failed; subsequent two-method attempt removed fatal crash but exposed Any initialization failure, both retained in G5_VALIDATION.md.

| Action | Collector | Contract | Professional label definition | Qualified real data | Formal training | ONNX verification | Flutter interface | Phone training | Formal enablement |
|---|---|---|---|---|---|---|---|---|---|
| turnPalm | PASS | PASS | NOT READY | NOT READY | NOT RUN | synthetic parity PASS / formal NOT RUN | PASS with fakes / formal model NOT RUN | user-assisted PASS | NO |
| sidePinch | PASS | PASS | NOT READY | NOT READY | NOT RUN | synthetic parity PASS / formal NOT RUN | PASS with fakes / formal model NOT RUN | user-assisted PASS | NO |
| wristExtension | PASS | PASS | NOT READY | NOT READY | NOT RUN | synthetic parity PASS / formal NOT RUN | PASS with fakes / formal model NOT RUN | user-assisted PASS | NO |
| wristSideBend | PASS | PASS | NOT READY | NOT READY | NOT RUN | synthetic parity PASS / formal NOT RUN | PASS with fakes / formal model NOT RUN | user-assisted PASS | NO |

Final Release turnPalm no longer crashes and displays skeleton per user retest; a subsequent user test confirms the other three actions, not an assumed shared-implementation PASS. The hand cloud-consent switch remains closed on purpose: hand scope/consent version/retention have not been approved/configured; local research opt-in is separate. Do not just set an environment flag to bypass professional approval. Older backend consent responses without handAvailable also fail closed.

Live final-APK trace confirms initialized Hand Landmarker, camera analyzer, detector result and `landmarks=21`. Successful init/events do not by themselves prove all voice/count/collection/lifecycle checks.

Final user reply confirms the requested remaining three actions, pause/flip/reentry and local-only sample/no-model UI checks are all normal. User-assisted results are not evidence of formal model accuracy. Separately pending phone export/delete/background/explicit difficulty/history checks are listed in G5_VALIDATION.md; qualified-model performance and cloud deployment remain NOT RUN. Final G5 full-suite result remains497PASS/7FAIL, not all PASS.

# G4 Progress / Handoff

## Baseline / Stage A (2026-10-03)

- Flutter clean master / `a8fb0c96486f0d8af8f5997051f25cb5d45b4c2f`, matches `git ls-remote origin refs/heads/master`.
- Backend clean main / `7c55d1c7527d94ca0e23c50213f68f7e4f973d7a`, matches remote. Read-only this round.
- Read required G35 validation/progress/action contract, ML cloud handoff, LABELS/train/feature_schema and actual Java approved-export implementation.
- Data readiness: **NOT READY**. No authorized export, approved professional label/action definition, current consent/retention evidence or sufficient independently reviewed participant dataset supplied. LABELS.md remains a draft. No private sample content inspected, no collection enabled, no DB/export API accessed.
- Existing five features, standing schema1 and legacy definition compatibility preserved. Existing exporter filters active consent, expiry, independent reviewer and trainable labels; ZIP manifest has action/version/features/count, not a signed governance attestation.
- Existing train.py lacks ONNX parity/manifest, duplicate JSON IDs can be skipped after popping labels; existing evaluator is unavailable and not integrated into rep events.

## Remaining (ordered)

1. Owner supplies fresh authorized independently reviewed export, professionally approved action/labels and current consent/retention evidence. Readiness remains NOT READY; do not invent labels or enable collection.
2. Run documented CLI against those private files, review subject-grouped real-data metrics and actual ONNX parity. No formal model has been trained this round.
3. Validate the real candidate on Android (native TreeEnsemble kernel, exact output contract, completed-rep behavior, offline operation, latency/memory and lifecycle). Only after separate human release approval package its versioned manifest/model. Do not authorize by merely flipping booleans.
4. Do not start G5, push/deploy or alter backend/database automatically.

## Decisions / Do not redo

- Use master; no branch/push/deploy/backend/schema change. Stage commits must include only G4 files.
- No real dataset or production model. Test synthetic artifacts remain temporary/ignored, never packaged.
- Training outputs default deployment-unapproved even after numerical parity. Runtime must refuse unapproved/synthetic models.
- Preserve consent separation, current RTMPose engine/counting and chat. Logs contain no sample/person identifiers.
- Python bundled runtime available at `C:/Users/kuoja/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`; use ignored local venv for ML dependencies.

## Tests

Stage A: branch/remote/status and static source contract inspection PASS. Clinical/data readiness NOT READY; Android and real-data training NOT RUN.

## Stage B/C completed

- Hardened train.py without replacing existing extractor/action registry; duplicate JSON IDs checked before label removal, class/group/version/float32 validation, deterministic grouped holdout and frozen RF parameters.
- CLI requires fresh existing export manifest and trusted private governance/content-hash verification. Backend export and auth unchanged. Offline attestation cannot prove new withdrawals or clinician credentials; manual governance remains necessary.
- model_artifacts.py checks actual sklearn/ORT string labels + ordered probabilities (1e-5 absolute tolerance), before writing versioned artifacts. Default deploymentApproved=false; synthetic artifacts remain nondeployable.
- Python 16/16 PASS (`.dart_tool/g4-python-tests.log`), actual ORT parity/reproducibility exercised only on temporary synthetic fixtures. No formal dataset/training/model/metrics.
- Initial two test failures fixed: preserved existing waiting-data error wording; protobuf7 rejects skl2onnx1.19.1 boolean integer attributes, pinned protobuf5.29.5 in Python-only requirements and validated. No native dependency upgrade.
- Files: ml/train.py, model_artifacts.py, requirements.txt, LABELS.md, test_g4_training.py, test_g4_golden.py, synthetic g4_features.json; G4 docs. No patient data committed.

## Stage D completed / E focused checks

- Local checkpoints: Stage A `8280669`, Stage B/C `6940978`; current checkpoint obtained using git log after commit.
- OnnxMlQualityEvaluator uses existing onnxruntime_v2, CPU one thread, exact manifest/type/order/classes/preprocessing/bytes hash + reviewed_export/approved_research gate. Native tensors/options/outputs released, disposal waits in-flight call; shared RTMPose OrtEnv never released.
- Lazy model loader returns Unavailable with absent/rejected model. No model assets created. Only crypto3.0.7 promoted from existing transitive dependency (same locked version).
- BodyTrainingScreen observes existing consented completed-rep sample, one auxiliary async call, no rule/rep/RTMPose changes. Busy inference cannot publish older rep as current. Sheet presents version/prediction/probability and research disclaimer; no arbitrary confidence cutoff.
- Existing local/cloud consent separation preserved. No camera images transmitted for inference. No backend changes.
- Shared synthetic JSON golden tested in Python and Dart: anatomical L/R, valid/incomplete/low confidence/non-finite, legacy schema1 and wrong definition/feature order.
- Flutter focused research+rehab+normalization/template **68/68 PASS**, scoped research analyze **0 issues**, Python **16/16 PASS**. Initial fake async typing/lints fixed; reproducible ONNX graph explicitly named (converter otherwise generated random graph name/hash).
- ADB device detected, arm64-v8a. No formal model exists, so actual clinical-model loading/rep/offline latency/memory remains NOT RUN. Do not describe this as no device available or actual inference PASS.
- Stage D checkpoint: `967c9f6`. Final Stage E results below supersede the earlier remaining validation list; do not rerun full tests/builds without code changes.

## Stage E completed / final checkpoint

- Full Flutter suite executed once: **469 PASS / 7 FAIL**. All seven names/reasons match the recorded baseline; details in G4_VALIDATION.md. No tests deleted/skipped or unrelated fixes attempted.
- Full analyze: **47 existing diagnostics (44 info, 3 warnings, 0 errors)**. Research scope remains 0 issues.
- Debug and Release builds both PASS. Release assets include original RTMDet, RTMPose and hand model; no synthetic classifier model/manifest included. Existing ONNX and MediaPipe R8 rules retained; no Android/native changes.
- Final diff check PASS; both working trees were clean after the Stage D commit/builds. Backend still `7c55d1c7527d94ca0e23c50213f68f7e4f973d7a`, read-only. Final documentation commit contains only these G4 documents; obtain its SHA with `git log -1` (self-referential hash not stored here).
- Engineering stages A–E completed to the available-data boundary. Formal model training, real-data metrics, qualified-model Android runtime and formal deployment acceptance remain NOT RUN / BLOCKED by absent approved data. An Android device is attached; it was not used to install/run this build. No clinical accuracy or hardware performance claim.
- No remote push, branch creation, backend/DB mutation, deployment, research enablement or model packaging. Existing RTMPose/MediaPipe, reps, local/cloud consent, chat and TV behavior were not redesigned.

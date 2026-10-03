# G4 Model Contract

Only standing_knee_raise / schema1 / standing-knee-raise-v1. Input order: peak_leg_height, minimum_hip_angle_deg, minimum_knee_angle_deg, peak_abs_trunk_lean_deg, duration_seconds.

These are existing normalized 2D RTMPose research features, not clinical 3D joint angles. Do not re-normalize the five values, change anatomical sides or infer labels from rule-based counting.

Formal training requires a fresh authorized approved export and human governance verification, not manually invented Ground Truth. Legacy standing samples without definition metadata retain v1 readability. unassessable is excluded, never a classifier output.

Planned artifact contract: model.onnx + model_manifest.json + metrics.json in ignored private output. ONNX float32 [N,5], ordered string labels and [N,3] probabilities (ZipMap off). Record feature/class order, versions, preprocessing, SHA256, parity tolerance/status and deployment approval. Numerical parity alone never authorizes release. No production model is bundled until real-data evaluation and separate human/device approval.

Implemented manifest v1: `modelVersion`, `actionId`, `schemaVersion`, `actionDefinitionVersion`, `labelVersion`, `featureNames`, `classes` (actual sklearn.classes_ order), `inputName`, `labelOutputName`, `probabilityOutputName`, `inputDimension=5`, `inputShape=[null,5]`, `inputDtype=float32`, `preprocessing=rtmpose17-normalized-2d-v1;features-identity;float32`, `modelSha256`, `dataOrigin`, `validationStatus`, `deploymentApproved`, `onnxParity`, `runtimeVersions`, `confidenceThreshold`, `confidenceThresholdValidated`.

Runtime contract must require reviewed_export, approved_research + deploymentApproved, parity PASS, exact action/schema/definition/label/features/shape/type/preprocessing and actual bytes hash. Exported artifacts are parity_verified/unapproved by default. Human approval is a trusted build-time process, not a server-side model-update service (G5 deferred).

No arbitrary confidence threshold. Unless a separately validated threshold is supplied, display predicted probability as uncalibrated model information, not correct/incorrect or medical reliability. Every result remains independent of rule-based reps/sets/plans.

Model version includes ONNX SHA256 first12 characters; deterministic graph name avoids random export hashes. Runtime asset location for a future reviewed build: assets/models/rehab_ml/model_manifest.json and model.onnx (existing assets/models/ declaration). **No files exist there this round**. Do not copy test fixtures to this location. Human approval must resolve labelVersion against the registered Dart contract and separately approve real-data/device results; flipping manifest booleans is not evidence of approval.

The completed-rep observer only runs inside existing explicit local research consent, not automatically upon login/training. Concurrent slow analysis is conservatively unavailable for a later rep and suppresses stale earlier output; counting continues. Reset/dispose clear displayed analysis. Missing models allocate no additional native session; available classifier uses the same Runtime, a separate lightweight model session, not a second pose detector.

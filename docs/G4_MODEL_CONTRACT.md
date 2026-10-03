# G4 Model Contract

Only standing_knee_raise / schema1 / standing-knee-raise-v1. Input order: peak_leg_height, minimum_hip_angle_deg, minimum_knee_angle_deg, peak_abs_trunk_lean_deg, duration_seconds.

These are existing normalized 2D RTMPose research features, not clinical 3D joint angles. Do not re-normalize the five values, change anatomical sides or infer labels from rule-based counting.

Formal training requires a fresh authorized approved export and human governance verification, not manually invented Ground Truth. Legacy standing samples without definition metadata retain v1 readability. unassessable is excluded, never a classifier output.

Planned artifact contract: model.onnx + model_manifest.json + metrics.json in ignored private output. ONNX float32 [N,5], ordered string labels and [N,3] probabilities (ZipMap off). Record feature/class order, versions, preprocessing, SHA256, parity tolerance/status and deployment approval. Numerical parity alone never authorizes release. No production model is bundled until real-data evaluation and separate human/device approval.

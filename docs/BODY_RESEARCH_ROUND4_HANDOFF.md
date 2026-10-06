# Body Research Round 4 Handoff

Read BODY_RESEARCH_ROUND4_PROGRESS.md, report (when present), and both Git diffs before continuing.

Current branches: Flutter master; backend main. Baselines are recorded in progress.
First independently tested commits: master c3fc4029d5f800fca9bf2963c3141d61ca519473; backend c5f45f7622fe299fcbd801ae12a25b49996ed49e.
Legacy ml/train.py handles v1 body / v2 hand; preserve it. New body v3 tooling must use the actual backend approved export contract.

Contract: schema 3, body, standing_knee_raise; action standing-knee-raise-body-v2; extractor standing-knee-raise-aspect-2d-v2; input body-attempt-features-v1; pose rtmpose-wholebody-133-v1.
Feature order: peak_leg_height, minimum_hip_angle_deg, minimum_knee_angle_deg, peak_abs_trunk_lean_deg, duration_seconds.
Sample geometry is image-normalized with width/height metadata, anatomical indices, uncalibrated SimCC scores (may exceed 1); not UI mirror coordinates or clinical 3D ROM.

Python executable: `.dart_tool/g4-python/Scripts/python.exe` (ignored existing environment). Never commit private exports, models or training data.
Flutter executable: C:/development/flutter/bin/flutter.bat.
Backend Maven: C:/Program Files/apache-maven-3.9.16/bin/mvn.cmd.

No real approved dataset supplied. Do not reuse cleaned Round 3 fake-account/test-motion samples as real research data. No laboratory/production access, push/deploy/new branches or further physical motions. Stop before Round 5.

Implemented: ml/body_v3 dataset, features/parity, subject-grouped splits/calibration, finite RF/XGBoost/SVM search, native/ONNX parity, benchmark and exclusive artifact packaging. Existing train.py untouched.
Run Dart fixture test before Python tests. Root ml/train_body.py is the body-v3 CLI; see ml/BODY_V3_README.md (when present).
Real final-test ledger (.final_holdout_ledger in private artifacts) prevents reusing a final test as pristine; debug replay must explicitly mark NON-PRISTINE. Do not delete/move ledger to fabricate a new test.
Current validation: Python 73 PASS, Flutter focused137 PASS, full556 PASS/7 pre-existing FAIL, scoped analyze0 issues, Maven300 PASS/33 skipped.
Next: save hardening commit, generate ignored synthetic artifact from committed code, write pilot/report and final checks. No dataset/model activation on App.

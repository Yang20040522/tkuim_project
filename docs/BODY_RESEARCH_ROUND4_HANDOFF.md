# Body Research Round 4 Handoff

Read BODY_RESEARCH_ROUND4_PROGRESS.md, report (when present), and both Git diffs before continuing.

Current branches: Flutter master; backend main. Baselines are recorded in progress. No Round 4 commit yet.
Legacy ml/train.py handles v1 body / v2 hand; preserve it. New body v3 tooling must use the actual backend approved export contract.

Contract: schema 3, body, standing_knee_raise; action standing-knee-raise-body-v2; extractor standing-knee-raise-aspect-2d-v2; input body-attempt-features-v1; pose rtmpose-wholebody-133-v1.
Feature order: peak_leg_height, minimum_hip_angle_deg, minimum_knee_angle_deg, peak_abs_trunk_lean_deg, duration_seconds.
Sample geometry is image-normalized with width/height metadata, anatomical indices, uncalibrated SimCC scores (may exceed 1); not UI mirror coordinates or clinical 3D ROM.

Python executable: `.dart_tool/g4-python/Scripts/python.exe` (ignored existing environment). Never commit private exports, models or training data.
Flutter executable: C:/development/flutter/bin/flutter.bat.
Backend Maven: C:/Program Files/apache-maven-3.9.16/bin/mvn.cmd.

No real approved dataset supplied. Do not reuse cleaned Round 3 fake-account/test-motion samples as real research data. No laboratory/production access, push/deploy/new branches or further physical motions. Stop before Round 5.

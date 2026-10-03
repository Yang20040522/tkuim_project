# G4 Validation

Baseline: Flutter `a8fb0c96486f0d8af8f5997051f25cb5d45b4c2f`, backend `7c55d1c7527d94ca0e23c50213f68f7e4f973d7a` (clean local/remote).

Stage A static audit PASS; actual approved dataset/consent/retention/professional definition verification **NOT READY** (not supplied). No real model/accuracy exists. No backend modification, SQL, export API call, secret access or research enablement.

Subsequent results must be appended only after commands actually execute. Real Android / Render acceptance NOT RUN. Seven baseline Flutter failures are documented in G35_VALIDATION.md and CHAT_REALTIME_VALIDATION.md; G4 must rerun and classify rather than assume no regression.

## Stage B/C

` .dart_tool/g4-python/Scripts/python.exe -m unittest discover -s ml/tests -v`: **PASS 16/16**, 0 skip. Evidence `.dart_tool/g4-python-tests.log` (ignored). Temporary synthetic RF exported and compared in real Python ORT; no formal accuracy/F1 reported. Repeated grouped run produces identical report. Non-finite/wrong-dimension inputs rejected; insufficient dataset writes no output; duplicate IDs/governance/version tests PASS.

Python env: 3.12.14, numpy2.2.6, sklearn1.7.2, skl2onnx1.19.1, onnx1.19.1, ORT1.23.2, protobuf5.29.5. Initial protobuf7 conversion TypeError and old waiting-data wording test failure corrected, not hidden/skipped.

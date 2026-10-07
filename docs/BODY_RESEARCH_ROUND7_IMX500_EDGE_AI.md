# Round 7 — IMX500 Edge AI + ROI-conditioned RTMPose

## Final progress / continuation checkpoint

- Round 7 engineering gate: PASS. Core local commit `69e1e7e75dab5df661c79429bc4e0cb948bdc20d`; final evidence/tooling commit is recorded in the completion report and `git log`.
- Implementation, official package installation, verified backup, Pi deployment, sensor tensor smoke, legacy/edge stream smoke, actual Release TV emulator ONNX/ROI/reconnect smoke, tests, scoped analyze and final normal TV Debug/Release builds completed.
- No Round 7 implementation remains. Live-person detection/optical overlay alignment/clinical accuracy are NOT RUN, not falsely included in this engineering gate. No physical movements requested. Stop before Round 8.
- No push, branch creation, master/backend changes, Render/Lab DB/Tailscale/network changes, new ports or reboot.
- The earlier checkpoints below are historical, superseded by the final 37-section evidence report. In particular early NOT RUN/pending and early 12-test counts are not the final status.

## Initial baseline (historical)

- TV baseline: `43901d0ae1269d162446b924e6570b27cd70fc9d` on existing `codex/android-tv-client` worktree.
- Mobile baseline: `f8f12948d31fb9fa1ec3be04c5ad6bad0f5c0d1b`, clean; no mobile changes planned.
- Existing TV generated Linux/macOS/Windows plugin edits: seven files, preserve and do not commit.
- Pi SSH verified on eth0; Debian 13.5 aarch64, Picamera2 0.3.36, websockets 16.1.1.
- Existing service `/etc/systemd/system/camera-server.service` runs `/usr/bin/python3 /home/iphone/camera_server.py` as iphone; raw JPEG WebSocket 8765.
- Existing server uses `capture_array()` + Pillow JPEG quality 60, 33ms sleep per client. No tracked authoritative server found.
- IMX500 model package not installed; `/usr/share/imx500-models` absent. Installation/model/API validation pending.
- No Pi file, package, service or network change yet. No Render/database/Tailscale access this round.

## Decisions

Sensor-only official person detector; TV retains existing RTMPose 133 model. Text metadata + binary JPEG only after explicit edge-v1 handshake; legacy stays binary. Metadata/image from same request, no cached detections. All ROI points map back before EMA, overlay, counters and BodyPoseObservation. Research v3 and ML contracts unchanged.

Official reference: https://www.raspberrypi.com/documentation/accessories/ai-camera.html (read 2026-10-07). Installed Picamera2 source is authoritative for the deployed API.

## Original plan (completed; historical)

1. Inspect sensor/API/packages; minimal official runtime installation if possible; preserve original server and verified backup.
2. Implement pure parser/ROI/protocol and tracked server, tests; TV protocol/crop/remap tests.
3. Deploy after tests; sensor/JPEG/edge/legacy smoke, rollback on failure.
4. TV analyze/regressions/Debug/Release and emulator engineering smoke; no physical repetitions requested.
5. Record actual metrics, limitations, deployment/rollback and local task-only commits. No push/new branch/production changes.

## Early results (historical)

NOT RUN (implementation/validation in progress). Do not claim sensor inference or live-person detection until measured.

### Implementation checkpoint

- Added `lib/services/pi_edge_frame.dart`: strict edge-v1 parser, monotonic ordering, SHA-256 JPEG binding, 500ms pairing expiry, integer ROI geometry and full-image remap.
- `PiCameraSource`: automatic optional handshake, serialized same-frame crop/infer/publish, latest-frame-wins, full-frame fallbacks, runtime `edgeRoiEnabled`, transient timings/path diagnostics. No research payload addition.
- `BodyPoseEngine`: optional ROI remap before existing EMA and all pose listeners, observation retains original full image dimensions. No additional ONNX session or model.
- Added canonical `tools/pi/camera_server.py`, pure tests and bounded `smoke_camera.py` (no persisted JPEG).
- Minimal official packages installed: imx500-firmware 0.FF23+3, imx500-models 1:1.0.0-1. No other upgrade, no reboot. Pi apt HTTP/HTTPS unreachable; downloaded identical official debs on Windows, verified apt metadata SHA256 on both machines, installed via dpkg.
- Firmware SHA256 cd69ff7acc1088bda140c45efde899d5ec66755fd962e91a7cdaf7cf5613d06b; models deb e82a9ff55ca9514157d397bdae1ad9c63348a7c4f41caeae8c4b6ccb5d3436b3.
- RPK SHA256 c7d92dd1e6dce90ac22aa8d34a8f115ed2505021987aa25dcdfad182409d526c. Actual embedded labels person=0; input320x320, object detection, inference_rate26. Installed SDK converter returns xywh tuple; SDK has no close() (device_fd cleanup used).
- Verified original backup `/home/iphone/camera_server.py.pre-round7-20261006-145850`, SHA256 eb71b0d91862e17bcb9a30ad71463777a3415ff3c41170de35d3ad43e47aa4e1. Pi clock date differs from workstation; preserve actual backup filename.
- Server/tests copied after backup. Pi and Windows pure tests12/12 PASS; py_compile PASS. TV focused27/27 PASS (21 new +6 existing). Initial scoped analyzer test lint/Rect import issues corrected; final rerun pending.
- Active Pi process still the original implementation until explicit restart; sensor initialization/live protocol not yet validated. Service unit unchanged.

Next: baseline stream measurements, restart and sensor/legacy/edge smoke with rollback if necessary; broader TV regressions, Debug/Release and emulator ROI smoke; final evidence/doc and task-only local commits. Master and backend unchanged. Never request physical repetitions or change networking.

### Hardware/build checkpoint

- Pi deployment active; IMX500 initialization succeeded without reboot. Actual request tensors `[1,100,4]`, `[1,100]`, `[1,100]`, `[1,1]`. No CPU inference engine imported/executed.
- Actual legacy baseline60frames:18.184fps, meanJPEG17059.88bytes, first130.81ms; old lifetime ps9.4%CPU/64468KiBRSS (not a controlled benchmark).
- New edge90frames:16.985fps, mean17036.37bytes, metadata90/90, tensor57/90, person0/90. New legacy60frames:16.923fps, mean17037.48bytes; new lifetime ps25.1%CPU/181636KiBRSS (includes model startup, not per-mode CPU comparison).
- Latest service restart smoke edge60:17.122fps, mean16854.35bytes, metadata60/60, tensor39/60, person0/60. LIVE_PERSON_DETECTION=NOT RUN (no person visible; no reposition/motion requested).
- Normal WebSocket disconnect initially produced ConnectionClosedOK traceback, corrected with bounded close handling; repeated smoke leaves service active.
- Preserved original595-byte server verbatim in `tools/pi/camera_server_legacy.py`; SHA256 matches Pi backup exactly.
- TV scoped analyze0issues; TV+research regression124/124 PASS. Initial wider command had two nonexistent test paths (mobile-only); no test assertion failed. Correct existing-folder command exits0; do not misreport path errors as regressions.
- TV Debug PASS42.5s; first normal Release PASS77.9s. Additional isolated x86_64 smoke build PASS34.0s. Final normal artifacts to rebuild after final refinements.
- Existing TV AVD booted with separate `.dart_tool/round7/tv-userdata.img`; original AVD/physical phone untouched. Explicit initdata path absent in official TV image, retry letting emulator create isolated data succeeded (4.8GiB free).
- Remaining: actual emulator ONNX/Pi smoke and performance evidence; latest extra request tests; final normal builds, complete docs and local commits.

### Emulator acceptance checkpoint

- Isolated TV emulator5560, separate userdata; engineering APK applicationId verified `com.rehabassist.edge.r7validation`. APK install and launch PASS, no physical device operation.
- Actual Release RTMPose133 ran six synthetic full/ROI frames; full640x480 metadata and unmirrored anatomical indices preserved, ROI points restored before publication: PASS.
- Actual Pi JPEG + edge metadata → TV PiCameraSource → existing RTMPose → 20 observations133points full640x480: PASS. Current path NO_PERSON; no live-person geometry claim.
- Runtime OFF + disconnect/reconnect + first full-frame result: PASS. No duplicate model session or camera owner created.
- Pi latest15/15 pure tests PASS including request/image/metadata pairing, release on encoder errors, missing sensor tensor and sensor parser exception fallback. Original service unit unchanged, reboot count0.
- Additional synthetic protocol replay benchmark in progress (distinct from hardware person detection); final normal Debug/Release artifacts and task-only commits pending.

## Final evidence report — 2026-10-07

### 1. R7 Final Status

PASS — engineering integration completed, not clinical validation. EDGE_MODEL_LOAD, EDGE_SENSOR_INFERENCE, EDGE_PROTOCOL, TV_ROI_INTEGRATION and LEGACY_FALLBACK PASS. LIVE_PERSON_DETECTION / physical optical overlay alignment NOT RUN: the actual view contained no detected person. No request for repositioning or rehabilitation repetitions.

### 2. Pi Baseline

Raspberry Pi 4 Model B Rev 1.5, approximately 4GB RAM (3795MiB reported), Debian 13.5/trixie aarch64, kernel 6.18.34+rpt-rpi-v8, Python 3.13.5, Picamera2 0.3.36-1, websockets 16.1.1. Camera enumeration identified imx500. Original 595-byte server captured images only, JPEG quality60, WebSocket8765. Original SHA256 `eb71b0d91862e17bcb9a30ad71463777a3415ff3c41170de35d3ad43e47aa4e1`.

Service remains `/etc/systemd/system/camera-server.service`, User=iphone, WorkingDirectory=/home/iphone, ExecStart=/usr/bin/python3 /home/iphone/camera_server.py, Restart=always. Unit unchanged; inspected before replacement. Original timestamped file backup verified with cmp and hash: `/home/iphone/camera_server.py.pre-round7-20261006-145850`. Pi clock differs from workstation, hence that actual filename.

### 3. IMX500 Runtime Discovery

PASS. Initially no model/firmware package. Installed only official `imx500-firmware 0.FF23+3` and `imx500-models 1:1.0.0-1`, zero unrelated package upgrades and zero reboots. Pi package-server connectivity failed; identical official debs downloaded on Windows, official apt metadata SHA256 verified on both hosts, copied and installed with dpkg. No networking workaround/configuration change.

Firmware deb SHA256: `cd69ff7acc1088bda140c45efde899d5ec66755fd962e91a7cdaf7cf5613d06b`.
Models deb SHA256: `e82a9ff55ca9514157d397bdae1ad9c63348a7c4f41caeae8c4b6ccb5d3436b3`.
Firmware `/lib/firmware/imx500_loader.fpk` and `imx500_firmware.fpk` present.

Installed SDK source inspected directly: `get_outputs(metadata, add_batch=True)` parses CnnOutputTensor; `convert_inference_coords` returns ISP xywh tuple using the same request's geometry. IMX500 must initialize before Picamera2. SDK cleanup uses device_fd; it has no public close method. No heavy CPU inference library installed or substituted.

### 4. Edge Model

PASS. Official pre-packaged `/usr/share/imx500-models/imx500_network_ssd_mobilenetv2_fpnlite_320x320_pp.rpk`, SHA256 `c7d92dd1e6dce90ac22aa8d34a8f115ed2505021987aa25dcdfad182409d526c`. Embedded intrinsics: object detection, RGB320x320, inference_rate26, four outputs. Person index0 was confirmed from actual embedded COCO labels, but implementation resolves labels rather than hard-coding index0. No new model trained; RTMPose not moved to Pi.

References: [official AI Camera documentation](https://www.raspberrypi.com/documentation/accessories/ai-camera.html), [official object detection example](https://raw.githubusercontent.com/raspberrypi/picamera2-examples/main/examples/imx500/imx500_object_detection_demo.py), [official model repository](https://github.com/raspberrypi/imx500-models). The deployed installed SDK is the API authority.

### 5. Proof of Sensor-side Inference

PASS. Actual service logs: `IMX500 model configured`, followed by `IMX500 sensor tensor shapes=[[1,100,4],[1,100],[1,100],[1,1]] (request metadata; no CPU inference)`. Edge120-frame smoke received sensor output on79 frames. Outputs came from CnnOutputTensor of camera requests; no ONNX/OpenCV DNN/Torch person detector runs on Pi. Python performs tensor parsing, SDK bbox conversion and JPEG encoding only.

Sensor inference rate differs from image rate: missing-output requests are marked unavailable, never paired with a previously cached detection. Same-request association is authoritative; zero sensor-to-image physical latency is NOT claimed. Hardware optical latency was not measured. Picamera2 exposes CnnKpiInfo, but this report does not invent KPI values or compare separate host monotonic clocks.

### 6. Pi Camera Server Changes

PASS. Canonical deployable source is `tools/pi/camera_server.py`. Exact original source retained as `tools/pi/camera_server_legacy.py`. One camera owner/request producer, one bounded latest-frame queue per client, one sequential writer, send timeout2s. One capture_request owns image and metadata; finally releases on success/error. Explicit RGB888640x480 and correct little-endian BGR-memory conversion for JPEG quality60. No images written to disk.

### 7. edge-v1 Protocol

PASS. Optional client text handshake `{"protocol":"edge-v1"}`. Server waits at most300ms; old/malformed/no opt-in clients receive binary JPEG only. Negotiated stream: TEXT metadata(N), then BINARY JPEG(N); no interleaving from another sender.

Required text fields: protocolVersion, frameId, monotonicTimestamp (SensorTimestamp nanoseconds converted to milliseconds; monotonic fallback only when missing), imageWidth/imageHeight, edgeAiAvailable, edgeModelName/Version, personDetected, roiPaddingPolicyVersion, jpegByteLength, jpegSha256. Person frames add confidence, full-image bbox pixel bounds, padded ROI pixel bounds and normalized ROI. Model version is RPK SHA256. Edge fields are transient, not added to research schema.

### 8. Frame Pairing

PASS. Server pixels/tensors/ScalerCrop come from one CompletedRequest. Client validates monotonically increasing sensor IDs/timestamps per connection, SHA256+JPEG length, dimensions, version and finite geometry. At most one pending metadata packet, consumed once. Replaced/malformed/missing/duplicate/out-of-order metadata cannot carry an ROI into another JPEG. Reconnect clears ordering state. Local receipt-to-pair and receipt-to-crop expiry500ms; this is not an asserted network/sensor end-to-end latency measurement.

### 9. Person Selection

PASS pure deterministic tests; live person NOT RUN. Only authoritative `person` label, finite confidence0.55–1, valid boxes. Highest confidence wins; larger area then coordinates break ties deterministically. Invalid/no-person output never treated as correct rehabilitation posture. SDK bbox normalization/order is read from deployed model intrinsics; official same-request converter maps sensor inference coordinates to ISP output.

### 10. ROI Policy

PASS. `person-padding-v1`, default20% bbox width/height on each side, configurable `EDGE_ROI_PADDING` within0–0.5. Clamp to full image, floor left/top, ceil right/bottom, minimum16px dimensions. TV rejects nonfinite, inverted, tiny/out-of-bounds boxes and ROI not containing person bbox. Pixel crop uses exactly those integer boundaries and preserves actual dimensions. This is engineering localization, not clinical tolerance or proof of full-body visibility.

### 11. TV PiCameraSource Integration

PASS. Optional handshake, text parser, hash pairing integrated into existing serialized/latest-frame flow. Existing stop/dispose/reconnect generation guards preserved. Full JPEG continues to feed preview. Optional RGB crop only for valid fresh paired metadata. `edgeRoiEnabled=false` is a runtime switch, no model/session rebuild needed. Path ValueNotifier: EDGE_ROI, FULL_FRAME_FALLBACK, EDGE_UNAVAILABLE, NO_PERSON, INVALID_ROI. No UI redesign or debug sliders added.

### 12. RTMPose ROI Integration

PASS. Existing BodyPoseEngine external-frame method accepts optional normalized sourceRegion and original dimensions. One existing133-keypoint RTMPose ONNX session and fixed input `[1,3,256,192]`; no second pose engine. RGB preprocessing/model/confidence behavior unchanged. Crop failure or ROI inference error/null result retries once with original full RGB and publishes at most one observation. Invalid metadata/no-person immediately uses full-frame inference.

### 13. Coordinate Remapping

PASS. For every133 output points, fullX=ROI.left+ROI.width*localX, fullY=ROI.top+ROI.height*localY. Remap before EMA, legacy listeners/counters, processed packet and research observation. Original full image width/height retained. Deterministic square/non-square/corner tests and actual ONNX ROI outputs on synthetic input validated. No anatomical index swapping.

### 14. Overlay Alignment

PASS mathematical full-frame geometry/preview contract; physical person overlay NOT RUN. Pi input remains unmirrored and unrotated, no new display transform. Existing painter receives full-frame normalized points against original JPEG. ROI+mirror/rotation rejected rather than double transforming. Tests cover non-square crop and all edges; emulator verifies133 restored points. Physical ISP bbox/person optical alignment requires a future suitable view, not requested here.

### 15. Legacy Fallback

PASS. Old JPEG-only server works with new TV source (automated). New server works with legacy JPEG client (actual Pi120-frame smoke). Unavailable sensor metadata/no person/stale/malformed/bad digest/invalid ROI: full-frame RTMPose, never disable rehab. Sensor model init failure falls back to ordinary Picamera2; no CPU detector impersonates Edge. Server engineering OFF: `EDGE_AI_ENABLED=false` at process startup. Runtime TV OFF/reconnect actual Release smoke PASS.

### 16. Compatibility Matrix

| Pair/path | Status | Evidence |
|---|---|---|
| Legacy server → new TV | PASS | Loopback binary-only tests |
| New server → legacy client | PASS | Actual Pi120 JPEG frames |
| New server edge-v1 → new TV | PASS | Actual Pi20 RTMPose observations |
| Valid ROI → new TV RTMPose | PASS | Synthetic protocol20 frames, real Release ONNX |
| Missing/invalid ROI → original full image | PASS | Unit tests + actual NO_PERSON |
| Runtime OFF/reconnect | PASS | Actual Release emulator |
| Live detected person's optical overlay | NOT RUN | No person detected, no movement requested |
| Phone body/hand | UNCHANGED / NOT RUN | Master untouched, not rebuilt |
| PiHandSource research | NOT APPLICABLE | Legacy capability untouched/out-of-scope |

### 17. Counter Independence

PASS architecture/regression: no counter/state-machine/hold/set/release changes. Sensor confidence/personDetected never counts a rep. Observation publication ordering preserved (packet callback before legacy pose listeners); crop remaps before any consumer. No R7 physical rep validation claimed or required.

### 18. Body v3 Compatibility

PASS existing tests. Schema, backend API and capture/source contracts unchanged. BodyFrameIdentity remains TV local frame/session/receipt time; sensor ID/time are only transient transport metadata. Original full image geometry, confidence validity, keypoint ordering and timestamp origin retained. No JPEG/bbox/Edge fields persisted in research records.

### 19. R4 Feature Compatibility

PASS. Deterministic existing v3 synthetic body fixture, both sides, remap → frozen feature extractor invariance tested. No feature names/order/normalization/schema changes. Body and hand data remain isolated. No dataset/training operation.

### 20. R5 ML Runtime Compatibility

PASS relevant existing body_ml_runtime tests. No activation, classifier, artifact, confidence policy or production-model change. Original no-model behavior remains. Edge localization is not an ML rehabilitation classification result.

### 21. Pi Performance

Actual bounded read-only smoke, JPEG in memory only; no person detected. Latest same deployed process, sequential120-frame runs:

| Metric | edge-v1 | legacy JPEG client |
|---|---:|---:|
| Observed JPEG FPS | 17.058 | 16.889 |
| Mean JPEG bytes | 17580.75 | 17296.27 |
| Metadata packets | 120/120 | 0 |
| Sensor-output frames visible to client | 79/120 | N/A |
| Person frames | 0 | N/A |
| First frame incl handshake/network ms | 116.55 | 479.84 |
| Server interval CPU, one core=100% | 58.79% | 55.54% |
| Server RSS KiB | 181388 | 181404 |

Both modes run the new sensor-enabled producer; legacy mode merely omits metadata on wire. CPU reads `/proc/PID/stat` over actual run, not lifetime ps. Different scenes/short sequential runs mean not a controlled performance claim. Baseline original server60frames18.184FPS, mean17059.88bytes; baseline lifetime ps9.4%/64468KiB is not directly comparable CPU benchmark. Approximate sensor-output delivery11.3FPS during latest edge test, not claimed26FPS configured rate. Full JPEG still transmitted; no bandwidth/image-resolution reduction claim.

### 22. TV Performance

Actual x86_64 TV emulator Release, deterministic gradient JPEG replay,10 full/10 ROI frames after six warmup/validation calls. Values milliseconds p50/p95:

| Stage | Full frame | ROI |
|---|---:|---:|
| JPEG decode | 31.807 / 34.524 | 31.167 / 35.035 |
| Crop preprocessing | 0.006 / 0.009 | 21.904 / 23.261 |
| Inference + remap + publication | 86.447 / 129.779 | 90.302 / 135.594 |
| Total | 117.895 / 160.588 | 144.066 / 191.931 |

No speedup: ROI slower overall here. Fixed ONNX tensor does not become smaller; crop adds overhead. Small10-frame populations, emulated CPU and fixed full-then-ROI order are not production benchmarks. No accuracy/clinical improvement asserted.

Separate engine timers include `tensorAndOnnx` and `decodeRemapAndEma`, not isolated pure-remap cost. Six preceding actual ONNX validation calls FULL/ROI respectively measured microseconds (tensor+ONNX, decode+remap+EMA): FULL(328220,24157), ROI(302563,17502), FULL(179246,13234), ROI(174913,13130), FULL(117225,20846), ROI(191531,16167). These cold/warm mixed calls prove execution, not comparable speedup. Fine-grained JNI/model-only or remap-only profiling NOT RUN.

Actual Pi20-frame TV processing p50/p95: decode29.562/32.377ms, inference+remap89.019/157.806ms, total116.258/190.045ms. PathNO_PERSON full-frame fallback. Timing uses monotonic Stopwatch, not wall clock/frame-count accumulation.

### 23. Pi Hardware Smoke

PASS: sensor initialization/tensors, edge metadata120/120, hash/sequence validation, legacy120JPEGs, multiple disconnects, camera-server.service active after all tests. Actual TV Release → Pi → RTMPose20 observations133points,640x480, unmirrored PASS. Synthetic hashed protocol validROI → actual ONNX PASS, runtimeOFF/reconnect PASS. LIVE_PERSON_DETECTION NOT RUN. No actual rehabilitation repetitions, original image persistence, physical TV or phone operation.

### 24. Automated Tests

Commands from TV worktree unless noted:

- Windows Python: existing `.dart_tool/g4-python/Scripts/python.exe -m unittest discover -s tools/pi -p test_camera_server.py -v`:15/15 PASS (run from master path to interpreter, TV tool directory).
- Pi: `python3 -m unittest -v test_camera_server.py`:15/15 PASS; `python3 -m py_compile camera_server.py test_camera_server.py smoke_camera.py` PASS.
- `flutter test --no-pub test/features/tv/pi_edge_frame_test.dart test/features/tv/pi_camera_source_test.dart test/features/rehab_ml/pi_body_observation_test.dart`:27/27 PASS.
- `flutter test --no-pub --reporter json test/features/tv test/features/rehab_ml`:124/124 PASS, exit0.
- `flutter analyze --no-pub lib/services/pi_edge_frame.dart lib/services/pi_camera_source.dart lib/services/body_pose_engine.dart test/features/tv/pi_camera_source_test.dart test/features/tv/pi_edge_frame_test.dart tools/pi/edge_roi_smoke.dart`:0 issues.
- Changed Dart files formatted; no unrelated format sweep. `git diff --check`:PASS.

Coverage: labels/selection/invalid bbox/padding/clamp; same request and release-on-error; metadata absent; malformed/order/stale/digest; both legacy/edge protocols; crop actual pixels; remap/mirror; single publication after ROI failure; v3/R4 feature invariance; existing observation/session/owner/R5 contracts.

### 25. TV Debug Build

PASS final normal `flutter build apk --debug --no-pub`, exit0,22.4s. Artifact `build/app/outputs/flutter-apk/app-debug.apk`. Main mobile repository not rebuilt. No Android dependency/native/build-setting change in R7.

### 26. TV Release Build

PASS final normal `flutter build apk --release --no-pub`, exit0,54.8s. Artifact `C:/Users/kuoja/Documents/GitHub/tkuim_project/.worktrees/round2-tv/build/app/outputs/flutter-apk/app-release.apk`,498094551bytes (475.02MiB), SHA256 `96b4c6fbae58144b70e0782f1ebdd43e8a1dcfafa4497dcaf525fe9726a37b5e`.

aapt36.1.0 parsed applicationId com.example.flutter_body,version1.0(1),min24,target36, arm64-v8a/armeabi-v7a/x86_64. APK contains RTMPose WholeBody/RTMDet assets and ONNX native libs. Baseline TV minify/resource shrink were already false and remain unchanged; mobile R8 untouched.

Engineering-only entry `tools/pi/edge_roi_smoke.dart` built Release using existing validation applicationId property `com.rehabassist.edge.r7validation`, installed only isolated emulator5560 with separate userdata. Normal final APK uses lib/main.dart/default app identity. No real patient app replaced.

### 27. Existing Regressions

Seven pre-existing generated Linux/macOS/Windows plugin working-tree modifications preserved, not staged. No full app suite run in R7; previous master full-suite failure records not overwritten or represented as all passing. Initial invocation mistakenly named two absent mobile-only test paths in TV tree, producing124success/2load errors; corrected existing TV/research folder invocation passed124/124. Path errors were not failing assertions and are preserved in ignored diagnostic log.

### 28. New Regressions

No known failure in executed final tests/build/smoke. Earlier normal client disconnect traceback corrected (ConnectionClosed/timeout cleanup); earlier SDK inspection lacking private metadata context and missing test Rect import/lint corrected. Initial AVD initdata path nonexistent; separate automatic userdata initialization succeeded. No result hidden by weakening/deleting tests. Fine-grained optical alignment/quality NOT RUN, not labeled new regression.

Final Windows Python rerun inside restricted execution stalled at the async protocol test; only that invocation was stopped. Same unmodified15 tests immediately passed in unrestricted execution (0.133s), and on Pi (0.149s). This execution-environment issue is recorded, not represented as a failed assertion or fixed by changing tests.

### 29. Privacy / Security

PASS scope. SSH credentials used only interactively, no secret in source/test/log/report. No raw JPEG/video/cropped image persisted; bounded memory frames only, aggregate diagnostics and model hash. Synthetic gradient replay is an engineering fixture, never a research dataset. Existing trusted-LAN unencrypted WS8765 retained: JPEG SHA256 provides pairing integrity, NOT authentication/encryption. No new ports, network/SSH configuration changes, backend/DB/Tailscale modification, production ML activation or research collection.

### 30. Files Added

- `docs/BODY_RESEARCH_ROUND7_IMX500_EDGE_AI.md`
- `lib/services/pi_edge_frame.dart`
- `test/features/tv/pi_edge_frame_test.dart`
- `tools/pi/camera_server.py` (canonical deployable source)
- `tools/pi/camera_server_legacy.py` (exact original)
- `tools/pi/test_camera_server.py`
- `tools/pi/smoke_camera.py`
- `tools/pi/edge_roi_smoke.dart` (engineering-only separate entry)

### 31. Files Modified

- `lib/services/pi_camera_source.dart`
- `lib/services/body_pose_engine.dart`
- `test/features/tv/pi_camera_source_test.dart`

No master/backend changes. Existing generated desktop edits excluded. No PiHandSource/Body v3/features/counters/ML classifier changes.

### 32. Pi Files Deployed

- `/home/iphone/camera_server.py` canonical SHA256 `e0297fe18f83f39180030d9019e81685f35e23687944aed870603350b31085fa`.
- `/home/iphone/test_camera_server.py`, `/home/iphone/smoke_camera.py` validation tools.
- Verified original timestamped backup above. Official debs copied for install; no secret or image artifacts.

Reproducible validated commands (from TV checkout; SSH prompts interactively, never embed password):

```powershell
scp tools/pi/camera_server.py tools/pi/test_camera_server.py tools/pi/smoke_camera.py iphone@192.168.137.186:/home/iphone/
ssh iphone@192.168.137.186
```

On Pi, after verifying an existing backup before any further replacement:

```sh
python3 -m unittest -v test_camera_server.py
python3 -m py_compile camera_server.py test_camera_server.py smoke_camera.py
sudo systemctl restart camera-server.service
systemctl is-active camera-server.service
python3 smoke_camera.py --edge --frames 120 --server-pid "$(systemctl show -p MainPID --value camera-server.service)"
python3 smoke_camera.py --frames 120 --server-pid "$(systemctl show -p MainPID --value camera-server.service)"
```

Rollback only if needed (NOT executed; new service healthy):

```sh
sha256sum /home/iphone/camera_server.py.pre-round7-20261006-145850
sudo systemctl stop camera-server.service
cp -p /home/iphone/camera_server.py.pre-round7-20261006-145850 /home/iphone/camera_server.py
sudo systemctl start camera-server.service
systemctl is-active camera-server.service
```

Expected backup SHA above; no package uninstall, unit/network edit or reboot needed for server rollback. Re-deploy canonical tracked server to restore R7 afterwards. Service unchanged and active at handoff.

### 33. Git Commits

Local TV core `69e1e7e75dab5df661c79429bc4e0cb948bdc20d` (`feat(tv): integrate sensor IMX500 metadata and safe RTMPose ROI`). Final task-only evidence/tooling commit recorded by completion report/git log; no self-referential SHA rewrite required. No push, branch creation, wholesale merge or unrelated staging.

### 34. Git Status

TV branch codex/android-tv-client; baseline43901d0ae1269d162446b924e6570b27cd70fc9d. Remaining seven generated baseline modifications only after task commits: linux/flutter/generated_plugin_registrant.cc/.h/generated_plugins.cmake, macos/Flutter/GeneratedPluginRegistrant.swift, windows/flutter/generated_plugin_registrant.cc/.h/generated_plugins.cmake. Kept untouched/uncommitted, not silently restored.

Mobile master f8f12948d31fb9fa1ec3be04c5ad6bad0f5c0d1b clean. Backend main read-only final check9c8335890464e8866a62e3de9e376f091fa1efa2 clean; no backend operation/change in R7. No extra branch, no remote mutation.

### 35. Known Limitations

No live detected person, optical bbox/skeleton alignment, clinical accuracy, multi-person practical selection or physical exercise acceptance in this round. SDK-associated sensor metadata used, no measured zero-lag claim.500ms freshness only local pending/processing age, not comparable host clocks. Full JPEG bandwidth unchanged. Short emulator performance cannot predict TV hardware; ROI not faster here. Server Edge-init-failure branch code-backed but hardware failure deliberately not induced. Full Flutter app suite NOT RUN; executed TV/research tests passed. Existing Pi clock discrepancy left untouched.

### 36. Final Architecture

IMX500 official sensor detector → same Picamera2 request pixels+tensors → full JPEG + optional transient edge-v1 metadata → TV PiCameraSource freshness/hash/geometry validation → valid ROI crop OR full-frame fallback → existing RTMPose133 → full-frame remap BEFORE EMA → original overlay/BodyPoseObservation/counters/research/R5 ML. Phone hand remains MediaPipe, PiHandSource remains legacy/out-of-scope. Production Phone/TV→Render→Tailscale→Lab MySQL unchanged and not accessed.

### 37. Future Full-Edge Pose Feasibility

NOT RUN / out-of-scope. RTMPose133 export/operator/quantization/memory compatibility, IMX500 conversion feasibility, anatomical/feature parity and validation would require a separate future assessment. Available sensor object detector does not establish feasibility of full Edge RTMPose. No PoseNet substitute, new model training or Round 8 started.

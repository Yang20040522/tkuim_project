# Round 7 — IMX500 Edge AI + ROI-conditioned RTMPose

## Progress / continuation checkpoint

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

## Remaining (in order)

1. Inspect sensor/API/packages; minimal official runtime installation if possible; preserve original server and verified backup.
2. Implement pure parser/ROI/protocol and tracked server, tests; TV protocol/crop/remap tests.
3. Deploy after tests; sensor/JPEG/edge/legacy smoke, rollback on failure.
4. TV analyze/regressions/Debug/Release and emulator engineering smoke; no physical repetitions requested.
5. Record actual metrics, limitations, deployment/rollback and local task-only commits. No push/new branch/production changes.

## Results

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

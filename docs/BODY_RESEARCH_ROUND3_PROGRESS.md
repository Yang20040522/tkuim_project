# Body Research Round 3 Progress

## Checkpoints
- master Round 2: 3e6d013184104898596e82e2a580006145c1b05d.
- TV Round 2: 2a0b10b95e95b5e7c29ff41f2815c258bf26d84d.
- Backend main Round 2: 45c7bbb0fc3b4aa09d22a212bf7b92c764e9f36c.
- Round 3 implementation checkpoints: master 1326472811298223182d009c252645e1da5a9610; TV 968d8a4be92c4a9696db7944001b4d187ce33ad4; backend main 6048bf32e6bccb6ae694297e68a57a600d41157b.
- No new branches, push or production deploy. TV worktree: .worktrees/round2-tv.
- TV generated desktop files had line-ending-only status; not staged as unrelated content.

## Scope
Therapist v3 list/filter/playback/features, independent review/disposition,
immutable resample linkage, isolated approved body export, MySQL and builds.
TV/Pi body only. No model training, Pi/network changes or production operations.

## Environment checks
- These are three distinct environments: local isolated validation only; laboratory MySQL NOT RUN/NOT VALIDATED; production NOT DEPLOYED. Do not connect laboratory without new explicit authorization/access.
- Local MySQL 8.4.11 reachable via existing DPAPI application credential.
- rehab_app has CRUD only on rehab_r2_validation. No DDL/create-schema permission.
- Existing business schema must not be used for this round's fresh migrations.
- User provisioned rehab_body_r3_validation; actual metadata PASS: MySQL 8.4.11, 29 tables, 253 columns/V004.
- V005 review/resample fields await owner interactive migration; application remains CRUD only.
- Pi camera TCP 192.168.137.186:8765 reachable; no Pi settings modified.
- adb has one physical Android phone (RMX3371), not a TV device.

## Completed
- Read complete Round 3 request and Round 2 checkpoints.
- Confirmed three worktrees and created authorized local checkpoint commits.
- Read current therapist page, API and backend review/export/data contracts.

## Remaining (order)
1. Owner applies V005 via body-round3-review-migration.ps1 (confirmed not yet executed).
2. Run new BodyRound3MySqlIntegrationTest using a local-only secure runner; do not use laboratory/production credentials.
3. Run isolated fake API/device E2E after explicitly configuring a non-production API.
4. Complete actual Pi/TV and Phone/TV Release runtime acceptance when hardware is available.
5. Update measured MySQL/Hibernate/concurrency results and final acceptance; stop before Round 4.

## Tests this round
- Backend focused PASS 58/58; latest full mvn test PASS: 328 discovered, 298 passed, 30 skipped (including seven new MySQL tests NOT RUN). mvn package -DskipTests PASS.
- master latest focused PASS 61/61; TV body focused PASS 35/35. v1 body/v2 hand regressions included.
- Full Flutter run once: 545 PASS / 7 FAIL; same seven names as Round 2 (four ZEGO timers, selected patient fixture, video wording, IP TextField finder). Not all passing.
- Phone Debug PASS, Release PASS (467.3 MB). Release --no-pub initially FAIL twice because generated registrant retained flutter_native_splash (dev-only) while Gradle excludes it; full flutter build apk --release regenerates correct registrant and PASS. No package/native/R8 changes.
- Initial new widget lifecycle test FAIL due to invalid paused->resumed synthetic transition; fixed to inactive/hidden transitions and rerun PASS.
- master scoped analyze PASS 0 issues; TV scoped analyze PASS 0 issues. Initial const suggestion fixed.
- TV final focused recheck PASS 35/35; TV Debug PASS and Release PASS (497865175 bytes). RTMPose/RTMDet/ONNX APK entries verified.
- Final master scoped analyze PASS, 0 issues; all three worktree diff checks PASS.
- Review pagination/account stale guards and resample note display are implemented and focused-tested.
- Full implementation report: docs/BODY_RESEARCH_ROUND3_REPORT.md; backend exact manifest/handoff in its matching report. Local checkpoint commits only.
- Implemented source-specific export UI, timestamp-based v3 skeleton playback, four review choices, safe nullable points/feature unavailable, resample selection and immutable linkage on both branches.
- Round 2 historical full Flutter 524 PASS / 7 FAIL preserved.

## Do Not Redo
- Keep all Round 2 tests/code and baseline migrations V001..V003.
- Do not modify Render/production database, classifier or native pipelines.
- Use secure local credential/interactive entry; never print or store plaintext secrets.

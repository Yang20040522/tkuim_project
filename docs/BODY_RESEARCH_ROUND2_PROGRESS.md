# Body Research Round 2 — TV Progress

## Branch / preservation
- Existing codex/android-tv-client, HEAD 2f3b67e544475ba3b35de129c8964f1ec3042635.
- Uncommitted; no new TV branch/merge/push/deploy.
- Worktree now .worktrees/round2-tv; prior .dart_tool location obsolete.
- Shared files applied individually; TV isolate/login/DPAD/main/manifest preserved.
- PiHandSource unchanged, not formal research. TV body only.

## Completed
- Shared observation/v3 contract/extractor/collector/owner repository/queue/API.
- Pi atomic JPEG/observation and generation-safe serial inference.
- BodyTrainingScreen opt-in sidecar, actual DEFAULT assignment and read-only counters.
- Local/cloud consent separate; pause/background/reconnect/end/logout interruption.
- Standing action read-only leg getter; AppSession identity generation.
- crypto/image existing versions promoted to direct dependencies; shared synthetic fixture.

## Validation
- PASS: flutter pub get.
- PASS: flutter test test/features/rehab_ml test/features/tv --no-pub, 57/57.
- PASS: scoped flutter analyze, 0 issues.
- PASS: final flutter build apk --debug --no-pub, 65.6s.
- APK: build/app/outputs/flutter-apk/app-debug.apk, 593553917 bytes.
- PASS: final git diff --check.
- NOT RUN: TV/Pi hardware, live MySQL/upload, Release build.
- Desktop generated plugin files show status changes after pub get but no semantic diff; preserved.

## Remaining / Do Not Redo
- Review uncommitted files; no new commits.
- Isolated V004 and real TV/Pi acceptance pending.
- Full report/file manifest: master docs/BODY_RESEARCH_ROUND2_REPORT.md.
- Do not delete/clean this worktree, overwrite from master, change native/R8, or start Round 3.

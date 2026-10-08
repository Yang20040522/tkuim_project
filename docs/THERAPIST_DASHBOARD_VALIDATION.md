# Mobile Therapist Dashboard Validation

## Scope and baseline

- Branch: `master`; starting HEAD: `33fd561233b9a7c7534f292e03c71ee6d6bc531c`.
- Starting working tree was clean. No new branch was created.
- Mobile therapist presentation only. No TV worktree, Pi, backend, database,
  Render, patient business logic, training or inference code was changed.

## Implementation

- Dynamic `AppSession.name` header, medical icon fallback and original logout.
- Overview: real bound-patient and saved-custom-exercise counts from the existing
  repositories; plan shortcut says 「安排」 rather than claiming a count.
- Reads once on entry and on explicit pull-to-refresh; no dashboard polling or
  requests in build. Failure shows `--` and keeps all actions available.
- Responsive, content-sized action grid: two authoring cards; care cards use two
  columns on phones and three only when there is sufficient width.
- Existing five routes, research annotation and backend-authorized management
  entry are preserved. Home can rebuild for asynchronous overview/authority
  updates; the chat page instance, PageController and keep-alive are preserved.
- No invented recent activity; a care-workflow tip is shown instead.

## Automated results

- `dart format` on the three changed Dart files: PASS.
- `flutter test test/features/account/therapist_dashboard_test.dart test/features/account/therapist_chat_navigation_test.dart --reporter expanded`: **21/21 PASS** (20 dashboard + 1 existing navigation test).
- Dashboard tests cover five real route destinations and return, dynamic name,
  logout/session clearing, real counts/zero/error fallback, once-only reads and
  refresh, research authority, widths 360/390/412/430 with text scales 1.0/1.3.
- Expanded run of the two above files plus
  `account_recovery_therapist_registration_test.dart`, `milestone_7_6_test.dart`
  and `test/features/home/main_navigation_test.dart`: **55 PASS / 1 FAIL**.
  The failed `successful therapist registration saves existing session` test
  leaves the existing AppSession ZEGO 800ms timer pending at teardown. The same
  failure is recorded in `BODY_RESEARCH_ROUND2_REPORT.md`,
  `BODY_RESEARCH_ROUND3_REPORT.md`, `BODY_RESEARCH_ROUND5_REPORT.md` and
  `G35_VALIDATION.md`. No test was deleted, skipped or weakened to hide it.
- Scoped `flutter analyze` on the three changed Dart files: **0 issues**.
- Full `flutter analyze`: exit 1, **54 findings (0 errors, 8 warnings, 46 infos)**,
  outside the changed files. No unrelated cleanup was performed.
- Full Flutter test suite: NOT RUN; this task ran the focused and expanded
  widget/navigation/account regressions above.

## Builds and device

- `flutter build apk --debug`: PASS.
- `flutter build apk --release`: PASS (105.9s Gradle build).
- `flutter devices`: RMX3371 Android 14 physical phone available; no phone
  emulator. No TV device was used.
- `flutter run --debug --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk --no-resident -d d698e1fa`: PASS, APK installed and launched.
- User-assisted therapist login/dashboard/summary/five actions/return/chat-tab
  switching/swiping/logout acceptance: **PASS**. User reported all normal on
  the physical phone running the new Debug APK. No credentials were searched,
  authentication modified or mock login used. Release runtime was NOT RUN;
  Release compilation/package success is not a device-runtime claim.
- `git diff --check`: PASS. Before committing, exactly four task files changed;
  no generated diagnostic reports or unrelated tracked files were modified.
- Version unchanged: `1.0.0+1`.

### APK artifacts

Debug:

- Path: `C:/Users/kuoja/Documents/GitHub/tkuim_project/build/app/outputs/flutter-apk/app-debug.apk`
- Size: 629382950 bytes / 600.23 MiB.
- SHA-256: `551F3A49E2CA63058B9664C634B0796590B29F1723E170BF39F196B98537DCCC`

Release:

- Path: `C:/Users/kuoja/Documents/GitHub/tkuim_project/build/app/outputs/flutter-apk/app-release.apk`
- Size: 490167419 bytes / 467.46 MiB.
- SHA-256: `C4F368DE7173321FA113FF1F016E948AE34D0DDB160C5CE00A6382415412ABCB`

No Android settings, dependencies, package IDs, signing or R8 rules were changed.

## Local evidence (ignored build workspace)

- `.dart_tool/therapist-dashboard-focused-final.log`
- `.dart_tool/therapist-dashboard-regression.log`
- `.dart_tool/therapist-dashboard-full-analyze.log`
- `.dart_tool/therapist-dashboard-debug-build.log`
- `.dart_tool/therapist-dashboard-release-build.log`
- `.dart_tool/therapist-dashboard-device-smoke.log`

## Git

- This record is included in the single local task commit
  `feat(therapist): redesign home as dashboard` on `master`.
- Changed files: `lib/features/account/therapist_home_screen.dart`,
  `test/features/account/therapist_dashboard_test.dart`,
  `test/features/account/therapist_chat_navigation_test.dart`, this document.
- Push and deployment: NOT RUN.

# Global Frontend Contrast Audit Progress

## Baseline

- `34ff31c86774b9e55dfba239ef00fa8aa4ef959c`
- Working tree was clean when this audit started.

## Root Causes Found

- `lib/main.dart` configures a dark `ColorScheme` while most application screens explicitly use white or light-gray surfaces. Material defaults therefore render active text, icons, controls, and input decoration with near-white foreground colors.
- Several screens also use local pale grays for active secondary content.
- The assignment screen currently relies on inherited colors and does not explicitly distinguish assigned (ON) content from unassigned (OFF) content.
- No shared application color/theme file existed at audit start.

## Theme / Shared Files Inspected

- `lib/main.dart`
- No existing `theme`, `color`, or `palette` Dart files were found under `lib/`.

## Files Already Modified

- `GLOBAL_FRONTEND_CONTRAST_PROGRESS.md`
- `lib/core/ui/app_colors.dart`
- `lib/core/ui/app_theme.dart`
- `lib/main.dart`
- `lib/features/account/account_info_screen.dart`
- `lib/features/account/login_screen.dart`
- `lib/features/account/patient_management_page.dart`
- `lib/features/account/profile_screen.dart`
- `lib/features/account/register_screen.dart`
- `lib/features/account/role_select_screen.dart`
- `lib/features/account/therapist_home_screen.dart`
- `lib/features/account/therapist_login_screen.dart`
- `lib/features/account/therapist_register_screen.dart`
- `lib/features/chat/chat_home_screen.dart`
- `lib/features/chat/chat_screen.dart`
- `lib/features/custom_exercise/custom_exercise_editor_page.dart`
- `lib/features/custom_exercise/patient_assigned_exercise_list_page.dart`
- `lib/features/custom_exercise/unified_exercise_assignment_page.dart`
- `lib/features/custom_exercise/widgets/custom_exercise_3d_viewer.dart`
- `lib/features/custom_exercise/widgets/joint_rotation_panel.dart`
- `lib/features/custom_exercise/widgets/keyframe_timeline.dart`
- `lib/features/custom_exercise/widgets/pose_measurement_rules_editor.dart`
- `lib/features/history/history_screen.dart`
- `lib/features/history/training_result_history_page.dart`
- `lib/features/home/home_screen.dart`
- `lib/features/notification/notification_screen.dart`
- `lib/features/notification/notification_settings_screen.dart`
- `lib/features/plan/plan_builder_screen.dart`
- `lib/features/plan/plan_screen.dart`
- `lib/features/plan/therapist_plan_management_page.dart`
- `lib/features/stats/badges_card.dart`
- `lib/features/stats/progress_trend_card.dart`
- `lib/features/stats/radar_chart_card.dart`
- `lib/features/stats/stats_screen.dart`
- `lib/features/training/action_list_screen.dart`
- `test/features/account/milestone_7_6_test.dart`
- `test/features/custom_exercise/milestone_7_5_test.dart`
- `test/features/custom_exercise/training_settings_test.dart`

## Backend Changed

NO

## Remaining Folders / Screens

- Implementation audit is complete across account, custom exercise, history, home, pose measurement, rehab, analysis, body test, TV cast, chat, notification, plan, stats, training, and shared widgets.
- Automated validation is complete. Remaining work is Android real-device visual acceptance only.

## Tests Already Run

- `flutter test test/features/custom_exercise/milestone_7_5_test.dart test/features/account/milestone_7_6_test.dart test/features/custom_exercise/training_settings_test.dart`
  - PASS, 27/27.
- `dart format` was run only for changed Dart files.
- Scoped `flutter analyze` completed: 33 existing repository issues; no issue points to newly added theme/palette/test code and no new issue was introduced by this audit.
- Full `flutter test`: PASS, 241/241.
- `flutter build apk --debug`: PASS; `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: PASS (only Git LF/CRLF conversion notices were emitted).

## Tests Remaining

- Android real-device visual acceptance.

## Important Decisions

- Active primary, active secondary, hint, disabled, border, and dark-surface foreground colors will remain semantically distinct.
- Placeholder/hint text remains lighter than typed values and labels.
- Assignment cards remain intentionally pale while OFF and become immediately readable while ON.
- Dark-background screens retain explicit light foreground styling where needed.
- `#9CA3AF` occurrences that represent genuine disabled/locked/completed, empty decorative icons, or intentionally subtle placeholders were retained; active secondary content was moved to the readable semantic secondary color.

## Do Not Redo

- Baseline verification and central root-cause identification are complete.
- Theme/shared audit, known-screen fixes, remaining frontend scan, focused tests, and formatting are complete.
- Do not rerun full Flutter tests or the APK build unless code changes after this checkpoint.
- Do not revisit Milestone 8 logic, backend, SQL, auth, 3D mechanics, pose geometry, training state machine, history architecture, DEFAULT routing, or Raspberry Pi code.

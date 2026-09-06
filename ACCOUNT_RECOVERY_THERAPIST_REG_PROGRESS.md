# Account Recovery + Therapist Registration Progress

## Baselines

- Flutter HEAD: `052159e3c2a5e4682c1d50677099b7eb4e16e83a`
- Backend HEAD: `3a32f08e7c8de267f29033c611100c9d46c3e526`
- Both working trees were clean at milestone start.

## Completed

- Replaced the existing patient 「忘記密碼？」 placeholder with a complete two-step recovery page.
- Added generic Email/Account ID forgot response, six-digit code, BCrypt reset, resend UX and safe Traditional Chinese errors.
- Added HMAC-SHA256 reset-code persistence with a 10-minute lifetime, five failed-attempt limit, one-time consumption and old-code invalidation.
- Added per-identifier 60-second / five-per-hour forgot throttling and per-source therapist-invite failure throttling.
- Added post-commit asynchronous SMTP delivery through `PasswordResetEmailService` so SMTP latency does not become an obvious account-enumeration signal.
- Added pessimistic user/reset-row locking plus a filtered unique active-reset index for concurrent request/consumption safety.
- Added cascade deletion for reset credentials so existing account deletion remains compatible.
- Replaced the local-only therapist registration shortcut with `/api/auth/therapist/register`.
- Therapist role is hardcoded by the backend after constant-time environment-secret validation; no client role field exists.
- Existing Google account linking now accepts Flutter's `currentPassword` field while retaining the legacy `password` key for compatibility.
- Added API, service, controller, security and Flutter widget/regression tests.
- Added the explicit idempotent SQL Server migration.

## Security Decisions

- Reset-code hash: `HMAC-SHA256(PASSWORD_RESET_SECRET, resetId + ':' + code)`; plaintext code is never persisted or returned.
- Code lifetime: 10 minutes.
- Verification attempts: maximum 5 per credential.
- Resend: old active credential is consumed before the replacement is persisted.
- Forgot limiter: in-process single-instance MVP, 60-second cooldown and 5 requests/hour per normalized-identifier digest.
- Therapist invite: `THERAPIST_REGISTRATION_SECRET`, minimum 16 bytes, constant-time comparison, five failed attempts per source per 15 minutes.
- Mail: SMTP via Spring Mail, queued only after transaction commit; logs contain neither address nor code.
- Existing stateless HMAC sessions cannot be centrally revoked by password reset without an auth redesign; this limitation is intentionally preserved and documented.

## Flutter Files Changed

- `ACCOUNT_RECOVERY_THERAPIST_REG_PROGRESS.md`
- `lib/features/account/account_recovery_service.dart`
- `lib/features/account/api_service.dart`
- `lib/features/account/auth_service.dart`
- `lib/features/account/forgot_password_page.dart`
- `lib/features/account/login_screen.dart`
- `lib/features/account/therapist_account_service.dart` (removed insecure local-only registration shortcut)
- `lib/features/account/therapist_login_screen.dart`
- `lib/features/account/therapist_register_screen.dart`
- `lib/features/account/therapist_registration_service.dart`
- `test/features/account/account_recovery_therapist_registration_test.dart`
- `test/features/account/google_auth_api_client_test.dart`

## Backend Files Changed

- `pom.xml`
- `sqlserver_migration_account_recovery.sql`
- `src/main/java/com/example/trainingsystems/config/AuthSecurityConfiguration.java`
- `src/main/java/com/example/trainingsystems/controller/AuthController.java`
- `src/main/java/com/example/trainingsystems/dto/AuthMessageResponse.java`
- `src/main/java/com/example/trainingsystems/dto/PasswordForgotRequest.java`
- `src/main/java/com/example/trainingsystems/dto/PasswordResetRequest.java`
- `src/main/java/com/example/trainingsystems/dto/TherapistRegisterRequest.java`
- `src/main/java/com/example/trainingsystems/entity/PasswordResetCredential.java`
- `src/main/java/com/example/trainingsystems/repository/PasswordResetCredentialRepository.java`
- `src/main/java/com/example/trainingsystems/repository/UserRepository.java`
- `src/main/java/com/example/trainingsystems/service/AuthAbuseRateLimiter.java`
- `src/main/java/com/example/trainingsystems/service/AuthService.java`
- `src/main/java/com/example/trainingsystems/service/PasswordResetCodeGenerator.java`
- `src/main/java/com/example/trainingsystems/service/PasswordResetCodeHasher.java`
- `src/main/java/com/example/trainingsystems/service/PasswordResetEmailService.java`
- `src/main/java/com/example/trainingsystems/service/PasswordResetService.java`
- `src/main/java/com/example/trainingsystems/service/PasswordService.java`
- `src/main/java/com/example/trainingsystems/service/SmtpPasswordResetEmailService.java`
- `src/main/java/com/example/trainingsystems/service/TherapistInviteVerifier.java`
- `src/main/java/com/example/trainingsystems/service/TherapistRegistrationService.java`
- `src/main/resources/application.properties`
- `src/test/java/com/example/trainingsystems/controller/AuthRecoveryControllerTest.java`
- `src/test/java/com/example/trainingsystems/service/PasswordResetServiceTest.java`
- `src/test/java/com/example/trainingsystems/service/TherapistRegistrationServiceTest.java`

## Backend Changed

YES

- New recovery table/API/services, SMTP dependency/configuration and controlled therapist registration require a backend deployment after migration/configuration.

## Tests Already Run

- Focused backend auth/security coverage: 41 distinct current tests passed (`AuthService` 17, password reset 13, therapist registration/login 7, auth controller 4).
- Full backend: 115 run, 113 passed, 2 known pre-existing unrelated failures (`LegacyBindingControllerSecurityTest`, `UserJsonSecurityTest`).
- Backend package: `mvn package -DskipTests` succeeded.
- Focused Flutter account/auth: 26/26 passed.
- Full Flutter: 254/254 passed.
- Scoped Flutter analyze: no new issue; one pre-existing info remains in `profile_screen.dart:161`.
- Android: `flutter build apk --debug` succeeded.
- Flutter and backend `git diff --check`: passed (line-ending conversion warnings only).

## Required Render Environment Variable Names

- `PASSWORD_RESET_SECRET`
- `THERAPIST_REGISTRATION_SECRET`
- `MAIL_HOST`
- `MAIL_PORT`
- `MAIL_USERNAME`
- `MAIL_PASSWORD`
- `MAIL_FROM`

## Remaining

1. Code review.
2. Configure the listed Render environment variables without exposing values.
3. Manually execute `sqlserver_migration_account_recovery.sql` before deploying the backend.
4. Deploy/restart backend, then build/install Flutter and perform Android acceptance tests.

## Do Not Redo

- Do not alter PATIENT registration, Google PATIENT-only policy, HMAC/session architecture or rehabilitation functionality.
- Do not expose reset codes or secrets through APIs, logs, Flutter storage or source defaults.
- Do not replace the in-scope solution with JWT, Firebase, Redis or a new user table.
- Do not rerun full suites unless code changes after this checkpoint.
- No Git add/commit/push, deployment or production SQL was performed.

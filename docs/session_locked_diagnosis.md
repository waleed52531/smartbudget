# TECNO authorization diagnosis — 2026-10-22

## Confirmed cause

The connected physical device identified as TECNO CM6, with the new app
`com.corehines.smartbudget` running. The screen displayed the configuration-specific
Session locked message. Read-only inspection of its installed APK's Dart kernel
found neither the approved Cloudflare Worker origin nor the existing registered
App Check debug definition. Configuration values were compared in memory; the
private token was not printed or written to this report.

Without the origin, `FirebaseSessionServices` selects the deliberately failing
unconfigured transport. Without the debug definition, the development APK selects
Play Integrity rather than the registered debug provider. Sanitized process-log
classification found two App Check token errors, HTTP 400 and a throttling message;
no Keystore, key-unwrapping, or protected-session-storage failure markers were
observed in the inspected log window. These observations do not justify deleting
secure storage or replacing any encryption keys.

The configuration failure does not qualify for offline authorization. Existing
fail-closed lease verification and invalidation behavior was preserved. A backend
configuration error is not evidence of an expired or incorrectly signed lease.

## Backend checks (read only)

- Public `/leaseVerificationKeys`: HTTP 200, Ed25519 key `beta-20261022-01`.
- `/authorizeSession` without credentials: HTTP 401 `unauthenticated`, as required.
- Firebase project and number matched `smartbudget-561d4` / `463515242262`.
- Billing remained disabled; Mumbai Firestore remained on its free tier.
- Deployed deny-all rules still matched the repository.
- Roster contained one member of the maximum five; one authorization grant was
  unexpired and within the 24-hour maximum. Subsequent read-only administrator
  lookup confirmed the existing test account is enabled, has a password provider,
  and has both an active member document and roster membership. The configured
  device then successfully completed online authorization.
- No backend configuration, membership, signing key, or App Check registration
  was changed. No migration ownership grant was issued.

## Fix and regression checks

`android/app/build.gradle.kts` now checks the normal `lib/main.dart` Flutter build
before compilation. Production-backend builds require the exact approved origin;
debug builds also require a UUID-shaped debug definition. Only Firebase itself
establishes whether that definition is registered. Emulators remain debug-only.
Profile/release builds reject a supplied private debug definition. Explicit
disposable native-test entry points retain their existing independent setup.
Errors contain instructions, not definition values.

Use the existing protected configuration via `python3 tool/run_debug.py`.
The ignored Android Studio `main.dart` run configuration already references that
same protected definition file. A plain unconfigured run now fails locally rather
than replacing the phone's app with an unusable build.

Actual checks:

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter expanded`: 178 passed, one emulator-only skipped.
- Android ARM64 debug build with the existing protected definition file: passed;
  built kernel contained both expected settings (private value withheld).
- Unconfigured debug build: rejected at `compileFlutterBuildDebug`, as intended.
- Origin-only debug build: rejected for missing registered debug configuration.
- Profile build supplied the private debug file: rejected before Flutter compilation.
- `git diff --check`: passed.

## Physical-device verification

Wireless ADB disconnected during `adb install --no-streaming -r -t` of the new-app
APK; the command returned `connect failed: closed`. No reset, clear, uninstall, or
destructive recovery was attempted. Both ADB device listing and service discovery
were then empty. After the user reconnected wireless debugging, the same TECNO
CM6 was discovered and the in-place update completed with `Success`.

The installed update was the previously validated configured debug APK, SHA-256
`b283f59ff16b717b6c4cb0ab89efc318f8ea291dc087d1c45541daa456ac66af`.
The device showed **Your session is authorized — Verified online** while retaining
the temporary financial-workspace lock. The first UI inspection saw a system
screen; after unlocking, the authorized labels were observable.

A cold-restart probe initially stopped without a result because its strict
process lookup returned no PID. This was not counted as a pass. A subsequent
explicit probe confirmed the new app was force-stopped, its process was absent,
and a new process started. That cold process restored the Firebase session and
again reached **Your session is authorized — Verified online**. Only
`com.corehines.smartbudget` was stopped or started.

This online transition exercises native App Check acquisition, server membership,
lease issuance, public-key retrieval, signature/project/UID/installation/policy
and expiry checks, and protected session persistence without bypassing any check.
The inspected restarted-process log window contained no App Check token error,
FirebaseException, PlatformException or fatal exception markers. Raw logs and
credentials were not retained in this report.

Before that attempt, read-only hashes matched the approved legacy app database
and reference snapshot. Two new-app encrypted database files and two key envelopes
were byte-hashed for preservation comparison after reconnection. No encryption
keys were unwrapped for diagnostics and no financial database was opened through
a diagnostic SQLite connection.

After the successful update and cold restart, all preservation comparisons passed:
the old application database, verified snapshot, both encrypted database files,
and both key envelopes remained byte-for-byte unchanged.

The user subsequently confirmed successful physical sign-out and fresh sign-in.
Final sanitized UI inspection independently observed **Your session is authorized**,
**Verified online**, and the temporary financial-workspace lock. Final process-log
classification found no App Check token errors, FirebaseException,
PlatformException, or fatal exception markers. The inspected window still included
an Android `IllegalArgumentException` class marker; no raw exception details or
unrelated Android log messages are interpreted as authorization failures when the
verified session has completed successfully.

Preservation comparisons were repeated after fresh login: the original legacy
database, reference snapshot, both encrypted databases and both key envelopes
still matched their earlier byte hashes. The installed APK's SHA-256 matched the
validated configured build. Final `git diff --check` passed. No further runtime
code changes were needed after the passing analysis and 178-test regression run.

The authorization repair and requested physical acceptance checks passed. The
temporary workspace-lock text remains intentional until later approved stages;
it is distinct from Session locked. No ownership grant or import was performed,
no dashboard was exposed, and Stage 6 was not begun.

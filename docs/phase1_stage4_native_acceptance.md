# Stage 4 Android native acceptance

Date: 2026-10-21. Device: physical TECNO CM6, Android 16 / API 36, ARM64.
Target application: `com.corehines.smartbudget`; instrumentation package:
`com.corehines.smartbudget.test`. No Stage 5 migration or production Firebase
configuration/deployment is part of this verification.

Status: **Android native acceptance passed.** Normal application restored;
legacy installation/database and verified backup unchanged. Stage 5 remains
unstarted and requires separate approval.

## Safety boundary

Read-only checks confirmed both app identities were installed. The original
`com.example.smartbudget` process was not running. Its database SHA-256, size and
modification time, and original APK path were recorded before testing. The host
backup remained readable and matched its recorded checksum. No original database
was opened through SQLite, copied into the new application or assigned an owner.
Only hashes/stat metadata were read. The existing new-app APK was preserved outside
Git and its public signing certificate matched the test build, allowing updates
without an uninstall or data clear. The new app had no financial databases or key
envelopes before this run.

Every install/start/force-stop/instrumentation action targets the new identity.
No original-app launch, stop, clear, uninstall, repair, SQL query or write occurs.
Tests use a unique `native-acceptance-<random run>` project with five synthetic
UIDs. Existing scopes are checked absent before exclusive registry creation.
Cleanup validates that registry and deletes only that run's disposable scopes and
wrapping aliases. No general key-reset/delete endpoint is added to the application.

## Finding and correction

The first physical run executed all four existing Keystore tests and failed before
key creation. `DatabaseKeyVault.rootPath()` rejected valid directories by comparing
`File.canonicalFile` with `File.absoluteFile`. Host tests could not establish this
native filesystem behavior.

The narrow correction rejects a symlink at the vault root using `lstat`, then
returns a canonical root path. Existing stricter child-folder and envelope checks
remain in place. The added physical regression exercises equivalent paths through
a parent alias and rejects a linked vault root. The corrected target APK and test
APK were both rebuilt and installed; all **five native Keystore tests passed**.
Earlier failed/incomplete build and stale-target diagnostic attempts are not counted
as successful verification.

The encrypted lifecycle probe also exposed an immutable platform-buffer bug:
Android's channel response used an unmodifiable `Uint8List`, while `DatabaseKey`
kept that buffer and attempted in-place erasure. Cleanup threw `UnsupportedError`
after opening the database; the generic open failure appeared as a lock despite a
valid signed lease. The key record now owns a writable copy, which can be erased
safely. A regression test supplies an actual read-only view. No key value,
algorithm, ownership policy or legacy record was changed.

A separate timing regression demonstrated that a slow current-session callback
could be mistaken for clock rollback. The grant checker now executes the callback
before sampling, brackets wall time with monotonic readings, and uses the later
monotonic bound for expiry. Tests cover both a valid lease during a slow callback
and expiry during that delay. The native lease verifier and maximum duration are
unchanged; this was not the cause of the immutable-buffer failure.

## Verification method

`tool/native_storage_acceptance.dart` is an explicitly selected debug-only entry
point, absent from `lib/main.dart`. It uses the real Android vault/channel, native
clock, SQLite3MultipleCiphers, Drift schema, SessionCubit, signed-lease verifier,
UserDatabaseManager and SQL guards. Auth transport and lease issuance are local test
fixtures; a public RFC 8032 test vector signs the actual lease format in the debug-only
fixture. This is published test material, not a privileged signing credential
([RFC 8032 §7.1](https://www.rfc-editor.org/rfc/rfc8032.html#section-7.1)). No Firebase account,
production authorization, service credentials or backend is changed. This verifies
native storage/lifecycle, not production Firebase login or live backend deployment.

The first phase creates independent A/B databases, checks isolation and rollback,
and confirms actual database file descriptors disappear after logout, switching,
and a five-second signed lease expiry. The second phase reuses the same test APK after force-stopping
only the new application; different process IDs and matching unwrapped-key
fingerprints establish process restart and encrypted reopen without saving raw keys.

Native support parses the packaged backup rules and flags, opens only disposable
encrypted files with ordinary Android SQLite, and removes one disposable wrapping
alias to simulate an incompatible restore/key-loss state. The ordinary SQLite
probe uses an explicit non-destructive corruption handler; Android's default
corruption-deletion handler is never used. No system-wide backup/restore, device
transport, root access or cloud backup is attempted.

The runner captures logs for the new app UID only. It checks one-way fingerprints
against hexadecimal, base64 and decimal-array representations of generated database
keys, plus a synthetic financial-note canary, before writing sanitized logs outside
Git. It does not collect unrelated applications' logs or print key material.

## Current results

| Check | Actual result |
| --- | --- |
| Initial native Keystore tests | 4 executed, 4 failed at root validation before creating keys |
| Corrected native Keystore suite | 5 passed on TECNO CM6 |
| Flutter analysis | No issues found |
| Full Flutter regression suite | 127 passed, 1 live-emulator-only test skipped |
| Target and instrumentation builds | Passed |
| Native support checks | 3 acceptance tests plus 1 diagnostic-fixture cleanup test passed |
| Device Dart lifecycle probe | Both phases passed; 16 named checks, plus explicit FD, total, integrity and file-preservation assertions |
| Actual process restart | PID 4434 → 6251; same unwrapped key fingerprints and encrypted records reopened |
| Backup exclusions / key-loss simulation | Passed on device; compiled manifest also confirms allowBackup=false and dataExtractionRules reference |
| Log scan | 201 new-app UID log lines; 5 database-key fingerprints checked; 0 key-representation matches and no synthetic financial-note canary |
| Final legacy/backup comparison | Passed: original APK path, database/sidecar hashes, sizes and modification times unchanged; host backup checksum unchanged |
| Normal APK restore | Passed; installed APK SHA-256 matches the normal build; disposable harness UI absent from its kernel |
| Disposable cleanup | Passed and earlier failed diagnostic scopes/aliases removed; 0 financial SQLite files and 0 key envelopes remain in new-app storage; temporary test package uninstalled |
| `git diff --check` | Passed |

Native commands use explicit package/component names. The host runner holds a
single-run lock and snapshots built APKs before transferring them, avoiding
concurrent updates or mutable-artifact races. The device does not support the
SDK fast-deploy path, so ordinary data-preserving streamed updates are used.
The test APK is installed
manually with `adb install -r -t`, and tests run with `am instrument`; Gradle's
automatic install/uninstall lifecycle is not used. No `pm clear` or original-app
uninstall is allowed. Commands use `tool/clean_run.py` to exclude inherited service
credentials. The existing 124 tests remain intact; three regression tests were added; no SDK/package upgrade or
dependency override was needed.

## Acceptance coverage

| Requested verification | Physical result |
| --- | --- |
| Secure key creation and wrapping/unwrapping | Passed; native AES-GCM, distinct 256-bit keys and non-exportable wrapping keys |
| Encrypted creation and reopen after process restart | Passed with the real protected keys and Drift schema 4 |
| Wrong key / ordinary plaintext SQLite | Both rejected; disposable files unchanged |
| Missing protected key, no destructive recovery | Wrapping alias removed only for disposable `missing` UID; access denied, no replacement alias/key and database/envelope unchanged |
| Corrupted envelope | Authenticated metadata tampering rejected; no repair, overwrite or replacement |
| A/B isolation | Independent databases and keys; synthetic totals preserved independently; stale A scope rejected while B active |
| Logout/account switch/pending write | Actual DB file descriptors closed; pending write rolled back; previous scope could not write to B |
| Authorization expiry | Real native clock and five-second signed test lease; automatic lock and physical FD closure observed |
| No plaintext fallback | Engine/key guards intact; both unkeyed SQLite3MultipleCiphers and ordinary Android SQLite rejected the encrypted files |
| Backup behavior | Runtime flags, all ten cloud/device-transfer exclusion entries, no-backup root, and attached APK manifest configuration verified |
| Logging | No generated database-key representations or synthetic financial note found in captured app-UID logs |

The signed test issuer and identity transport are fixtures; production Firebase
login/allowlist deployment is not claimed. Missing-key restore was simulated using
a disposable alias; a system-wide backup/restore or OEM transfer was not attempted.

## Evidence and final state

Passing-run evidence: `/private/tmp/smartbudget-stage4-native-dffd7dbc2353/`.
The two result JSON files, three support-test outputs, log-scan summary, immutable
probe/normal APK snapshots and sanitized app-UID log remain outside Git. Earlier
failed-run logs are retained outside Git for traceability, but their on-device test
financial files and wrapping aliases were removed after validating their registries.
No real user scope or unrelated credential was deleted.

Final safety receipt: `/private/tmp/smartbudget-stage4-acceptance-safety-after.json`.
Native Keystore suite output:
`/private/tmp/smartbudget-stage4-acceptance-native-corrected-results.log`.
Earlier-fixture cleanup output:
`/private/tmp/smartbudget-stage4-acceptance-failed-fixture-cleanup.log`.
Flutter checks:
`/private/tmp/smartbudget-stage4-acceptance-analyze.log` and
`/private/tmp/smartbudget-stage4-acceptance-flutter-tests.log`.

The legacy backup remains
`/Users/waleed/SmartBudgetBackups/tecno-legacy-20261021T115349Z-l5f1mo2p/legacy_snapshot.sqlite`
(53248 bytes), unchanged and still matching its recorded verification. The original
phone database and WAL/SHM inventory also match the pre-run receipt exactly.
The old app remains installed and was not launched, stopped or modified. The new
app is restored to the normal `lib/main.dart` APK and left stopped. The newly
installed instrumentation package was removed; no `pm clear` occurred.

The three small production corrections are root validation, owned writable key
buffers, and conservative grant timing. A temporary error-location observer used
to identify the immutable-buffer exception was removed. No Firebase configuration,
financial schema or dependency version changed in this verification.

Android Stage 4 native storage acceptance is ready for review. There is no
remaining Android acceptance blocker in the listed cases. This is not a production
release approval or permission to start legacy ownership migration.

## Files changed for this verification

- `android/app/src/main/kotlin/com/corehines/smartbudget/DatabaseKeyVault.kt` — root validation correction.
- `lib/core/user_storage/database_key_vault.dart` — mutable owned key buffers.
- `lib/core/user_storage/storage_access.dart` — consistent live-deadline sampling.
- `test/user_storage/platform_key_vault_test.dart`, `test/user_storage/storage_grant_timing_test.dart` — read-only-buffer and delayed-callback regressions.
- `android/app/src/androidTest/kotlin/com/corehines/smartbudget/DatabaseKeyVaultTest.kt` — identity guard and alias/symlink regression.
- `android/app/src/androidTest/kotlin/com/corehines/smartbudget/NativeStorageAcceptanceSupportTest.kt` — disposable backup/plaintext/key-loss/cleanup support.
- `tool/native_storage_acceptance.dart` — native encrypted storage lifecycle probe.
- `tool/run_native_storage_acceptance.py` — scoped device runner and sanitized evidence capture.
- This report; the Stage 4 status report links the final acceptance result.

Apple signing/Keychain runtime acceptance and production Firebase end-to-end
acceptance remain outside this Android device check. Existing offline revocation,
device-bound key loss, debug release-signing and test-only backend advisory limits
remain described in the Stage 3/4 reports. Stage 5 remains unstarted.

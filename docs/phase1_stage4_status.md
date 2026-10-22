# Phase 1 Stage 4 implementation report

Date: 2026-10-21. Existing branch `Budgeting-with-trasaction`, Phase 0 checkpoint
`9b7fef4`, and all preceding uncommitted Stage 1–3 work preserved. No commits,
pushes, backend deployments, production configuration changes or device installs.

The storage architecture and recovery safeguards are documented in
[phase1_stage4_storage.md](phase1_stage4_storage.md).

## Subsequent Android native acceptance

The later physical TECNO CM6 acceptance run passed after three narrow corrections:
canonical root handling, owned writable key buffers, and conservative grant timing.
The new full Flutter count is **127 passed, one emulator-only test skipped**.
Five native Keystore tests, the two-phase native lifecycle probe (16 named checks),
and four native support/cleanup tests passed. Original legacy data and backup
checksums remain unchanged. The original Stage 4 results below are retained as
historical evidence; the former Android runtime blocker is superseded by
[the native acceptance report](phase1_stage4_native_acceptance.md).
Stage 5 has not started.

## Implementation stages

1. Baseline: 89 Flutter tests passed, one live emulator test skipped. Read the
   approved Stage 4 attachment, checked the actual dependency/toolchain and native
   targets, and saved synthetic schema fixture copies before schema changes.
2. Added schema-v4 ownership metadata, generated Drift code using build_runner,
   and preserved financial backup compatibility. The first regression run passed
   91 tests, including the added schema-4 backup combinations.
3. Added per-session scoped storage, real SQLite encryption, native Android vault,
   Apple Keychain preparation and Stage 3 lifecycle integration. Initial new tests
   revealed matcher-import/test-double issues; these were corrected. Production
   checks were also tightened before the final passing runs.
4. Added isolation, wrong/missing key, corrupt envelope/channel error, owner,
   stale-scope, transaction rollback, restart/restoration, lease and migration
   tests, including session close while a native key load is pending. Native Android Keystore tests compile but require a device to execute.

## Files changed in Stage 4

This list describes this stage, not all work already uncommitted at its start.

| Files | Change |
| --- | --- |
| `.gitignore` | Exclude database files/sidecars and native key envelopes |
| `pubspec.yaml`, `pubspec.lock` | Promote already-resolved crypto 3.0.7 to direct dependency; retain CocoaPods with project-scoped Flutter setting |
| `lib/core/db/app_db.dart`, `app_db.g.dart` | Explicit-executor construction, additive schema 4 and immutable ownership; generated through build_runner |
| `lib/core/user_storage/storage_access.dart` | Verified-session capability, deadline, safe error and lifecycle contracts |
| `lib/core/user_storage/database_key_vault.dart` | Android channel, Apple Keychain, bound key records and scope derivation |
| `lib/core/user_storage/encrypted_database_factory.dart` | Cipher-only open, read-only owner/integrity preflight, safe creation and locking |
| `lib/core/user_storage/guarded_executor.dart` | Guard SQL, nested transactions and commits after session invalidation |
| `lib/core/user_storage/user_database_manager.dart` | Serial session generations, scoped operations, drain/rollback and close |
| `lib/features/auth/presentation/session_cubit.dart`, `lib/main.dart` | Connect verified signed leases and logout/lifecycle to storage; keep financial UI unmounted |
| `lib/features/backup/data/backup_repository.dart` | Accept schema-4 financial payloads without exporting/replacing ownership |
| `android/app/build.gradle.kts` | AndroidX test runner and test-only dependencies |
| `android/app/src/main/kotlin/com/corehines/smartbudget/MainActivity.kt`, `DatabaseKeyVault.kt` | Keystore AES-GCM vault and redacted channel handling |
| `android/app/src/androidTest/kotlin/com/corehines/smartbudget/DatabaseKeyVaultTest.kt` | Four disposable native Keystore instrumentation tests |
| `ios/Runner/AppDelegate.swift`, `macos/Runner/MainFlutterWindow.swift` | No-backup Application Support root; iOS complete file protection |
| `test/fixtures/schema_v3.sql` | Pre-change schema-only synthetic fixture |
| `test/database_migration_test.dart`, `test/sqlite_encryption_test.dart`, `test/backup_repository_test.dart` | Schema-4 expectations/compatibility while preserving old regressions |
| `test/user_storage/support.dart`, `schema_v4_test.dart`, `user_database_manager_test.dart`, `session_storage_test.dart`, `platform_key_vault_test.dart` | Synthetic test support and 33 new tests |
| `docs/phase1_stage4_storage.md`, `docs/phase1_stage4_status.md` | Architecture, migration/recovery, verification and remaining limits |

CocoaPods validation also generated `ios/Podfile.lock`, updated
`ios/Runner.xcodeproj/project.pbxproj` and
`ios/Runner.xcworkspace/contents.xcworkspacedata` with normal Pods integration,
and updated `macos/Podfile.lock` for the existing plugins, including protected
storage. Both native lockfiles resolve Firebase 12.19.0. The generated macOS
registrant remains consistent with the existing Flutter dependencies. Automatic
SwiftPM project/scheme additions were removed; no SwiftPM migration is retained.
Existing deployment targets remain iOS 15/macOS 11 and Apple bundle identifiers
remain `com.example.smartbudget`.

## Verification

All development commands use `python3 tool/clean_run.py` to remove inherited
service credentials. A fresh child check confirmed `GEMINI_API_KEY` is absent.
No credential was printed or rotated in this stage. The pinned financial stack
remains Drift 2.35.2/drift_dev 2.35.1/sqlite3 3.5.2, with
flutter_secure_storage 10.3.4; crypto 3.0.7 changed classification only. No
SDK upgrade, dependency override or dependency-check bypass was used. The Stage 3 revocation finding
and unresolved test-only backend gRPC advisory remain documented in its report.

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed; no existing package version changed |
| `dart run build_runner build` | Passed; generated Drift ownership code |
| `dart format` on changed Dart files only | Passed |
| `flutter analyze` | No issues found |
| `flutter test` | 124 passed, 1 live-emulator-only test skipped |
| Stage 4 new tests | 33 passed; uses real host SQLite3MultipleCiphers and signed Stage 2 lease fixtures; key vault transport/storage doubles are explicitly not device verification |
| Synthetic v2/v3 migration and rollback | Passed; every financial row and pre/post income 100000/spent 20000 minor units preserved; copied backup bytes unchanged; owners remain unassigned |
| SQLite integrity / foreign keys / encrypted reopen | Passed in synthetic storage tests |
| Wrong/missing key and owner rejection | Passed; existing disposable files stay byte-identical, no replacement key |
| Release AOT asset-aware encryption probe | Passed: encrypted creation, reopen, integrity, missing/wrong-key rejection |
| Android debug APK | Passed; `com.corehines.smartbudget` |
| APK native SQLite packaging | Exactly one `libsqlite3mc.so` per ABI (ARM64, ARMv7, x86_64); ARM64 exports `sqlite3_key` and `sqlite3mc_config` |
| `:app:assembleDebugAndroidTest` | Passed; real-vault tests compile |
| `:app:connectedDebugAndroidTest` | Blocked: `No connected devices!`; no AVD configured |
| iOS `flutter build ios --debug --no-codesign` | Passed with CocoaPods; unsigned `build/ios/iphoneos/Runner.app`; no install or Keychain runtime claim |
| macOS `flutter build macos --debug` | Blocked by existing entitlements requiring a development certificate; signing settings were not weakened |
| `swiftc -frontend -parse` for changed Apple files | Passed; syntax only |
| `python3 tool/clean_run_test.py` | 3 environment/redaction tests passed |
| Revoked key source scan | 252 tracked/nonignored source/config files checked; 0 exact matches; no value printed |
| `git diff --check` | Passed |
| Verified legacy backup | Readable, 53248 bytes, SHA-256 matches its recorded verification; bytes read for checksum only, never opened as SQLite |

Commands/logs are outside Git under `/private/tmp/smartbudget-stage4-*`.
The AOT bundle is `/private/tmp/smartbudget-stage4-cipher-aot`.
Android debug APK: `build/app/outputs/flutter-apk/app-debug.apk`.

## Remaining verification and risks

Android Keystore runtime behavior, invalidation and persistence across a genuine
application/device restart must still run on a device/emulator; compiled tests and
mocked channels do not establish these. Apple Firebase registration/startup remains
intentionally unsupported, and actual Keychain behavior requires a signed target.
iOS native code compiled in the unsigned build; macOS full compilation remains
blocked by development signing. CocoaPods/Xcode also report old deployment-target
warnings in some transitive Pods, and iOS warns about a future UIScene lifecycle
migration. These warnings were not addressed by changing unrelated dependencies.
The Android build retains its existing Kotlin/Gradle future-migration warnings and
existing debug release signing; this is not a distribution-ready release.
No StrongBox/hardware protection guarantee or full process-memory zeroization claim
is made. Offline revocation has the existing bounded-lease limitation. Device-bound
key loss and interrupted first creation deliberately lock storage without destructive
recovery. A permanently stuck callback can delay close; it cannot retain SQL access
or let B open early.

The existing protected legacy backup is unchanged, remains outside Git, and has not
been imported or attributed to a Firebase user. No device was connected, so its
current installation could not be re-inspected; no device command altered it.
The product remains on the temporary authorized-session screen. Stage 5 legacy
ownership migration, Stage 6 financial provider mounting, production backend setup
and cloud synchronization are outside this stage.

Stage 4 is ready for code review; native runtime acceptance remains required before
calling this a verified production storage foundation. Stop here for review.

# Phase 1, Stage 1 — dependency and native foundation

Date: 2026-10-21. Branch: `Budgeting-with-trasaction`.

**Android foundation implemented and verified. Optional Apple/release APK verification has environment blockers. Stop here for review; Stage 2 has not started.**

## Data preservation and scope

Phase 0 checkpoint `9b7fef4` remains intact; this retry made no additional commit or push. The verified legacy backup remains readable and checksum-identical. It was not opened with SQLite, imported, modified or encrypted. The original TECNO application was neither installed over, launched, stopped nor uninstalled. Its database hash matched before and after the isolated Android library probe.

All SQLite writes used newly created synthetic/temporary databases. Existing schema version 3, financial tables, constraints and Phase 0 migration logic remain unchanged. Generated Drift code was regenerated with the official generator, never hand edited.

This stage packages an encryption-capable engine and initializes Firebase Core on Android. It does not encrypt existing records, add key vaults, implement per-UID databases, authenticate users, enforce beta membership, issue leases or synchronize data. The current app is not a secure private-beta release. Those behaviors remain later approved stages.

## Exact resolved versions

Normal `flutter pub get` succeeded on the unchanged Flutter 3.44.2 / Dart 3.12.2 SDK. No overrides, dependency-check bypasses, dependency patches or SDK changes were used.

| Package | Resolved version |
| --- | --- |
| firebase_core | 5.0.0 |
| firebase_auth | 7.0.0 |
| cloud_functions | 7.0.0 |
| drift | 2.35.2 |
| drift_dev | 2.35.1 |
| sqlite3 | 3.5.2 |
| hooks | 2.0.2 |
| native_toolchain_c | 0.19.2 |
| code_assets | 1.2.1 |
| record_use | 0.6.0 |
| meta | 1.18.0, Flutter pin retained |
| build_runner | 2.15.1 |

The approved SQLite range is `>=3.5.2 <3.6.0`. It resolves compatible hooks normally, avoiding the earlier SQLite 3.7.1/meta conflict. The bundled engine is SQLite3MultipleCiphers 2.5.0 / SQLite 3.53.4.

`sqlite3_flutter_libs` was removed. No competing SQLite/SQLCipher Flutter plugin remains in the dependency graph or Android APK. The root hook selects `source: sqlite3mc`. Generated hook inputs/outputs confirm that selection on macOS and the three Android ABIs. The official package hook verifies downloaded native library hashes.

## Firebase and Android foundation

Official FlutterFire CLI 1.4.1 generated `lib/firebase_options.dart`, `firebase.json`, native Android configuration and the Google Services plugin setup, reusing the existing registration:

- Project: `smartbudget-561d4`.
- Android Firebase app: `1:463515242262:android:066c564503b6ba967e0a37`.
- Application ID, namespace and Kotlin activity package: `com.corehines.smartbudget`.
- Google Services Gradle plugin: 4.4.4.
- Minimum SDK 24, compile/target SDK 36, Java target 17.
- Existing AGP 8.11.1 and Gradle 8.14 retained.

Firebase Auth's native dependency uses Kotlin 2.4 metadata. The first debug build failed with the old Kotlin 2.2 compiler. Updating to the supported Kotlin Gradle plugin 2.4.21 and `compilerOptions` DSL resolved it; the debug build passed. This version supports the retained Gradle/AGP pair. Existing Flutter-generated built-in-Kotlin/DSL compatibility flags were retained; no compatibility check was bypassed.

Startup checks the cipher engine in memory before opening a financial file, then initializes Firebase Core on Android. The normal database factory also checks the engine before financial SQL. Checks use ordinary runtime conditions in debug and release, not assertions. No production key-setting or plaintext-to-encrypted migration was introduced.

Generated Firebase options contain public client configuration, not service-account credentials, user passwords or signing keys. No backend/app registration was created, no functions/rules deployed, and no billing or authorization services enabled. The app was not device-launched: initialization is wired and compiled, but device runtime Firebase initialization/sign-in is not claimed verified.

## Encryption checks

- Automated test: encrypted creation and reopen, integrity, non-plaintext SQLite header, missing/wrong-key rejection, unchanged file after rejected read-only attempts.
- Automated Drift test: schema 3, synthetic financial write, encrypted close/reopen, preserved totals, integrity and references.
- Release AOT host probe: native assets bundled by `dart build cli`; encrypted reopen/rejection checks passed without assertions.
- APK inspection: only `libsqlite3mc.so` in ARM64, ARMv7 and x86_64.
- Exact ARM64 APK library tested on the TECNO with a C probe compiled using `-O2 -DNDEBUG`: encrypted creation, reopen, integrity, non-plaintext header and `SQLITE_NOTADB` rejection for wrong/missing keys all passed.

Device probe files existed only under a newly generated `/data/local/tmp/smartbudget-cipher-probe-*` directory and were removed afterward. It did not install an application or execute financial SQL against the original database. Test keys were ephemeral and never logged.

An initial `dart compile exe` diagnostic omitted native-asset hooks; the runtime guard rejected the missing cipher engine. The corrected `dart build cli` bundle passed. Reproduce AOT checks with the asset-aware command below, not an executable without its required library.

## Native Apple preparation

Prepared iOS deployment target 15 and macOS 11. Apple identifiers remain `com.example.smartbudget`. Keychain entitlements use the existing identity; macOS has outgoing network capability. Modified entitlement/framework plists pass `plutil -lint`.

Apple Firebase registration/options remain deferred until permanent Apple identifiers, signing and existing-container/Keychain migration implications are decided. Android-only Firebase bootstrap leaves existing Apple startup behavior intact.

macOS CocoaPods resolution succeeded and its lockfile is updated. The signed build then failed because Keychain entitlements require a development certificate/team. Required entitlements were retained. An unsigned follow-up could not start on the full disk.

The optional unsigned iOS build stopped during pod installation with `Errno::ENOSPC`. Flutter's automatic UIScene edits were specifically reverted, preserving the original AppDelegate and Info.plist. No Apple build is claimed successful.

## Commands and actual results

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed with approved SQLite range |
| `dart run build_runner build` | Passed; generated code compatible |
| `dart format` on changed non-generated Dart files | Passed |
| Final `flutter analyze --no-pub` | No issues found, exit 0 |
| Final `flutter test --no-pub` | 59 passed, exit 0: existing 56 plus 3 new tests |
| `git diff --check` | Passed |
| `flutter build apk --debug --no-pub` | Passed after supported Kotlin update |
| APK identity/SDK/native library inspection | Correct package, minimum SDK 24, sqlite3mc only |
| Exact APK engine probe on TECNO ARM64 | Passed |
| `dart build cli --target=bin/sqlite_encryption_probe.dart --output=/private/tmp/smartbudget-cipher-aot` and bundled executable | Passed; release AOT encryption |
| Optional Android release APK | Failed during packaging: disk full |
| Optional signed macOS debug build | Missing development signing certificate/team |
| Optional unsigned iOS debug build | Pod installation blocked by full disk |

The full disk interrupted an intermediate test rerun. Removing only this run's reproducible `build/app/intermediates/merged_native_libs`, `build/app/intermediates/incremental` and incomplete release APK recovered about 2.7 GiB. The final analysis and all 59 tests then passed. The verified debug APK, source, production databases and backups remain intact. Optional heavy builds were not retried on the nearly full host disk.

Artifact: `build/app/outputs/flutter-apk/app-debug.apk`. Optional-build diagnostics remain outside Git in `/private/tmp/smartbudget-stage1-*-build.log`. Android release signing still uses the pre-existing debug signing configuration; production signing is a later distribution requirement.

## Files changed or retained for review

This includes earlier approved Android identity/configuration work still in the working tree; the Phase 0 checkpoint is unchanged.

| Area | Files |
| --- | --- |
| Dependencies/tooling | `pubspec.yaml`, `pubspec.lock`, `.gitignore`, `analysis_options.yaml` |
| Firebase configuration | `firebase.json`, `lib/firebase_options.dart`, `android/app/google-services.json` |
| Android build/manifest | `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml` |
| Earlier Android work retained | `android/gradle.properties`; move `android/app/src/main/kotlin/com/example/smartbudget/MainActivity.kt` to `android/app/src/main/kotlin/com/corehines/smartbudget/MainActivity.kt` |
| Startup/engine | `lib/main.dart`, `lib/core/firebase/firebase_foundation.dart`, `lib/core/db/sqlite_engine.dart`, `lib/core/db/app_db.dart` |
| Generated Drift | `lib/core/db/app_db.g.dart` |
| iOS | `ios/Podfile`, `ios/Flutter/AppFrameworkInfo.plist`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Runner.entitlements` |
| macOS | `macos/Podfile`, `macos/Podfile.lock`, `macos/Runner.xcodeproj/project.pbxproj`, `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements` |
| Generated registration | `macos/Flutter/GeneratedPluginRegistrant.swift`, `linux/flutter/generated_plugin_registrant.cc`, `linux/flutter/generated_plugins.cmake` |
| Existing test API updates | `test/database_migration_test.dart`, `test/support/v2_fixture.dart`: deprecated SQLite `dispose()` replaced with `close()`; assertions preserved |
| New tests | `test/sqlite_encryption_test.dart`, `test/firebase_configuration_test.dart` |
| Probe tools | `tool/sqlite_encryption_probe.dart`, `bin/sqlite_encryption_probe.dart`, `tool/android_sqlite_encryption_probe.c` |
| Reports | `docs/phase1_stage1_preflight.md`, `docs/phase1_stage1_status.md` |

Generated build directories are excluded from analysis because Flutter stages third-party Swift package examples/tests there. Kotlin's generated cache is ignored. No lint rule for application source was disabled. Financial databases, exports, signing material, private keys and service-account credentials are excluded from the Git review.

## Readiness

Android dependency/native foundation is ready for review. Free adequate host disk capacity before repeating optional builds; configure an Apple development team/certificate for signed macOS validation. Apple Firebase registration, device startup acceptance, release signing and the later authorization/user-isolation stages remain outstanding. No Stage 2 work or deployment was performed; stop for the user's review.

References: [Drift encryption](https://drift.simonbinder.eu/platforms/encryption/), [SQLite 3.5.2](https://pub.dev/packages/sqlite3/versions/3.5.2), [Firebase setup](https://firebase.google.com/docs/flutter/setup), [Kotlin compatibility](https://kotlinlang.org/docs/gradle-configure-project.html), [Dart native-asset build](https://dart.dev/tools/dart-build).

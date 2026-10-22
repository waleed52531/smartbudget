# Phase 1 Stage 4: encrypted user storage

Stage 4 adds storage infrastructure only. The production entry point still mounts
`AuthSessionApp`, never the financial application, repositories or financial BLoCs.
No cloud synchronization, legacy claim/import, backend deployment or production
Firebase changes are included.

## Authorization and lifecycle

`SessionCubit` implements `StorageAuthority`. It issues an in-process `StorageGrant`
only after the existing Stage 2 signed lease has passed Stage 3 verification. A
Firebase login or a caller-provided UID cannot open storage. Project and UID are
read from that verified grant, and verified again against the current session.

`UserDatabaseManager` serializes open, transaction and close operations. Auth
changes synchronously invalidate every SQL operation, including retained Drift
references, batches, nested transactions and commits. Rollback/close remain
available. A pending transaction must finish/roll back before closing A and opening
B. An asynchronous callback that never returns can delay physical close/logout;
SQL access stays locked and B cannot open during that wait. Future financial
services should keep callbacks short and perform network work outside transactions.

Only give `UserDatabaseScope` to future session-scoped repositories/services. A
scope captures its authorization generation. An A scope retained across an await
cannot redirect a later write to B. Do not give widgets the manager or construct
an authority from a UI UID. There is no production global database constructor.

Each operation checks the live grant, then re-verifies the real signed lease using
the native clock, installation binding and current identity before work and before
commit. The SQL interceptor also checks a monotonic, wall-clock-aware deadline.
Logout, app backgrounding, lease expiry and observed revocation invalidate access.
Offline revocation still cannot be learned until online verification or expiry,
up to the approved 24 hours. Rooted devices, a compromised process and sophisticated
clock manipulation are outside the guarantees of this local lease design; there
is no access-on-error fallback. Stage 3 reauthorization rules remain in force.

## Encryption and identity binding

The folder is SHA-256 of UTF-8 `projectId + NUL + uid`, derived internally. Every
user gets a random 256-bit database key and random database-instance UUID.
SQLite3MultipleCiphers `chacha20` is selected and keyed before schema reads/writes.
The required cipher engine must be present in ordinary runtime code, including
release. Plaintext SQLite is never a fallback. Temporary SQLite storage is memory;
user databases use encrypted rollback journaling (`DELETE`), rather than enabling
WAL here. SQLite encrypts the on-disk journal as well as database pages.

An existing file is first opened read-only and must have schema 4, exactly one
matching project/UID/database UUID, a successful integrity check and no FK
violations. Wrong/missing keys, an unowned file, corrupt content or incompatible
schema stop before read-write open. A matching database is then opened under a
per-scope file lock and an in-process lock. No mismatch triggers delete, reset,
key regeneration, reassigning ownership or automatic migration. Native/SQLite
errors are reduced to fixed failure categories, without SQL, records or key bytes.

Raw key buffers are cleared after setup, and the native Android return buffer is
cleared after channel encoding. Dart/FFI/native copies and immutable key-setting
strings cannot all be guaranteed zeroized by a garbage-collected runtime. Keys
must remain available to SQLite while a connection is open; close releases it.
No key or financial record is stored in SharedPreferences.

## Android key vault

`DatabaseKeyVault.kt` creates non-exportable AES-256-GCM wrapping keys in
`AndroidKeyStore`, with a separate alias per project/UID scope. Hardware/StrongBox
backing is not asserted. A fresh random IV and authenticated additional data bind
version, project, UID and database UUID to the encrypted 32-byte database key.

Only the authenticated envelope is written, exclusively and fsynced, to
`noBackupFilesDir/user_storage_v1/<scope>/key.envelope.json`. The database and its
sidecars are in the same no-backup folder. Existing `allowBackup=false` and Android
cloud/device-transfer extraction exclusions remain enabled. No raw key enters
SharedPreferences. A missing/invalidated Keystore key, missing/corrupt envelope,
or an orphan alias is a recovery condition, including after incompatible restore.
There is no reset-on-error operation. A crash between envelope creation and initial
database ownership commit also requires recovery rather than an automatic retry
that replaces material.

## Apple preparation

A separate Keychain namespace stores each user's key and bound metadata using
`unlocked_this_device`, `synchronizable=false`. macOS retains the data protection
Keychain default. Native channels create Application Support storage excluded
from backup; iOS also requests complete file protection. Existing bundle IDs stay
unchanged. The approved Firebase initialization remains Android-only, so this does
not silently enable Apple authentication without its registration/configuration.

CocoaPods remains the project's dependency manager. Flutter 3.44 attempted an
automatic SwiftPM migration during validation; those automatic project/scheme edits
were removed while preserving the recorded Stage 1 platform settings. The official
per-project `flutter.config.enable-swift-package-manager: false` setting prevents
that unrelated migration. No global Flutter settings or SDK versions were changed.

## Schema 4, migration and rollback

The six financial tables, constraints, integer minor-unit amounts and Phase 0
validation remain intact. Schema 4 adds only `database_ownership`: a singleton
primary-key row containing project, UID and database UUID. Update/delete triggers
make the assigned owner immutable. New encrypted databases insert the owner once.
No preference table is needed while financial features remain unmounted.

Copied v2/v3 synthetic fixtures upgrade transactionally. Phase 0 rejects duplicate
IDs, orphans and ambiguous records; an unexpected ownership table also stops an
upgrade. Legacy upgrades leave ownership empty, never claiming data. Tests compare
every financial row and pre/post totals, FK/integrity results, and version rollback
on late failure. Fixture SQL copies were saved before schema edits under
`/private/tmp/smartbudget-stage4-fixture-backups`; no production DB was used.

Financial backup JSON remains six tables and accepts schema 2/3/4 payloads.
Ownership and key material are never exported/imported by that backup repository;
overwrites preserve the destination owner. Existing explicit JSON exports are
still plaintext, as before, and must not become an automatic recovery/sync mechanism.
A later backup-product review is needed before exposing those features to beta users.

There is no in-place production migration or automatic downgrade in Stage 4.
For test rollback, close the working database and restore its untouched pre-upgrade
copy, including version. For a real recovery incident: lock/sign out, preserve the
database, all sidecars, envelope and native key state; do not clear app storage,
uninstall, delete aliases or manufacture a replacement key. Work on a separate copy
under an approved recovery plan. Device-bound key loss may be unrecoverable; copying
an envelope alone to another device is not a recovery mechanism. Stage 5 must use
an independently verified legacy backup and explicit ownership confirmation, with
copied-database validation and rollback, before claiming any financial record.

The original TECNO app/DB and the verified legacy backup are not opened by this
code. No legacy data was imported, assigned, repaired or encrypted in this stage.

## Primary references

- [Drift encryption and SQLite3MultipleCiphers hooks](https://drift.simonbinder.eu/platforms/encryption/)
- [Android Keystore](https://developer.android.com/privacy-and-security/keystore)
- [AndroidX instrumentation dependencies](https://developer.android.com/jetpack/androidx/releases/test)
- [Apple device-only unlocked Keychain accessibility](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly)
- [Flutter project configuration](https://docs.flutter.dev/tools/pubspec)

# Phase 1, Stage 1: Android identity and existing-data preflight

Current status: **the legacy-backup safety gate subsequently passed and the user approved Stage 1 implementation.** See `phase1_stage1_status.md` for current implementation/validation results. The observations below are historical, before the separately approved backup was captured and verified. Production backup/report contents remain outside Git.
Observed on 2026-10-21, on branch `Budgeting-with-trasaction`.

## Verified configuration

- The Android application ID and namespace are already `com.corehines.smartbudget`, following the earlier explicit package-rename request. This preflight has not changed or reverted them.
- `MainActivity.kt` is in `android/app/src/main/kotlin/com/corehines/smartbudget/` and declares the matching package. The manifest uses `.MainActivity`.
- The existing `android/app/google-services.json` identifies project `smartbudget-561d4` and contains a client for `com.corehines.smartbudget`. Its contents have not been changed.
- Gradle uses Android Gradle Plugin 8.11.1 and Kotlin 2.2.20. Android inherits minimum SDK 24 from the installed Flutter SDK.
- The iOS bundle identifier remains `com.example.smartbudget`. Recommend `com.corehines.smartbudget` for a separately approved permanent iOS registration; first account for any existing iOS installation, data container, signing and Keychain access. No Apple identifiers were changed.
- The checked-out app currently opens `monthly_budget.sqlite` under `getApplicationDocumentsDirectory()`. Authentication and user isolation are not yet implemented.

## Connected-device findings

Read-only package/file-metadata inspection of the connected TECNO CM6, Android user 0, found:

- `com.example.smartbudget` is installed.
- `com.corehines.smartbudget` is not installed for the current profile.
- The old application's own debug identity can access its existing `app_flutter/monthly_budget.sqlite` file. It is 53,248 bytes.
- No `monthly_budget.sqlite-wal` or `monthly_budget.sqlite-shm` was present at the time of the file listing. This does not establish that WAL contents can be ignored during a later export.
- No SQLite command-line executable was found in the old application's command search path.
- A default package query encountered a restricted additional Android profile. Repeating the query for `--user current` inspected user 0 only; the restricted profile was not accessed.

File size does not prove whether financial records exist. No production database was opened, copied, repaired, upgraded, deleted or reassigned. No record counts, balances or financial contents were read. No application was installed, launched, stopped or uninstalled.

The presence of this unverified database is a data-preservation gate. The new Android identity cannot read the old private container, and no validated owner-controlled migration artifact has been established. Treat the old installation as containing valuable records until verified otherwise.

## Export options while the old application remains installed

### Existing in-app export, if available in the installed version

The checkout contains `BackupRepository.exportPayload()` and `exportBackupJson()`. The payload includes the format version, schema version, export timestamp and all six financial tables. All table reads occur inside one SQLite transaction, so the logical snapshot includes committed records visible through SQLite, including committed WAL records. Uncommitted changes are intentionally excluded.

However, `BackupScreen` has no navigation entry in this checkout. The installed application's UI has not been inspected, so an accessible export screen there cannot be assumed. If its export screen is accessible, use Export & Share to save a private owner-controlled JSON artifact. JSON exports are plaintext: keep them outside the repository and public/shared locations.

If export is inaccessible, do not install an export-helper update over the old app before preserving its raw database. Opening a newer build could trigger a schema upgrade.

### Debuggable old application: quiescent raw snapshot

The existing `run-as com.example.smartbudget` access makes an owner-supervised backup possible without adding cross-application access to the new app:

1. Confirm this is the intended legacy device and pause use of the old app. Finish pending edits. Establish that no process is writing the database; pausing/stopping the old app is a distinct device operation to arrange with the owner.
2. Create a private, owner-only backup directory outside this repository. Record the old package ID, installed version/signing identity, Android user, source paths, capture time and file inventory without logging records or tokens.
3. While writes remain paused, export the main SQLite file and every present WAL/SHM sidecar through the **old application's own** debug identity, for example using `adb exec-out run-as com.example.smartbudget tar ...`. First verify the exact inventory and tool availability; include the actual present files rather than treating missing sidecars as a successful capture.
4. Retain an untouched raw capture and checksums. Verify transfer completeness and source stability before allowing writes to resume. Never copy just the main file from a live database and call that a consistent backup.
5. Work on a separate copy of that capture. Use SQLite's backup API to produce a standalone snapshot, allowing SQLite to interpret committed WAL contents. Check the SQLite schema version, `integrity_check`, references and all six table contents. Do not checkpoint, repair or otherwise write the original installation's database.
6. Validate an independent restore into a temporary synthetic/staging database. Compare every retained ID and field, row counts, recurring markers and integer financial totals. Ambiguous v2 data must stop validation; no automatic deletion, merging or reassignment is permitted.
7. Keep the old installation and raw recovery capture intact. If the old app is used again, the artifact is a point-in-time backup; a fresh capture and reconciliation are required before final cutover.

This is a documented procedure, **not an executed or verified production export**. A backup must actually be captured and validated before this preflight can pass. If debug export stops being available and in-app export is inaccessible, stop and resolve that blocker; do not uninstall, clear storage, root the device, or bypass the Android sandbox.

## Later import and rollback gates

- Stage 1 does not import financial records or assign legacy ownership.
- Stage 5 must require authenticated identity, explicit ownership confirmation and administrator-approved ownership before restoring into a separate encrypted UID database.
- Test that restore against copied synthetic v2/v3 fixtures first, then verify the owner-approved artifact. Preserve categories, budgets, transactions, recurring records, IDs, references and totals; verify encrypted reopening before activating the destination.
- The new app must not automatically discover or read another package's private files. Import uses an explicitly selected migration artifact.
- Keep the old installation and source files. Retained plaintext backups remain an at-rest risk until a separately agreed archive-protection procedure is completed.
- Rollback initially means continuing with the preserved old installation. Once either application has accepted further writes, reconcile those writes explicitly; restoring a stale snapshot is not a lossless rollback.
- A new identity must not silently seed an empty database and report that the old data was migrated.

## Verification performed in this preflight

- `flutter test --no-pub`: **56 tests passed**, exit 0; synthetic/in-memory fixtures only.
- `flutter analyze --no-pub`: **no issues found**, exit 0.
- `git diff --check`: passed before writing this report; rerun after writing.
- Package metadata and old database-file metadata queries: completed for the current Android profile.
- No new build, dependency resolution, Firebase deployment, billable-service activation or production-data restore was performed.

The existing backup tests verify schema-v2/v3 payload compatibility, idempotency, conflict rejection and atomic restores. They do not establish that a real device backup exists, that live WAL export has been tested, or that encrypted new-application restore has passed.

## Next authorized stage after the data gate is resolved

Implement Stage 1 only: resolve approved Firebase/Drift/SQLite encryption dependencies, regenerate Drift code without manually editing generated files, make targeted native deployment/capability changes, test the native encryption library on synthetic databases, rerun all Phase 0 regressions and analysis, and verify available debug builds. Keep Apple identifiers and existing financial behavior intact. Report results before proceeding; Stage 2 is not automatically authorized by completion of Stage 1.

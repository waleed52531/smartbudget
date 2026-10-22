# Stage 5 — legacy migration implementation and acceptance

Date: 2026-10-22, Asia/Karachi. Existing branch `Budgeting-with-trasaction`.
No commit, reset, push, production grant issuance or real-data import was performed.
Existing Stage 1–4 work is preserved. The financial schema stays at v4; existing
Drift migrations are reused, with no generated schema edits or destructive DDL.

## Baseline and data safety

The TECNO CM6 was connected. Before implementation, the new app showed authorized
/ verified online and the public keys endpoint returned HTTP 200. The old app
`com.example.smartbudget` stayed installed. Its database was byte-hashed only:
`51b830d0d59683994c0b579a1a2c55496fb10a19f79fd16d323f8603ee65968f`.
No old-app start, stop, clear, uninstall, SQLite connection or repair was attempted.
The new app uses `com.corehines.smartbudget`, native Keystore-protected independent
UID keys, SQLite3MultipleCiphers and the existing immutable ownership table.
Physical logout/relogin remains a separate outstanding acceptance check; the
earlier cold-process authorization restoration passed.

The original backup remains:
`/Users/waleed/SmartBudgetBackups/tecno-legacy-20261021T115349Z-l5f1mo2p/legacy_snapshot.sqlite`.
It is 53,248 bytes with approved SHA-256
`4fbe5a990460efd757dcebae0d870c9538ef7d08c469d8d7b6bab94fbc2e9b7a`.
Only an owner-restricted reference copy was inspected with SQLite, opened read-only.
It has schema v2; 24 category nodes; 9 budget months; zero limits, transactions,
recurring templates and recurring applications. Integrity returned `ok`; duplicate
ID checks across all six financial tables and category/transaction/budget reference
checks returned zero issues. This inspection did not run a migration or assign
ownership. Synthetic SQL fixtures were backed up alongside that private reference
copy under the task's temporary `smartbudget-stage5-reference-*` directory.

## Architecture and safeguards

`LegacyMigrationService` receives the existing session-bound
`UserDatabaseManager`. It accepts no destination UID selector. Every operation
uses the current `StorageGrant`; the authority revalidates the signed lease/native
clock, and identity changes invalidate in-flight work. Maintenance closes normal
connections before taking the same per-user filesystem/in-process lock used by
normal database opening. A stale financial scope cannot redirect work to a new user.

The workflow is deliberately separated:

1. **Review:** explicit ownership confirmation and a valid session; returns only
   aggregate counts/totals, source fingerprint and existing destination database ID.
2. **Prepare:** additionally requires a signed administrator ownership grant.
   Creates a separate encrypted candidate; does not replace the active database.
3. **Activate / resume:** fresh session/grant verification and a second explicit
   confirmation. Requires an empty, correctly owned destination, exact candidate
   fingerprint and correct-key reopen. Retains the previous empty database.
4. **Rollback:** explicit pre-activation recovery under the verified owner session.
   Retains staging artifacts and restores the old empty destination when necessary.
   An active migration cannot be rolled back automatically.

The authorized-session screen links to an administrator-assisted migration page.
There is no automatic import, predefined real backup path, database owner guessed
from an email/device, or budgeting dashboard. User input cannot supply a trusted
verification-key URL. The page is bound to the original authenticated UID and
hides its review immediately when that session is lost or switched. File paths
are operator-supplied; no document-picker cache silently copies financial data.

### Snapshot, schema compatibility and financial preservation

The input must match its reviewed main-file SHA-256. A standalone source must have
a normal SQLite header, rollback-journal format and no pending WAL/journal. A bare
copied WAL-mode main file is rejected. For a stable complete WAL bundle, both the
main and WAL digests and existing SHM file are required. SQLite's Online Backup API
copies the committed read snapshot into memory; source digests are checked before
and after. Concurrent changes fail closed. The original source is never upgraded.

An in-memory copy runs the existing approved v2/v3 → v4 Drift migrations. This
repairs v2 structural foreign keys without editing the source. Unknown tables,
views, triggers or columns, duplicate IDs, invalid references, non-integer monetary
values and other invalid rows block import. There is no conflict merge, default
category reassignment, missing-record deletion or ID regeneration. Unknown table
names resembling SQLite internals are also rejected. SQLite temporary storage stays
in memory; trusted-schema behavior is disabled for source processing.

All six tables are copied with their original columns and identifiers. Full typed
row fingerprints cover category hierarchy/flags/icons, budget month IDs/currency,
limits, transactions/notes/timestamps, recurring templates/history and the recurring
AUTOINCREMENT sequence. Before/after fingerprints must match. Monetary aggregates
are computed with `BigInt` and presented as integer minor-unit strings; no doubles
or decimal currency conversions are used. Tests cover values above JavaScript's
safe-integer precision. The original source version is retained in the journal.

The candidate is created with schema v4, immutable current-user ownership and the
existing UID key/database ID. SQLite3MultipleCiphers capability/cipher selection
must succeed. Correct-key reopening, ownership, SQLite integrity, foreign keys,
full row fingerprint, ordinary plaintext rejection and incorrect-key rejection
are verified before activation. No financial record is staged in a plaintext
destination or journal. The selected legacy source itself remains a legacy
plaintext backup and must stay protected and retained.

### Administrator ownership approval

Ownership grants have separate JWS type `sb-legacy-ownership+jwt` and issuer
`smartbudget:<project>:legacy-ownership`. They bind project, authenticated UID,
source fingerprint, exact destination database ID, policy, issue/expiry time and
unique grant ID. A session lease cannot be used as an ownership grant. The client
uses only the trusted authorization service's public Ed25519 JWKS. Signature,
key ID, exact claims, identity, source, destination and lifetime are verified.
The verifier caps lifetime at 24 hours; the operator CLI issues one-hour grants.

`tool/issue_legacy_ownership_grant.cjs` is prepared but was **not run for real data**.
It requires explicit production project confirmation and an ownership-approval
flag; uses the workstation administrator Firebase CLI identity in memory; resolves
the existing enabled password account through Firebase Admin; confirms active beta
membership; and checks project number and disabled billing. It signs with the
existing protected signing key only if it matches the deployed public JWKS.
Private key/input/output paths must be outside Git with restrictive permissions;
output is exclusively created mode 0600. It prints neither UID records nor tokens.
No approval HTTP endpoint or backend deployment was introduced.

The signer shares the existing authorization trust root, with strict purpose
separation. A compromise of that signing key remains a trust-root compromise.
There is no instantaneous offline ownership-grant revocation: short expiry,
fresh trusted-key retrieval and the session lease bound recovery. A separate
ownership-signing infrastructure is a possible later hardening, not a security
bypass or requirement for this controlled beta workflow.

### Crash safety and recovery

Each user directory holds a metadata-only `.legacy-migration.json` with source
fingerprint, database ID, hashed owner scope, row digest, source version and phase.
It contains no key, raw rows, monetary totals or grant token. File contents are
flushed; journal replacement and database renames are followed by native Android
directory `fsync`. That method accepts only a project/UID-derived vault directory,
not arbitrary paths. Unsupported/failed synchronization blocks the operation.

Phases are `preparing`, `verified`, `activating`, `active`, and `rolledBack`.
Incomplete, malformed or pending `.next` journals block normal financial opening.
Orphan candidate/previous files and inconsistent active/rollback layouts also
block normal opening. The candidate uses DELETE journaling and FULL synchronous
writes. Activation keeps `.legacy-previous-empty.sqlite`, then renames the verified
candidate to `financial.sqlite` on the same filesystem, verifies it again, and
records `active`. It never overwrites an existing financial dataset.

For recovery:

* A `verified` operation can be retried idempotently with the same source and a
  current matching grant, or explicitly activated.
* An `activating` operation can resume after either database rename; all ownership,
  empty-old-database and fingerprint conditions are rechecked first.
* An interrupted `preparing` operation requires explicit rollback before retry.
  Rollback archives candidate files and hot sidecars together, retains partial
  journal writes, and restores the retained empty database as needed.
* A missing key, owner mismatch, corrupt journal or conflicting file arrangement
  requires operator review. Do not delete artifacts, recreate keys, edit ownership
  rows, reset app data or guess which file should become active.
* After `active`, repeated activation does not reinsert rows. Different sources or
  an already populated destination are rejected; post-activation rollback needs
  separate review and approval.

Logical interruption points are automated fault-injection tests. Physical native
acceptance also checks encrypted reopening across an actual process stop/start.
These are not a claim of testing battery removal or every filesystem power-loss
failure. Native directory synchronization is Android-specific in this stage;
Apple migration acceptance is not claimed.

## Verification results

| Check | Actual result |
| --- | --- |
| `flutter pub get` | Passed; no SDK upgrade, dependency overrides or package changes requested |
| `dart format` | Changed Stage 5 Dart files only |
| `flutter analyze --no-pub` | No issues |
| Full `flutter test --no-pub --reporter expanded` | 178 passed; one emulator-only test skipped |
| Migration coverage | v2/v3 empty and populated; full rows/IDs/totals; duplicate/orphan/unknown schema; ownership/expiry/signature/purpose; wrong key; WAL/missing WAL; destination preservation; fault phases; rollback/retry/resume; account switch; repeated calls |
| UI acceptance | Preparation disabled without confirmation; logout hides the prior UID's aggregate review |
| `npm --prefix functions test` | 41 passed; purpose separation and lifetime validation added |
| Grant CLI / native runner syntax checks | Passed |
| `git diff --check` | Passed |
| Android normal and disposable-probe ARM64 debug builds | Passed; configured normal APK restored after testing |
| Physical TECNO native migration | Passed: real Keystore, directory fsync, v2 → v4, minor units, rollback/retry, ownership/FK checks, plaintext/wrong-key rejection, unchanged synthetic source |
| Physical cold-process encrypted reopening | Passed in a second process using the existing wrapped key and same database ID |
| Legacy data final safety checks | Old-app database and original snapshot hashes still match |
| New-app storage byte-header inspection | Two financial files inspected after native acceptance; both encrypted headers; no keys or user records read |
| Git-visible credential scan | No exact production signing/runtime private key or App Check debug token found |

An initial UI test run stalled during cleanup of a database manager created under
Flutter's fake clock. That harness was corrected to use a no-storage capability
double for UI-only assertions; actual storage behavior remains covered by real
SQLite tests. The interrupted runs are not counted as passing. All temporary
diagnostic print markers were removed before the passing complete suite.

The first Android build found that `OsConstants.O_DIRECTORY` is not exposed by
this Android SDK. The helper was corrected to public `Os.open(O_RDONLY)`,
directory verification through `Os.fstat`, and `Os.fsync`. That failed build
installed nothing. The corrected normal/probe builds and physical directory-sync
checks passed. Existing future Kotlin Gradle Plugin migration warnings remain.

Native evidence is retained privately at
`/var/folders/2x/f7sb5mns05s7d5f82b8v7j680000gn/T/smartbudget-stage5-native-obdtiiun`.
The prepared/reopened reports have nine passing boolean checks. Synthetic device
records use only project `migration-test-b92073cd6752`, UID `synthetic-a`; no real
Firebase user, production signing secret or reference-backup record was used by
the probe. The source and encrypted disposable artifacts were retained. The
configured `com.corehines.smartbudget` app was reinstalled with `-r`, with no
uninstall or reset, and started again after the probe.

## Exact real-backup procedure — separate approval required

The following procedure is prepared for review, **not executed**:

1. Recheck the approved snapshot checksum and retain its untouched master copy.
   Verify the intended Firebase UID through the administrator API and complete the
   outstanding physical logout/relogin acceptance. Verify online access and that
   this UID's encrypted destination is empty. Stop on any existing financial rows.
2. After explicit real-import approval, transfer a byte-identical, read-only
   **copy** of the standalone snapshot to a private input directory readable only
   by the new app. Use binary transfer and verify the copied SHA-256. Never extract
   or write the original app's private database, transfer a signing key to the
   phone, or use Git/shared logs for the backup or grant.
3. In the new app choose **Legacy migration**. Enter the private backup-copy path
   and approved SHA-256; explicitly confirm ownership for the signed-in account;
   choose **Review backup only**. Check 24 category nodes, 9 budget months and zero
   other financial rows, with the expected source schema v2. Record the displayed
   source fingerprint and destination database ID privately.
4. An administrator makes the explicit ownership decision and runs the prepared
   CLI below against that verified account. Email is used only for authoritative
   identity lookup, not as evidence of ownership. The explicit approval flag,
   source fingerprint, destination ID and signing key are required.

```sh
python3 tool/clean_run.py node tool/issue_legacy_ownership_grant.cjs \
  --project smartbudget-561d4 --confirm-project smartbudget-561d4 \
  --email '<verified-account-email>' --confirm-ownership \
  --source-id '<reviewed-source-fingerprint>' \
  --database-id '<reviewed-destination-database-id>' \
  --kid beta-20261022-01 \
  --key-file /Users/waleed/SmartBudgetPrivate/authorization-20261022/lease-private.pem \
  --output '<new-private-directory>/ownership-grant.json' \
  --firebase-tools-lib /opt/homebrew/lib/node_modules/firebase-tools/lib
```

Use Node 22 as for existing backend tooling and build `functions` first. Output
must be a new file in an existing owner-only directory outside the repository.

5. Transfer only the private grant JSON to an owner-restricted input location on
   the new app. Enter its path, then choose **Prepare encrypted copy**. Review all
   counts, exact minor-unit totals and source/destination identifiers. Stop on any
   mismatch or conflict; no record should be manually reassigned or discarded.
6. Choose **Activate / resume verified migration** and confirm. This activates
   only the verified encrypted candidate while retaining the original backup,
   source copy and old empty encrypted destination. An expired grant requires
   fresh administrator approval; retrying never bypasses expiry.
7. Reopen the app, verify ownership, row counts/totals, encryption and SQLite/FK
   integrity through the controlled acceptance workflow. Recheck the original
   backup and old-app database hashes. The budgeting dashboard remains locked;
   Stage 6 needs separate approval.

## Files changed

New:

* `lib/core/legacy_migration/legacy_source.dart`
* `lib/core/legacy_migration/ownership_grant.dart`
* `lib/core/legacy_migration/migration_journal.dart`
* `lib/core/legacy_migration/legacy_migration_service.dart`
* `lib/core/user_storage/user_storage_lock.dart`
* `lib/features/legacy_migration/presentation/legacy_migration_page.dart`
* `functions/src/legacy_ownership.ts`
* `tool/issue_legacy_ownership_grant.cjs`
* `tool/native_legacy_migration_acceptance.dart`
* `tool/run_native_legacy_migration.py`
* `test/legacy_migration_test.dart`
* `test/legacy_migration_page_test.dart`
* `test/fixtures/stage5_ownership.json` (public synthetic signed-contract fixture)
* This report.

Modified:

* `lib/core/user_storage/encrypted_database_factory.dart`: shared lock, pending
  migration gate and reusable encrypted ownership/integrity verification.
* `lib/core/user_storage/user_database_manager.dart`: serialized session-bound
  maintenance with closure and final authorization checks.
* `lib/core/user_storage/storage_access.dart`: pending-migration failure and
  conservative trusted-time getter.
* `lib/features/auth/presentation/session_app.dart`, `lib/main.dart`: guarded
  migration-page factory/link; financial dashboard stays absent.
* `android/app/src/main/kotlin/com/corehines/smartbudget/DatabaseKeyVault.kt`
  and `MainActivity.kt`: scoped directory-fsync native method.
* `functions/test/unit.test.ts`: administrator grant purpose/lifetime tests.

Existing financial repositories, budgeting calculations, recurring behavior,
backup exports, deployed authorization endpoints/rules/IAM, Firebase project and
legacy financial schema were not rewritten or deployed by this task.

## Remaining limits and readiness

Real-data import still needs explicit user approval and a real administrator
ownership grant; none has been issued. Physical logout/relogin remains recorded
as outstanding. Legacy snapshots themselves are plaintext and must stay protected.
Large source datasets are copied into memory, so capacity must be evaluated before
using this workflow for substantially larger backups. Unrecognized schema/data
requires review, not automatic conversion. Offline session/grant revocation,
existing native secure-storage compatibility warnings, test-only gRPC advisory,
release attestation/signing and Apple acceptance remain as documented previously.
There is no cloud financial synchronization or Stage 6 dashboard activation.

Stage 5 is ready for review and **conditional approval of a controlled Android
real-data import**. Complete the outstanding physical logout/relogin check,
explicit ownership decision and administrator grant before executing the prepared
procedure. No real backup was migrated or claimed in this implementation stage.
The budgeting workspace remains locked and Stage 6 was not started.

References: [SQLite Online Backup API](https://www.sqlite.org/backup.html),
[SQLite WAL safety](https://www.sqlite.org/wal.html),
[SQLite3MultipleCiphers](https://github.com/utelle/SQLite3MultipleCiphers).

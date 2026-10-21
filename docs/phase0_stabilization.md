# Phase 0 — Stabilize existing Smart Budget

Branch: `Budgeting-with-trasaction`. Scope: existing local budgeting only. No authentication, Firestore, cloud sync, bank APIs, financial-account entities, or new product features are implemented.

## Findings and order of implementation

| Stage | Verified problem | Change | Main evidence |
| --- | --- | --- | --- |
| 1 | Two invalid database import paths; counter test references nonexistent `MyApp` | Fix imports; inject a database executor; replace starter test with isolated dashboard smoke test | `test/widget_test.dart` |
| 2 | Category, transaction and budget-limit IDs have no PK; FK checks disabled; duplicate top-level category names allowed | Schema 3, explicit PKs, category parent FK, unique category-name index, FK enforcement | `test/database_migration_test.dart` |
| 2 | Existing rows may be ambiguous or violate new constraints | Preflight detects duplicate IDs/names, invalid/orphan references, invalid monetary values and recurring days; abort without changing records | Invalid v2 fixture cases |
| 2 | Upgrade must preserve balances and survive failures | Transactional table rebuild, pre/post counts and financial aggregates, FK check, atomic schema-version update | Exact row comparison, reopened-file checks and failure after DDL begins |
| 3 | Merge duplicates transactions; replacement can cascade; incomplete overwrite can erase tables | Require complete supported payload; validate in isolated staging DB; atomic restore; skip identical rows; reject conflicts instead of replacing them | `test/backup_repository_test.dart` |
| 3 | Backup export reads tables at different times; file state can repeat sharing | Export one transactional snapshot; clear stale file state; prevent sharing again on toast acknowledgement; remove recursive backup navigation | Repository and BLoC changes |
| 4 | Month selection applies recurring entries and creates empty budget months | Navigation uses read-only defaults; recurring application is explicit only; budget rows are created by writes | `test/navigation_refresh_test.dart` |
| 4 | Floating-point parsing; negative/zero transactions; invalid recurring values | Exact decimal parsing with signed-64-bit bounds; positive transaction/template amounts; nonnegative budgets/limits; repository and schema checks | `test/finance_regression_test.dart` |
| 4 | Transaction dates can silently change to fit a selected month | Reject a date/month mismatch before writing | Repository regression |
| 4 | Category filters with no members match everything; archived history omitted | Empty membership matches zero rows; category drill-down/filter membership includes archived subcategories; clear stale membership on reset | Filtering regression |
| 4 | Dashboard/report results stale after writes or older loads complete late | Refresh from committed Drift table notifications; remove same-month reports cache; guard load generations | Navigation/refresh tests |
| 4 | Budget surplus is labeled savings progress | Display income minus expenses as net income; preserve budget-minus-expenses remainder | Financial calculation regression |
| 4 | Forms pop before save success; repeated taps can duplicate writes | Await operation completion, disable Save while pending, retain form on failure; preference failures do not retry a successful financial write | `test/form_save_test.dart` |
| 4 | Quick-add prefill overwritten; editing archived rows can change classification | Explicit prefill has priority; editing resolves archived categories | Form selection regressions |
| 4 | Recurring category picker creates a subcategory; forms overflow | Correct add-category operation; scroll both forms | Form source and widget regressions |
| 5 | Analyzer findings and plugin declaration problems | Mounted-context checks, current share API, dependency placement; format changed Dart files only | `flutter analyze --no-pub` |

## Migration and rollback contract

The immutable `test/fixtures/schema_v2.sql` was captured from the original v2 Drift schema before changing table definitions. `test/support/v2_fixture.dart` creates synthetic databases containing all six tables. Tests copy each synthetic file to a `.pre-upgrade.sqlite` backup before attempting migration and compare the original rows afterward. Temporary databases and backups are removed by test teardown. No real application database is read, copied, upgraded, or repaired during this work.

Upgrade sequence:

1. Inspect existing rows before any table rebuild. Duplicate IDs are blocking even when row values are identical. Orphan references and references to the wrong category kind also block. Duplicate top-level category names and invalid values are not automatically renamed, merged, clamped, deleted, or reassigned.
2. Capture counts, monthly income/expense sums, budget values, category limits, and recurring amounts.
3. Rebuild the affected tables using Drift's migration API. Preserve every existing column value and identity.
4. Create the unique category-name index, validate references and values, and compare financial snapshots.
5. Commit the rebuilt schema and SQLite `user_version = 3` in the same transaction. Enable FK enforcement on opened connections.

Any exception rolls back the upgrade. Tests verify unchanged v2 rows and version for both preflight rejection and failure after table rebuilding begins. Downgrades are rejected.

Before deploying an upgrade to an existing installation, retain a verified pre-upgrade database snapshot while the application is closed, including any SQLite sidecars if present. This implementation does not automatically make a production database file backup. A failed upgrade leaves v2 intact. Rolling back a **successful** upgrade requires restoring the pre-upgrade snapshot with the previous application; merely reinstalling old code is not a safe downgrade. Writes made after upgrading would need an explicit reconciliation plan before restoring an older snapshot.

If a real installation contains ambiguous records, stop and obtain an owner-approved resolution. The migration deliberately cannot resolve those records automatically. This task did not inspect installations to determine whether such records exist.

## Backup compatibility

Backup envelope version 1 with database schema 2 or 3 is supported. All six table lists and all known row fields are required. Older/unknown versions, unknown row shapes, incomplete payloads, duplicate identities, invalid references and invalid values are rejected before destination mutation.

Merge adds missing records and skips exact matches. A same-ID/different-content record, or a conflicting natural key, stops the transaction. There is no last-writer-wins rule or silent record replacement. Overwrite remains an explicit user action and runs only after the entire backup passes validation. JSON backups remain unencrypted, as in the existing application.

## Toolchain and verification

Observed: Flutter 3.44.2, Dart 3.12.2, Xcode 26.6, CocoaPods 1.16.2. `flutter doctor -v` reports unknown Android SDK license status. No SDK licenses were accepted, and no device app was launched.

Commands executed:

- `flutter --version`, `dart --version`, `flutter doctor -v`
- `flutter pub get` (preserves application-package versions; the installed Flutter SDK requires five transitive lockfile updates)
- `dart run build_runner build` (Drift code regenerated, never manually edited)
- `dart format <changed non-generated Dart files>` (37 files; final formatting pass changed zero files)
- `dart fix --apply --code=curly_braces_in_flow_control_structures lib` (21 brace fixes, all in already-changed files)
- `flutter analyze --no-pub`
- Targeted migration, backup, finance, navigation/refresh, form and smoke tests
- `flutter test --no-pub`
- `flutter build macos --debug --no-pub`
- `FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter build macos --debug --no-pub`
- `git diff --check`

The first sandboxed Flutter/Dart attempts could not write SDK/analytics caches. Retrying with the required access succeeded. Automatic approval rejected a proposed bulk native-project restoration. That command did not run; targeted removal of Swift Package Manager additions preserved the CocoaPods configuration and its generated lockfile. No user-wide Flutter configuration was changed.

Final results:

| Check | Before | After |
| --- | --- | --- |
| Import/test entry points | Two invalid imports and obsolete `MyApp` counter test | Valid imports and application smoke test |
| Analyzer | 37 findings after the initial import/test fix | No issues; exit 0 |
| Automated tests | Only the starter counter test existed | 56 tests passed; exit 0 |
| Schema | Version 2 | Version 3 for valid fixtures; version 2 unchanged for rejected fixtures |
| Synthetic v2 transaction count | 2 | 2, including after reopening |
| Synthetic v2 income, minor units | 100000 | 100000 |
| Synthetic v2 expense, minor units | 20000 | 20000 |
| Synthetic v2 monthly budget, minor units | 90000 | 90000 |
| Synthetic v2 saving target, minor units | 10000 | 10000 |
| Synthetic v2 category limit, minor units | 50000 | 50000 |
| Complete fixture contents | Original six-table snapshot | Every row/column unchanged |
| `git diff --check` | — | Passed |
| macOS debug build | Not validated | Passed, including the final formatted source with CocoaPods |

The 56 tests comprise 18 migration/schema tests, 22 backup tests, 7 financial/repository tests, 2 navigation/refresh tests, 6 form tests, and 1 application smoke test. The generated artifact is `build/macos/Build/Products/Debug/smartbudget.app`; it was not launched.

Native dependency compilation reports upstream SQLite C warnings and an Xcode run-script warning; Drift generation warns that the pinned analyzer language version is older than the installed Dart SDK. No broad dependency upgrade was performed. CocoaPods-generated Xcode integration and `macos/Podfile.lock` are retained for the validated native build; Swift Package Manager references and its generated lockfiles were removed with targeted edits.

## Remaining risks and Phase 1 readiness

- Ready to begin identity/isolation design after review of these changes. **Not ready to invite five members as a secure shared application.** The current app still uses one local database path and has no user ownership boundary, authenticated identity, server authorization, or sync/conflict model.
- Existing databases with ambiguous/invalid legacy data intentionally require a separate, owner-approved repair. The UI does not provide an automated repair flow.
- Plaintext backup protection, release signing and physical-device acceptance testing remain required before beta distribution. Android/iOS builds and release builds were not validated by the macOS debug build.
- Recurring application still tracks template/month, without a transaction link. Deleting a generated transaction does not clear its applied marker. No scheduler or recurrence-model expansion was added.
- Forecasting remains the existing linear spending projection; net income is not a savings-goal contribution ledger.
- Large-history performance, web persistence, inline-picker refresh polish, and broader architecture cleanup remain outside this stabilization task.

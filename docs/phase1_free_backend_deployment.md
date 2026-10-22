# Free authorization backend deployment acceptance

Date: 2026-10-22 (Asia/Karachi). Branch `Budgeting-with-trasaction`.
Phase 0 checkpoint remains `9b7fef4`; no commit or push was performed.

## Result

The authorization backend is deployed. The physical TECNO CM6 showed
**Your session is authorized**, **Verified online**, and the temporary financial
workspace lock. This verifies the restored Firebase session, native debug App
Check, live backend membership, signed lease issuance, Flutter signature/binding
verification and protected session persistence during that run. A subsequent
cold-process restart of the corrected debug build also passed, returning to
authorized / verified online. Physical logout/relogin confirmation is still pending.

The user agreed to perform the physical logout/relogin check; its completion has
not been separately confirmed. The wireless TECNO disconnected from ADB during
the initial final inspection, then reconnected for the configuration correction
documented below. No restart was attempted while the user was entering
credentials. No budgeting dashboard or financial repositories were enabled.

## Resources created or configured

Only Firebase project `smartbudget-561d4`, number `463515242262`, was modified.
Cloud Billing reported `billingEnabled: false` before mutations and at final
readback. No Firebase billing-plan update or Cloud Functions deployment occurred.

| Resource | Result |
| --- | --- |
| Firestore `(default)` | Native mode, Standard edition, `asia-south1` Mumbai, `freeTier: true` |
| Database protection | Deletion protection enabled; PITR disabled; no TTL or managed backup configured |
| Firestore rules | Existing reviewed deny-all file deployed; source matches exactly on readback |
| Rules scope verification | No prior database, collections or default rules release existed; empty database confirmed before publishing |
| Metadata | Only `authorization`, `authorizationMembers`, `authorizationRateLimits`, `authorizationGrants` present |
| Beta roster | First existing enabled password account resolved through the administrator API and approved; readback 1 active, maximum 5 |
| Runtime service account | `smartbudget-authz@smartbudget-561d4.iam.gserviceaccount.com` |
| Runtime custom role | `projects/smartbudget-561d4/roles/smartbudgetAuthorizationRuntime`; sole project role for that service account on readback |
| Cloudflare account | Existing connected account `001fb786fa0e7bf85a8e9153e2837e5b`; OAuth credentials remain encrypted with a Keychain-protected key |
| Worker | `smartbudget-authorization`; no existing Worker was overwritten |
| Workers subdomain | Created `corehines-smartbudget.workers.dev` because none existed |
| Deployed version | `e7b8cd24-003e-4241-8a20-4ab930c5d597`, tag `beta-authz-20261022` |
| Secret bindings | `GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY`, `AUTH_LEASE_PRIVATE_KEY`; uploaded as encrypted secrets, not public vars |
| Lease signer | Independent Ed25519 key; public ID `beta-20261022-01`; TTL 86,400 seconds; policy 1 |
| App Check | API already enabled; one private development debug-token registration added for the exact Android app |
| Android app | Existing `com.corehines.smartbudget` updated with the new Worker origin and private debug definitions |

The six runtime permissions are `datastore.entities.get`,
`datastore.entities.create`, `datastore.entities.update`,
`datastore.databases.get`, `firebaseauth.users.get`, and
`firebaseappcheck.appCheckTokens.verify`. Existing IAM bindings were preserved
using the policy etag. No Owner, Editor, Firebase administrator or billing role was
granted to the runtime. Firestore IAM is broader than document-level rules; future
financial cloud data requires a separate privilege review.

The connected Cloudflare account was supplied as Free by the user. No subscription
mutation, payment-method change, plan upgrade or paid-resource creation was
requested. Independent billing
subscription lookup returned HTTP 403 with the deliberately narrow OAuth scopes;
Workers' `standard` usage-model metadata alone is not proof of billing status.
Consequently this report does not claim independently verified Cloudflare billing.
The account's billing dashboard remains the place to confirm its Free subscription.

Endpoints:

* `https://smartbudget-authorization.corehines-smartbudget.workers.dev/authorizeSession`
* `https://smartbudget-authorization.corehines-smartbudget.workers.dev/leaseVerificationKeys`

The Worker runs globally; Mumbai is the Firestore storage location. The Flutter
client calls the Worker directly, rather than an undeployed Firebase Functions
region. Authentication and App Check remain enforced on authorization requests.
Worker observability/invocation logging, Logpush and preview URLs are disabled;
remote readback returned no observability configuration and `logpush: false`.

## Verification executed

| Command or check | Actual result |
| --- | --- |
| Worker `npm run check` | Passed |
| Worker `npm test` | 28 passed, including real local workerd execution |
| Existing `npm --prefix functions test` | 40 passed |
| `flutter analyze --no-pub` | No issues |
| `flutter test --no-pub --reporter expanded` | 144 passed, one emulator-only test skipped |
| Android ARM64 debug APK build with private define file | Passed; installed successfully using `adb install --no-streaming -r -t` |
| `git diff --check` | Passed |
| Administrator provisioning CLI | Approved authoritative existing password account; transactional membership readback 1 of 5 |
| Public keys endpoint | HTTP 200; exact expected public JWKS; no private-key fields |
| Missing Firebase authentication | Deployed endpoint returned HTTP 401 `unauthenticated` |
| Runtime Firebase Auth permission | Real lookup of the expected enabled password account succeeded; credentials and account details withheld |
| Runtime Firestore permissions | Real production transactions accepted approved membership and denied an unapproved identifier |
| App Check issuance | Real debug-token exchange returned HTTP 200 |
| App Check consumption | Restricted runtime identity verified first use; second verification reported `alreadyConsumed: true` |
| Real unapproved Auth account | Disposable account successfully signed in by password; deployed Worker returned HTTP 403 `permission-denied`, no lease; test account removed |
| Missing/replayed App Check at deployed endpoint | Each returned HTTP 403 `app-check-failed`, no lease |
| TECNO session | Automatically restored and reached authorized / verified-online temporary screen |
| Corrected-build cold process restart | Passed; only the new app was force-stopped and started, then returned to authorized / verified online |
| Production grant readback | One unexpired grant; expiry within the maximum 24-hour window |
| Git-visible secret scan | 279 tracked/unignored paths checked; no exact production runtime key, lease private key or private debug token found |

No dependency versions changed in this deployment continuation. Node 22.23.3,
Wrangler 4.151.3, jose 6.2.13, TypeScript 5.9.3, Flutter 3.44.2 and Dart 3.12.2
were retained. The APK build emitted the existing future Kotlin Gradle Plugin
migration warning; it did not fail.

The full local Firestore-emulator interoperability and Postman outage tests from
the preceding implementation were not rerun here. Their earlier results and
limitations remain in the implementation report. Native Keystore acceptance was
also not rerun; its prior Stage 4 report remains separate.

The first disposable live-account probe used an invalid installation identifier
format and failed its expected-denial assertion; its test account was removed.
The probe was corrected to the required UUID4 format and rerun successfully,
including cleanup of its new disposable account. No application security check was
changed to accommodate the probe.

## Files changed in this deployment continuation

* `workers/authorization/wrangler.jsonc`: exact account ID, signing key ID and
  public-only JWKS; no private material.
* `tool/approve_beta_member.cjs`: operator-only bridge using the existing local
  Firebase CLI login in memory, explicit project confirmation, server-side account
  lookup and existing transactional five-member store. No operator credential is
  uploaded to the Worker. Requires the installed CLI library path and built backend.
* `docs/phase1_free_authorization_backend.md`: current-result link; prior report
  retained as a historical snapshot.
* This deployment report.

Deployment/inspection scripts used in the shell temporary directory contain no
embedded credentials. Private recovery files are outside Git under
`/Users/waleed/SmartBudgetPrivate/authorization-20261022`, with restrictive directory
and file permissions. The previous **new-app** APK was retained there for rollback.
Private key contents, Firebase ID/access/refresh tokens, passwords, debug secrets
and raw account records were not printed. Development subprocesses used the
credential-stripping launcher. No unrelated credentials were modified or deleted.

## Running the configured development app

Plain `flutter run` does not supply the deployment definition or private debug
attestation. On this Mac, use the configured launcher, which validates the private file and
strips inherited service credentials before starting Flutter:

```sh
python3 tool/run_debug.py
```

Choose the TECNO if Flutter asks for a device. Keep this debug APK private: its
compiled development attestation secret is intentionally accessible to trusted
testers. Profile/release builds select Play Integrity regardless of a debug-token
definition. Real release Play Integrity acceptance, Play app-signing fingerprints
and production signing remain unverified; no release-readiness claim is made.

### Corrected an unconfigured development launch

A later TECNO screenshot showed the configuration-specific session lock. The
installed APK matched the current local debug APK byte-for-byte, and its Dart
kernel did not contain the deployed Worker origin. Android Studio's local
`main.dart` run configuration had no additional build arguments. This confirms
that the device was running a build without the required deployment definitions;
the browser root-path 404 was a separate, expected API routing behavior.

The ignored `.idea/workspace.xml` was changed only to add the private definition
file to `main.dart`'s `additionalArgs`. The new tracked `tool/run_debug.py` provides
a terminal equivalent. It validates that the definition file is outside Git,
owner-only, owned by the current user, selects the approved Worker origin and
contains a valid private debug-token definition. It starts a debug build through
an allowlisted environment and redacts the debug token from output. It never
generates or replaces credentials. No Flutter security checks, database code,
financial schema or backend configuration changed for this correction.

Verification: definition-file and IDE XML validation passed; Python syntax check
passed using a writable temporary bytecode cache after the default macOS cache
write was sandbox-blocked; `flutter analyze --no-pub` found no issues; 22 existing
authentication UI/transport/Firebase-configuration tests passed. Running the new
launcher completed dependency resolution, Android build, installation and launch.
The rebuilt APK contained the approved origin and registered debug configuration
(values withheld), and the TECNO again showed **Your session is authorized /
Verified online**. The debugger was detached with `d`, leaving the app running.
Both the old app database byte-hash and the approved legacy snapshot SHA-256 still
matched. The existing native secure-storage compatibility warning appeared during
startup, but the session authorized successfully; no storage reset or repair was
attempted. After detaching, only `com.corehines.smartbudget` was force-stopped and
started again. The fresh process restored the session and again showed authorized
/ verified online. This verifies the corrected build across a cold process restart.

## Data preservation, recovery and remaining checks

The old `com.example.smartbudget` app stayed installed and was never started,
stopped, cleared, uninstalled or replaced. Its database was only byte-hashed,
returning the previously approved checksum immediately before installation. The
final phone checksum recheck could not run after ADB disconnected. No legacy
database was opened with
SQLite, repaired, imported, encrypted or assigned to a Firebase user.
The 53,248-byte legacy snapshot still matched its approved SHA-256 both before
deployment and in the final host-side verification.

Rollback retains all databases and keys. Reinstall the retained previous new-app
APK with `-r`, or disable/roll back only this Worker; neither requires touching the
legacy app. Revoke membership to stop future online grants. Do not delete the
Firestore database, replace missing keys, or remove old public verification keys
as an automatic recovery action. During planned signer rotation retain old public
keys for at least the 24-hour lease lifetime plus distribution margin. Offline
revocation remains delayed until lease expiry; device-clock tampering remains a
documented limitation.

Pending: user completion/observation of physical logout/relogin,
release attestation/signing, independent Cloudflare subscription readback and
free-tier capacity monitoring. The existing test-only gRPC advisory remains
unresolved. This task does not approve Stage 5, legacy migration, financial cloud
synchronization or budgeting-dashboard activation.

References: [Firestore database creation](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases/create),
[App Check debug registration](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps.debugTokens/create),
[runtime App Check permission](https://docs.cloud.google.com/iam/docs/roles-permissions/firebaseappcheck),
[Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/).

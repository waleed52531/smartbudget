# Free authorization backend: implementation and deployment handoff

Date: 2026-10-22 (Asia/Karachi). Branch: `Budgeting-with-trasaction`.

## Current result

Deployment has since completed after Cloudflare connection and explicit Mumbai
approval. The TECNO showed **Your session is authorized / Verified online**.
See [deployment acceptance](phase1_free_backend_deployment.md) for current
resources, actual test results, remaining checks and rollback instructions.
The following pre-deployment snapshot is retained as implementation history.

## Pre-deployment snapshot

The Firebase Spark / Cloudflare Workers Free alternative is implemented locally.
**It has not been deployed, no production lease has been issued, and the TECNO
authorization screen is not yet expected to unlock.** Cloudflare's browser login
timed out. Creating the first Firestore database is pending approval of its
permanent location; `asia-south1` (Mumbai) is proposed. These are the deployment
blockers. Existing deployment approval remains valid for the authorized scope.

The only production mutation in this work was enabling
`firestore.googleapis.com` in the verified project. No database, rules release,
member, service account, IAM grant, signing key, secret or Worker was created.
Billing was verified disabled before that mutation; no billing update was attempted.
No Android installation, financial database SQLite access, legacy import, dashboard
activation, Stage 5 work, Git commit or push was performed.

## Verified Firebase prerequisites

Authenticated Firebase CLI access was used in memory, with CLI logging disabled.
Credentials and raw Auth records were not printed or exported. Checks targeted
only project `smartbudget-561d4`, number `463515242262`.

| Check | Observed result |
| --- | --- |
| Firebase project identity/state | Correct ID/number; ACTIVE |
| Cloud Billing `billingEnabled` | false |
| Auth Email/Password | Enabled; password required |
| App Check API | Already ENABLED when this work began |
| Android Play Integrity configuration | Resource exists; token TTL 3600s; live attestation not tested |
| Firestore API | Initially DISABLED; explicitly enabled successfully |
| Firestore databases after API enablement | Empty list |
| Default Firestore rules release | NOT_FOUND before database creation |
| Existing account from the screenshot | Authoritative Admin lookup found one enabled password account; revocation timestamp present; UID/records not printed; not approved yet |
| Administrator capabilities | API enable, service-account/key creation, project IAM updates, database get, Auth configuration/user get and user update were present |
| Existing Cloud Functions | CLI listing failed generically; final API check confirmed Cloud Functions API DISABLED; no functions modified or deployed |
| Cloudflare account | `wrangler whoami`: not authenticated; browser OAuth attempt timed out |

The final Cloud Billing check still returned false. Firebase reported no existing
default resource location. The verified legacy snapshot remains 53,248 bytes and
its byte-read SHA-256 still matches the approved checksum; it was not opened with
SQLite or modified. HEAD remains Phase 0 checkpoint `9b7fef4`.

The first preflight IAM test contained an unsupported permission and returned 400;
the narrowed supported permission test succeeded. Production Firestore listing
initially returned 403 because its API was disabled; listing succeeded after the
approved API enablement. Neither result was interpreted as proof of authorization.

## Implementation

`workers/authorization/src/index.ts` exports only two HTTP paths:

* `POST /authorizeSession` accepts exactly `{installationId}` and requires both
  `Authorization: Bearer <Firebase-ID-token>` and `X-Firebase-AppCheck`.
* `GET /leaseVerificationKeys` returns public-only Ed25519 JWKS.

The existing Stage 2 authorization orchestration, five-member policy, validation,
Ed25519 signer and JWS claim format are reused from `functions/src/`. The Cloud
Functions implementation remains available for isolated emulator regression
testing, but no Cloud Function deployment is part of this free path.

Worker adapters use Google's HTTPS REST APIs with fixed project/service origins:

* `identity.ts` verifies RS256 Firebase ID tokens against Google's trusted keys,
  checks issuer, audience, UID, time and password provider, then queries Firebase
  Auth for disabled state and `validSince` revocation. Request UIDs are not trusted.
* App Check signatures, issuer/project/audience and Android app ID are verified;
  Google's `verifyAppCheckToken` consumes the token and replays are rejected. There
  is no deployed emulator, mock-authorization or attestation bypass.
* `firebase_rest.ts` obtains short-lived OAuth access tokens from the dedicated
  service-account key and retains them only in Worker memory. Requests have
  timeouts and body limits; redirects are explicitly refused. Workers does not
  support Fetch's `redirect: error`, so `manual` plus a status check is required.
* `firestore.ts` reads membership and writes rate limits/grants through REST
  transactions with bounded conflict retries. It rechecks membership in the grant
  transaction. The adapter rejects paths outside the four authorization metadata
  collections. Its `batchGet` protocol was exercised against the official emulator;
  that emulator's transaction query-string parser fails on byte-string parameters,
  so transaction bytes are sent in documented JSON request bodies.

Firestore rules remain deny-all for direct clients. No financial collections are
added. IAM bypasses Firestore rules, so the Worker runtime identity must have a
reviewed custom role, never Owner, Editor, Auth Admin or administrator credentials.

Flutter sends direct HTTPS requests to the compiled Worker origin. It refuses
redirects, limits response sizes, discards responses after account switching, and
retains the existing signed-lease verifier, protected vault and 24-hour limit.
`SMARTBUDGET_AUTH_ORIGIN` accepts only
`https://smartbudget-authorization.<account-subdomain>.workers.dev` without
credentials, custom port, query or fragment. No runtime user-provided origin or
plaintext fallback is accepted. An absent origin produces a specific configuration
lock instead of contacting the old undeployed Cloud Functions endpoint.

Configuration errors, App Check failures, network failures and explicit account
denials now have separate locked-screen messages. Previously verified same-user
leases may still restore during genuine network/service outages. Explicit denial,
invalid signatures and malformed success responses never reuse an older grant.

The temporary authorized-session screen remains in place; no financial navigation
was enabled. Existing encrypted per-user storage, data schema and migration code
were not changed.

## Secrets and App Check

The free backend uses **Cloudflare Worker encrypted secret bindings**, rather than
Google Secret Manager, for:

* `GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY`: dedicated, restricted runtime RSA key;
* `AUTH_LEASE_PRIVATE_KEY`: independent Ed25519 lease-signing private key.

The project, account email, app ID, policy, TTL, key ID and public JWKS are nonsecret
configuration. Never place a Google administrator credential, private key, access
token, refresh token or App Check debug secret in public vars or Flutter source.
Do not upload Firebase CLI user credentials to Cloudflare. No production key has
been generated yet. Use protected, exclusive key files outside Git for recovery
and secret uploads; do not expose secrets as shell arguments or terminal output.

The required runtime role is limited to `datastore.entities.get/create/update`,
`datastore.databases.get`, `firebaseauth.users.get`, and
`firebaseappcheck.appCheckTokens.verify`. Review exact permissions and existing
policy before granting them. The administrator/provisioning identity remains
separate. Runtime Firestore IAM is not document-level authorization; the application
path checks are additional protections, and future financial backend privileges
need a separate review. Provisioning or changing IAM remains pending live setup.

For debug Android builds only, a separately provided
`SMARTBUDGET_APP_CHECK_DEBUG_TOKEN` activates `AndroidDebugProvider`. It must be
registered privately for the exact Firebase Android app. Without this input, or
in profile/release, Play Integrity is selected. A compiled debug APK therefore
contains its development attestation secret and must stay restricted to trusted
testers. Do not pass this secret in a public command or commit a build-definition
file; use an outside-repository file with mode 0600 and `--dart-define-from-file`.
The provider is supplied the token explicitly to avoid automatic SDK secret
generation/logging. Actual debug-token registration and physical-device attestation
are pending; no native success is claimed for them.

Worker observability, invocation logs, preview URLs and Logpush are disabled in
configuration. Source contains no request/credential/record logging. Providers may
still process transport metadata; disabling application logs is not a claim that
Cloudflare or Google retains no infrastructure metadata.

## Deployment sequence after the blockers are resolved

1. Connect the intended Cloudflare **Free** account using official Wrangler OAuth.
   Prefer `--use-keyring` and only account/user read, Workers write/scripts write
   and refresh scopes. Do not use an anonymous temporary preview account for real
   authorization. Verify the selected Cloudflare account ID and its free Workers
   subscription before publishing. Never upgrade either provider automatically.
   From the repository root, the scoped login can be run as:

   ```sh
   python3 tool/clean_run.py workers/authorization/node_modules/.bin/wrangler login --use-keyring --scopes account:read user:read workers:write workers_scripts:write
   ```

   Complete the browser flow locally; never paste the resulting credentials in
   chat. The earlier attempt timed out and its old browser URL cannot be reused.
   Wrangler adds its refresh scope itself; `offline_access` is not an accepted
   explicit `--scopes` argument in 4.151.3.
2. Approve the first default Firestore database's location. Proposed: Native-mode
   Standard edition `(default)` in `asia-south1` (Mumbai), on Spark, with no PITR,
   managed backups or TTL deletion. Confirm other project location dependencies
   before creation; no database or rules currently exists. Location is permanent.
3. Deploy the existing deny-all rules to this confirmed new database only. Create
   and review the dedicated runtime service account and the narrow role above.
   Grant no unrelated project roles; stop if organization policy blocks safe key
   provisioning. Do not create a broad service-account JSON credential for reuse.
4. Generate the independent lease signer using the existing secure keygen CLI,
   choose a key ID, retain an outside-repository rollback copy, and configure public
   JWKS. Upload the two private values only as Worker secrets through private stdin
   or protected files. Do not print or commit them. Missing keys fail closed; never
   regenerate a missing key as automatic recovery.
5. Provision the first verified Auth UID through the existing administrator CLI,
   using a trusted workstation identity and explicit project confirmation. No user
   should be approved from a client-supplied UID. The transactional roster caps
   active membership at five. The runtime has no approval HTTP endpoint.
6. Check for an existing Worker with this name and stop if it belongs to unrelated
   work; preserve any existing versions before updating it. Publish only Worker
   `smartbudget-authorization`, using `workers.dev` HTTPS and
   the reviewed public config/secrets. Validate public keys, unauthenticated and
   unapproved rejection, replay rejection, approved issuance and revocation.
7. Register a private Android development App Check token, build with the verified
   Worker origin and private build-definition file, and update only
   `com.corehines.smartbudget`. Verify login, authorization, restart/logout/account
   switching and rejection on the TECNO. Keep `com.example.smartbudget` untouched.

Rollback: revert the new app to the prior APK if necessary; retain all databases
and keys. Revoke beta membership to stop new online leases, or remove/roll back the
Worker deployment without changing billing or unrelated resources. Retain old
public verification keys for at least the maximum 24-hour lease duration plus
distribution margin during planned rotations. Offline revocation cannot be
immediate. A new database's location cannot be changed in place. No automatic
database deletion or key replacement is an authorized rollback procedure.

## Commands and actual verification

Node 22.23.3; Worker dependencies resolved normally, in a separate package:
`jose 6.2.13`, `wrangler 4.151.3`, `tsx 4.23.15`, TypeScript 5.9.3.
Wrangler resolves Miniflare `5.20261019.1-beta` / workerd `1.20261019.1` for local
runtime tests; this is Wrangler's own locked dependency, not an override or patch.
Compatibility date is pinned to supported `2026-10-19`. Flutter 3.44.2 / Dart 3.12.2
and all Flutter dependency versions were preserved.

| Check | Actual result |
| --- | --- |
| `flutter pub get` | Passed |
| `flutter analyze --no-pub` | No issues |
| `flutter test --no-pub --reporter expanded` | 144 passed; one emulator-only test skipped |
| `flutter build apk --debug --no-pub --target-platform android-arm64` | Passed; APK not installed |
| Existing `npm --prefix functions test` | 40 passed |
| Worker `npm run check` | Passed after final cleanup |
| Worker `npm run build` | Dry-run bundle passed; no deployment |
| Worker `npm test` | 28 passed, including native workerd issuance/replay and explicit upstream redirect rejection |
| `tool/run_worker_firestore_tests.py` with Node 22 / Java 21 | Passed against disposable official Firestore emulator; 5-of-6 approvals, signed-grant metadata, rate limit, revocation and corrupt-roster preservation |
| Postman local key-outage simulation + `test/postman_outage.integration.ts` | Passed; simulation log confirmed a real GET to the keys stand-in and HTTP 503; no grant issued |
| `python3 tool/clean_run_test.py` | 3 passed |
| Worker `npm audit --omit=dev --json` | 0 runtime vulnerabilities reported |
| Postman `spec lint` | Blocked: local Keychain `SecItemCopyMatching` error -50, exit 245; no credentials were changed to work around it |
| `git diff --check` | Passed |
| Production Worker / TECNO online authorization | Not run: account login and permanent database location pending |

The HTTP tests use fresh synthetic RSA/Ed25519 keys and loopback stand-ins; they
are not proof of production IAM, Firebase attestation or Cloudflare free CPU usage.
The Firestore test uses the real local database emulator and no production token.
The Postman skill's Orbit catalog was unavailable, so official Google/Cloudflare
references were used. No Postman cloud workspace/mock was created or published.
The API contract is `workers/authorization/openapi.yaml`.

The temporary native-crypto diagnostic used during development was removed from
the final tests; the passing native test runs the normal bundled Worker. The
Postman simulation is local-only and is stopped after validation.

Remaining operational risks: free-tier request/CPU/storage limits must be checked
after real account connection; outages/exhaustion must fail closed. Account and
service-account compromise remain trust-root risks. The previously documented
test-only gRPC advisory, Android release-signing preparation and Apple runtime
configuration remain unresolved. No claim of production readiness or a successful
TECNO login is made.

## Files changed in this work

* `.gitignore`: Worker dependency/output/local-secret ignores and Postman artifacts.
* `lib/features/auth/data/session_environment.dart`
* `lib/features/auth/data/firebase_session_services.dart`
* `lib/features/auth/data/worker_authorization_transport.dart` (new)
* `lib/features/auth/domain/session_contracts.dart`
* `lib/features/auth/presentation/session_cubit.dart`
* `test/auth/lease_verifier_test.dart`
* `test/auth/worker_authorization_test.dart` (new)
* `workers/authorization/package.json`, `package-lock.json`, `tsconfig.json`,
  `wrangler.jsonc`, `openapi.yaml` (new)
* `workers/authorization/src/firebase_rest.ts`, `identity.ts`, `firestore.ts`,
  `index.ts` (new)
* `workers/authorization/test/support.ts`, `authorization.test.ts`,
  `native_runtime.test.ts`, `firestore_emulator.integration.ts`,
  `postman_outage.integration.ts` (new)
* `tool/run_worker_firestore_tests.py` (new)
* `postman/mocks/firebase-keys-outage.js` and
  `postman/simulations/authorization-key-outage.sim.yaml` (new)
* This report (new).

Existing uncommitted Phase 0–4 files were preserved. No generated Drift file,
financial schema, repository or legacy backup was edited in this work.

References: [Firebase plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans),
[Firestore free quota](https://firebase.google.com/docs/firestore/quotas),
[Firestore locations](https://firebase.google.com/docs/firestore/locations),
[App Check consume API](https://firebase.google.com/docs/reference/appcheck/rest/v1beta/projects/verifyAppCheckToken),
[Workers limits](https://developers.cloudflare.com/workers/platform/limits/),
[Workers crypto](https://developers.cloudflare.com/workers/runtime-apis/web-crypto/),
[Wrangler account login](https://developers.cloudflare.com/workers/wrangler/commands/general/).

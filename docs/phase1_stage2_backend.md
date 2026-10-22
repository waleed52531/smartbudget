# Phase 1 Stage 2 — backend authorization

Scope: local backend implementation only. Nothing has been deployed, no billing or
production configuration has been changed, and no users or production signing keys
have been created. The Flutter financial application and database lifecycle are
unchanged. This stage alone does **not** gate the existing application's local UI.

## Structure and trust boundaries

`functions/src/index.ts` exports only `authorizeSession` (callable) and
`leaseVerificationKeys` (public GET). TypeScript runs on Node 22. Authentication,
membership, rate limiting, leases, configuration validation and the local
administrator CLI have separate modules. `firebase.json` retains Stage 1's
FlutterFire configuration and adds the authorization codebase and deny-all rules.

The callable accepts exactly `{installationId: "<lowercase UUID v4>"}`. It derives
UID from the authenticated callable context and independently calls Admin SDK
`verifyIdToken(token, true)` and `getUser(uid)`, checking project, matching UID,
email/password provider and disabled state. A body UID or extra field is rejected.
Failures return generic authentication, permission, argument, rate-limit or
availability errors. Application code never logs requests, tokens or raw exceptions.

Firestore stores authorization metadata only:

| Path | Purpose |
| --- | --- |
| `authorization/betaRoster` | Versioned list of at most five active UIDs |
| `authorizationMembers/<sha256(uid)>` | Active/revoked state and administrative timestamp |
| `authorizationGrants/<sha256(uid + ":" + installationId)>` | Last grant nonce, installation, UID and expiration |
| `authorizationRateLimits/u_<sha256(uid)>`, `.../global` | Atomic minute-window counters and cleanup timestamp |

Hashes are document identifiers, not anonymization. Every direct client read,
query and write is denied, including requests with an `admin` or `beta` custom
claim. Admin SDK bypasses rules and therefore requires restricted IAM. No financial
records are stored in Firestore. The single roster transaction prevents concurrent
provisioning from admitting a sixth member. Inconsistent membership fails closed;
the CLI does not silently reconstruct or repair it.

Email/password's direct signup API can still create an unapproved Auth identity.
Removing a registration screen does not disable that API. Such an identity cannot
obtain a lease or access any Firestore data. Identity Platform blocking functions
are not required for this authorization model. Registration UI remains a later
stage; signup-abuse quotas and monitoring still require operational attention.

## Lease contract

Compact JWS: `base64url(header).base64url(payload).base64url(signature)`, without
padding. Sign the ASCII first two parts joined with `.` using Ed25519 (JWS
`EdDSA`, 64-byte signature). Issuance uses UTF-8 `JSON.stringify` with these
insertion orders and no whitespace:

* Header: `alg`, `typ`, `kid`; values `EdDSA`, `sb-auth-lease+jwt`, configured key ID.
* Payload: `iss`, `aud`, `project_id`, `sub`, `installation_id`, `iat`, `exp`,
  `policy_version`, `jti`.

`iss` is `smartbudget:<project>:authorization`; audience/project are the Firebase
project ID, subject is verified Firebase UID, timestamps are integer Unix seconds,
and `jti` is a random UUID. `kid` is in the signed protected header. For fixed
claims and key, signing produces identical bytes. Verification checks the exact
header/claim set, signature, project, authenticated UID, installation, policy,
`iat <= now < exp`, and duration at most 86,400 seconds. No clock-skew grace extends
expiry. A signed token is not encrypted; store and transport it as sensitive data.

Default TTL is 86,400 seconds; configuration permits 300–86,400 seconds and rejects
other values. Clients cannot choose TTL or signing keys. A final membership check
and grant write run in one transaction after signing; revocation committed before
that transaction prevents issuance. A grant committed before revocation may still
be returned by an in-flight request.

Production signing material is a bound Secret Manager secret,
`AUTH_LEASE_PRIVATE_KEY`. Only the signing function receives it. The public endpoint
returns a restricted public JWKS with `kty`, `crv`, `x`, `kid`, `alg`, `use` only;
private JWK fields and duplicate key IDs are rejected. The configured private key
must match its published public key. Public key sets support up to five overlapping
keys. Clients must trust the configured HTTPS origin or provisioned public keys,
never a public key supplied beside an untrusted lease.

Rotation procedure, after separate operational approval: generate a new key ID,
publish both public keys, allow clients to receive the new key, switch the signing
secret/key ID together, retain the old verification key for at least the maximum
lease lifetime plus distribution/cache margin, then retire it. Public responses
cache for five minutes. Retain recoverable old secret versions under restricted
administrative control; do not overwrite key material or regenerate missing keys
silently. Emergency key removal cannot immediately reach an offline installation.

## Offline and device limitations

A revoked member cannot renew online. A previously issued offline lease remains
cryptographically valid until expiry, at most 24 hours; immediate offline
revocation is impossible. Disabled-account and token-revocation checks apply on
each online issuance. A future client should invalidate its cached grant after an
explicit authorization denial; an outage is `unavailable`, not proof of revocation.

Later client stages must require an initial online authorization, bind verification
to the **current Firebase UID** and protected installation UUID, and reject expiry
before opening that user's encrypted database. Installation UUID is self-asserted
by an authenticated caller; it is not hardware attestation or proof that the
device cannot be cloned. App Check is an additional signal, not user authorization.
Lease/installation storage and per-user database keys must use platform protection.
This stage does not implement that client storage or claim hardware key binding.

Offline wall-clock rollback can extend apparent validity. Later client work must
record last trusted server time and use monotonic elapsed time where available,
reject backward movement/uncertain reboot state as appropriate, and require online
verification when time cannot be trusted. A compromised OS can defeat purely local
checks. An expired lease never permits a different UID's data to be opened.

## Abuse protection

Production requires valid App Check from the registered Stage 1 Android Firebase
app and consumes limited-use App Check tokens, rejecting already-consumed tokens.
Emulator-only code disables this requirement in the fixed `demo-smartbudget-authz`
project with loopback Auth/Firestore endpoints. No emulator signing key or bypass
is used in production. Functions limits: two signing instances, concurrency 20,
15-second timeout, 256 MiB, minimum zero instances. Public keys use one instance,
concurrency 20 and a five-second timeout.

Firestore counters allow ten issuance attempts per UID per minute and 100 globally
per minute, shared across instances. Malformed/invalid-auth requests are rejected
before these counters; they still consume HTTP/verification resources. Fixed
windows can allow bursts around boundaries, and global limits can cause denial of
service to legitimate members. Rate limits and max instances are not spending caps.
Set budget alerts, service quotas and abuse monitoring before deployment. TTL on
`expiresAt` for grants/rate counters is optional cleanup, not an authorization check;
configure it explicitly later if desired. Membership records have no TTL.

## Administrator workflow (documentation only; not executed in production)

Use an administrator workstation with restricted Application Default Credentials
or service-account impersonation. Never copy a service-account JSON key into the
repository or use a Firebase client ID token as administrator credentials. Commands
must specify `--project smartbudget-561d4 --confirm-project smartbudget-561d4`.
The CLI rejects accidental demo/production target mixing. No administrator function
is exported over HTTP.

1. After approval, enable Email/Password in Firebase Authentication. Create each
   invited account in Firebase Console's **Authentication → Users → Add user**,
   using unique passwords delivered through a separate secure process. Do not put
   passwords in shell arguments, logs or Git. The callable never creates accounts.
2. Build using Node 22: `npm --prefix functions ci`, then
   `npm --prefix functions run build`.
3. Identify an existing UID:
   `npm --prefix functions run admin -- find-user --project smartbudget-561d4 --confirm-project smartbudget-561d4 --email <invited-email>`.
4. Approve:
   `npm --prefix functions run admin -- approve --project smartbudget-561d4 --confirm-project smartbudget-561d4 --uid <verified-uid>`.
   Approval checks that the account exists, is enabled and has a password provider;
   repeats are idempotent and a sixth active member is rejected.
5. Check:
   `npm --prefix functions run admin -- status --project smartbudget-561d4 --confirm-project smartbudget-561d4`.
   UID output is administrative metadata; do not commit or broadly share it.
6. Revoke:
   `npm --prefix functions run admin -- revoke --project smartbudget-561d4 --confirm-project smartbudget-561d4 --uid <verified-uid>`.
   This denies roster membership **first**, then revokes Auth refresh tokens. If
   Auth revocation fails, membership remains denied; check status and retry.

For a signing key, choose an existing secure directory outside this repository:

```sh
npm --prefix functions run admin -- keygen --kid <new-key-id> --private-output /secure/outside-repository/lease-private.pem --public-output /secure/outside-repository/lease-public.json
```

Files are created exclusively with mode 0600; existing files are never replaced.
The private output must be outside the repository. Protect the directory and avoid
symlinked output paths. Keygen prints no private material. The public file supplies
`AUTH_PUBLIC_KEY_SET_JSON`. Only after separate approval, upload the private PEM
to Secret Manager using a file argument rather than a literal secret:

```sh
firebase functions:secrets:set AUTH_LEASE_PRIVATE_KEY --project smartbudget-561d4 --data-file /secure/outside-repository/lease-private.pem
```

The command above changes production and has **not** been run. No real signing key
was generated during this stage; automated tests generate only ephemeral keys.

## Production prerequisites requiring a later approval

* Confirm Blaze billing and budgets. Functions/Cloud Run, build artifacts, Secret
  Manager, Firestore and network usage may incur costs. No billing action was taken.
* Create/review the authorization Firestore database and location. `asia-south1` is
  the proposed Functions region, configurable before deployment; review data
  residency and co-location with the actual database first. Rules here target the
  default database. Named-database use would require an explicit code/config change.
* Review existing production rules/resources before deploying the deny-all file;
  replacing rules affects every collection in that database. Deploy rules before
  making the backend usable. No production rules were inspected or changed here.
* Create a dedicated runtime service account and set `AUTH_SERVICE_ACCOUNT`.
  Grant only Firestore entity get/create/update plus `datastore.databases.get`
  for transactions on the authorization database,
  Auth user-read permission for token revocation/disabled checks, access to the
  one signing secret, and Firebase App Check Token Verifier for replay protection.
  Validate exact custom-role permissions in a separately approved staging rollout.
  Do not grant runtime Owner, Editor or Firebase Authentication Admin. IAM grants
  are not per-document rules; isolate future financial backend privileges separately.
* Use a separate provisioning identity for roster writes and Auth user reads/
  refresh-token revocation. Restrict who can impersonate either identity and who
  can deploy code, edit metadata, rotate secrets or modify IAM; those are trust roots.
* Register Android App Check/Play Integrity, review signing SHA-256 fingerprints and
  the exact Firebase Android App ID, and provide the future client with limited-use
  App Check tokens. Replay protection requires the verifier IAM role and adds a
  backend round trip. No Flutter App Check integration is included in this stage.
* Configure nonsecret parameters from `functions/.env.example` in ignored
  `functions/.env.smartbudget-561d4`. Keep private signing material in Secret Manager.
  Missing service account/key configuration must block deployment or issuance.
* Enable required deployment APIs and grant deployer/service-agent permissions
  deliberately. Any future command to deploy rules/functions needs explicit user
  approval. Do not run a broad `firebase deploy` against unrelated resources.
* Run live staging checks for IAM, real JWT revocation, App Check enforcement,
  secret binding, key distribution and concurrency before production acceptance.
  Emulator tests cannot establish any deployed security configuration.

## Local verification

With Node 22, Firebase CLI and Java 21 on PATH:

```sh
npm --prefix functions ci
npm --prefix functions test
npm --prefix functions run test:emulator
flutter analyze
flutter test
git diff --check
```

The emulator runner uses only a demo project and loopback endpoints, generates
ephemeral test keys, isolates the Firebase CLI configuration, does not inherit
credentials/API keys/verbose logging, and never exports emulator data. It removes
its temporary configuration directory and CLI-generated `.env.local` after exit.
It refuses existing operator dotenv/secret files rather than loading or overwriting
them; use a clean worktree for tests if production configuration is present.
Logs/dependencies/build output,
actual dotenv files and PEM/key files are ignored by Git. Test identities and
passwords are synthetic. See `phase1_stage2_status.md` for actual results and files.

Official references: [supported runtimes](https://firebase.google.com/docs/functions/manage-functions),
[Admin token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens),
[session revocation](https://firebase.google.com/docs/auth/admin/manage-sessions),
[App Check enforcement/replay protection](https://firebase.google.com/docs/app-check/cloud-functions),
[managed secrets and parameters](https://firebase.google.com/docs/functions/config-env),
[demo emulator projects](https://firebase.google.com/docs/emulator-suite/connect_and_prototype).

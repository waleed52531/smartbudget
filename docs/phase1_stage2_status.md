# Phase 1 Stage 2 — implementation and validation

Date: 2026-10-21. Branch: `Budgeting-with-trasaction`. Phase 0 checkpoint
`9b7fef4` is intact. Existing uncommitted Stage 1 changes were preserved.

## Result and scope

Backend authorization is implemented locally for review: an atomic five-member
allowlist, revoked/disabled-token checks, strict installation identifiers,
Ed25519 offline leases, public verification keys, administrator-only local
provisioning, App Check enforcement and shared rate limits. Direct Firestore
client access is denied. See [the architecture and operational guide](phase1_stage2_backend.md).

No Cloud Functions/rules were deployed; no billing, production IAM, Auth users,
App Check registrations, signing secrets or production Firebase settings changed.
No login UI, user database lifecycle, financial synchronization, legacy migration,
payment or banking features were added. The application still needs later client
authorization and database-isolation work before private-beta security is complete.

No phone installation was launched, replaced or uninstalled during this stage.
No financial database was opened or modified. The verified legacy snapshot was
read as bytes only and its SHA-256 matched the existing verification metadata.
No production backup path, record contents, signing key or real user identity is
included in the new backend source. No commits were created during this stage.

## Changed files in this stage

Existing files extended:

* `.gitignore` — backend build/dependency, local configuration, key and log exclusions.
* `firebase.json` — authorization codebase, Node 22, build hook, deployment exclusions
  and rules reference; existing FlutterFire configuration retained.

New root configuration:

* `firebase.emulators.json` — loopback Auth, Firestore and Functions demo testing.
* `firestore.rules` — deny all direct client access.

New backend files:

* `functions/package.json` — scripts, Node 22 engine and dependencies.
* `functions/package-lock.json` — exact resolved dependency graph.
* `functions/tsconfig.json` — strict TypeScript compilation.
* `functions/.env.example` — nonsecret configuration template.
* `functions/src/index.ts` — callable and public-key endpoint; production security settings.
* `functions/src/security.ts` — limits, UID/installation/policy/environment validation.
* `functions/src/authentication.ts` — verified identity, revocation and disabled checks.
* `functions/src/membership.ts` — transactional membership and final grant recheck.
* `functions/src/authorization.ts` — authorization orchestration.
* `functions/src/leases.ts` — deterministic JWS signing, public keys and verification.
* `functions/src/rate_limit.ts` — per-UID and global atomic limits.
* `functions/src/admin_cli.ts` — explicit-target approval/revocation/status/lookup/keygen.
* `functions/tools/run-emulators.mjs` — isolated, temporary demo environment and keys.
* `functions/test/unit.test.ts` — isolated service/crypto/configuration/CLI tests.
* `functions/test/emulator.test.ts` — real local Auth, Firestore/rules and callable tests.

New documentation:

* `docs/phase1_stage2_backend.md` — protocol, trust boundaries, provisioning,
  rotation, IAM, Console/billing prerequisites, offline behavior and limitations.
* `docs/phase1_stage2_status.md` — this report.

The other files shown by `git status` are the pre-existing Stage 1 work. No Flutter
source, dependency, schema, generated Drift or native project file changed in Stage 2.

## Toolchain and resolved direct packages

Node 22.23.3 was installed in a disposable directory under `/private/tmp` for this
stage; the machine's global Node 26 installation was not changed. Firebase CLI
15.29.0 and Java 21.0.8 ran the emulators. Flutter/Dart remain 3.44.2/3.12.2.

| Package | Exact installed version | Use |
| --- | --- | --- |
| `firebase-admin` | 14.5.0 | Runtime |
| `firebase-functions` | 7.4.0 | Runtime |
| `@firebase/rules-unit-testing` | 5.0.0 | Tests |
| `firebase` | 12.19.0 | Tests only |
| `typescript` | 5.9.3 | Build |
| `@types/node` | 22.20.5 | Build |

No overrides, SDK upgrades or dependency-check bypasses were used. The newest
Firebase 13/rules-test 6 packages require a newer Node major, so compatible
Firebase 12/rules-test 5 were selected. Normal npm installation succeeded. npm
11 reported optional postinstall approvals for Firebase util/protobuf tooling;
the installed graph compiled and passed the tests without granting those scripts.

## Commands and actual results

Node 22 was put first on PATH for npm/Firebase commands; Java 21 was selected for
emulator commands. Commands below are recorded results, not deployment instructions.

| Command/check | Result |
| --- | --- |
| `npm install --prefix functions --no-audit --no-fund` | Passed; lockfile generated/updated |
| `npm --prefix functions run build` | Passed with strict TypeScript |
| `npm --prefix functions test` | 40 passed, 0 failed |
| `npm --prefix functions run test:emulator` | 7 integration tests passed, 0 failed |
| `flutter analyze` | Passed: no issues |
| `flutter test` | 59 passed, including the 56 Phase 0 regressions and 3 Stage 1 tests |
| `git diff --check` | Passed |
| `npm --prefix functions ls --depth=0` | Expected direct packages, no invalid dependency graph |
| `npm --prefix functions audit --omit=dev --json` | Passed: 0 reported runtime vulnerabilities |
| `npm --prefix functions audit --json` | Exit 1: 5 high-severity package findings in the test-only gRPC dependency chain; see below |
| Legacy snapshot byte-read/checksum comparison | Passed; matched existing verified SHA-256 |

Unit tests cover missing/invalid/expired/revoked authentication, disabled accounts,
network failure versus explicit denial, trusted UID/project/provider matching,
approved/unapproved membership, revocation during issuance, malformed requests,
TTL cap, deterministic signatures, expiry/future timestamps, project/UID/installation/
policy binding, modified payload, invalid signature, rotation, public-only keys,
administrator target confirmation, exclusive 0600 private-key creation (including
repository/symlink rejection), and production/emulator configuration separation.

Seven real emulator integration tests cover:

1. Unauthenticated/authenticated client get/list/set/update/delete/batch denial on
   backend and arbitrary paths, even with forged-looking admin/beta claims.
2. Six concurrent approvals produce exactly five active members; repeat approval
   uses no extra slot; revocation frees a slot and denies the former member.
3. Corrupt duplicate roster fails closed without rewriting metadata.
4. Atomic per-UID limits under concurrent requests and next-minute reset.
5. Global limits across UIDs and malformed rate-limit metadata failing closed.
6. Missing/invalid/unapproved callable identities and sanitized body-UID rejection.
7. Real emulator email/password identity receiving a verifiable 24-hour lease and
   public keys, followed by denial after membership revocation, account disablement
   and refresh-token revocation. The existing offline signature remains valid until
   its signed expiry, as documented.

An initial strict-TypeScript error and an emulator parameter prompt were corrected
before these final passes. Test output is local, contains synthetic identities only,
and is excluded from Git. Emulator suites used `demo-smartbudget-authz`, not the
production Firebase project. No Android build was needed for this backend-only
change; native/Flutter code and dependency files were unchanged.

## Remaining risks and approval boundary

* **No deployed security proof:** production IAM, real token revocation, Secret
  Manager access, App Check/Play Integrity, billing and runtime behavior still need
  separately approved setup and live staging validation. Emulators do not establish
  that production configuration is secure. Client integration remains a later stage.
* **Test dependency advisory:** Firebase 12.19.0 still pins `@grpc/grpc-js ~1.9.0`,
  resolving to 1.9.16. Full npm audit flags this and four dependent packages; the
  underlying advisories are [GHSA-m9gg-hp2v-232j](https://github.com/grpc/grpc-node/security/advisories/GHSA-m9gg-hp2v-232j)
  and [GHSA-f596-whhp-79r4](https://github.com/grpc/grpc-node/security/advisories/GHSA-f596-whhp-79r4).
  These packages are test-only and used as clients to loopback emulators, not as a
  certificate-authenticating server. Runtime Admin SDK dependencies resolve patched
  gRPC 1.14.6, and runtime audit is clear. No forced overrides or unsafe downgrade
  were applied. Track the upstream client SDK fix; do not reuse test dependencies
  in a deployed server or infer that the full audit passed.
* **Initial CLI environment dump:** inherited `DEBUG` made the first emulator
  attempt log its environment, including an unrelated API credential. That local
  environment-dump entry was removed. The final runner uses a small environment
  allowlist and separate Firebase configuration, excluding saved login, credentials,
  API keys and verbose logging. The exposed external API credential should be rotated;
  local cleanup cannot retract earlier tool output. No credential value is in Git.
* **Offline limits:** valid signatures cannot learn about revocation without
  connectivity; offline access is bounded by signed expiry, at most 24 hours.
  Clock rollback and compromised-device risks need explicit later client controls.
  Installation IDs are bindings, not hardware possession proofs.
* **Operational trust/cost:** administrators and runtime IAM are trust roots;
  Firestore rules do not restrict Admin SDK access. Direct Auth signups can exist
  without membership. Quotas/rate limits do not impose an absolute spending cap.

Stage 2 is ready for local code/security review. Production deployment and the next
implementation stage require the user's separate approval. No production resources
or legacy databases should be modified as part of reviewing this change.

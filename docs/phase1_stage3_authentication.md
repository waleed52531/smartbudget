# Stage 3 — authentication and offline authorization

This stage has an authentication-only entry point. It never constructs
`AppDatabase`, seeds legacy records, mounts financial providers, or routes to
`AppShell`. The existing financial application is preserved in
`lib/core/financial_app.dart` for regression tests and later integration. An
authorized session reaches a temporary session screen only. Financial database
ownership, encryption, migration and synchronization remain outside this stage.

## Authentication and navigation

`SessionCubit` owns restoration, signed-out, authorizing, authorized and locked
states. Firebase Auth manages native email/password sessions; application code
does not store passwords or manually persist ID/refresh tokens. Forms validate
email/nonempty password, obscure passwords, clear the password controller on
submission and prevent duplicate submission. No registration UI is provided.
Password-reset success is deliberately generic, including for unknown accounts.
Errors expose fixed messages, never SDK exceptions or credentials.

A signed-in Firebase identity alone never grants access. On sign-in the Cubit
requires online authorization from Stage 2 and verifies the returned signature
before storing a grant. Unapproved/disabled/revoked accounts stay locked. An
explicit backend denial or invalid signature invalidates the active grant;
neither can fall back to an older cached grant. Authentication-stream errors
require fresh online verification. Transient backend outages can use an existing
valid grant only for a restored, previously authorized session.

The callable sends exactly `{installationId}`; Firebase Functions attaches the
current Firebase Auth identity and, in production, a limited-use App Check token.
No client UID is sent for authorization. The Cubit checks the current SDK UID
again after asynchronous work, and the verifier binds the lease subject to it.
Backend roster limits, revocation checks and deny-all Firestore rules remain
Stage 2's implementation. No Firestore Flutter client was introduced.

Logout locks the UI immediately, cancels timers/in-flight results, marks the
protected active binding inactive, deletes that UID's cached grant and signs out
of Firebase Auth. A late login or lease response cannot reactivate the session.
Vault operations are serialized so a delayed write cannot undo logout. If logout
or protected-storage cleanup fails, the app stays locked and offers retry. No
financial records, legacy files or financial encryption keys are deleted.

## Signed lease verification

`LeaseVerifier` consumes Stage 2's exact compact JWS format over the original
header and payload bytes: Ed25519/`EdDSA`, protected `kid`, and
`typ: sb-auth-lease+jwt`. It checks canonical unpadded base64url, signature length,
exact header/claim fields, issuer/audience/project, UID, installation UUID, policy,
integer issue/expiry times, `iat <= now < exp` and lifetime at most 86,400 seconds.
It rejects unknown key IDs, private JWK fields and duplicate IDs. Public keys are
retrieved from the configured Firebase project's HTTPS key endpoint, not a
caller-supplied origin. Redirects, malformed/oversized key responses and invalid
signatures are rejected. No signing secret exists in Flutter.

The synthetic fixture in `test/fixtures/stage2_authorization.json` was produced by
`functions/tools/create-lease-fixture.mjs`, which calls the actual Stage 2 signer.
Its ephemeral private keys were never printed or stored. The fixture is test data
only and is not an application asset or trusted production key set. The live Dart
emulator test also verifies leases issued by the running Functions emulator.

On renewal, fresh public keys support signing-key rotation and overlap. A removed
or unknown key fails closed. Offline verification uses only keys already obtained
with that verified grant. Publish overlapping public keys before changing the
server signer and allow for the public endpoint's cache interval; see Stage 2's
rotation procedure. Offline installations cannot immediately discover emergency
key removal or membership revocation. Existing grants remain usable until their
signed expiry, at most 24 hours, unless the client receives an explicit denial.

## Protected storage and time

Authorization data uses `flutter_secure_storage` in a Firebase-project-specific
namespace, with separate entries per UID and an explicit active-UID binding.
Android uses AES-GCM with a direct Android KeyStore AES key; preferences contain
ciphertext, not the AES key or plaintext lease. Destructive reset and automatic
algorithm migration are disabled. A storage/decryption error locks the session;
application code never repairs the vault by deleting it or silently falling back
to plaintext. Apple options use nonsynchronizing, device-only unlocked Keychain
accessibility, but Apple Firebase applications remain unconfigured and locked.

Installation UUIDs, leases, public verification keys and time anchors are stored
in the protected vault. No financial data or financial encryption key is managed
here, and no authorization value is written with the SharedPreferences Flutter
package. A missing installation UUID cannot validate an old grant and therefore
requires new online authorization. Existing financial encryption keys are not
created, regenerated or reassigned.

Android's native clock bridge returns wall time, `SystemClock.elapsedRealtime()`
and `Settings.Global.BOOT_COUNT`. A grant records these anchors. Offline time
advances by monotonic elapsed time, never backward, and is also clamped to wall
time. A meaningful wall-clock rollback (over two seconds), decreasing elapsed
time or changed boot identity requires online verification. **After a device
reboot, offline restoration is intentionally unavailable until reauthorization.**
Normal application restart in the same boot can restore a valid grant offline.
Device time must be reasonably synchronized for initial online verification.

Local checks run every 30 seconds; these do not poll the server. A separate timer
locks at the signed expiry. Time is checked again after cryptographic verification
and secure-storage writes so slow operations cannot extend validity. Backgrounding
hides the authorized screen and cancels active checks; resume verifies again,
using a valid offline grant only if online service is unavailable. Protected
anchors cannot make a compromised/rooted OS trustworthy; this remains a limitation.

Android OS backup/device transfer is excluded for the new app to avoid moving
device-bound authorization material. This changes no existing files and does not
affect the separate legacy `com.example.smartbudget` installation or its backup.
Production cleartext traffic is disabled. Debug network policy permits cleartext
only for emulator loopback hosts.

## Local development

Use the sanitized launcher for Smart Budget commands:

```sh
python3 tool/clean_run.py flutter pub get
python3 tool/clean_run.py flutter analyze
python3 tool/clean_run.py flutter test
python3 tool/clean_run.py flutter build apk --debug
```

The launcher passes a small environment allowlist and redacts known credentials,
API key patterns, bearer tokens, reset-link codes and common JSON credential
fields from output. It does not edit the developer's shell configuration or
unrelated credentials. The IDE/Codex parent still holds a **revoked** environment
copy; remove its original environment assignment and restart the IDE to clear
that parent. Unwrapped commands cannot be claimed to have a sanitized environment.

With Node 22 and Java 21 on PATH, the combined emulator verification is:

```sh
python3 tool/clean_run.py npm --prefix functions test
python3 tool/clean_run.py npm --prefix functions run test:emulator -- --flutter
```

This starts only `demo-smartbudget-authz` Auth/Firestore/Functions emulators,
checks backend tests, and then exercises the real Dart authorization gateway
against them. Test accounts/passwords are synthetic and emulator state is not
exported. The standalone Flutter suite skips this one network-dependent test;
the combined command runs it explicitly. Operator dotenv/secret files are refused
rather than overwritten by the emulator runner.

For a manually started demo emulator session, run the Android debug client with:

```sh
python3 tool/clean_run.py flutter run --dart-define=SMARTBUDGET_USE_EMULATORS=true --dart-define=SMARTBUDGET_EMULATOR_HOST=10.0.2.2
```

Use Android emulator host `10.0.2.2`; physical-device testing would need separately
configured loopback port forwarding and host `127.0.0.1`. No installation or
forwarding was performed on the legacy TECNO phone. The client uses a named demo
Firebase app and a separate vault namespace so demo sessions do not replace the
default production Firebase session. Profile/release builds reject emulator mode;
there is no release mock-authorization path. Other platforms stay on the setup
failure screen until separately approved Firebase registrations are available.

## Console/deployment prerequisites — instructions only

No backend deployment, billing or production settings were changed. Before live
use, a separately approved setup must confirm:

* Email/password enabled, invited accounts created securely, reset email templates
  and authorized action domains reviewed; account enumeration protection enabled.
* Stage 2 Functions/rules deployed only after approval, five UIDs approved through
  the trusted administrator workflow, IAM/App Check verifier role and signing
  Secret Manager bindings validated. No production lease can be obtained from an
  undeployed endpoint, and this client remains locked in that situation.
* Android App Check/Play Integrity registered for the existing Firebase app ID and
  actual signing certificate. Production and non-emulator debug mode use Play
  Integrity, not a debug App Check token. Release signing still needs its own
  production configuration; Stage 1's existing debug-signing setup was preserved.
* Client region `asia-south1` and policy version `1` match the approved deployment.
  Build-time `SMARTBUDGET_AUTH_REGION`/`SMARTBUDGET_AUTH_POLICY` may configure these;
  they are public policy settings, not secrets. The production project is fixed.
* Real-device acceptance tests cover Firebase SDK restoration, Android KeyStore
  persistence and native clock behavior. Host tests/doubles and emulator REST
  integration are not proof of native or deployed production security behavior.

References: [Firebase Flutter password authentication](https://firebase.google.com/docs/auth/flutter/password-auth),
[App Check enforcement](https://firebase.google.com/docs/app-check/cloud-functions),
[secure-storage package](https://pub.dev/packages/flutter_secure_storage/versions/10.3.4),
[cryptography package](https://pub.dev/packages/cryptography).

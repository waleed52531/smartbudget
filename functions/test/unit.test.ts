import {test} from "node:test";
import assert from "node:assert/strict";
import {generateKeyPairSync} from "node:crypto";
import {mkdtempSync, readFileSync, rmSync, statSync, symlinkSync} from "node:fs";
import {tmpdir} from "node:os";
import {resolve} from "node:path";
import {authorize, AuthorizationDependencies} from "../src/authorization";
import {checkAdminTarget, generateSigningKey} from "../src/admin_cli";
import {issueLease, KeySet, publicKeys, signer, verifyLease} from "../src/leases";
import {AccessError, installationFrom, validateEnvironment} from "../src/security";
import {issueLegacyOwnership} from "../src/legacy_ownership";

const projectId = "demo-smartbudget-authz", uid = "synthetic-user";
const installationId = "12345678-1234-4234-8234-123456789abc", now = 1_800_000_000;
function key(kid: string) {
  const pair = generateKeyPairSync("ed25519");
  const jwk = pair.publicKey.export({format: "jwk"});
  return {privateKey: pair.privateKey, pem: pair.privateKey.export({format: "pem", type: "pkcs8"}).toString(),
    publicKey: {kty: "OKP", crv: "Ed25519", x: jwk.x!, kid, alg: "EdDSA", use: "sig"} as const};
}
const first = key("first"), second = key("second");
const keys: KeySet = {keys: [first.publicKey, second.publicKey]};
const expected = {projectId, uid, installationId, now, policyVersion: 1};
test("legacy ownership grant is purpose separated and capped", () => {
  const input = {project: projectId, uid, databaseId: installationId, sourceId: "a".repeat(64), now, ttl: 3600, kid: "first", key: first.privateKey};
  const token = issueLegacyOwnership(input);
  const [header, payload] = token.split(".");
  assert.equal(JSON.parse(Buffer.from(header!, "base64url").toString()).typ, "sb-legacy-ownership+jwt");
  assert.equal(JSON.parse(Buffer.from(payload!, "base64url").toString()).source_id, input.sourceId);
  assert.throws(() => verifyLease(token, keys, expected), code("permission-denied"));
  assert.throws(() => issueLegacyOwnership({...input, ttl: 86401}));
  assert.throws(() => issueLegacyOwnership({...input, sourceId: "invalid"}));
});
function issued(options: Partial<Parameters<typeof issueLease>[0]> = {}) {
  return issueLease({projectId, uid, installationId, now, ttlSeconds: 86400, policyVersion: 1,
    kid: "first", key: first.privateKey, ...options});
}
const code = (expectedCode: string) => (error: unknown) => error instanceof AccessError && error.code === expectedCode;

function fixture() {
  const state = {active: true, disabled: false, badToken: "", getUserFailure: false,
    provider: "password", tokenUid: uid, tokenProject: projectId, calls: 0, consumed: 0, revokeDuringSigning: false};
  const deps: AuthorizationDependencies = {
    identity: {
      async verifyIdToken(token, checkRevoked) {
        assert.equal(checkRevoked, true); assert.equal(token, "synthetic-token"); state.calls++;
        if (state.badToken) throw {code: state.badToken};
        return {uid: state.tokenUid, aud: state.tokenProject, firebase: {sign_in_provider: state.provider}};
      },
      async getUser(user) {
        assert.equal(user, uid);
        if (state.getUserFailure) throw {code: "app/network-error"};
        return {uid, disabled: state.disabled};
      },
    },
    store: {
      async assertActive() { if (!state.active) throw new AccessError("permission-denied"); },
      async commitGrant(user, installation, jti, exp) {
        if (!state.active) throw new AccessError("permission-denied");
        assert.equal(user, uid); assert.equal(installation, installationId);
        assert.ok(jti); assert.equal(exp, now + 86400);
      },
    },
    rateLimit: {async consume(user) { assert.equal(user, uid); state.consumed++; }},
    projectId, ttlSeconds: 86400, policyVersion: 1, kid: "first", now: () => now,
    signingKey: () => { if (state.revokeDuringSigning) state.active = false; return first.privateKey; },
  };
  return {deps, state, request: {contextUid: uid as unknown, authorization: "Bearer synthetic-token" as unknown,
    data: {installationId} as unknown}};
}

test("missing authentication never reaches identity or membership", async () => {
  const f = fixture(); f.request.contextUid = undefined;
  await assert.rejects(authorize(f.deps, f.request), code("unauthenticated"));
  assert.equal(f.state.calls, 0);
});
for (const error of ["auth/invalid-id-token", "auth/id-token-revoked", "auth/id-token-expired", "auth/user-disabled", "auth/argument-error"]) {
  test(`${error} cannot receive a lease`, async () => {
    const f = fixture(); f.state.badToken = error;
    await assert.rejects(authorize(f.deps, f.request), code("unauthenticated"));
  });
}
test("disabled account cannot receive a lease", async () => {
  const f = fixture(); f.state.disabled = true;
  await assert.rejects(authorize(f.deps, f.request), code("unauthenticated"));
});
test("verification outage is unavailable, not an explicit access denial", async () => {
  const f = fixture(); f.state.getUserFailure = true;
  await assert.rejects(authorize(f.deps, f.request), code("unavailable"));
});
for (const mutate of [(f: ReturnType<typeof fixture>) => f.state.tokenUid = "another-user",
  (f: ReturnType<typeof fixture>) => f.state.tokenProject = "wrong-project",
  (f: ReturnType<typeof fixture>) => f.state.provider = "anonymous"]) {
  test("verified identity must match context, project and password provider", async () => {
    const f = fixture(); mutate(f);
    await assert.rejects(authorize(f.deps, f.request), code("unauthenticated"));
  });
}
test("unapproved or revoked member is denied", async () => {
  const f = fixture(); f.state.active = false;
  await assert.rejects(authorize(f.deps, f.request), code("permission-denied"));
});
test("approved user gets a signed lease bound to trusted UID and installation", async () => {
  const f = fixture(); const result = await authorize(f.deps, f.request);
  assert.equal(verifyLease(result.lease, keys, expected).exp, now + 86400);
  assert.equal(f.state.consumed, 1);
});
test("revocation between initial check and grant commit stops issuance", async () => {
  const f = fixture(); f.state.revokeDuringSigning = true;
  await assert.rejects(authorize(f.deps, f.request), code("permission-denied"));
});
for (const data of [null, {}, {installationId, uid: "forged"}, {installationId: "../other"},
  {installationId: "123"}, {installationId: 42}, [installationId]]) {
  test("malformed installation/body or client-supplied UID rejected", () => {
    assert.throws(() => installationFrom(data), code("invalid-argument"));
  });
}
for (const ttlSeconds of [0, -1, 86401, Infinity, 12.5]) {
  test("invalid or excessive lifetime rejected", () => {
    assert.throws(() => issued({ttlSeconds}), code("unavailable"));
  });
}
test("shorter configured lifetime works and deterministic signing is stable", () => {
  const options = {ttlSeconds: 300, jti: "fixed-synthetic-nonce"};
  assert.equal(issued(options).lease, issued(options).lease);
  assert.equal(verifyLease(issued(options).lease, keys, expected).exp, now + 300);
});
for (const context of [{...expected, now: now + 86400}, {...expected, now: now - 1},
  {...expected, uid: "another-user"}, {...expected, installationId: "87654321-1234-4234-8234-123456789abc"},
  {...expected, projectId: "another-project"}, {...expected, policyVersion: 2}]) {
  test("expired/future lease or wrong context binding rejected", () => {
    assert.throws(() => verifyLease(issued().lease, keys, context), code("permission-denied"));
  });
}
test("modified payload and invalid signature rejected", () => {
  const parts = issued().lease.split(".");
  const claims = JSON.parse(Buffer.from(parts[1]!, "base64url").toString()); claims.exp += 86400;
  assert.throws(() => verifyLease(`${parts[0]}.${Buffer.from(JSON.stringify(claims)).toString("base64url")}.${parts[2]}`, keys, expected), code("permission-denied"));
  assert.throws(() => verifyLease(`${parts[0]}.${parts[1]}.${Buffer.alloc(64).toString("base64url")}`, keys, expected), code("permission-denied"));
});
test("signing key rotation accepts overlap, rejects removed/unknown keys", () => {
  const newer = issued({kid: "second", key: second.privateKey});
  verifyLease(issued().lease, keys, expected); verifyLease(newer.lease, keys, expected);
  assert.throws(() => verifyLease(issued().lease, {keys: [second.publicKey]}, expected), code("permission-denied"));
  assert.throws(() => signer(first.pem, "second", keys), code("unavailable"));
});
test("public key parser rejects private material and duplicate identifiers", () => {
  assert.throws(() => publicKeys({keys: [{...first.publicKey, d: "private"}]}), code("unavailable"));
  assert.throws(() => publicKeys({keys: [first.publicKey, first.publicKey]}), code("unavailable"));
  assert.equal(publicKeys(keys).keys.length, 2);
});
test("production admin commands require explicit approved target", () => {
  assert.throws(() => checkAdminTarget(projectId, projectId, false));
  assert.throws(() => checkAdminTarget("smartbudget-561d4", undefined, false));
});
test("administrator key generation protects private output and never replaces keys", () => {
  const directory = mkdtempSync(resolve(tmpdir(), "smartbudget-synthetic-keys-"));
  try {
    const privateFile = resolve(directory, "private.pem"), publicFile = resolve(directory, "public.json");
    assert.throws(() => generateSigningKey("synthetic", resolve(__dirname, "../../private.pem"), publicFile));
    const alias = resolve(directory, "repository-alias");
    symlinkSync(resolve(__dirname, "../.."), alias, "dir");
    assert.throws(() => generateSigningKey("synthetic", resolve(alias, "private.pem"), publicFile));
    generateSigningKey("synthetic", privateFile, publicFile);
    const before = readFileSync(privateFile);
    assert.equal(statSync(privateFile).mode & 0o777, 0o600);
    const published = publicKeys(JSON.parse(readFileSync(publicFile, "utf8")));
    signer(before.toString(), "synthetic", published);
    assert.throws(() => generateSigningKey("synthetic", privateFile, publicFile));
    assert.deepEqual(readFileSync(privateFile), before);
    assert.equal(JSON.stringify(published).includes("PRIVATE"), false);
  } finally { rmSync(directory, {recursive: true, force: true}); }
});
test("production rejects emulator endpoints, test signing material and wrong projects", () => {
  const production = "smartbudget-561d4";
  validateEnvironment(production, production, false, {});
  for (const name of ["FIREBASE_AUTH_EMULATOR_HOST", "FIRESTORE_EMULATOR_HOST",
    "SMARTBUDGET_TEST_SIGNING_KEY", "SMARTBUDGET_TEST_JWKS"]) {
    assert.throws(() => validateEnvironment(production, production, false, {[name]: "synthetic"}), code("unavailable"));
  }
  assert.throws(() => validateEnvironment(production, projectId, false, {}), code("unavailable"));
  assert.throws(() => validateEnvironment(projectId, projectId, false, {}), code("unavailable"));
});
test("emulator authorization requires the fixed demo project and loopback services", () => {
  const environment = {FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099", FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080"};
  validateEnvironment(projectId, projectId, true, environment);
  assert.throws(() => validateEnvironment(projectId, projectId, true, {}), code("unavailable"));
  assert.throws(() => validateEnvironment("smartbudget-561d4", "smartbudget-561d4", true, environment), code("unavailable"));
  assert.throws(() => validateEnvironment(projectId, projectId, true,
    {...environment, FIREBASE_AUTH_EMULATOR_HOST: "remote.example:9099"}), code("unavailable"));
});

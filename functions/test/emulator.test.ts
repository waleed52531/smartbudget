import {after, before, test} from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {initializeApp as adminApp, deleteApp as deleteAdmin} from "firebase-admin/app";
import {getAuth as adminAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {assertFails, initializeTestEnvironment, RulesTestEnvironment} from "@firebase/rules-unit-testing";
import {collection, doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, writeBatch} from "firebase/firestore";
import {FirestoreBetaStore, memberPath} from "../src/membership";
import {FirestoreRateLimiter} from "../src/rate_limit";
import {publicKeys, verifyLease} from "../src/leases";
import {AccessError} from "../src/security";

const projectId = "demo-smartbudget-authz";
assert.equal(process.env.GEMINI_API_KEY, undefined, "Emulator test processes must not inherit external API credentials");
const installationId = "12345678-1234-4234-8234-123456789abc";
if (process.env.GCLOUD_PROJECT !== projectId || !process.env.FIRESTORE_EMULATOR_HOST?.startsWith("127.0.0.1:") ||
    !process.env.FIREBASE_AUTH_EMULATOR_HOST?.startsWith("127.0.0.1:")) throw new Error("Local demo emulators required.");
const app = adminApp({projectId}), db = getFirestore(app), auth = adminAuth(app);
const members = new FirestoreBetaStore(db);
let rules: RulesTestEnvironment;
const endpoint = `http://127.0.0.1:5001/${projectId}/asia-south1`;
async function callable(token?: string, data: unknown = {installationId}) {
  const response = await fetch(`${endpoint}/authorizeSession`, {method: "POST", headers: {
    "Content-Type": "application/json", ...(token ? {Authorization: `Bearer ${token}`} : {}),
  }, body: JSON.stringify({data})});
  return {status: response.status, body: await response.json() as any};
}
async function user(index: number) {
  const email = `synthetic-${index}@example.test`, password = "Synthetic-only-Password-123!";
  const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`, {
    method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({email, password, returnSecureToken: true}),
  });
  const body = await response.json() as any;
  assert.equal(response.status, 200); return {uid: body.localId as string, token: body.idToken as string};
}
before(async () => {
  rules = await initializeTestEnvironment({projectId, firestore: {
    host: "127.0.0.1", port: 8080, rules: readFileSync(resolve(__dirname, "../../..", "firestore.rules"), "utf8"),
  }});
});
after(async () => { await rules?.cleanup(); await db.terminate(); await deleteAdmin(app); });

test("Firestore denies every direct client read/write, including approved-looking claims", async () => {
  await db.doc("authorization/betaRoster").set({version: 1, members: []});
  for (const context of [rules.unauthenticatedContext(), rules.authenticatedContext("synthetic-approved", {admin: true, beta: true})]) {
    const client = context.firestore();
    for (const path of ["authorization/betaRoster", "authorizationMembers/synthetic", "authorizationGrants/synthetic", "authorizationRateLimits/global", "transactions/anything", "arbitrary/path"]) {
      const reference = doc(client, path);
      await assertFails(getDoc(reference)); await assertFails(setDoc(reference, {state: "active"}));
      await assertFails(updateDoc(reference, {state: "active"})); await assertFails(deleteDoc(reference));
      const batch = writeBatch(client); batch.set(reference, {state: "active"}); await assertFails(batch.commit());
    }
    await assertFails(getDocs(collection(client, "authorizationMembers")));
  }
});
test("concurrent provisioning admits exactly five and idempotent reapproval uses no slot", async () => {
  await rules.clearFirestore();
  const results = await Promise.allSettled(Array.from({length: 6}, (_, i) => members.approve(`synthetic-member-${i}`)));
  assert.equal(results.filter(r => r.status === "fulfilled").length, 5);
  const rejected = results.find(r => r.status === "rejected");
  assert.ok(rejected?.status === "rejected" && rejected.reason instanceof AccessError && rejected.reason.code === "resource-exhausted");
  const active = await members.status(); assert.equal(active.length, 5);
  await members.approve(active[0]!); assert.equal((await members.status()).length, 5);
  await members.revoke(active[0]!); await members.approve("replacement-member");
  assert.equal((await members.status()).length, 5);
  await assert.rejects(members.assertActive(active[0]!), (e: unknown) => e instanceof AccessError && e.code === "permission-denied");
});
test("corrupt roster fails closed without silently repairing membership", async () => {
  await rules.clearFirestore();
  await db.doc("authorization/betaRoster").set({version: 1, members: ["duplicate", "duplicate"]});
  await assert.rejects(members.approve("another"));
  assert.deepEqual((await db.doc("authorization/betaRoster").get()).data()?.members, ["duplicate", "duplicate"]);
});
test("rate limit is atomic across concurrent requests and resets next minute", async () => {
  await rules.clearFirestore(); const limiter = new FirestoreRateLimiter(db);
  const results = await Promise.allSettled(Array.from({length: 11}, () => limiter.consume("synthetic", 1800000000)));
  assert.equal(results.filter(r => r.status === "fulfilled").length, 10);
  await limiter.consume("synthetic", 1800000060);
});
test("global rate limit spans UIDs and unavailable metadata fails closed", async () => {
  await rules.clearFirestore(); const limiter = new FirestoreRateLimiter(db);
  await db.doc("authorizationRateLimits/global").set({window: 30000000, count: 99});
  await limiter.consume("synthetic-first", 1800000000);
  await assert.rejects(limiter.consume("synthetic-second", 1800000000),
    (e: unknown) => e instanceof AccessError && e.code === "resource-exhausted");
  await db.doc("authorizationRateLimits/global").set({window: 30000000, count: -1});
  await assert.rejects(limiter.consume("synthetic-second", 1800000000),
    (e: unknown) => e instanceof AccessError && e.code === "unavailable");
});
test("callable rejects unauthenticated/invalid/unapproved accounts and returns sanitized errors", async () => {
  await rules.clearFirestore();
  assert.equal((await callable()).status, 401);
  assert.equal((await callable("invalid-token")).status, 401);
  const account = await user(1);
  const denied = await callable(account.token); assert.equal(denied.status, 403);
  assert.equal(denied.body.error.message, "Access is not authorized.");
  assert.equal(JSON.stringify(denied.body).includes(account.uid), false);
  assert.equal((await callable(account.token, {installationId, uid: "forged"})).status, 400);
});
test("real emulator identity gets a signed lease; revoked member and disabled account cannot renew", async () => {
  await rules.clearFirestore(); const account = await user(2); await members.approve(account.uid);
  const response = await callable(account.token); assert.equal(response.status, 200);
  const keysResponse = await fetch(`${endpoint}/leaseVerificationKeys`);
  assert.equal(keysResponse.status, 200);
  const keys = publicKeys(await keysResponse.json());
  const claims = verifyLease(response.body.result.lease, keys, {projectId, uid: account.uid, installationId,
    now: Math.floor(Date.now() / 1000), policyVersion: 1});
  assert.equal(claims.exp - claims.iat, 86400);
  await members.revoke(account.uid);
  assert.equal((await callable(account.token)).status, 403);
  // A previously issued offline signature cannot learn about server revocation.
  verifyLease(response.body.result.lease, keys, {projectId, uid: account.uid, installationId, now: claims.iat, policyVersion: 1});
  await members.approve(account.uid); await auth.updateUser(account.uid, {disabled: true});
  assert.equal((await callable(account.token)).status, 401);
  await auth.updateUser(account.uid, {disabled: false});
  // Revocation timestamps have one-second resolution, so cross a boundary.
  await new Promise(resolve => setTimeout(resolve, 1100));
  await auth.revokeRefreshTokens(account.uid);
  assert.equal((await callable(account.token)).status, 401);
});

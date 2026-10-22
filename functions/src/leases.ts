import {createPrivateKey, createPublicKey, KeyObject, randomUUID, sign, verify} from "node:crypto";
import {AccessError, installationFrom, MAX_LEASE_SECONDS, validatePolicy, validUid} from "./security";

export interface PublicKey {kty: "OKP"; crv: "Ed25519"; x: string; kid: string; alg: "EdDSA"; use: "sig"}
export interface KeySet {keys: PublicKey[]}
export interface LeaseClaims {
  iss: string; aud: string; project_id: string; sub: string; installation_id: string;
  iat: number; exp: number; policy_version: number; jti: string;
}
const type = "sb-auth-lease+jwt";
const kidPattern = /^[A-Za-z0-9_-]{1,64}$/;
const b64Pattern = /^[A-Za-z0-9_-]+$/;

export function publicKeys(value: unknown): KeySet {
  if (!value || typeof value !== "object" || !("keys" in value) ||
      Object.keys(value).length !== 1 || !Array.isArray(value.keys) ||
      value.keys.length < 1 || value.keys.length > 5) throw new AccessError("unavailable");
  const seen = new Set<string>();
  for (const key of value.keys) {
    if (!key || typeof key !== "object" || Object.keys(key).sort().join() !== "alg,crv,kid,kty,use,x" ||
        key.kty !== "OKP" || key.crv !== "Ed25519" || key.alg !== "EdDSA" || key.use !== "sig" ||
        typeof key.kid !== "string" || !kidPattern.test(key.kid) || seen.has(key.kid) ||
        typeof key.x !== "string" || !/^[A-Za-z0-9_-]{43}$/.test(key.x) ||
        Buffer.from(key.x, "base64url").toString("base64url") !== key.x) throw new AccessError("unavailable");
    createPublicKey({key, format: "jwk"});
    seen.add(key.kid);
  }
  // Construct a clean public-only projection; private JWK fields are rejected.
  return {keys: value.keys.map(k => ({kty: k.kty, crv: k.crv, x: k.x, kid: k.kid, alg: k.alg, use: k.use}))};
}

export function signer(privatePem: string, kid: string, keys: KeySet): KeyObject {
  try {
    const key = createPrivateKey(privatePem);
    const published = keys.keys.find(k => k.kid === kid);
    if (key.asymmetricKeyType !== "ed25519" || !published ||
        createPublicKey(key).export({format: "jwk"}).x !== published.x) throw new Error();
    return key;
  } catch { throw new AccessError("unavailable"); }
}

export function issueLease(input: {
  projectId: string; uid: string; installationId: string; now: number;
  ttlSeconds: number; policyVersion: number; kid: string; key: KeyObject; jti?: string;
}): {lease: string; claims: LeaseClaims} {
  validatePolicy(input.ttlSeconds, input.policyVersion);
  if (!validUid(input.uid) || !kidPattern.test(input.kid) || input.key.asymmetricKeyType !== "ed25519" ||
      !/^[a-z][a-z0-9-]{4,62}$/.test(input.projectId) ||
      !Number.isSafeInteger(input.now) || input.now < 0 ||
      !Number.isSafeInteger(input.now + input.ttlSeconds)) throw new AccessError("unavailable");
  installationFrom({installationId: input.installationId});
  const claims: LeaseClaims = {
    iss: `smartbudget:${input.projectId}:authorization`, aud: input.projectId,
    project_id: input.projectId, sub: input.uid, installation_id: input.installationId,
    iat: input.now, exp: input.now + input.ttlSeconds,
    policy_version: input.policyVersion, jti: input.jti ?? randomUUID(),
  };
  const header = {alg: "EdDSA", typ: type, kid: input.kid};
  const message = [header, claims].map(o => Buffer.from(JSON.stringify(o)).toString("base64url")).join(".");
  return {lease: `${message}.${sign(null, Buffer.from(message), input.key).toString("base64url")}`, claims};
}

export function verifyLease(lease: string, keys: KeySet, expected: {
  projectId: string; uid: string; installationId: string; now: number; policyVersion: number;
}): LeaseClaims {
  try {
    if (typeof lease !== "string" || lease.length > 4096) throw new Error();
    const parts = lease.split(".");
    if (parts.length !== 3 || parts.some(p => !b64Pattern.test(p) ||
        Buffer.from(p, "base64url").toString("base64url") !== p)) throw new Error();
    const [headerPart, payload, signature] = parts as [string, string, string];
    const header = JSON.parse(Buffer.from(headerPart, "base64url").toString("utf8"));
    if (Object.keys(header).sort().join() !== "alg,kid,typ" || header.alg !== "EdDSA" || header.typ !== type) throw new Error();
    const jwk = keys.keys.find(k => k.kid === header.kid);
    if (!jwk || Buffer.from(signature, "base64url").length !== 64 ||
        !verify(null, Buffer.from(`${headerPart}.${payload}`), createPublicKey({key: {...jwk}, format: "jwk"}), Buffer.from(signature, "base64url"))) throw new Error();
    const c: LeaseClaims = JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
    if (Object.keys(c).sort().join() !== "aud,exp,iat,installation_id,iss,jti,policy_version,project_id,sub" ||
        c.iss !== `smartbudget:${expected.projectId}:authorization` || c.aud !== expected.projectId ||
        c.project_id !== expected.projectId || c.sub !== expected.uid || c.installation_id !== expected.installationId ||
        c.policy_version !== expected.policyVersion || typeof c.jti !== "string" || !c.jti ||
        !Number.isSafeInteger(expected.now) || !Number.isSafeInteger(c.iat) || c.iat < 0 || !Number.isSafeInteger(c.exp) ||
        c.iat > expected.now || c.exp <= expected.now || c.exp <= c.iat || c.exp - c.iat > MAX_LEASE_SECONDS) throw new Error();
    return c;
  } catch { throw new AccessError("permission-denied"); }
}

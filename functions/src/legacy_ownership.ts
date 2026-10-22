import {KeyObject, randomUUID, sign} from "node:crypto";
import {validUid} from "./security";

/** Operator-only signing primitive. It is never exported as an HTTP function. */
export function issueLegacyOwnership(input: {
  project: string; uid: string; databaseId: string; sourceId: string;
  now: number; ttl: number; kid: string; key: KeyObject;
}): string {
  if (!/^[a-z][a-z0-9-]{4,62}$/.test(input.project) || !validUid(input.uid) ||
      !/^[0-9a-f-]{36}$/.test(input.databaseId) || !/^[0-9a-f]{64}$/.test(input.sourceId) ||
      !/^[A-Za-z0-9_-]{1,64}$/.test(input.kid) || input.key.asymmetricKeyType !== "ed25519" ||
      !Number.isSafeInteger(input.now) || input.now < 0 || !Number.isSafeInteger(input.ttl) ||
      input.ttl < 60 || input.ttl > 86400 || !Number.isSafeInteger(input.now + input.ttl)) {
    throw new Error("Invalid administrator ownership grant inputs.");
  }
  const header = {alg: "EdDSA", typ: "sb-legacy-ownership+jwt", kid: input.kid};
  const claims = {iss: `smartbudget:${input.project}:legacy-ownership`, aud: input.project,
    project_id: input.project, sub: input.uid, database_id: input.databaseId,
    source_id: input.sourceId, policy_version: 1, iat: input.now,
    exp: input.now + input.ttl, jti: randomUUID()};
  const message = [header, claims].map(v => Buffer.from(JSON.stringify(v)).toString("base64url")).join(".");
  return message + "." + sign(null, Buffer.from(message), input.key).toString("base64url");
}

import {KeyObject} from "node:crypto";
import {IdentityAdmin, verifyIdentity} from "./authentication";
import {BetaStore} from "./membership";
import {issueLease} from "./leases";
import {installationFrom, validatePolicy} from "./security";

export interface AuthorizationDependencies {
  identity: IdentityAdmin; store: BetaStore;
  rateLimit: {consume(uid: string, now: number): Promise<void>};
  projectId: string; ttlSeconds: number; policyVersion: number;
  kid: string; signingKey: () => KeyObject; now: () => number;
}

export async function authorize(deps: AuthorizationDependencies, request: {
  contextUid: unknown; authorization: unknown; data: unknown;
}): Promise<{lease: string}> {
  validatePolicy(deps.ttlSeconds, deps.policyVersion);
  const uid = await verifyIdentity(deps.identity, request.contextUid, request.authorization, deps.projectId);
  const installationId = installationFrom(request.data);
  const now = deps.now();
  await deps.rateLimit.consume(uid, now);
  await deps.store.assertActive(uid);
  const result = issueLease({projectId: deps.projectId, uid, installationId, now,
    ttlSeconds: deps.ttlSeconds, policyVersion: deps.policyVersion, kid: deps.kid, key: deps.signingKey()});
  // Recheck membership in the grant transaction so a concurrent revocation wins
  // if it committed before authorization's linearization point.
  await deps.store.commitGrant(uid, installationId, result.claims.jti, result.claims.exp);
  return {lease: result.lease};
}

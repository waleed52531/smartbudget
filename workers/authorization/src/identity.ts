import {createRemoteJWKSet, customFetch, jwtVerify, type JWTVerifyGetKey} from 'jose';
import {AccessError, validUid} from '../../../functions/src/security';
import type {IdentityAdmin} from '../../../functions/src/authentication';
import {APP_ID, GoogleFailure, GoogleRest, PROJECT, PROJECT_NUMBER} from './firebase_rest';

export const AUTH_JWKS = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
export const APP_CHECK_JWKS = 'https://firebaseappcheck.googleapis.com/v1/jwks';

export function remoteKeys(url: string, send: typeof fetch = fetch): JWTVerifyGetKey {
  const resolve = createRemoteJWKSet(new URL(url), {timeoutDuration: 10000, [customFetch]: send});
  return async (header, token) => {
    try { return await resolve(header, token); }
    catch (error) {
      if ((error as {code?: string}).code === 'ERR_JWKS_NO_MATCHING_KEY') throw error;
      throw new AccessError('unavailable');
    }
  };
}

export class AppCheckFailure extends AccessError {
  constructor() { super('permission-denied'); }
}

// Auth identity is derived from a verified Firebase ID token, never a body UID.
export class RestIdentity implements IdentityAdmin {
  private users = new Map<string, Record<string, any>>();
  constructor(private readonly api: GoogleRest, private readonly keys: JWTVerifyGetKey,
    private readonly now = () => Math.floor(Date.now() / 1000)) {}
  private async user(uid: string): Promise<Record<string, any>> {
    if (this.users.has(uid)) return this.users.get(uid)!;
    let result;
    try {
      result = await this.api.request(`https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:lookup`, {localId: [uid]});
    } catch (e) {
      if (e instanceof GoogleFailure && e.status === 404) throw new AccessError('unauthenticated');
      throw e;
    }
    if (!Array.isArray(result.users) || result.users.length !== 1 || result.users[0]?.localId !== uid) {
      throw new AccessError('unauthenticated');
    }
    const user = result.users[0];
    if (user.disabled === true || !Array.isArray(user.providerUserInfo) ||
        !user.providerUserInfo.some((p: any) => p.providerId === 'password')) throw new AccessError('unauthenticated');
    this.users.set(uid, user);
    return user;
  }
  async verifyIdToken(token: string, checkRevoked: boolean) {
    let claims;
    try {
      claims = (await jwtVerify(token, this.keys, {
        algorithms: ['RS256'], issuer: `https://securetoken.google.com/${PROJECT}`, audience: PROJECT,
        currentDate: new Date(this.now() * 1000), requiredClaims: ['exp', 'iat', 'auth_time', 'sub'],
      })).payload;
    } catch (error) {
      if (error instanceof AccessError) throw error;
      // Remote key outages must not look like an account revocation.
      if ((error as {code?: string}).code === 'ERR_JWKS_TIMEOUT' || error instanceof TypeError) throw new AccessError('unavailable');
      throw new AccessError('unauthenticated');
    }
    const now = this.now();
    if (!validUid(claims.sub) || !Number.isSafeInteger(claims.iat) || claims.iat! > now ||
        !Number.isSafeInteger(claims.auth_time) || (claims.auth_time as number) > now ||
        (claims.auth_time as number) < 0 ||
        !claims.firebase || typeof claims.firebase !== 'object' ||
        !('sign_in_provider' in claims.firebase) || claims.firebase.sign_in_provider !== 'password') {
      throw new AccessError('unauthenticated');
    }
    if (!checkRevoked) throw new AccessError('unavailable');
    const user = await this.user(claims.sub);
    if (typeof user.validSince !== 'string' || !/^\d+$/.test(user.validSince) ||
        !Number.isSafeInteger(Number(user.validSince))) throw new AccessError('unavailable');
    if ((claims.auth_time as number) < Number(user.validSince)) throw new AccessError('unauthenticated');
    return {uid: claims.sub, aud: PROJECT, firebase: {sign_in_provider: 'password'}};
  }
  async getUser(uid: string) {
    const user = await this.user(uid);
    return {uid: user.localId as string, disabled: user.disabled === true};
  }
}

export async function verifyAppCheck(token: string, keys: JWTVerifyGetKey, api: GoogleRest,
  now = Math.floor(Date.now() / 1000)): Promise<void> {
  let claims;
  try {
    claims = (await jwtVerify(token, keys, {
      algorithms: ['RS256'], issuer: `https://firebaseappcheck.googleapis.com/${PROJECT_NUMBER}`,
      audience: [`projects/${PROJECT_NUMBER}`, `projects/${PROJECT}`],
      currentDate: new Date(now * 1000), requiredClaims: ['sub', 'iat', 'exp'],
    })).payload;
  } catch (error) {
    if (error instanceof AccessError) throw error;
    if ((error as {code?: string}).code === 'ERR_JWKS_TIMEOUT' || error instanceof TypeError) throw new AccessError('unavailable');
    throw new AppCheckFailure();
  }
  if (claims.sub !== APP_ID || !Number.isSafeInteger(claims.iat) || claims.iat! > now) throw new AppCheckFailure();
  let consumed;
  try {
    consumed = await api.request(`https://firebaseappcheck.googleapis.com/v1beta/projects/${PROJECT_NUMBER}:verifyAppCheckToken`, {appCheckToken: token});
  } catch (e) {
    // A 403 here can be missing service-account IAM. Do not report it as revoked membership.
    if (e instanceof GoogleFailure && e.status === 400) throw new AppCheckFailure();
    throw e;
  }
  if (consumed.alreadyConsumed === true) throw new AppCheckFailure();
  if (consumed.alreadyConsumed !== undefined && consumed.alreadyConsumed !== false) throw new AccessError('unavailable');
}

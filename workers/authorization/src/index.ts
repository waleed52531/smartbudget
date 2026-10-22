import {decodeJwt} from 'jose';
import {authorize} from '../../../functions/src/authorization';
import {publicKeys, signer} from '../../../functions/src/leases';
import {AccessError, validatePolicy} from '../../../functions/src/security';
import {APP_ID, GoogleOAuth, GoogleRest, PROJECT, PROJECT_NUMBER, SERVICE_ACCOUNT, type Fetch} from './firebase_rest';
import {RestBetaStore, RestFirestore, RestRateLimiter} from './firestore';
import {APP_CHECK_JWKS, AUTH_JWKS, AppCheckFailure, remoteKeys, RestIdentity, verifyAppCheck} from './identity';

export interface Env {
  AUTH_EXPECTED_PROJECT: string; AUTH_PROJECT_NUMBER: string; AUTH_ANDROID_APP_ID: string;
  AUTH_SERVICE_ACCOUNT: string; AUTH_LEASE_TTL_SECONDS: string; AUTH_POLICY_VERSION: string;
  AUTH_SIGNING_KEY_ID: string; AUTH_PUBLIC_KEY_SET_JSON: string;
  AUTH_LEASE_PRIVATE_KEY: string; GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY: string;
}
const messages = {
  unauthenticated: 'Sign in again to verify access.',
  'permission-denied': 'Access is not authorized.',
  'invalid-argument': 'Invalid authorization request.',
  'resource-exhausted': 'Please retry later.',
  unavailable: 'Authorization service is unavailable or not configured.',
};
const statuses = {'unauthenticated': 401, 'permission-denied': 403, 'invalid-argument': 400, 'resource-exhausted': 429, unavailable: 503};
const headers = {'content-type': 'application/json', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff'};

function config(env: Env) {
  if (env.AUTH_EXPECTED_PROJECT !== PROJECT || env.AUTH_PROJECT_NUMBER !== PROJECT_NUMBER ||
      env.AUTH_ANDROID_APP_ID !== APP_ID || env.AUTH_SERVICE_ACCOUNT !== SERVICE_ACCOUNT ||
      !/^\d+$/.test(env.AUTH_LEASE_TTL_SECONDS) || !/^\d+$/.test(env.AUTH_POLICY_VERSION)) throw new AccessError('unavailable');
  const ttl = Number(env.AUTH_LEASE_TTL_SECONDS), policy = Number(env.AUTH_POLICY_VERSION);
  validatePolicy(ttl, policy);
  const keys = publicKeys(JSON.parse(env.AUTH_PUBLIC_KEY_SET_JSON));
  return {ttl, policy, keys};
}

async function body(request: Request): Promise<unknown> {
  if (request.headers.get('content-type')?.split(';')[0]?.trim() !== 'application/json') throw new AccessError('invalid-argument');
  if (Number(request.headers.get('content-length')) > 1024 || !request.body) throw new AccessError('invalid-argument');
  const reader = request.body.getReader();
  let size = 0; const chunks = [];
  try {
    while (true) {
      const {value, done} = await reader.read(); if (done) break;
      size += value.length; if (size > 1024) throw new AccessError('invalid-argument'); chunks.push(value);
    }
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch { throw new AccessError('invalid-argument'); }
  finally { await reader.cancel(); }
}

// Dependency wiring is injectable only in tests, never through request input,
// environment origins, emulator flags or a deployed authorization bypass.
export function createWorker(send: Fetch = fetch) {
  const authKeys = remoteKeys(AUTH_JWKS, send), appKeys = remoteKeys(APP_CHECK_JWKS, send);
  const oauthCache = new WeakMap<Env, GoogleOAuth>();
  return {async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);
      if (url.search || !['/authorizeSession', '/leaseVerificationKeys'].includes(url.pathname)) return new Response(null, {status: 404, headers});
      if ((url.pathname === '/leaseVerificationKeys' && request.method !== 'GET') ||
          (url.pathname === '/authorizeSession' && request.method !== 'POST')) return new Response(null, {status: 405, headers});
      const c = config(env);
      if (url.pathname === '/leaseVerificationKeys') {
        return Response.json(c.keys, {headers: {...headers, 'cache-control': 'public, max-age=300'}});
      }
      const authorization = request.headers.get('authorization');
      const attestation = request.headers.get('x-firebase-appcheck');
      if (!authorization || !/^Bearer [A-Za-z0-9_.-]{1,8192}$/.test(authorization)) throw new AccessError('unauthenticated');
      if (!attestation || !/^[A-Za-z0-9_.-]{1,8192}$/.test(attestation)) throw new AppCheckFailure();
      const data = await body(request);
      let oauth = oauthCache.get(env);
      if (!oauth) { oauth = new GoogleOAuth(env.GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY, send); oauthCache.set(env, oauth); }
      const api = new GoogleRest(oauth, send), db = new RestFirestore(api);
      // Verify both token signatures before consuming App Check or touching membership.
      const identity = new RestIdentity(api, authKeys);
      let contextUid;
      try { contextUid = decodeJwt(authorization.slice(7)).sub; } catch { throw new AccessError('unauthenticated'); }
      await identity.verifyIdToken(authorization.slice(7), true);
      await verifyAppCheck(attestation, appKeys, api);
      const result = await authorize({identity, store: new RestBetaStore(db), rateLimit: new RestRateLimiter(db),
        projectId: PROJECT, ttlSeconds: c.ttl, policyVersion: c.policy, kid: env.AUTH_SIGNING_KEY_ID,
        signingKey: () => signer(env.AUTH_LEASE_PRIVATE_KEY, env.AUTH_SIGNING_KEY_ID, c.keys),
        now: () => Math.floor(Date.now() / 1000),
      }, {contextUid, authorization, data});
      return Response.json(result, {headers});
    } catch (error) {
      const code = error instanceof AccessError ? error.code : 'unavailable';
      return Response.json({error: {code: error instanceof AppCheckFailure ? 'app-check-failed' : code,
        message: error instanceof AppCheckFailure ? 'App verification failed.' : messages[code]}}, {status: statuses[code], headers});
    }
  }};
}

export default createWorker();

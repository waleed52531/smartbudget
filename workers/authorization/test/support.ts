import {generateKeyPairSync, randomUUID} from 'node:crypto';
import {createServer, type Server} from 'node:http';
import {createLocalJWKSet, SignJWT} from 'jose';
import {createWorker, type Env} from '../src/index';
import {APP_ID, PROJECT, PROJECT_NUMBER, SERVICE_ACCOUNT} from '../src/firebase_rest';

export const installation = '12345678-1234-4234-9234-123456789abc';
const name = `projects/${PROJECT}/databases/(default)/documents/`;
function value(v: any): any {
  if (typeof v === 'string') return {stringValue: v};
  if (typeof v === 'number') return {integerValue: String(v)};
  if (Array.isArray(v)) return {arrayValue: {values: v.map(value)}};
  throw Error('Unsupported synthetic fixture');
}
export function document(path: string, data: Record<string, any>) {
  return {name: name + path, fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, value(v)]))};
}

// All credentials, identities and databases below are generated test fixtures.
// The HTTP server is loopback only; no production Firebase request can escape.
export class Fixture {
  rsa = generateKeyPairSync('rsa', {modulusLength: 2048});
  ed = generateKeyPairSync('ed25519');
  jwk = {...this.rsa.publicKey.export({format: 'jwk'}), kid: 'synthetic-rsa', alg: 'RS256', use: 'sig'};
  publicKeys = {keys: [{...this.ed.publicKey.export({format: 'jwk'}), kid: 'synthetic-lease', alg: 'EdDSA', use: 'sig'}]};
  env: Env = {
    AUTH_EXPECTED_PROJECT: PROJECT, AUTH_PROJECT_NUMBER: PROJECT_NUMBER, AUTH_ANDROID_APP_ID: APP_ID,
    AUTH_SERVICE_ACCOUNT: SERVICE_ACCOUNT, AUTH_LEASE_TTL_SECONDS: '86400', AUTH_POLICY_VERSION: '1',
    AUTH_SIGNING_KEY_ID: 'synthetic-lease', AUTH_PUBLIC_KEY_SET_JSON: JSON.stringify(this.publicKeys),
    AUTH_LEASE_PRIVATE_KEY: this.ed.privateKey.export({format: 'pem', type: 'pkcs8'}).toString(),
    GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY: this.rsa.privateKey.export({format: 'pem', type: 'pkcs8'}).toString(),
  };
  documents = new Map<string, any>();
  consumed = new Set<string>();
  requests: {host: string; path: string; method: string}[] = [];
  failHost?: string;
  redirectHost?: string;
  failStatus = 503;
  html = false;
  disabled = false;
  validSince = '0';
  userMissing = false;
  onGrantRead?: () => void;
  conflicts = 0;
  rollbacks = 0;
  private server?: Server;
  origin = '';
  private transactions = new Map<string, {reads: number; grant: boolean}>();
  approve(uid = 'synthetic-user') {
    const hash = requireHash(uid);
    this.documents.set('authorization/betaRoster', document('authorization/betaRoster', {version: 1, members: [uid]}));
    this.documents.set(`authorizationMembers/${hash}`, document(`authorizationMembers/${hash}`, {uid, state: 'active'}));
  }
  async token(uid = 'synthetic-user', extra: Record<string, any> = {}) {
    const now = Math.floor(Date.now() / 1000);
    return new SignJWT({auth_time: now, firebase: {sign_in_provider: 'password'}, ...extra})
      .setProtectedHeader({alg: 'RS256', kid: this.jwk.kid}).setSubject(uid)
      .setIssuer(extra.iss ?? `https://securetoken.google.com/${PROJECT}`).setAudience(extra.aud ?? PROJECT)
      .setIssuedAt(now).setExpirationTime(now + 3600).sign(this.rsa.privateKey);
  }
  async appToken(app = APP_ID) {
    return new SignJWT({jti: randomUUID()}).setProtectedHeader({alg: 'RS256', kid: this.jwk.kid})
      .setSubject(app).setIssuer(`https://firebaseappcheck.googleapis.com/${PROJECT_NUMBER}`)
      .setAudience([`projects/${PROJECT_NUMBER}`]).setIssuedAt().setExpirationTime('1h').sign(this.rsa.privateKey);
  }
  async start() {
    this.server = createServer(async (req, res) => {
      try {
        const url = new URL(req.url!, 'http://localhost');
        const path = url.pathname;
        const host = path === '/token' ? 'oauth2.googleapis.com' : path.includes('accounts:lookup') ? 'identitytoolkit.googleapis.com' :
          path.includes('/documents') ? 'firestore.googleapis.com' : path.includes('/jwk/') ? 'www.googleapis.com' : 'firebaseappcheck.googleapis.com';
        const upstream = new URL(url.searchParams.get('upstream') ?? `https://${host}${req.url}`);
        const chunks: Buffer[] = []; for await (const chunk of req) chunks.push(Buffer.from(chunk));
        const text = Buffer.concat(chunks).toString();
        let body: any; try { body = JSON.parse(text); } catch { body = undefined; }
        const response = await this.respond(upstream, req.method!, body);
        res.statusCode = response.status; res.setHeader('content-type', response.headers.get('content-type')!);
        res.end(await response.text());
      } catch { res.statusCode = 500; res.end('{}'); }
    });
    await new Promise<void>(resolve => this.server!.listen(0, '127.0.0.1', resolve));
    const address = this.server.address(); if (!address || typeof address === 'string') throw Error();
    this.origin = `http://127.0.0.1:${address.port}`;
    return this;
  }
  async close() { await new Promise<void>((resolve, reject) => this.server!.close(e => e ? reject(e) : resolve())); }
  send: typeof fetch = async (input, init) => {
    const url = typeof input === 'string' || input instanceof URL ? String(input) : input.url;
    return fetch(`${this.origin}/upstream?upstream=${encodeURIComponent(url)}`, init);
  };
  async respond(url: URL, method: string, body: any): Promise<Response> {
    this.requests.push({host: url.host, path: url.pathname, method});
    const error = (status: number, code: string) => Response.json({error: {status: code}}, {status});
    if (url.host === this.redirectHost) return new Response(null, {status: 307, headers: {location: `${this.origin}/must-not-follow`}});
    if (url.host === this.failHost) return this.html ? new Response('<html>unavailable</html>', {status: this.failStatus}) : error(this.failStatus, 'UNAVAILABLE');
    if (url.pathname.includes('/jwk') || url.pathname.includes('/jwks')) return Response.json({keys: [this.jwk]});
    if (url.host === 'oauth2.googleapis.com') return Response.json({access_token: 'synthetic-access', expires_in: 3600});
    if (url.host === 'identitytoolkit.googleapis.com') {
      const uid = body?.localId?.[0];
      return Response.json({users: this.userMissing ? [] : [{localId: uid, disabled: this.disabled, validSince: this.validSince,
        providerUserInfo: [{providerId: 'password'}]}]});
    }
    if (url.pathname.endsWith(':verifyAppCheckToken')) {
      if (!body?.appCheckToken || Object.keys(body).join() !== 'appCheckToken') return error(400, 'INVALID_ARGUMENT');
      const already = this.consumed.has(body.appCheckToken); this.consumed.add(body.appCheckToken);
      return Response.json(already ? {alreadyConsumed: true} : {});
    }
    if (url.host !== 'firestore.googleapis.com') return error(501, 'UNIMPLEMENTED');
    if (url.pathname.endsWith(':beginTransaction')) {
      const id = randomUUID(); this.transactions.set(id, {reads: 0, grant: false}); return Response.json({transaction: id});
    }
    if (url.pathname.endsWith(':batchGet')) {
      const path = body.documents[0].slice(name.length);
      if (!this.transactions.has(body.transaction)) return error(409, 'ABORTED');
      if (path === 'authorization/betaRoster' && this.onGrantRead && this.requests.filter(r => r.path.endsWith(':beginTransaction')).length >= 3) this.onGrantRead();
      const found = this.documents.get(path);
      return Response.json([found ? {found} : {missing: name + path}]);
    }
    if (url.pathname.endsWith(':rollback')) { this.rollbacks++; this.transactions.delete(body.transaction); return Response.json({}); }
    if (url.pathname.endsWith(':commit')) {
      const tx = this.transactions.get(body.transaction); if (!tx) return error(409, 'ABORTED');
      if (body.writes.length && this.conflicts > 0) { this.conflicts--; return error(409, 'ABORTED'); }
      for (const write of body.writes) this.documents.set(write.update.name.slice(name.length), write.update);
      this.transactions.delete(body.transaction); return Response.json({commitTime: new Date().toISOString()});
    }
    const path = url.pathname.split('/documents/')[1];
    const tx = this.transactions.get(url.searchParams.get('transaction')!);
    if (path && tx) {
      tx.reads++;
      if (path === 'authorization/betaRoster' && this.onGrantRead && this.requests.filter(r => r.path.endsWith(':beginTransaction')).length >= 3) this.onGrantRead();
      const doc = this.documents.get(path);
      return doc ? Response.json(doc) : error(404, 'NOT_FOUND');
    }
    return error(501, 'UNIMPLEMENTED');
  }
  async request(options: {uid?: string; token?: string; app?: string; data?: unknown; env?: Env} = {}) {
    const token = options.token ?? await this.token(options.uid), app = options.app ?? await this.appToken();
    return createWorker(this.send).fetch(new Request('https://smartbudget-authorization.synthetic.workers.dev/authorizeSession', {
      method: 'POST', headers: {authorization: `Bearer ${token}`, 'x-firebase-appcheck': app, 'content-type': 'application/json'},
      body: JSON.stringify(options.data ?? {installationId: installation}),
    }), options.env ?? this.env);
  }
  localKeys() { return createLocalJWKSet({keys: [this.jwk]}); }
}

import {createHash} from 'node:crypto';
export function requireHash(s: string) { return createHash('sha256').update(s).digest('hex'); }

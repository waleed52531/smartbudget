import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createWorker} from '../src/index';
import {verifyLease, publicKeys} from '../../../functions/src/leases';
import {APP_ID, PROJECT, GoogleRest} from '../src/firebase_rest';
import {RestTransaction, roster} from '../src/firestore';
import {Fixture, installation, document} from './support';

test('real HTTP adapters issue an unchanged Stage 2 lease and publish public-only keys', async t => {
  const f = await new Fixture().start(); t.after(() => f.close()); f.approve();
  const response = await f.request(); assert.equal(response.status, 200);
  const result = await response.json() as {lease: string};
  const claims = verifyLease(result.lease, publicKeys(f.publicKeys), {projectId: PROJECT, uid: 'synthetic-user',
    installationId: installation, now: Math.floor(Date.now() / 1000), policyVersion: 1});
  assert.equal(claims.exp - claims.iat, 86400);
  assert.equal([...f.documents.keys()].filter(k => k.startsWith('authorizationGrants/')).length, 1);
  const keys = await createWorker(f.send).fetch(new Request('https://worker/leaseVerificationKeys'), f.env);
  assert.deepEqual(await keys.json(), f.publicKeys);
  assert(!JSON.stringify(await (await createWorker(f.send).fetch(new Request('https://worker/leaseVerificationKeys'), f.env)).json()).includes('PRIVATE'));
  for (const host of ['oauth2.googleapis.com', 'www.googleapis.com', 'identitytoolkit.googleapis.com', 'firebaseappcheck.googleapis.com', 'firestore.googleapis.com']) {
    assert(f.requests.some(r => r.host === host), `HTTP path not exercised: ${host}`);
  }
});

for (const scenario of ['unapproved', 'disabled', 'missing-user', 'revoked-token', 'wrong-project', 'wrong-provider', 'wrong-app', 'replayed-app-token', 'forged-uid', 'bad-signature', 'membership-revoked-during-issuance']) {
  test(`${scenario} never produces a grant`, async t => {
    const f = await new Fixture().start(); t.after(() => f.close()); f.approve();
    let token = await f.token(), app = await f.appToken(), data: unknown;
    if (scenario === 'unapproved') f.documents.clear();
    if (scenario === 'disabled') f.disabled = true;
    if (scenario === 'missing-user') f.userMissing = true;
    if (scenario === 'revoked-token') f.validSince = String(Math.floor(Date.now() / 1000) + 1);
    if (scenario === 'wrong-project') token = await f.token('synthetic-user', {aud: 'other-project'});
    if (scenario === 'wrong-provider') token = await f.token('synthetic-user', {firebase: {sign_in_provider: 'anonymous'}});
    if (scenario === 'wrong-app') app = await f.appToken(APP_ID + '-wrong');
    if (scenario === 'replayed-app-token') f.consumed.add(app);
    if (scenario === 'forged-uid') data = {installationId: installation, uid: 'another-user'};
    if (scenario === 'bad-signature') { const parts = token.split('.'); parts[2] = Buffer.alloc(256).toString('base64url'); token = parts.join('.'); }
    if (scenario === 'membership-revoked-during-issuance') f.onGrantRead = () => f.documents.set('authorization/betaRoster', document('authorization/betaRoster', {version: 1, members: []}));
    const response = await f.request({token, app, data}); assert([400, 401, 403].includes(response.status));
    assert.equal([...f.documents.keys()].filter(k => k.startsWith('authorizationGrants/')).length, 0);
    assert(!JSON.stringify(await response.json()).includes(token));
  });
}

for (const host of ['oauth2.googleapis.com', 'identitytoolkit.googleapis.com', 'firebaseappcheck.googleapis.com', 'firestore.googleapis.com', 'www.googleapis.com']) {
  for (const html of [false, true]) test(`${host} ${html ? 'HTML' : 'JSON'} outage returns safe service-unavailable`, async t => {
    const f = await new Fixture().start(); t.after(() => f.close()); f.approve(); f.failHost = host; f.html = html;
    const response = await f.request(); assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), {error: {code: 'unavailable', message: 'Authorization service is unavailable or not configured.'}});
    assert.equal([...f.documents.keys()].filter(k => k.startsWith('authorizationGrants/')).length, 0);
  });
}

test('atomic rate limits enforce ten grants per UID and transaction conflicts retry safely', async t => {
  const f = await new Fixture().start(); t.after(() => f.close()); f.approve(); f.conflicts = 1;
  for (let i = 0; i < 10; i++) assert.equal((await f.request()).status, 200);
  assert.equal((await f.request()).status, 429); assert(f.rollbacks >= 1);
});

test('wrong project, missing configuration, oversized body and unsupported routes fail closed', async t => {
  const f = await new Fixture().start(); t.after(() => f.close()); f.approve();
  assert.equal((await f.request({env: {...f.env, AUTH_EXPECTED_PROJECT: 'other'}})).status, 503);
  assert.equal((await f.request({env: {...f.env, AUTH_PUBLIC_KEY_SET_JSON: '{}'}})).status, 503);
  assert.equal((await f.request({env: {...f.env, AUTH_LEASE_TTL_SECONDS: '86401'}})).status, 503);
  assert.equal((await f.request({data: {installationId: 'x'.repeat(2000)}})).status, 400);
  assert.equal((await createWorker(f.send).fetch(new Request('https://worker/no-such-route'), f.env)).status, 404);
  assert.equal((await createWorker(f.send).fetch(new Request('https://worker/authorizeSession'), f.env)).status, 405);
});

test('roster corruption or more than five active members cannot authorize', () => {
  for (const data of [{version: 1, members: ['same', 'same']}, {version: 1, members: ['a', 'b', 'c', 'd', 'e', 'f']}]) {
    assert.throws(() => roster(data));
  }
});

test('REST adapter cannot read or overwrite unrelated Firestore data', async () => {
  const api = new GoogleRest({token: async () => 'synthetic'}, async () => { throw Error('must not send'); });
  const tx = new RestTransaction(api, 'synthetic');
  await assert.rejects(tx.get('transactions/sensitive'));
  assert.throws(() => tx.set('transactions/sensitive', {amount: 1}));
});

test('upstream redirects cannot forward service credentials to another endpoint', async t => {
  const f = await new Fixture().start(); t.after(() => f.close()); f.approve();
  f.redirectHost = 'oauth2.googleapis.com';
  assert.equal((await f.request()).status, 503);
  assert(!f.requests.some(r => r.path.includes('must-not-follow')));
});

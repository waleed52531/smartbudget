import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Miniflare, Log, LogLevel, Response as RuntimeResponse, convertV4MiniflareOptions} from 'miniflare';
import {Fixture, installation} from './support';
import {publicKeys, verifyLease} from '../../../functions/src/leases';
import {PROJECT} from '../src/firebase_rest';

test('bundled Worker runs in workerd with HTTP Firebase adapters and unchanged signed leases', async t => {
  const f = await new Fixture().start(); t.after(() => f.close()); f.approve();
  const outbound = async (request: any) => {
      const response = await f.send(request.url, {method: request.method, headers: Object.fromEntries(request.headers),
        ...(request.method === 'GET' ? {} : {body: await request.arrayBuffer()})});
      return new RuntimeResponse(await response.arrayBuffer(), {status: response.status, headers: Object.fromEntries(response.headers)});
  };
  const runtime = new Miniflare(convertV4MiniflareOptions({
    modules: true, scriptPath: 'dist/index.js', compatibilityDate: '2026-10-19',
    compatibilityFlags: ['nodejs_compat'], bindings: {...f.env}, outboundService: outbound,
    log: new Log(LogLevel.ERROR),
  }));
  t.after(() => runtime.dispose());
  const app = await f.appToken();
  const response = await runtime.dispatchFetch('https://smartbudget-authorization.synthetic.workers.dev/authorizeSession', {
    method: 'POST', headers: {authorization: `Bearer ${await f.token()}`, 'x-firebase-appcheck': app,
      'content-type': 'application/json'}, body: JSON.stringify({installationId: installation}),
  });
  assert.equal(response.status, 200);
  const result = await response.json() as {lease: string};
  const claims = verifyLease(result.lease, publicKeys(f.publicKeys), {projectId: PROJECT, uid: 'synthetic-user',
    installationId: installation, now: Math.floor(Date.now() / 1000), policyVersion: 1});
  assert.equal(claims.exp - claims.iat, 86400);
  const replay = await runtime.dispatchFetch('https://smartbudget-authorization.synthetic.workers.dev/authorizeSession', {
    method: 'POST', headers: {authorization: `Bearer ${await f.token()}`, 'x-firebase-appcheck': app,
      'content-type': 'application/json'}, body: JSON.stringify({installationId: installation}),
  });
  assert.equal(replay.status, 403);
  assert.equal((await replay.json() as any).error.code, 'app-check-failed');
  assert(f.requests.some(r => r.path.endsWith(':commit')));
});

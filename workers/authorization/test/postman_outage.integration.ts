import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createWorker} from '../src/index';
import {Fixture, installation} from './support';

test('running Worker rejects an Auth key-service outage through the Postman HTTP simulation', async t => {
  const f = await new Fixture().start(); t.after(() => f.close()); f.approve();
  let keyRequests = 0;
  const worker = createWorker(async (input, init) => {
    const url = new URL(String(input));
    if (url.host === 'www.googleapis.com') {
      keyRequests++;
      return fetch(`http://127.0.0.1:4907/google-keys${url.pathname}`, init);
    }
    return f.send(input, init);
  });
  const response = await worker.fetch(new Request('https://worker/authorizeSession', {
    method: 'POST', headers: {authorization: `Bearer ${await f.token()}`, 'x-firebase-appcheck': await f.appToken(),
      'content-type': 'application/json'}, body: JSON.stringify({installationId: installation}),
  }), f.env);
  assert.equal(response.status, 503); assert.equal(keyRequests, 1);
  assert.equal([...f.documents.keys()].filter(k => k.startsWith('authorizationGrants/')).length, 0);
});

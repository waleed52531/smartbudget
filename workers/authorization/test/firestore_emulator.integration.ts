import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {GoogleRest, PROJECT} from '../src/firebase_rest';
import {RestBetaStore, RestFirestore, RestRateLimiter} from '../src/firestore';

// Explicit loopback emulator only. No production account, token or ADC is used.
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^127\.0\.0\.1:\d+$/.test(host)) throw Error('Isolated loopback Firestore emulator is required');
const require = createRequire(new URL('../../../functions/package.json', import.meta.url));
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {FirestoreBetaStore, memberPath} = require('./lib/src/membership.js');
const app = initializeApp({projectId: PROJECT}, 'disposable-worker-rest-emulator');
const sdk = getFirestore(app), admin = new FirestoreBetaStore(sdk);
const api = new GoogleRest({token: async () => 'owner'}, async (input, init) => {
  const url = new URL(String(input));
  assert.equal(url.origin, 'https://firestore.googleapis.com');
  return fetch(`http://${host}${url.pathname}${url.search}`, init);
});
const db = new RestFirestore(api), members = new RestBetaStore(db), rate = new RestRateLimiter(db);

test('real emulator: REST transactions interoperate with the existing secure admin CLI store', async t => {
  t.after(async () => { await sdk.terminate(); await deleteApp(app); });
  const outcomes = await Promise.allSettled(Array.from({length: 6}, (_, i) => admin.approve(`synthetic-rest-${i}`)));
  assert.equal(outcomes.filter(r => r.status === 'fulfilled').length, 5);
  const roster = await admin.status(); assert.equal(roster.length, 5);
  const uid = roster[0];
  await members.assertActive(uid);
  await members.commitGrant(uid, '12345678-1234-4234-9234-123456789abc', 'synthetic-jti', Math.floor(Date.now() / 1000) + 3600);
  const grants = await sdk.collection('authorizationGrants').get(); assert.equal(grants.size, 1);
  for (let i = 0; i < 10; i++) await rate.consume(uid, 1800000000);
  await assert.rejects(rate.consume(uid, 1800000000), (e: any) => e.code === 'resource-exhausted');
  await admin.revoke(uid);
  await assert.rejects(members.commitGrant(uid, '12345678-1234-4234-9234-123456789abc', 'must-not-persist', 1800003600), (e: any) => e.code === 'permission-denied');
  assert.equal((await sdk.collection('authorizationGrants').get()).docs[0].get('jti'), 'synthetic-jti');
  await sdk.doc('authorization/betaRoster').set({version: 1, members: ['duplicate', 'duplicate']});
  await assert.rejects(members.assertActive(roster[1]), (e: any) => e.code === 'unavailable');
  assert.deepEqual((await sdk.doc('authorization/betaRoster').get()).get('members'), ['duplicate', 'duplicate']);
  assert.equal((await sdk.doc(memberPath(uid)).get()).get('state'), 'revoked');
});

// Synthetic cross-language fixture, issued by the actual Stage 2 implementation.
// No private key is persisted or printed. Run after npm run build.
import {createRequire} from 'node:module';
import {generateKeyPairSync} from 'node:crypto';
const require = createRequire(import.meta.url);
const {issueLease} = require('../lib/src/leases.js');
const first = generateKeyPairSync('ed25519'), second = generateKeyPairSync('ed25519');
const publicKey = (pair, kid) => ({kty: 'OKP', crv: 'Ed25519',
  x: pair.publicKey.export({format: 'jwk'}).x, kid, alg: 'EdDSA', use: 'sig'});
const projectId = 'demo-smartbudget-authz', uid = 'synthetic-user';
const installationId = '12345678-1234-4234-8234-123456789abc', now = 1800000000;
const issue = (key, kid, user = uid) => issueLease({projectId, uid: user, installationId, now,
  ttlSeconds: 86400, policyVersion: 1, key, kid, jti: 'synthetic-cross-language-vector'}).lease;
process.stdout.write(JSON.stringify({projectId, uid, secondUid: 'synthetic-second', installationId, now,
  keys: {keys: [publicKey(first, 'first'), publicKey(second, 'second')]},
  lease: issue(first.privateKey, 'first'), rotatedLease: issue(second.privateKey, 'second'),
  secondUserLease: issue(first.privateKey, 'first', 'synthetic-second')}, null, 2) + '\n');

#!/usr/bin/env node
// Operator-only bridge for an existing Firebase CLI login. No credentials are
// exported, copied into a service account, or sent to the authorization Worker.
const {parseArgs} = require('node:util');
const {resolve} = require('node:path');
const {createRequire} = require('node:module');
let stage = 'validate arguments';

async function main() {
  const {values: v} = parseArgs({options: {
    project: {type: 'string'}, 'confirm-project': {type: 'string'},
    email: {type: 'string'}, 'firebase-tools-lib': {type: 'string'},
  }});
  const root = resolve(__dirname, '..');
  const backendRequire = createRequire(root + '/functions/package.json');
  const {checkAdminTarget} = require(root + '/functions/lib/src/admin_cli');
  checkAdminTarget(v.project, v['confirm-project'], false);
  if (!v.email || !v['firebase-tools-lib']) throw Error('Explicit account email and installed Firebase CLI library required.');
  stage = 'administrator CLI authentication';
  const base = resolve(v['firebase-tools-lib']);
  require(base + '/logger').logger.silent = true;
  const cliAuth = require(base + '/auth');
  const {requireAuth} = require(base + '/requireAuth');
  const {Client} = require(base + '/apiv2');
  const operator = cliAuth.getGlobalDefaultAccount();
  if (!operator?.tokens?.refresh_token) throw Error('An existing administrator Firebase CLI login is required.');
  await requireAuth({project: v.project, nonInteractive: true, user: operator.user, tokens: operator.tokens});
  stage = 'project and billing verification';
  const project = (await new Client({urlPrefix: 'https://firebase.googleapis.com', apiVersion: 'v1beta1'})
    .get('/projects/' + v.project)).body;
  const billing = (await new Client({urlPrefix: 'https://cloudbilling.googleapis.com', apiVersion: 'v1'})
    .get('/projects/' + v.project + '/billingInfo')).body;
  if (project.projectId !== 'smartbudget-561d4' || project.projectNumber !== '463515242262' || billing.billingEnabled !== false) {
    throw Error('Project or free-billing guard failed.');
  }
  const credential = {async getAccessToken() {
    const token = await cliAuth.getAccessToken(operator.tokens.refresh_token, [
      'https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase',
    ]);
    return {access_token: token.access_token, expires_in: Math.floor((token.expires_at - Date.now()) / 1000)};
  }};
  stage = 'administrator SDK initialization';
  const {initializeApp, deleteApp} = backendRequire('firebase-admin/app');
  const {getAuth} = backendRequire('firebase-admin/auth');
  const {Firestore} = backendRequire('@google-cloud/firestore');
  const {GoogleAuth, OAuth2Client} = backendRequire('google-auth-library');
  const {FirestoreBetaStore} = require(root + '/functions/lib/src/membership');
  const app = initializeApp({projectId: v.project, credential});
  let db;
  try {
    // Resolve identity through the administrator API, never a client-supplied UID.
    stage = 'authoritative account lookup';
    const user = await getAuth(app).getUserByEmail(v.email);
    if (user.disabled || !user.providerData.some(p => p.providerId === 'password')) {
      throw Error('An enabled email/password account is required.');
    }
    const access = await credential.getAccessToken();
    const oauth = new OAuth2Client();
    oauth.setCredentials({access_token: access.access_token, expiry_date: Date.now() + access.expires_in * 1000});
    db = new Firestore({projectId: v.project, preferRest: true, auth: new GoogleAuth({authClient: oauth})});
    const members = new FirestoreBetaStore(db);
    stage = 'transactional membership approval';
    await members.approve(user.uid);
    stage = 'membership readback';
    const active = await members.status();
    if (!active.includes(user.uid) || active.length > 5) throw Error('Membership readback failed.');
    process.stdout.write(JSON.stringify({approvedVerifiedAccount: true, activeMembers: active.length, maximumMembers: 5}) + '\n');
  } finally {
    if (db) await db.terminate();
    await deleteApp(app);
  }
}

main().catch(error => {
  const code = typeof error.code === 'string' && /^[a-zA-Z0-9_/-]{1,70}$/.test(error.code) ? error.code : undefined;
  process.stderr.write(JSON.stringify({failed: true, stage, code}) + '\n');
  process.stderr.write('Provisioning failed; no success is implied. Check the explicit target, administrator login, IAM and roster state before retrying. Details withheld to protect credentials and account records.\n');
  process.exitCode = 1;
});

#!/usr/bin/env node
// PREPARED ONLY. Issuing a real-data grant requires separate user approval.
const {parseArgs} = require('node:util');
const {createRequire} = require('node:module');
const {resolve, dirname, relative, isAbsolute, sep} = require('node:path');
const {readFileSync, writeFileSync, realpathSync, statSync} = require('node:fs');
const root = resolve(__dirname, '..');
const backend = createRequire(root + '/functions/package.json');
let app, db;
async function main() {
  const {values: v} = parseArgs({options: {
    project: {type:'string'}, 'confirm-project': {type:'string'}, email: {type:'string'},
    'confirm-ownership': {type:'boolean'}, 'database-id': {type:'string'}, 'source-id': {type:'string'},
    'key-file': {type:'string'}, kid: {type:'string'}, output: {type:'string'}, 'firebase-tools-lib': {type:'string'},
  }});
  require(root + '/functions/lib/src/admin_cli').checkAdminTarget(v.project, v['confirm-project'], false);
  if (!v['confirm-ownership'] || ['email','database-id','source-id','key-file','kid','output','firebase-tools-lib'].some(k => !v[k])) throw Error();
  for (const file of [v['key-file'],v.output]) {
    const path = resolve(realpathSync(dirname(file)), require('node:path').basename(file));
    const r = relative(realpathSync(root), path);
    if (!(r === '..' || r.startsWith('..' + sep) || isAbsolute(r))) throw Error();
    if ((statSync(dirname(path)).mode & 0o077) !== 0) throw Error();
  }
  const privatePath = realpathSync(v['key-file']);
  const r = relative(realpathSync(root), privatePath);
  if (!(r === '..' || r.startsWith('..' + sep) || isAbsolute(r)) || (statSync(privatePath).mode & 0o077) !== 0) throw Error();
  const base = resolve(v['firebase-tools-lib']);require(base + '/logger').logger.silent = true;
  const auth = require(base + '/auth'), {requireAuth} = require(base + '/requireAuth'), {Client} = require(base + '/apiv2');
  const operator = auth.getGlobalDefaultAccount();
  if (!operator?.tokens?.refresh_token) throw Error();
  await requireAuth({project:v.project, nonInteractive:true, user:operator.user, tokens:operator.tokens});
  const p = (await new Client({urlPrefix:'https://firebase.googleapis.com',apiVersion:'v1beta1'}).get('/projects/'+v.project)).body;
  const billing = (await new Client({urlPrefix:'https://cloudbilling.googleapis.com',apiVersion:'v1'}).get('/projects/'+v.project+'/billingInfo')).body;
  if (p.projectId !== 'smartbudget-561d4' || p.projectNumber !== '463515242262' || billing.billingEnabled !== false) throw Error();
  const credential = {async getAccessToken() {
    const t = await auth.getAccessToken(operator.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase']);
    return {access_token:t.access_token, expires_in:Math.floor((t.expires_at-Date.now())/1000)};
  }};
  app = backend('firebase-admin/app').initializeApp({projectId:v.project,credential});
  const user = await backend('firebase-admin/auth').getAuth(app).getUserByEmail(v.email);
  if (user.disabled || !user.providerData.some(p=>p.providerId==='password')) throw Error();
  const {GoogleAuth,OAuth2Client}=backend('google-auth-library');
  const oauth=new OAuth2Client(),access=await credential.getAccessToken();
  oauth.setCredentials({access_token:access.access_token,expiry_date:Date.now()+access.expires_in*1000});
  db=new (backend('@google-cloud/firestore').Firestore)({projectId:v.project,preferRest:true,auth:new GoogleAuth({authClient:oauth})});
  await new (require(root+'/functions/lib/src/membership').FirestoreBetaStore)(db).assertActive(user.uid);
  const {publicKeys,signer}=require(root+'/functions/lib/src/leases');
  const response=await fetch('https://smartbudget-authorization.corehines-smartbudget.workers.dev/leaseVerificationKeys',{redirect:'error',signal:AbortSignal.timeout(15000)});
  if(!response.ok)throw Error();
  const keys=publicKeys(await response.json());
  const key=signer(readFileSync(privatePath,'utf8'),v.kid,keys);
  const grant=require(root+'/functions/lib/src/legacy_ownership').issueLegacyOwnership({project:v.project,uid:user.uid,databaseId:v['database-id'],sourceId:v['source-id'],now:Math.floor(Date.now()/1000),ttl:3600,kid:v.kid,key});
  writeFileSync(v.output,JSON.stringify({grant})+'\n',{flag:'wx',mode:0o600});
  process.stdout.write('Administrator-approved ownership grant saved privately; expires in one hour. No financial data imported.\n');
}
main().catch(()=>{process.stderr.write('Ownership approval failed; no grant or import success is implied. Details withheld to protect credentials.\n');process.exitCode=1;})
  .finally(async()=>{if(db)await db.terminate();if(app)await backend('firebase-admin/app').deleteApp(app);});

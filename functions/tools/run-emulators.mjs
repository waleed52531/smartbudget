// No production project, credentials, persistent private keys or billing calls.
import {generateKeyPairSync} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readdirSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
// The CLI reads dotenv files independently of the child environment and may
// persist emulator parameter defaults. Never reuse or overwrite operator config.
if (readdirSync(resolve(root, 'functions')).some(name =>
  (name === '.env' || name.startsWith('.env.') || name === '.secret.local') && name !== '.env.example')) {
  throw new Error('Use a clean worktree without operator dotenv/secret files for emulator tests.');
}
const pair = generateKeyPairSync('ed25519');
const jwk = pair.publicKey.export({format: 'jwk'});
const configurationDirectory = mkdtempSync(resolve(tmpdir(), 'smartbudget-emulators-'));
// Do not inherit API keys, tokens, DEBUG logging, or the CLI's saved login.
const environment = Object.fromEntries(['PATH', 'HOME', 'JAVA_HOME', 'TMPDIR', 'LANG', 'LC_ALL',
  'SYSTEMROOT', 'TEMP', 'TMP'].filter(k => process.env[k]).map(k => [k, process.env[k]]));
const env = {...environment,
  XDG_CONFIG_HOME: configurationDirectory, CLOUDSDK_CONFIG: configurationDirectory,
  GOOGLE_APPLICATION_CREDENTIALS: resolve(configurationDirectory, 'no-credentials.json'),
  SMARTBUDGET_TEST_SIGNING_KEY: pair.privateKey.export({format: 'pem', type: 'pkcs8'}),
  SMARTBUDGET_TEST_JWKS: JSON.stringify({keys: [{kty: 'OKP', crv: 'Ed25519', x: jwk.x,
    kid: 'emulator-only', alg: 'EdDSA', use: 'sig'}]}),
  GCLOUD_PROJECT: 'demo-smartbudget-authz', GOOGLE_CLOUD_PROJECT: 'demo-smartbudget-authz',
  AUTH_EXPECTED_PROJECT: 'demo-smartbudget-authz', AUTH_REGION: 'asia-south1',
  AUTH_SERVICE_ACCOUNT: 'emulator-only@demo-smartbudget-authz.iam.gserviceaccount.com',
  AUTH_SIGNING_KEY_ID: 'emulator-only', AUTH_PUBLIC_KEY_SET_JSON: '{"keys":[]}',
  CI: 'true', FIREBASE_CLI_DISABLE_UPDATE_CHECK: 'true',
};
try {
  const result = spawnSync('firebase', ['emulators:exec', '--project', 'demo-smartbudget-authz',
    '--config', 'firebase.emulators.json', '--only', 'auth,firestore,functions',
    process.argv.includes('--flutter') ? 'node functions/tools/run-client-tests.mjs' :
      'npm --prefix functions run test:integration'], {cwd: root, env, stdio: 'inherit'});
  process.exitCode = result.status ?? 1;
} finally {
  rmSync(resolve(root, 'functions/.env.local'), {force: true});
  rmSync(configurationDirectory, {recursive: true, force: true});
}

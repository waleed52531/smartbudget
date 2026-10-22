import {spawnSync} from 'node:child_process';
if (process.env.GCLOUD_PROJECT !== 'demo-smartbudget-authz' ||
    process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080' ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099' || process.env.GEMINI_API_KEY) {
  throw new Error('Isolated demo emulator environment required.');
}
for (const [command, args] of [
  ['npm', ['--prefix', 'functions', 'run', 'test:integration']],
  ['python3', ['tool/clean_run.py', 'flutter', 'test', 'test/auth/backend_emulator_test.dart',
    '--dart-define=SMARTBUDGET_AUTH_EMULATOR_TEST=true']],
]) {
  const result = spawnSync(command, args, {stdio: 'inherit', env: process.env});
  if (result.status !== 0) { process.exitCode = result.status ?? 1; break; }
}

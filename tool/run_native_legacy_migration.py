#!/usr/bin/env python3
"""Explicit disposable Stage 5 device acceptance; restores the configured app."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid
from clean_run import clean_environment, redact

ROOT = Path(__file__).resolve().parents[1]
PKG = 'com.corehines.smartbudget'
LEGACY_HASH = '51b830d0d59683994c0b579a1a2c55496fb10a19f79fd16d323f8603ee65968f'
BACKUP_HASH = '4fbe5a990460efd757dcebae0d870c9538ef7d08c469d8d7b6bab94fbc2e9b7a'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    args = parser.parse_args()
    os.chdir(ROOT)
    env = clean_environment(os.environ)
    flutter = str(Path.home() / 'development/flutter/bin/flutter')
    adb = [str(Path.home() / 'Library/Android/sdk/platform-tools/adb'), '-s', args.device]
    run = uuid.uuid4().hex[:12]
    output = Path(tempfile.mkdtemp(prefix='smartbudget-stage5-native-'))
    output.chmod(0o700)
    print('Disposable native evidence:', output, flush=True)
    apk = ROOT / 'build/app/outputs/flutter-apk/app-debug.apk'
    private = Path.home() / 'SmartBudgetPrivate/authorization-20261022/tecno-debug.defines.json'
    debug = json.loads(private.read_text())['SMARTBUDGET_APP_CHECK_DEBUG_TOKEN']
    normal = output / 'normal-configured.apk'

    def read(command):
        p = subprocess.run(command, env=env, capture_output=True, timeout=30)
        if p.returncode:
            raise RuntimeError('Read-only device check failed; output withheld.')
        return p.stdout.decode().strip()

    def step(name, command):
        print(name, flush=True)
        with (output / (name + '.log')).open('w') as log:
            p = subprocess.Popen(command, env=env, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True, errors='replace')
            for line in p.stdout:
                log.write(redact(line.replace(debug, '[REDACTED_APP_CHECK_DEBUG_TOKEN]'), ''))
            if p.wait():
                raise RuntimeError(name + ' failed; inspect its sanitized log.')

    def legacy_hash():
        return read(adb + ['shell', 'run-as', 'com.example.smartbudget', 'sha256sum',
                           'app_flutter/monthly_budget.sqlite']).split()[0]

    backup = Path.home() / 'SmartBudgetBackups/tecno-legacy-20261021T115349Z-l5f1mo2p/legacy_snapshot.sqlite'
    if read(adb + ['shell', 'getprop', 'ro.product.model']) != 'TECNO CM6':
        raise RuntimeError('Intended TECNO required.')
    if legacy_hash() != LEGACY_HASH or hashlib.sha256(backup.read_bytes()).hexdigest() != BACKUP_HASH:
        raise RuntimeError('Legacy safety gate failed.')
    step('build-normal', [flutter, 'build', 'apk', '--debug', '--no-pub', '--target-platform',
                          'android-arm64', '--dart-define-from-file=' + str(private)])
    normal.write_bytes(apk.read_bytes())
    normal.chmod(0o600)
    definitions = output / 'synthetic-defines.json'
    definitions.write_text(json.dumps({'NATIVE_STAGE5_RUN': run,
        'NATIVE_STAGE5_SCHEMA': base64.b64encode((ROOT / 'test/fixtures/schema_v2.sql').read_bytes()).decode()}))
    changed = False
    try:
        step('build-disposable', [flutter, 'build', 'apk', '--debug', '--no-pub', '--target-platform',
            'android-arm64', '--target', 'tool/native_legacy_migration_acceptance.dart',
            '--dart-define-from-file=' + str(definitions)])
        changed = True
        step('stop-new-app', adb + ['shell', 'am', 'force-stop', PKG])
        step('install-disposable', adb + ['install', '--no-streaming', '-r', '-t', str(apk)])
        report = 'no_backup/user_storage_v1/stage5-acceptance-' + run + '.json'
        for phase in ['prepared', 'reopened']:
            step('start-' + phase, adb + ['shell', 'am', 'start', '-n', PKG + '/.MainActivity'])
            deadline = time.monotonic() + 60
            while True:
                p = subprocess.run(adb + ['shell', 'run-as', PKG, 'cat', report],
                                   env=env, capture_output=True, text=True, timeout=10)
                try:
                    result = json.loads(p.stdout)
                except ValueError:
                    result = {}
                if result.get('status') == 'failed':
                    raise RuntimeError('Native probe failed; all disposable artifacts retained.')
                if result.get('status') == phase:
                    (output / (phase + '.json')).write_text(json.dumps(result, indent=2))
                    break
                if time.monotonic() > deadline:
                    raise RuntimeError('Native report timed out; no success claimed.')
                time.sleep(1)
            step('stop-' + phase, adb + ['shell', 'am', 'force-stop', PKG])
        if legacy_hash() != LEGACY_HASH or hashlib.sha256(backup.read_bytes()).hexdigest() != BACKUP_HASH:
            raise RuntimeError('Legacy final safety check failed.')
        print(json.dumps({'nativeMigration': 'passed', 'coldEncryptedReopen': 'passed',
                          'legacyAndBackupUnchanged': True, 'testProject': 'migration-test-' + run}), flush=True)
    finally:
        if changed:
            step('restore-configured-app', adb + ['install', '--no-streaming', '-r', '-t', str(normal)])
            step('start-configured-app', adb + ['shell', 'am', 'start', '-n', PKG + '/.MainActivity'])
        apk.write_bytes(normal.read_bytes())
        apk.chmod(0o600)


if __name__ == '__main__':
    main()

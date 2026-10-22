#!/usr/bin/env python3
"""Explicit device acceptance; never clears/uninstalls apps or writes legacy data.

Run through clean_run.py. Builds one debug-only entry point for one unique test
project, force-stops only the NEW app between them, then restores a normal APK.
"""
import argparse
import base64
import hashlib
import fcntl
import shutil
import json
import os
from pathlib import Path
import re
import subprocess
import threading
import time
import uuid
from clean_run import clean_environment, redact

PKG = 'com.corehines.smartbudget'
ROOT = 'no_backup/user_storage_v1'
SUPPORT = PKG + '.NativeStorageAcceptanceSupportTest'
RUNNER = PKG + '.test/androidx.test.runner.AndroidJUnitRunner'


def main():
    os.chdir(Path(__file__).resolve().parents[1])
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', required=True)
    args = parser.parse_args()
    environment = clean_environment(os.environ)
    # Never let another acceptance run update the same APK/device concurrently.
    device_lock = open('/private/tmp/smartbudget-native-acceptance.lock', 'a+')
    try:
        fcntl.flock(device_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print('Another native acceptance run is active; no device action taken.', flush=True)
        return 2
    run_id = uuid.uuid4().hex[:12]
    output = Path('/private/tmp') / ('smartbudget-stage4-native-' + run_id)
    output.mkdir(mode=0o700)
    print('Acceptance evidence:', output, flush=True)
    (Path('/private/tmp') / 'smartbudget-stage4-acceptance-active-run.txt').write_text(str(output))
    sdk = Path(environment.get('ANDROID_SDK_ROOT') or environment.get('ANDROID_HOME') or str(Path.home() / 'Library/Android/sdk'))
    adb = [str(sdk / 'platform-tools/adb'), '-s', args.device]
    summary = {'runId': run_id, 'project': 'native-acceptance-' + run_id}
    raw_lines = []
    logcat = None
    thread = None
    installed_harness = False
    normal_restored = False

    def step(name, command):
        if command[0] == 'flutter':
            command = [str(Path(environment.get('FLUTTER_ROOT') or (Path.home() / 'development/flutter')) / 'bin/flutter')] + command[1:]
        print(name, flush=True)
        with (output / (name + '.log')).open('w') as log:
            child = subprocess.Popen(command, env=environment, stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT, text=True, errors='replace')
            for line in child.stdout:
                log.write(redact(line, ''))
            code = child.wait()
        if code:
            raise RuntimeError(name + ' failed; inspect its sanitized log')

    def capture(command, require=True):
        result = subprocess.run(command, env=environment, capture_output=True, text=True)
        if require and result.returncode:
            raise RuntimeError('Read-only device command failed')
        return result

    def data_file(name, wait=False):
        start = time.monotonic()
        while True:
            r = capture(adb + ['shell', 'run-as', PKG, 'cat', ROOT + '/' + name], False)
            if r.returncode == 0:
                return json.loads(r.stdout)
            if not wait or time.monotonic() - start > 120:
                progress = capture(adb + ['shell','run-as',PKG,'cat',ROOT + '/acceptance-' + run_id + '-progress.json'],False)
                if progress.returncode == 0:
                    (output / 'progress-diagnostic.json').write_text(progress.stdout)
                raise RuntimeError('Acceptance result unavailable')
            time.sleep(1)

    def instrument(name, method):
        step(name, adb + ['shell', 'am', 'instrument', '-w', '-r', '-e', 'class',
                          SUPPORT + '#' + method, '-e', 'acceptanceRun', run_id, RUNNER])
        content = (output / (name + '.log')).read_text()
        if not re.search(r'OK \(1 test\)', content) or 'FAILURES!!!' in content:
            raise RuntimeError(name + ' instrumentation assertion failed')

    try:
        model = capture(adb + ['shell', 'getprop', 'ro.product.model']).stdout.strip()
        abi = capture(adb + ['shell', 'getprop', 'ro.product.cpu.abi']).stdout.strip()
        if model != 'TECNO CM6' or abi != 'arm64-v8a':
            raise RuntimeError('This run is approved for the intended TECNO ARM64 device only')
        summary['device'] = model
        uid_text = capture(adb + ['shell', 'pm', 'list', 'packages', '-U', PKG]).stdout
        match = re.search(r'package:com\.corehines\.smartbudget uid:(\d+)\b', uid_text)
        if not match:
            raise RuntimeError('New application UID unavailable')
        logcat = subprocess.Popen(adb + ['logcat', '--uid=' + match.group(1), '-T', '1', '-v', 'threadtime'],
                                  env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  text=True, errors='replace')
        def read_logs():
            for line in logcat.stdout:
                raw_lines.append(line)
        thread = threading.Thread(target=read_logs, daemon=True)
        thread.start()
        for phase in ['prepare', 'reopen']:
            if phase == 'prepare':
                step('build-' + phase, ['flutter', 'build', 'apk', '--debug', '--target-platform', 'android-arm64',
                        '--target=tool/native_storage_acceptance.dart', '--dart-define=NATIVE_ACCEPTANCE_RUN=' + run_id])
                # Snapshot the exact built artifact before any device transfer.
                probe_apk = output / 'probe.apk'
                shutil.copy2('build/app/outputs/flutter-apk/app-debug.apk', probe_apk)
                # Same-signature updates preserve data; never uninstall on error.
                step('install-' + phase, adb + ['install', '-r', '-t', str(probe_apk)])
                installed_harness = True
            step('fresh-process-' + phase, adb + ['shell','am','force-stop',PKG])
            step('start-' + phase, adb + ['shell', 'am', 'start', '-n', PKG + '/.MainActivity'])
            result = data_file('acceptance-' + run_id + '-' + phase + '-result.json', True)
            (output / (phase + '-result.json')).write_text(json.dumps(result, indent=2))
            summary[phase] = result
            if result.get('status') != 'passed':
                raise RuntimeError(phase + ' failed: ' + str(result.get('failure', 'unknown')))
            registry = data_file('acceptance-' + run_id + '-registry.json')
            (output / 'registry.json').write_text(json.dumps(registry, indent=2))
            step('stop-' + phase, adb + ['shell', 'am', 'force-stop', PKG])
            if phase == 'prepare':
                instrument('backup-and-ordinary-sqlite', 'backupExclusionsAndOrdinarySQLiteRejection')
                instrument('remove-disposable-wrapping-key', 'removeOnlyDisposableMissingWrappingKey')
                step('stop-before-restart', adb + ['shell', 'am', 'force-stop', PKG])
        instrument('no-replacement-and-disposable-cleanup', 'confirmNoReplacementAndCleanupOnlyPassedDisposableRun')
        summary['status'] = 'passed'
    except Exception as error:
        summary['status'] = 'failed'
        summary['failure'] = str(error)
    finally:
        if logcat is not None:
            logcat.terminate()
            try:
                logcat.wait(timeout=5)
            except subprocess.TimeoutExpired:
                logcat.kill()
            thread.join(timeout=5)
        text = ''.join(raw_lines)
        fingerprints = set()
        for phase in ['prepare', 'reopen']:
            fingerprints.update(summary.get(phase, {}).get('keyDigests', {}).values())
        leaked = set()
        for candidate in re.findall(r'(?<![0-9A-Fa-f])[0-9A-Fa-f]{64}(?![0-9A-Fa-f])', text):
            if hashlib.sha256(bytes.fromhex(candidate)).hexdigest() in fingerprints:
                leaked.add(candidate)
        for candidate in re.findall(r'(?<![A-Za-z0-9_+/\-])[A-Za-z0-9_+/\-]{43}=?(?![A-Za-z0-9_+/\-])', text):
            try:
                value = base64.urlsafe_b64decode(candidate + '=' * (-len(candidate) % 4))
                if len(value) == 32 and hashlib.sha256(value).hexdigest() in fingerprints:
                    leaked.add(candidate)
            except ValueError:
                pass
        for candidate in re.findall(r'\[(?:\d{1,3},\s*){31}\d{1,3}\]', text):
            values = [int(v) for v in re.findall(r'\d+', candidate)]
            if all(v <= 255 for v in values) and hashlib.sha256(bytes(values)).hexdigest() in fingerprints:
                leaked.add(candidate)
        note_found = 'private-acceptance-' + run_id in text
        summary['logScan'] = {'keyRepresentationsFound': len(leaked), 'syntheticFinancialNoteFound': note_found,
                              'capturedLines': len(raw_lines), 'fingerprintedKeys': len(fingerprints)}
        for value in leaked:
            text = text.replace(value, '[REDACTED_DATABASE_KEY]')
        text = text.replace('private-acceptance-' + run_id, '[REDACTED_SYNTHETIC_FINANCIAL_NOTE]')
        (output / 'new-app-logcat.redacted.log').write_text(''.join(redact(line, '') for line in text.splitlines(True)))
        if summary.get('status') == 'passed' and (len(raw_lines) < 5 or 'logcat: unknown' in text.lower() or 'logcat: invalid' in text.lower()):
            summary['status'] = 'failed'
            summary['failure'] = 'Insufficient app-UID logcat coverage'
        if leaked or note_found:
            summary['status'] = 'failed'
            summary['failure'] = 'Sensitive test canary appeared in new-app logs'
        if installed_harness:
            try:
                step('stop-before-normal-restore', adb + ['shell', 'am', 'force-stop', PKG])
                step('build-normal-debug', ['flutter', 'build', 'apk', '--debug', '--target-platform', 'android-arm64', '--target=lib/main.dart'])
                normal_apk = output / 'normal-app.apk'
                shutil.copy2('build/app/outputs/flutter-apk/app-debug.apk', normal_apk)
                step('restore-normal-debug', adb + ['install', '-r', '-t', str(normal_apk)])
                normal_restored = True
            except Exception:
                summary['status'] = 'failed'
                summary['restoreFailure'] = 'Normal debug restore failed; new app remains stopped. No uninstall attempted.'
        summary['normalAppRestored'] = normal_restored
        (output / 'summary.json').write_text(json.dumps(summary, indent=2))
        print(json.dumps({'status': summary['status'], 'evidence': str(output),
                          'failure': summary.get('failure'), 'normalAppRestored': normal_restored,
                          'logScan': summary['logScan']}, indent=2), flush=True)
    return 0 if summary['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())

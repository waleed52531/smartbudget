#!/usr/bin/env python3
"""Run Worker REST interoperability against an isolated disposable emulator."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from clean_run import clean_environment, redact


def main():
    root = Path(__file__).resolve().parent.parent
    with tempfile.TemporaryDirectory(prefix='smartbudget-worker-firestore-') as temp:
        config = Path(temp) / 'firebase.json'
        config.write_text(json.dumps({
            'firestore': {'rules': str(root / 'firestore.rules')},
            'emulators': {'firestore': {'host': '127.0.0.1', 'port': 8189},
                          'ui': {'enabled': False}, 'singleProjectMode': False},
        }))
        env = clean_environment(os.environ)
        env.update({'XDG_CONFIG_HOME': temp, 'CLOUDSDK_CONFIG': temp,
                    'GOOGLE_APPLICATION_CREDENTIALS': str(Path(temp) / 'no-credentials.json'),
                    'CI': 'true', 'FIREBASE_CLI_DISABLE_UPDATE_CHECK': 'true'})
        firebase = shutil.which('firebase', path=env.get('PATH'))
        child = subprocess.Popen([firebase, 'emulators:exec', '--project', 'demo-smartbudget-worker',
                                  '--config', str(config), '--only', 'firestore',
                                  'node --import tsx --test test/firestore_emulator.integration.ts'],
                                 cwd=root / 'workers/authorization', env=env,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in child.stdout:
            print(redact(line, os.environ.get('GEMINI_API_KEY', '')), end='', flush=True)
        return child.wait()


if __name__ == '__main__':
    raise SystemExit(main())

#!/usr/bin/env python3
"""Run the configured Android beta without putting attestation secrets in argv."""
import argparse
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import uuid

from clean_run import clean_environment, redact

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DEFINES = (
    Path.home() / "SmartBudgetPrivate/authorization-20261022/tecno-debug.defines.json"
)
ORIGIN = "https://smartbudget-authorization.corehines-smartbudget.workers.dev"


def read_definitions(path):
    destination = path.resolve(strict=True)
    if ROOT == destination or ROOT in destination.parents:
        raise ValueError("Keep the private debug definitions outside the repository.")
    info = destination.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077 or info.st_uid != os.getuid():
        raise ValueError("Private debug definitions must be owner-only and owned by you.")
    definitions = json.loads(destination.read_text())
    if definitions.get("SMARTBUDGET_AUTH_ORIGIN") != ORIGIN:
        raise ValueError("Debug definitions must select the approved authorization backend.")
    token = definitions.get("SMARTBUDGET_APP_CHECK_DEBUG_TOKEN")
    if not isinstance(token, str) or str(uuid.UUID(token, version=4)) != token.lower():
        raise ValueError("The private registered App Check debug definition is missing or invalid.")
    if set(definitions) != {"SMARTBUDGET_AUTH_ORIGIN", "SMARTBUDGET_APP_CHECK_DEBUG_TOKEN"}:
        raise ValueError("Unexpected debug definitions; review them before running.")
    return destination, token


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", help="Flutter device ID (otherwise Flutter asks).")
    parser.add_argument("--defines", type=Path, default=DEFAULT_DEFINES)
    args = parser.parse_args()
    try:
        definitions, token = read_definitions(args.defines)
    except (OSError, ValueError, TypeError, AttributeError):
        print("Private beta debug settings are missing or invalid. Recover the registered "
              "owner-only definitions file; no replacement token was generated.", file=sys.stderr)
        return 2
    environment = clean_environment(os.environ)
    flutter = shutil.which("flutter", path=environment.get("PATH"))
    if flutter is None:
        flutter = str(Path.home() / "development/flutter/bin/flutter")
    command = [flutter, "run", "--debug", "--dart-define-from-file=" + str(definitions)]
    if args.device:
        command += ["--device-id", args.device]
    print("Starting the configured Smart Budget debug app; private values are withheld.", flush=True)
    child = subprocess.Popen(command, cwd=ROOT, env=environment,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, errors="replace", bufsize=1)
    try:
        for line in child.stdout:
            print(redact(line.replace(token, "[REDACTED_APP_CHECK_DEBUG_TOKEN]"),
                         os.environ.get("GEMINI_API_KEY", "")), end="", flush=True)
        return child.wait()
    except KeyboardInterrupt:
        child.terminate()
        return child.wait()


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Run Smart Budget development commands without inherited service credentials."""
import os
import re
import subprocess
import sys

SAFE_ENVIRONMENT = {
    "PATH", "HOME", "USER", "LOGNAME", "SHELL", "TMPDIR", "TMP", "TEMP",
    "LANG", "LC_ALL", "LC_CTYPE", "TERM", "NO_COLOR", "CI",
    "JAVA_HOME", "ANDROID_HOME", "ANDROID_SDK_ROOT", "ANDROID_USER_HOME",
    "FLUTTER_ROOT", "PUB_CACHE", "GRADLE_USER_HOME", "DEVELOPER_DIR", "SDKROOT",
    "SYSTEMROOT", "APPDATA", "LOCALAPPDATA", "XDG_CACHE_HOME",
}


def clean_environment(source):
    return {key: value for key, value in source.items() if key in SAFE_ENVIRONMENT}


def redact(line, exposed):
    if exposed:
        line = line.replace(exposed, "[REDACTED]")
    line = re.sub(r"AIza[0-9A-Za-z_-]{30,}", "[REDACTED_API_KEY]", line)
    line = re.sub(r"(?i)Bearer\s+[A-Za-z0-9_.-]+", "Bearer [REDACTED]", line)
    line = re.sub(r'(?i)([?&](?:oobCode|token|key|apiKey)=)[^&\s]+', r'\1[REDACTED]', line)
    return re.sub(r'(?i)("(?:idToken|refreshToken|password|private_key)"\s*:\s*)"(?:\\.|[^"\\])*"',
                  r'\1"[REDACTED]"', line)


def main():
    if len(sys.argv) < 2:
        raise SystemExit("Usage: python3 tool/clean_run.py <command> [arguments]")
    exposed = os.environ.get("GEMINI_API_KEY", "")
    child = subprocess.Popen(sys.argv[1:], env=clean_environment(os.environ),
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, errors="replace", bufsize=1)
    try:
        for line in child.stdout:
            sys.stdout.write(redact(line, exposed))
            sys.stdout.flush()
        return child.wait()
    except KeyboardInterrupt:
        child.terminate()
        return child.wait()


if __name__ == "__main__":
    sys.exit(main())

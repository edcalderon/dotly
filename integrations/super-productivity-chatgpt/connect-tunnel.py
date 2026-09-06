#!/usr/bin/env python3
"""Finish the account-owned tunnel connection without exposing credentials in argv."""
import getpass
import argparse
import os
from pathlib import Path
import re
import shlex
import subprocess

home = Path.home()
binary = home / '.local/bin/tunnel-client'
launcher = home / '.local/bin/super-productivity-chatgpt'
if not binary.is_file() or not launcher.is_file():
    raise SystemExit('Install the bridge and the official tunnel-client first; see README.md.')
print('Create a tunnel associated with your ChatGPT workspace at:')
print('https://platform.openai.com/settings/organization/tunnels')
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--tunnel-id', help='Existing tunnel ID; skips the ID prompt.')
args = parser.parse_args()
tunnel_id = (args.tunnel_id or input('Tunnel ID: ')).strip()
if not re.fullmatch(r'tunnel_[A-Za-z0-9_-]+', tunnel_id):
    raise SystemExit('Expected an OpenAI tunnel ID starting with tunnel_.')
directory = home / '.config/super-productivity-chatgpt'
directory.mkdir(parents=True, exist_ok=True, mode=0o700)
directory.chmod(0o700)
keyfile = directory / 'tunnel-runtime-key'
key = getpass.getpass('Runtime API key (hidden; Enter keeps the saved key): ').strip()
if key:
    if not key.startswith('sk-') or any(c.isspace() for c in key):
        raise SystemExit('Expected a runtime API key, not an admin key or a browser login token.')
    fd = os.open(keyfile, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as f:
        os.fchmod(f.fileno(), 0o600)
        f.write(key)
elif not keyfile.is_file():
    raise SystemExit('A runtime key is required.')
subprocess.run([
    str(binary), 'runtimes', 'connect', '--alias', 'super-productivity',
    '--tunnel-id', tunnel_id, '--mcp-command', shlex.quote(str(launcher)),
    '--runtime-api-key', 'file:' + str(keyfile),
], check=True)
subprocess.run([str(binary), 'runtimes', 'status', 'super-productivity', '--json'], check=True)
print('In ChatGPT developer-mode connection settings, choose Tunnel and select: ' + tunnel_id)
print('Attach the connection inside your ChatGPT Project and run the checks in README.md.')

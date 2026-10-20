#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -f "$fixture/scripts/create-ssh-key.sh" "$fixture/.local/ssh/ww-demo" "$fixture/.local/ssh/ww-demo.pub" "$fixture/output"; rmdir "$fixture/scripts" "$fixture/.local/ssh" "$fixture/.local" "$fixture"' EXIT
mkdir "$fixture/scripts"
cp "$repo_root/scripts/create-ssh-key.sh" "$fixture/scripts/"

bash "$fixture/scripts/create-ssh-key.sh"
key="$fixture/.local/ssh/ww-demo"
before=$(cksum "$key" "$key.pub")
bash "$fixture/scripts/create-ssh-key.sh"
test "$before" = "$(cksum "$key" "$key.pub")"
if find "$key" -perm -004 -o -perm -040 | grep -q .; then
    echo 'FAIL: private key is readable by group or others.' >&2
    exit 1
fi

printf 'ssh-ed25519 invalid wrong-key\n' > "$key.pub"
if bash "$fixture/scripts/create-ssh-key.sh" > "$fixture/output" 2>&1; then
    echo 'FAIL: mismatched key pair was accepted.' >&2
    exit 1
fi
grep -q 'do not match' "$fixture/output"
rm "$key.pub"
if bash "$fixture/scripts/create-ssh-key.sh" > "$fixture/output" 2>&1; then
    echo 'FAIL: incomplete key pair was overwritten.' >&2
    exit 1
fi
grep -q 'Incomplete demo key pair' "$fixture/output"
echo 'PASS: key generation, reuse, permissions, and overwrite protection.'

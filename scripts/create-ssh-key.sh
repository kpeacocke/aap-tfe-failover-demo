#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
key_dir="$repo_root/.local/ssh"
key_path="$key_dir/ww-demo"
umask 077
mkdir -p "$key_dir"

if [[ -e "$key_path" || -e "$key_path.pub" ]]; then
    if [[ ! -f "$key_path" || ! -f "$key_path.pub" ]]; then
        echo "Incomplete demo key pair at $key_path; refusing to overwrite either file." >&2
        exit 1
    fi
    derived_public_key=$(ssh-keygen -y -P '' -f "$key_path")
    derived_public_key=$(printf '%s\n' "$derived_public_key" | awk '{print $1 " " $2}')
    stored_public_key=$(awk '{print $1 " " $2}' "$key_path.pub")
    if [[ "$derived_public_key" != "$stored_public_key" ]]; then
        echo "Demo public and private keys do not match; refusing to overwrite them." >&2
        exit 1
    fi
    chmod 600 "$key_path"
    echo "Reusing existing demo SSH key at $key_path."
else
    ssh-keygen -q -t ed25519 -N '' -C ww-demo-presenter -f "$key_path"
    echo "Created demo SSH key at $key_path."
fi
echo "Only its public key will be registered in AWS by Terraform."

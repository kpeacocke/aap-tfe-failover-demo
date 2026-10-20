#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/load-env.sh
source "$script_dir/load-env.sh" optional

usage() {
    echo "Usage: $0 <dc1|dc2> [haproxy-public-ip] [ssh-private-key]" >&2
    echo "Set HAPROXY_PUBLIC_IP and SSH_PRIVATE_KEY_PATH in .env to omit the optional arguments." >&2
}

if [[ "$#" -lt 1 || "$#" -gt 3 ]]; then
    usage
    exit 2
fi

target_dc=$1
haproxy_host=${2:-${HAPROXY_PUBLIC_IP:-}}
ssh_key=${3:-${SSH_PRIVATE_KEY_PATH:-$repo_root/.local/ssh/ww-demo}}
if [[ "$ssh_key" != /* ]]; then
    ssh_key="$repo_root/$ssh_key"
fi

case "$target_dc" in
    dc1|dc2) ;;
    *)
        usage
        exit 2
        ;;
esac

if [[ -z "$haproxy_host" || -z "$ssh_key" ]]; then
    echo "Set HAPROXY_PUBLIC_IP and SSH_PRIVATE_KEY_PATH in .env, or pass both optional arguments." >&2
    usage
    exit 2
fi

if [[ ! -r "$ssh_key" ]]; then
    echo "SSH private key is not readable: $ssh_key" >&2
    exit 1
fi

exec ssh \
    -i "$ssh_key" \
    -o IdentitiesOnly=yes \
    -o ConnectTimeout=10 \
    "ec2-user@$haproxy_host" \
    "sudo /usr/local/sbin/set-active-datacentre $target_dc"

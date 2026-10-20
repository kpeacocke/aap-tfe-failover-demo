#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/load-env.sh
source "$script_dir/load-env.sh"

if [[ "$#" -lt 2 || "$#" -gt 3 || ! "$1" =~ ^dc[12]$ || ! "$2" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
    echo "Usage: bash scripts/runtime-failover.sh <dc1|dc2> <INC-or-CHG-reference> [planned|failure]" >&2
    exit 2
fi
mode=${3:-planned}
if [[ "$mode" != planned && "$mode" != failure ]]; then
    echo "Mode must be planned or failure." >&2
    exit 2
fi
drain_timeout=${FAILOVER_DRAIN_TIMEOUT_SECONDS:-60}
if [[ ! "$drain_timeout" =~ ^[1-9][0-9]{0,2}$ || "$drain_timeout" -gt 600 ]]; then
    echo "FAILOVER_DRAIN_TIMEOUT_SECONDS must be an integer from 1 to 600." >&2
    exit 2
fi

for executable in jq ansible-playbook; do
    if ! command -v "$executable" >/dev/null 2>&1; then
        echo "Required command is missing: $executable" >&2
        exit 1
    fi
done
ssh_key=${SSH_PRIVATE_KEY_PATH:-.local/ssh/ww-demo}
if [[ "$ssh_key" != /* ]]; then
    ssh_key="$repo_root/$ssh_key"
fi
if [[ ! -r "$ssh_key" ]]; then
    echo "SSH private key is not readable: $ssh_key" >&2
    exit 1
fi

umask 077
fixture=$(mktemp -d)
trap 'rm -f "$fixture/request.json" "$fixture/inventory.json"; rmdir "$fixture"' EXIT
jq -n \
    --arg path "$fixture/inventory.json" \
    --arg key "$ssh_key" \
    --arg target "$1" \
    --arg reference "$2" \
    --arg mode "$mode" \
    --arg version "${TF_VAR_application_version:-1.0.0}" \
    --arg drain_timeout "$drain_timeout" \
    '
    {
      terraform_workspace_inventory_path: $path,
      runtime_ssh_private_key_path: $key,
      runtime_target_dc: $target,
      runtime_reference: $reference,
      failover_mode: $mode,
      failover_application_version: $version,
      failover_drain_timeout_seconds: ($drain_timeout | tonumber)
    }' > "$fixture/request.json"

cd "$repo_root"
export ANSIBLE_CONFIG="$repo_root/ansible.cfg"
ansible-playbook -i localhost, playbooks/terraform-discover.yml -e "@$fixture/request.json"
ansible-playbook -i "$fixture/inventory.json" playbooks/runtime-failover.yml -e "@$fixture/request.json"

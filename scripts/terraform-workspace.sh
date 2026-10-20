#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/load-env.sh
source "$script_dir/load-env.sh"

usage() {
    echo "Usage: bash scripts/terraform-workspace.sh discover | <lock|unlock> <dc1|dc2> <INC-or-CHG-reference>" >&2
}
if [[ "$#" -eq 1 && "$1" == discover ]]; then
    action=discover
elif [[ "$#" -eq 3 && "$1" =~ ^(lock|unlock)$ && "$2" =~ ^dc[12]$ && "$3" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
    action=$1
else
    usage
    exit 2
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "Activate the project virtualenv and install bootstrap/requirements.txt and bootstrap/requirements.yml." >&2
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "Required command is missing: jq" >&2
    exit 1
fi
ssh_key=${SSH_PRIVATE_KEY_PATH:-.local/ssh/ww-demo}
if [[ "$ssh_key" != /* ]]; then
    ssh_key="$repo_root/$ssh_key"
fi
if [[ "$action" != discover && ! -r "$ssh_key" ]]; then
    echo "SSH private key is not readable: $ssh_key" >&2
    exit 1
fi

umask 077
fixture=$(mktemp -d)
trap 'rm -f "$fixture/request.json" "$fixture/inventory.json"; rmdir "$fixture"' EXIT
jq -n --arg path "$fixture/inventory.json" --arg key "$ssh_key" \
    --arg action "$action" --arg dc "${2:-}" --arg reference "${3:-}" \
    --arg version "${TF_VAR_application_version:-1.0.0}" \
    '{terraform_workspace_inventory_path:$path,runtime_ssh_private_key_path:$key,
      workspace_cli_action:$action,workspace_cli_dc:$dc,workspace_cli_reference:$reference,
      runtime_application_version:$version}' > "$fixture/request.json"
cd "$repo_root"
export ANSIBLE_CONFIG="$repo_root/ansible.cfg"
ansible-playbook -i localhost, playbooks/terraform-discover.yml -e "@$fixture/request.json"
if [[ "$action" != discover ]]; then
    ansible-playbook -i "$fixture/inventory.json" playbooks/terraform-workspace.yml -e "@$fixture/request.json"
fi

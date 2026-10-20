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

for executable in terraform jq ansible-playbook; do
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
trap 'rm -f "$fixture/shared.json" "$fixture/dc1.json" "$fixture/dc2.json" "$fixture/inventory.json"; rmdir "$fixture"' EXIT
for root in shared dc1 dc2; do
    bash "$script_dir/terraform.sh" "$root" output -json > "$fixture/$root.json"
done

jq -n -e \
    --slurpfile shared "$fixture/shared.json" \
    --slurpfile dc1 "$fixture/dc1.json" \
    --slurpfile dc2 "$fixture/dc2.json" \
    --arg key "$ssh_key" \
    --arg target "$1" \
    --arg reference "$2" \
    --arg mode "$mode" \
    --arg version "${TF_VAR_application_version:-1.0.0}" \
    --arg drain_timeout "$drain_timeout" \
    '
    def nodes($dc):
      if $dc.datacentre_name.value as $name |
        ($name | test("^dc[12]$")) and
        ($dc.application_private_ips.value | length == 2) and
        ($dc.health_urls.value | length == 2)
      then [range(0; 2) as $i |
        {server: ($dc.datacentre_name.value + "_app_0" + (($i + 1) | tostring)),
         hostname: ($dc.datacentre_name.value + "-app-0" + (($i + 1) | tostring)),
         address: $dc.application_private_ips.value[$i],
         health_url: $dc.health_urls.value[$i]}]
      else error("Missing or invalid datacentre outputs; provision both DCs first") end;
    if ($shared[0].frontdoor_public_ip.value | type == "string" and length > 0) and
       ($shared[0].frontdoor_url.value | type == "string" and length > 0) and
       $dc1[0].datacentre_name.value == "dc1" and $dc2[0].datacentre_name.value == "dc2"
    then {all: {children: {haproxy: {hosts: {demo_haproxy: {
      ansible_host: $shared[0].frontdoor_public_ip.value,
      ansible_user: "ec2-user",
      ansible_ssh_private_key_file: $key,
      ansible_ssh_common_args: "-o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10",
      runtime_frontdoor_url: $shared[0].frontdoor_url.value,
      runtime_sites: {dc1: nodes($dc1[0]), dc2: nodes($dc2[0])},
      runtime_target_dc: $target,
      runtime_reference: $reference,
      failover_mode: $mode,
      failover_application_version: $version,
      failover_drain_timeout_seconds: ($drain_timeout | tonumber)
    }}}}}}
    else error("Missing shared outputs or incorrect DC identity; provision all roots first") end
    ' > "$fixture/inventory.json"

cd "$repo_root"
export ANSIBLE_CONFIG="$repo_root/ansible.cfg"
ansible-playbook -i "$fixture/inventory.json" playbooks/runtime-failover.yml

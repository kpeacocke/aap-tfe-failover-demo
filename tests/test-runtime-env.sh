#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -f "$fixture/.env" "$fixture/key" "$fixture/output" "$fixture/inventory.json" "$fixture/scripts/runtime-failover.sh" "$fixture/scripts/load-env.sh" "$fixture/scripts/terraform.sh" "$fixture/bin/ansible-playbook"; rmdir "$fixture/scripts" "$fixture/bin" "$fixture"' EXIT
mkdir "$fixture/scripts" "$fixture/bin"
cp "$repo_root/scripts/runtime-failover.sh" "$repo_root/scripts/load-env.sh" "$fixture/scripts/"
touch "$fixture/key" "$fixture/.env"
export SSH_PRIVATE_KEY_PATH="$fixture/key"
export RUNTIME_TEST_FIXTURE="$fixture"
export PATH="$fixture/bin:$PATH"

cat > "$fixture/scripts/terraform.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${TEST_OUTPUT_FAILURE:-}" == yes ]]; then
    echo "Output access denied" >&2
    exit 1
fi
if [[ "$1" == shared ]]; then
    printf '%s\n' '{"frontdoor_public_ip":{"value":"192.0.2.50"},"frontdoor_url":{"value":"http://192.0.2.50"}}'
else
    jq -n --arg dc "$1" --arg subnet "$([[ "$1" == dc1 ]] && echo 1 || echo 2)" \
        '{datacentre_name:{value:$dc},
          application_private_ips:{value:[("10.20."+$subnet+".10"),("10.20."+$subnet+".11")]},
          health_urls:{value:[("http://10.20."+$subnet+".10:8080/health"),("http://10.20."+$subnet+".11:8080/health")]}}'
fi
MOCK
cat > "$fixture/bin/ansible-playbook" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
cp "$2" "$RUNTIME_TEST_FIXTURE/inventory.json"
exit "${TEST_ANSIBLE_EXIT_CODE:-0}"
MOCK
chmod +x "$fixture/bin/ansible-playbook"

for args in 'dc3 INC1' 'dc2' 'dc2 INVALID/REFERENCE' 'dc2 INC1 arbitrary'; do
    # Intentional word splitting to exercise argument-count validation.
    # shellcheck disable=SC2086
    if bash "$fixture/scripts/runtime-failover.sh" $args > "$fixture/output" 2>&1; then
        echo "FAIL: invalid arguments accepted: $args" >&2
        exit 1
    fi
done
for timeout in 0 abc 1.5 601; do
    if FAILOVER_DRAIN_TIMEOUT_SECONDS="$timeout" bash "$fixture/scripts/runtime-failover.sh" dc2 INC123 > "$fixture/output" 2>&1; then
        echo "FAIL: invalid drain timeout accepted: $timeout" >&2
        exit 1
    fi
    grep -Fq 'must be an integer from 1 to 600' "$fixture/output"
done
TF_VAR_application_version=2.0.0 FAILOVER_DRAIN_TIMEOUT_SECONDS=12 \
    bash "$fixture/scripts/runtime-failover.sh" dc2 INC123 failure
jq -e '.all.children.haproxy.hosts.demo_haproxy |
    .ansible_host == "192.0.2.50" and .runtime_target_dc == "dc2" and
    .runtime_reference == "INC123" and .failover_mode == "failure" and
    .failover_application_version == "2.0.0" and .failover_drain_timeout_seconds == 12 and
    .runtime_sites.dc1[0].server == "dc1_app_01" and
    .runtime_sites.dc2[1].health_url == "http://10.20.2.11:8080/health"' "$fixture/inventory.json" >/dev/null

if TEST_OUTPUT_FAILURE=yes bash "$fixture/scripts/runtime-failover.sh" dc2 INC123 > "$fixture/output" 2>&1; then
    echo "FAIL: Terraform output failure was ignored." >&2
    exit 1
fi
grep -Fq 'Output access denied' "$fixture/output"
if TEST_ANSIBLE_EXIT_CODE=4 bash "$fixture/scripts/runtime-failover.sh" dc2 INC123 > "$fixture/output" 2>&1; then
    echo "FAIL: Ansible failure was ignored." >&2
    exit 1
fi
echo "PASS: runtime CLI input guards, Terraform-derived inventory, configuration forwarding and failure propagation."

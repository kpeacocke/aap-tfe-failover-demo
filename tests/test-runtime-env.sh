#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -f "$fixture/.env" "$fixture/key" "$fixture/output" "$fixture/request.json" "$fixture/calls" "$fixture/scripts/runtime-failover.sh" "$fixture/scripts/terraform-workspace.sh" "$fixture/scripts/load-env.sh" "$fixture/bin/ansible-playbook"; rmdir "$fixture/scripts" "$fixture/bin" "$fixture"' EXIT
mkdir "$fixture/scripts" "$fixture/bin"
cp "$repo_root/scripts/runtime-failover.sh" "$repo_root/scripts/terraform-workspace.sh" "$repo_root/scripts/load-env.sh" "$fixture/scripts/"
touch "$fixture/key" "$fixture/.env"
export SSH_PRIVATE_KEY_PATH="$fixture/key"
export RUNTIME_TEST_FIXTURE="$fixture"
export PATH="$fixture/bin:$PATH"

cat > "$fixture/bin/ansible-playbook" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$3" >> "$RUNTIME_TEST_FIXTURE/calls"
cp "${5#@}" "$RUNTIME_TEST_FIXTURE/request.json"
if [[ "$3" == playbooks/terraform-discover.yml && "${TEST_OUTPUT_FAILURE:-}" == yes ]]; then
    echo "Output access denied" >&2
    exit 1
fi
exit "${TEST_ANSIBLE_EXIT_CODE:-0}"
MOCK
chmod +x "$fixture/bin/ansible-playbook"

for args in 'dc3 INC1' 'dc2' 'dc2 INVALID/REFERENCE' 'dc2 INC1 arbitrary'; do
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
jq -e '.runtime_target_dc == "dc2" and .runtime_reference == "INC123" and
    .failover_mode == "failure" and .failover_application_version == "2.0.0" and
    .failover_drain_timeout_seconds == 12 and
    (.runtime_ssh_private_key_path | startswith("/"))' "$fixture/request.json" >/dev/null
grep -Fxq 'playbooks/terraform-discover.yml' "$fixture/calls"
grep -Fxq 'playbooks/runtime-failover.yml' "$fixture/calls"

: > "$fixture/calls"
if TEST_OUTPUT_FAILURE=yes bash "$fixture/scripts/runtime-failover.sh" dc2 INC123 > "$fixture/output" 2>&1; then
    echo "FAIL: API output failure was ignored." >&2
    exit 1
fi
grep -Fq 'Output access denied' "$fixture/output"
test "$(wc -l < "$fixture/calls" | tr -d ' ')" = 1
if TEST_ANSIBLE_EXIT_CODE=4 bash "$fixture/scripts/runtime-failover.sh" dc2 INC123 > "$fixture/output" 2>&1; then
    echo "FAIL: Ansible failure was ignored." >&2
    exit 1
fi
for action in lock unlock; do
    bash "$fixture/scripts/terraform-workspace.sh" "$action" dc1 INC123
    jq -e --arg action "$action" '.workspace_cli_action == $action and
        .workspace_cli_dc == "dc1" and .workspace_cli_reference == "INC123"' "$fixture/request.json" >/dev/null
done
bash "$fixture/scripts/terraform-workspace.sh" discover
for args in 'lock shared INC1' 'unlock dc3 INC1' 'unlock dc1 bad/ref' 'force-unlock dc1 INC1'; do
    # shellcheck disable=SC2086
    if bash "$fixture/scripts/terraform-workspace.sh" $args > "$fixture/output" 2>&1; then
        echo "FAIL: invalid workspace action accepted: $args" >&2
        exit 1
    fi
done
echo "PASS: API-only CLI guards, request forwarding, discovery-before-operation and failure propagation."

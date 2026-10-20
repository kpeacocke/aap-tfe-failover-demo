#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -f "$fixture/curl" "$fixture/output" "$fixture/calls"; rmdir "$fixture"' EXIT
cat > "$fixture/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
cat >/dev/null
printf '%q ' "$@" >> "$CALL_LOG"
printf '\n' >> "$CALL_LOG"
if [[ "$*" == *"--request POST"* ]]; then
    [[ "$SCENARIO" != existing && "$SCENARIO" != denied ]]
    payload=
    while [[ "$#" -gt 0 ]]; do
        if [[ "$1" == --data ]]; then
            payload=$2
            break
        fi
        shift
    done
    jq -e '.data.attributes["execution-mode"] == "local" and .data.attributes["auto-apply"] == false and .data.attributes.name == "ww-demo-shared"' <<< "$payload" >/dev/null
    if [[ "$SCENARIO" == create-failed ]]; then
        printf '{}\n422'
    else
        printf '{"data":{"id":"ws-test","type":"workspaces","attributes":{"name":"ww-demo-shared","execution-mode":"local"}}}\n201'
    fi
elif [[ "$SCENARIO" == existing ]]; then
    printf '{"data":{"id":"ws-test","type":"workspaces","attributes":{"name":"ww-demo-shared","execution-mode":"remote"}}}\n200'
elif [[ "$SCENARIO" == denied ]]; then
    printf '{}\n403'
elif [[ "$SCENARIO" == network ]]; then
    exit 7
else
    printf '{}\n404'
fi
MOCK
chmod +x "$fixture/curl"
export PATH="$fixture:$PATH"
export HCP_TERRAFORM_ORGANIZATION=test-org TF_TOKEN_app_terraform_io=fake-test-token
export CALL_LOG="$fixture/calls"

for scenario in existing missing denied create-failed network; do
    : > "$CALL_LOG"
    if SCENARIO=$scenario bash "$repo_root/scripts/ensure-workspace.sh" ww-demo-shared > "$fixture/output" 2>&1; then
        [[ "$scenario" == existing || "$scenario" == missing ]]
    else
        [[ "$scenario" == denied || "$scenario" == create-failed || "$scenario" == network ]]
    fi
    if [[ "$scenario" == existing || "$scenario" == denied || "$scenario" == network ]]; then
        test "$(wc -l < "$CALL_LOG" | tr -d ' ')" -eq 1
    else
        test "$(wc -l < "$CALL_LOG" | tr -d ' ')" -eq 2
    fi
    if grep -q fake-test-token "$fixture/output" "$CALL_LOG"; then
        echo 'FAIL: token appeared in output or command arguments.' >&2
        exit 1
    fi
done
echo 'PASS: workspace reuse, creation, authorization, network and creation failures.'

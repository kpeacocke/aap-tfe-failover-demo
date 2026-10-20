#!/usr/bin/env bash
set -euo pipefail

# This fixture runs only inside the disposable Linux test container.
fixture=$(mktemp -d)
export ANSIBLE_LOCAL_TEMP="$fixture/ansible"
export ANSIBLE_CONFIG=/repo/ansible.cfg
pids=()
cleanup() {
    local status=$?
    if [[ "$status" -ne 0 ]]; then
        echo "Runtime fixture failed (exit $status). Last test diagnostics:"
        for log in deadline.log stage-rollback.log result.log haproxy-tcp.log; do
            if [[ -f "$fixture/$log" ]]; then
                echo "--- $log ---"
                tail -50 "$fixture/$log"
            fi
        done
    fi
    for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
        fi
    done
    return "$status"
}
trap cleanup EXIT

start_app() {
    local index=$1
    local dc="dc$(( (index - 1) / 2 + 1 ))"
    local node="$(( (index - 1) % 2 + 1 ))"
    DEMO_DATACENTRE="$dc" DEMO_HOSTNAME="$dc-app-0$node" DEMO_VERSION=1.0.0 PORT="$((8080 + index))" \
        python /repo/application/app.py > "$fixture/app-$index.log" 2>&1 &
    app_pid=$!
    pids+=("$app_pid")
}
for index in 1 2 3 4; do
    start_app "$index"
    printf '%s\n' "$app_pid" > "$fixture/app-$index.pid"
    socat "TCP-LISTEN:8080,bind=127.0.0.$((10 + index)),reuseaddr,fork" "TCP:127.0.0.1:$((8080 + index))" \
        > "$fixture/forward-$index.log" 2>&1 &
    pids+=("$!")
done

cat > "$fixture/haproxy.cfg" <<EOF
global
    stats socket $fixture/admin.sock level admin
defaults
    mode http
    timeout connect 1s
    timeout client 5s
    timeout server 5s
frontend demo_frontdoor
    bind 127.0.0.1:8080
    default_backend demo_applications
backend demo_applications
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    default-server inter 100ms rise 1 fall 1
    server dc1_app_01 127.0.0.11:8080 check
    server dc1_app_02 127.0.0.12:8080 check
    server dc2_app_01 127.0.0.13:8080 check disabled
    server dc2_app_02 127.0.0.14:8080 check disabled
EOF
haproxy -f "$fixture/haproxy.cfg" -db > "$fixture/haproxy.log" 2>&1 &
haproxy_pid=$!
pids+=("$haproxy_pid")
for attempt in {1..50}; do
    if [[ -S "$fixture/admin.sock" ]]; then break; fi
    sleep 0.1
done
test -S "$fixture/admin.sock"

jq -n --arg socket "$fixture/admin.sock" --arg marker "$fixture/operation.lock" '
  def nodes($dc; $start):
    [range(0;2) as $i | {server:($dc+"_app_0"+(($i+1)|tostring)),
      hostname:($dc+"-app-0"+(($i+1)|tostring)),
      instance_id:(if $i == 0 then "i-0123" else "i-0456" end),
      address:("127.0.0."+ (($start+$i)|tostring)),
      health_url:("http://127.0.0."+ (($start+$i)|tostring)+":8080/health")}];
  {all:{children:{haproxy:{hosts:{fixture:{
    ansible_connection:"local", ansible_python_interpreter:"/usr/local/bin/python",
    runtime_sites:{dc1:nodes("dc1";11),dc2:nodes("dc2";13)},
    runtime_frontdoor_url:"http://127.0.0.1:8080",
    haproxy_state_socket:$socket,runtime_operation_marker:$marker
  }}}}}}' > "$fixture/inventory.json"

run() {
    ansible-playbook -i "$fixture/inventory.json" playbooks/runtime-failover.yml \
        -e runtime_reference=TEST-PHASE2 -e runtime_health_delay_seconds=1 \
        -e runtime_health_retries=3 -e "runtime_operation_marker=$fixture/operation.lock" \
        -e runtime_terraform_enabled=false \
        "$@" > "$fixture/result.log" 2>&1
}
require_success() {
    if ! run "$@"; then cat "$fixture/result.log"; exit 1; fi
    grep -Fq 'FAILOVER COMPLETE' "$fixture/result.log"
}
require_failure() {
    local expected=$1
    shift
    if run "$@"; then echo "Expected a failure: $expected"; exit 1; fi
    if ! grep -Fq "$expected" "$fixture/result.log"; then cat "$fixture/result.log"; exit 1; fi
}
require_active() {
    local dc=$1
    socat - "UNIX-CONNECT:$fixture/admin.sock" <<< 'show stat' > "$fixture/stats.csv"
    awk -F, -v dc="$dc" '$1=="demo_applications" && $2 ~ /^dc[12]_app_/ {
        if (substr($2,1,3)==dc && $18!="UP") exit 1;
        if (substr($2,1,3)!=dc && $18!="MAINT") exit 1;
    }' "$fixture/stats.csv"
    test ! -d "$fixture/operation.lock"
}
sleep 1
require_failure 'Supply one HAProxy host' -e runtime_target_dc=invalid
require_failure 'already active' -e runtime_target_dc=dc1
require_active dc1
mkdir "$fixture/operation.lock"
require_failure 'File exists' -e runtime_target_dc=dc2
test -d "$fixture/operation.lock"
rmdir "$fixture/operation.lock"
require_failure 'is not ready' -e runtime_target_dc=dc2 -e runtime_application_version=wrong
require_active dc1
require_failure 'Source still responds' -e runtime_target_dc=dc2 -e runtime_mode=failure
require_active dc1
require_success -e runtime_target_dc=dc2
require_active dc2
require_success -e runtime_target_dc=dc1
require_active dc1
echo "PASS: invalid inputs, existing marker, readiness refusal, planned failover in both directions."

# Fail one target after preflight, while the source is draining.
(
    for ((attempt = 0; attempt < 2000; attempt++)); do
        stats=$(socat - "UNIX-CONNECT:$fixture/admin.sock" <<< 'show stat')
        if grep -q 'demo_applications,dc1_app_01,.*DRAIN' <<< "$stats"; then
            kill "$(cat "$fixture/app-3.pid")"
            exit 0
        fi
        sleep 0.01
    done
    exit 1
) &
watcher=$!
pids+=("$watcher")
require_failure 'Rollback to dc1 validated successfully' -e runtime_target_dc=dc2
wait "$watcher"
require_active dc1
start_app 3
printf '%s\n' "$app_pid" > "$fixture/app-3.pid"
sleep 1
echo "PASS: mid-transition target failure restores and validates healthy source; CLI still fails."

# In failure mode, stop both source services and fail the target during activation.
kill "$(cat "$fixture/app-1.pid")" "$(cat "$fixture/app-2.pid")"
(
    for ((attempt = 0; attempt < 2000; attempt++)); do
        stats=$(socat - "UNIX-CONNECT:$fixture/admin.sock" <<< 'show stat')
        if grep -q 'demo_applications,dc1_app_01,.*MAINT' <<< "$stats"; then
            kill "$(cat "$fixture/app-3.pid")"
            exit 0
        fi
        sleep 0.01
    done
    exit 1
) &
watcher=$!
pids+=("$watcher")
require_failure 'Automatic rollback is unsafe; human escalation required' -e runtime_target_dc=dc2 -e runtime_mode=failure
wait "$watcher"
test ! -d "$fixture/operation.lock"
echo "PASS: unavailable source never receives an impossible automatic rollback."

for index in 1 2 3; do
    start_app "$index"
    printf '%s\n' "$app_pid" > "$fixture/app-$index.pid"
done
for server in dc1_app_01 dc1_app_02; do
    printf 'set server demo_applications/%s state ready\n' "$server" | socat - "UNIX-CONNECT:$fixture/admin.sock"
done
for server in dc2_app_01 dc2_app_02; do
    printf 'set server demo_applications/%s state maint\n' "$server" | socat - "UNIX-CONNECT:$fixture/admin.sock"
done
sleep 1
require_active dc1
kill "$(cat "$fixture/app-1.pid")" "$(cat "$fixture/app-2.pid")"
require_success -e runtime_target_dc=dc2 -e runtime_mode=failure
require_active dc2
echo "PASS: demonstrated source outage skips graceful drain and activates the healthy target."

# TCP mode lets an idle connection deterministically hold one source session.
# The other scenarios above exercise the deployed HTTP-mode configuration.
kill "$haproxy_pid"
wait "$haproxy_pid" || test "$?" -eq 143
for index in 1 2; do
    start_app "$index"
    printf '%s\n' "$app_pid" > "$fixture/app-$index.pid"
done
sed 's/mode http/mode tcp/;s/timeout client 5s/timeout client 60s/;s/timeout server 5s/timeout server 60s/' \
    "$fixture/haproxy.cfg" > "$fixture/tcp.cfg"
haproxy -f "$fixture/tcp.cfg" -db > "$fixture/haproxy-tcp.log" 2>&1 &
pids+=("$!")
sleep 1
exec 3<>/dev/tcp/127.0.0.1/8080
sleep 0.2
socat - "UNIX-CONNECT:$fixture/admin.sock" <<< 'show stat' > "$fixture/stats.csv"
awk -F, '$1=="demo_applications" && $2 ~ /^dc1_app_/ {sessions+=$5} END {exit sessions<1}' "$fixture/stats.csv"
started=$SECONDS
if bash roles/haproxy_state/files/wait-for-drain.sh "$fixture/admin.sock" demo_applications dc1_app_01 dc1_app_02 1 0 3 \
    > "$fixture/deadline.log" 2>&1; then
    echo "Drain deadline accepted a held source session."
    exit 1
fi
elapsed=$((SECONDS - started))
test "$elapsed" -ge 1
test "$elapsed" -le 3
grep -Fq 'Drain timed out after 1s' "$fixture/deadline.log"
require_failure 'Rollback to dc1 validated successfully' -e runtime_target_dc=dc2 -e runtime_drain_timeout_seconds=1
grep -Fq 'Wait for source sessions to drain within the timeout' "$fixture/result.log"
grep -Fq 'Drain timed out after 1s' "$fixture/result.log"
require_active dc1
awk -F, '$1=="demo_applications" && $2 ~ /^dc1_app_/ {sessions+=$5} END {exit sessions<1}' "$fixture/stats.csv"
exec 3<&-
exec 3>&-
echo "PASS: a nonzero source session hits the drain timeout and restores the healthy source without killing sessions."

python -B tests/terraform_api/support.py "$fixture/api.json" > "$fixture/api.log" 2>&1 &
pids+=("$!")
for ((attempt = 0; attempt < 100; attempt++)); do
    if [[ -f "$fixture/api.json" ]]; then break; fi
    sleep 0.1
done
export TFE_ADDRESS
TFE_ADDRESS=$(jq -r .address "$fixture/api.json")
export SSL_CERT_FILE
SSL_CERT_FILE=$(jq -r .ca_bundle "$fixture/api.json")
export TFE_TOKEN=fixture-token
export HCP_TERRAFORM_ORGANIZATION=test-org
jq -n '{terraform_workspace_workspaces:{
    shared:{id:"ws-shared",name:"ww-demo-shared",locked:false},
    dc1:{id:"ws-dc1",name:"ww-demo-dc1",locked:false},
    dc2:{id:"ws-dc2",name:"ww-demo-dc2",locked:false}}}' > "$fixture/workspaces.json"

workspace() {
    ansible-playbook -i "$fixture/inventory.json" playbooks/terraform-workspace.yml \
        -e "@$fixture/workspaces.json" -e "runtime_operation_marker=$fixture/operation.lock" \
        -e workspace_cli_action="$1" -e workspace_cli_dc="$2" -e workspace_cli_reference=TEST-PHASE2 \
        -e runtime_health_delay_seconds=1 -e runtime_health_retries=3 \
        > "$fixture/result.log" 2>&1
}

if ! require_success -e runtime_target_dc=dc2 -e runtime_terraform_enabled=true -e "@$fixture/workspaces.json"; then
    cat "$fixture/result.log"
    exit 1
fi
require_active dc2
if workspace unlock dc2; then echo "Released active-site quarantine unexpectedly."; exit 1; fi
grep -Fq 'runtime state does not match' "$fixture/result.log"
require_failure 'Target workspace ww-demo-dc1 is locked' \
    -e runtime_target_dc=dc1 -e runtime_terraform_enabled=true -e "@$fixture/workspaces.json"
require_active dc2
if ! workspace unlock dc1; then cat "$fixture/result.log"; exit 1; fi
require_success -e runtime_target_dc=dc1 -e runtime_terraform_enabled=true -e "@$fixture/workspaces.json"
require_active dc1
kill "$(cat "$fixture/app-3.pid")"
if workspace unlock dc2; then echo "Released an unhealthy standby unexpectedly."; exit 1; fi
grep -Fq 'is not ready' "$fixture/result.log"
start_app 3
printf '%s\n' "$app_pid" > "$fixture/app-3.pid"
sleep 1
if ! workspace unlock dc2; then cat "$fixture/result.log"; exit 1; fi
require_active dc1
echo "PASS: failover quarantines the source, refuses a locked target, and releases only healthy standby sites."

exec 3<>/dev/tcp/127.0.0.1/8080
sleep 0.2
require_failure 'Rollback to dc1 validated successfully' -e runtime_target_dc=dc2 \
    -e runtime_drain_timeout_seconds=1 -e runtime_terraform_enabled=true -e "@$fixture/workspaces.json"
require_active dc1
grep -Fq 'Drain timed out after 1s' "$fixture/result.log"
python - <<'PY'
import json
import os
import ssl
import urllib.request

request = urllib.request.Request(
    os.environ["TFE_ADDRESS"] + "/api/v2/organizations/test-org/workspaces/ww-demo-dc1",
    headers={"Authorization": "Bearer " + os.environ["TFE_TOKEN"]},
)
with urllib.request.urlopen(request, context=ssl.create_default_context(cafile=os.environ["SSL_CERT_FILE"])) as response:
    attributes = json.load(response)["data"]["attributes"]
assert attributes["locked"], "Runtime rollback must retain source quarantine"
assert attributes["locked-reason"] == "Demo-managed datacentre quarantine - TEST-PHASE2 - dc1"
PY
exec 3<&-
exec 3>&-
echo "PASS: a failed API-integrated drain rolls back traffic but retains incident-owned source quarantine."

curl --fail --silent --show-error --cacert "$SSL_CERT_FILE" -X POST \
    -H "Authorization: Bearer $TFE_TOKEN" "$TFE_ADDRESS/api/v2/workspaces/ws-dc1/actions/unlock" > /dev/null
export AWS_ACCESS_KEY_ID=fixture-access-key AWS_SECRET_ACCESS_KEY=fixture-secret
export AWS_REGION=us-east-2 AWS_DEFAULT_REGION=us-east-2 DEMO_AWS_ACCOUNT_ID=123456789012
export AWS_ENDPOINT_URL_STS="$TFE_ADDRESS/sts" AWS_ENDPOINT_URL_EC2="$TFE_ADDRESS/ec2"
export AWS_CA_BUNDLE="$SSL_CERT_FILE" AWS_EC2_METADATA_DISABLED=true

stage() {
    local requested_stage=$1
    local status=0
    shift
    ansible-playbook -i "$fixture/inventory.json" tests/runtime/workflow-stage.yml \
        -e "@$fixture/workspaces.json" -e "runtime_operation_marker=$fixture/operation.lock" \
        -e demo_stage="$requested_stage" -e awx_workflow_job_id="${workflow_id:-9001}" \
        -e '{"demo_service":"Customer Orders Demo","demo_reason":"Planned maintenance"}' \
        -e demo_reference=TEST-WORKFLOW -e demo_confirmation=CONFIRM \
        -e demo_target=dc2 -e demo_recovery_dc=dc1 \
        -e runtime_health_delay_seconds=1 -e runtime_health_retries=3 "$@" \
        > "$fixture/result.log" 2>&1 || status=$?
    cp "$fixture/result.log" "$fixture/stage-$requested_stage.log"
    return "$status"
}
for step in validate_request determine_state validate_target quarantine_source drain_source activate_target validate_service evidence_success; do
    if ! stage "$step"; then cat "$fixture/result.log"; exit 1; fi
done
require_active dc2
grep -Fq '"outcome": "success"' "$fixture/result.log"
workflow_id=9002
for step in recovery_request recovery_infrastructure recovery_application recovery_network recovery_terraform_health \
    recovery_unlock recovery_standby recovery_validation recovery_evidence; do
    if ! stage "$step"; then cat "$fixture/result.log"; exit 1; fi
done
require_active dc2
grep -Fq '"outcome": "success"' "$fixture/result.log"
echo "PASS: separately executed AAP stage jobs fail over, retain quarantine and recover the standby without switchback."

workflow_id=9003
if stage validate_request; then echo "Already-active target unexpectedly accepted."; exit 1; fi
test -d "$fixture/operation.lock"
workflow_id=9004
if stage evidence_failure; then echo "Another workflow stole the marker."; exit 1; fi
grep -Fq 'Marker ownership' "$fixture/result.log"
test -d "$fixture/operation.lock"
workflow_id=9003
if stage evidence_failure; then echo "Failure evidence converted failure into success."; exit 1; fi
grep -Fq '"outcome": "failed"' "$fixture/result.log"
require_active dc2
echo "PASS: failed request evidence cleans only its own marker and another workflow cannot steal it."

workflow_id=9005
if ! stage validate_request -e demo_target=dc1; then cat "$fixture/result.log"; exit 1; fi
if stage quarantine_source -e demo_target=dc1; then echo "Skipped workflow stages unexpectedly accepted."; exit 1; fi
grep -Fq 'stage order' "$fixture/result.log"
if stage evidence_failure -e demo_target=dc1; then echo "Out-of-order workflow unexpectedly succeeded."; exit 1; fi
require_active dc2
echo "PASS: isolated jobs cannot skip readiness stages before quarantine."

workflow_id=9006
for step in validate_request determine_state validate_target quarantine_source drain_source; do
    if ! stage "$step" -e demo_target=dc1; then cat "$fixture/result.log"; exit 1; fi
done
kill "$(cat "$fixture/app-1.pid")"
if stage activate_target -e demo_target=dc1; then echo "Unhealthy target unexpectedly activated."; exit 1; fi
if ! stage rollback -e demo_target=dc1; then cat "$fixture/result.log"; exit 1; fi
if stage evidence_failure -e demo_target=dc1; then echo "Rolled-back failover unexpectedly succeeded."; exit 1; fi
grep -Fq '"outcome": "rolled_back"' "$fixture/result.log"
grep -Fq '"locked": true' "$fixture/result.log"
require_active dc2
start_app 1
printf '%s\n' "$app_pid" > "$fixture/app-1.pid"
echo "PASS: AAP failure branches validate rollback, retain source quarantine and keep the workflow failed."

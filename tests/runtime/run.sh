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
        for log in deadline.log result.log haproxy-tcp.log; do
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

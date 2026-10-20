#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 7 ]]; then
    echo "Expected socket, backend, two servers, timeout, threshold and poll interval." >&2
    exit 2
fi
socket=$1
backend=$2
first_server=$3
second_server=$4
timeout=$5
threshold=$6
interval=$7
if [[ ! "$timeout" =~ ^[1-9][0-9]*$ || ! "$threshold" =~ ^[0-9]+$ || ! "$interval" =~ ^[1-9][0-9]*$ ]]; then
    echo "Drain timeout and poll interval must be positive integers; threshold must be nonnegative." >&2
    exit 2
fi
threshold=$((10#$threshold))

# Poll on HAProxy so controller/SSH round trips do not extend the drain timeout.
SECONDS=0
while true; do
    stats=$(printf 'show stat\n' | socat -T 1 - "UNIX-CONNECT:$socket")
    sessions=$(awk -F, -v backend="$backend" -v first="$first_server" -v second="$second_server" '
        NR == 1 {
            sub(/^# /, "");
            for (i=1; i<=NF; i++) {
                if ($i=="pxname") px=i;
                if ($i=="svname") sv=i;
                if ($i=="scur") sc=i;
            }
            if (!px || !sv || !sc) exit 2;
            next;
        }
        px && sv && sc && $px==backend && ($sv==first || $sv==second) {
            if ($sc !~ /^[0-9]+$/) exit 2;
            count++;
            total+=$sc;
        }
        END {
            if (count!=2) exit 2;
            print total;
        }' <<< "$stats") || {
        echo "Cannot determine session counts for both source servers; refusing to complete drain." >&2
        exit 1
    }
    if (( sessions <= threshold )); then
        printf '{"remaining_connections":%s,"elapsed_seconds":%s}\n' "$sessions" "$SECONDS"
        exit 0
    fi
    remaining=$((timeout - SECONDS))
    if (( remaining <= 0 )); then
        echo "Drain timed out after ${timeout}s with ${sessions} active source sessions (threshold ${threshold})." >&2
        exit 1
    fi
    if (( remaining < interval )); then
        sleep "$remaining"
    else
        sleep "$interval"
    fi
done

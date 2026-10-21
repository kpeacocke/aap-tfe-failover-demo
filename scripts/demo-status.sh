#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ "$#" -gt 1 || ( "$#" -eq 1 && "$1" != --details ) ]]; then
    echo "Usage: bash scripts/demo-status.sh [--details]" >&2
    exit 2
fi
umask 077
mkdir -p "$script_dir/../.local/status"
DEMO_STATUS_DIRECTORY=$(mktemp -d "$script_dir/../.local/status/check-XXXXXX")
export DEMO_STATUS_DIRECTORY
rc=0
bash "$script_dir/aap-configure.sh" status > "$DEMO_STATUS_DIRECTORY/details.log" 2>&1 || rc=$?
if [[ -f "$DEMO_STATUS_DIRECTORY/report.txt" ]]; then
    cat "$DEMO_STATUS_DIRECTORY/report.txt"
else
    echo "NOT READY: status inspection failed before producing a complete report." >&2
    tail -35 "$DEMO_STATUS_DIRECTORY/details.log" >&2
    if [[ "$rc" == 0 ]]; then rc=1; fi
fi
echo "Diagnostics: $DEMO_STATUS_DIRECTORY/details.log"
if [[ "${1:-}" == --details ]]; then cat "$DEMO_STATUS_DIRECTORY/details.log"; fi
exit "$rc"

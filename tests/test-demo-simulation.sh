#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
run_fixture() {
    docker run --rm --workdir /runner/project --entrypoint ansible-playbook \
    --mount "type=bind,src=$repo_root/tests/demo,dst=/runner/project/tests/demo,readonly" \
    --mount "type=bind,src=$repo_root/playbooks,dst=/runner/project/playbooks,readonly" \
    --mount "type=bind,src=$repo_root/ansible.cfg,dst=/runner/project/ansible.cfg,readonly" \
    -e "DEMO_LIVE_FAILURE_SMOKE=$1" -e TF_VAR_aws_account_id=123456789012 -e TF_VAR_aws_region=us-east-2 \
    ww-demo-aap-ee:phase4 -i localhost, tests/demo/simulation.yml
}
run_fixture true
output=$(mktemp)
trap 'rm -f -- "$output"' EXIT
rc=0
run_fixture false > "$output" 2>&1 || rc=$?
if [[ "$rc" != 2 ]] || ! grep -Fq 'Administrator-only failure simulation requires DEMO_LIVE_FAILURE_SMOKE=true' "$output"; then
    cat "$output"
    echo "Expected explicit production opt-in rejection; got exit $rc." >&2
    exit 1
fi
echo "PASS: missing simulation approval rejected by the actual production assertion"

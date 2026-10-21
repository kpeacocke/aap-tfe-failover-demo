#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/scripts"
cp "$repo_root/scripts/demo-status.sh" "$fixture/scripts/"
cat > "$fixture/scripts/aap-configure.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == status ]]
echo "fixture detailed diagnostics"
if [[ "${STATUS_TEST_MISSING_REPORT:-}" != true ]]; then
    printf '%s\n' "${STATUS_TEST_REPORT:-READY fixture}" > "$DEMO_STATUS_DIRECTORY/report.txt"
fi
exit "${STATUS_TEST_RC:-0}"
SH
bash "$fixture/scripts/demo-status.sh" > "$fixture/output"
grep -Fq 'READY fixture' "$fixture/output"
if grep -Fq 'fixture detailed diagnostics' "$fixture/output"; then
    echo "Detailed output leaked into normal presenter view." >&2; exit 1
fi
bash "$fixture/scripts/demo-status.sh" --details > "$fixture/output"
grep -Fq 'fixture detailed diagnostics' "$fixture/output"
rc=0
STATUS_TEST_RC=2 STATUS_TEST_REPORT='NOT READY fixture' bash "$fixture/scripts/demo-status.sh" > "$fixture/output" 2>&1 || rc=$?
[[ "$rc" == 2 ]]
grep -Fq 'NOT READY fixture' "$fixture/output"
rc=0
STATUS_TEST_MISSING_REPORT=true bash "$fixture/scripts/demo-status.sh" > "$fixture/output" 2>&1 || rc=$?
[[ "$rc" == 1 ]]
grep -Fq 'failed before producing a complete report' "$fixture/output"
rc=0
bash "$fixture/scripts/demo-status.sh" --unsafe > "$fixture/output" 2>&1 || rc=$?
[[ "$rc" == 2 ]]
docker run --rm --user 0 --workdir /runner/project --entrypoint ansible-playbook \
    --mount "type=bind,src=$repo_root/bootstrap,dst=/runner/project/bootstrap,readonly" \
    --mount "type=bind,src=$repo_root/tests/status,dst=/runner/project/tests/status,readonly" \
    --mount "type=bind,src=$repo_root/ansible.cfg,dst=/runner/project/ansible.cfg,readonly" \
    --mount "type=bind,src=$fixture,dst=/run/demo-status" \
    -e DEMO_STATUS_REPORT_FILE=/run/demo-status/report.txt \
    ww-demo-aap-ee:phase4 -i localhost, tests/status/report.yml
echo "PASS: concise wrapper, error propagation, missing-report refusal and production readiness report cases"

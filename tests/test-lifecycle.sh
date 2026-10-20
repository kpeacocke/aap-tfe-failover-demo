#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/scripts" "$fixture/terraform/shared" "$fixture/.local/lifecycle" "$fixture/bin"
cp "$repo_root/scripts/terraform.sh" "$repo_root/scripts/load-env.sh" "$fixture/scripts/"
cp "$repo_root/scripts/lifecycle.sh" "$repo_root/scripts/bootstrap.sh" "$repo_root/scripts/teardown.sh" "$fixture/scripts/"
cp "$repo_root/tests/lifecycle/terraform" "$fixture/bin/terraform"
chmod +x "$fixture/bin/terraform"
printf '%s\n' 'HCP_TERRAFORM_ORGANIZATION=fixture-org' 'TF_TOKEN_app_terraform_io=fixture-only' \
    'TF_VAR_aws_region=us-east-2' 'TF_VAR_ssh_key_pair_name=fixture-key' > "$fixture/.env"
export LIFECYCLE_FIXTURE_ROOT="$fixture" LIFECYCLE_FIXTURE_CALLS="$fixture/calls"
export PATH="$fixture/bin:$PATH"
export LIFECYCLE_FIXTURE_PLAN='{"resource_changes":[{"mode":"managed","address":"aws_instance.haproxy","type":"aws_instance","change":{"before":{"tags_all":{"Project":"AAP-TFE-Failover-Demo","ManagedBy":"Terraform","Demo":"Datacentre-Failover"}}}}]}'

reject_command() {
    local rc=0
    "$@" > "$fixture/arguments-output" 2>&1 || rc=$?
    [[ "$rc" == 2 ]] || { cat "$fixture/arguments-output"; echo "Unsafe or invalid lifecycle arguments were accepted" >&2; exit 1; }
}
reject_command bash "$fixture/scripts/teardown.sh" profiles/demo.yml --apply
reject_command bash "$fixture/scripts/bootstrap.sh" profiles/demo.yml --confirm-destroy
reject_command bash "$fixture/scripts/teardown.sh" profiles/demo.yml --confirm-destroy extra
reject_command bash "$fixture/scripts/bootstrap.sh" missing-profile.yml
reject_command bash "$fixture/scripts/teardown.sh"
echo "PASS: malformed inputs and cross-operation confirmation flags rejected before tool installation or execution"

run_case() {
    local operation=$1 approved=$2 plan_rc=$3 expected_rc=$4 expected_applies=$5
    export LIFECYCLE_FIXTURE_OPERATION=$operation LIFECYCLE_FIXTURE_APPROVED=$approved LIFECYCLE_FIXTURE_RC=$plan_rc
    : > "$LIFECYCLE_FIXTURE_CALLS"
    local rc=0
    ansible-playbook -i localhost, "$repo_root/tests/lifecycle/plan.yml" > "$fixture/output" 2>&1 || rc=$?
    if [[ "$rc" != "$expected_rc" ]]; then
        cat "$fixture/output"
        echo "Unexpected test exit code $rc for $operation/$approved/$plan_rc" >&2
        exit 1
    fi
    local applies
    applies=$(grep -c ' apply ' "$LIFECYCLE_FIXTURE_CALLS" || true)
    [[ "$applies" == "$expected_applies" ]] || { cat "$fixture/output"; echo "Unexpected apply count: $applies" >&2; exit 1; }
    if find "$fixture/.local/lifecycle" -mindepth 1 -print -quit | grep -q .; then
        echo "Private saved-plan directory leaked" >&2
        exit 1
    fi
    echo "PASS: $operation approved=$approved plan_rc=$plan_rc applies=$applies"
}

run_case bootstrap false 2 2 0
run_case bootstrap true 2 0 1
run_case bootstrap false 0 0 0
run_case teardown false 2 0 0
run_case teardown true 2 0 1
run_case teardown true 1 2 0
export LIFECYCLE_FIXTURE_PLAN='{"resource_changes":[{"mode":"managed","address":"aws_instance.unrelated","type":"aws_instance","change":{"before":null}}]}'
run_case teardown true 2 2 0
export LIFECYCLE_FIXTURE_PLAN='{"resource_changes":[{"mode":"managed","address":"aws_instance.haproxy","type":"aws_instance","change":{"before":{"tags_all":{"Project":"unrelated","ManagedBy":"Terraform","Demo":"Datacentre-Failover"}}}}]}'
run_case teardown true 2 2 0
ansible-playbook -i localhost, "$repo_root/tests/lifecycle/guards.yml"
ansible-playbook -i localhost, "$repo_root/tests/lifecycle/platform.yml"
echo "Lifecycle saved-plan, approval, failure cleanup, ownership and quarantine tests passed."

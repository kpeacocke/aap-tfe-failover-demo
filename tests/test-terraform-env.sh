#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -f "$fixture/.env" "$fixture/output" "$fixture/demo.pub" "$fixture/bin/terraform" "$fixture/scripts/terraform.sh" "$fixture/scripts/load-env.sh"; rmdir "$fixture/bin" "$fixture/scripts" "$fixture"' EXIT
mkdir "$fixture/scripts" "$fixture/bin"
cp "$repo_root/scripts/terraform.sh" "$repo_root/scripts/load-env.sh" "$fixture/scripts/"

cat > "$fixture/.env" <<'ENV'
HCP_TERRAFORM_ORGANIZATION=test-org
TF_TOKEN_app_terraform_io=test-token
TF_VAR_aws_region=
TF_VAR_ssh_key_pair_name=test-existing-key
ENV

cat > "$fixture/bin/terraform" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${EXPECT_PUBLIC_KEY:-}" == "yes" ]]; then
    test "${TF_VAR_ssh_public_key:-}" = 'ssh-ed25519 test-public-key'
    test -z "${TF_VAR_ssh_key_pair_name:-}"
fi
printf 'Region=%s\n' "${TF_VAR_aws_region:-}"
MOCK
chmod +x "$fixture/bin/terraform"
export PATH="$fixture/bin:$PATH"

for root in shared dc1 dc2; do
    for command in plan apply destroy import refresh; do
        if bash "$fixture/scripts/terraform.sh" "$root" "$command" > "$fixture/output" 2>&1; then
            echo "FAIL: $root $command accepted an empty region." >&2
            exit 1
        fi
        grep -q 'Set TF_VAR_aws_region' "$fixture/output"
    done
done

for region in us-east-1 eu-west-2 ap-southeast-2; do
    printf 'TF_VAR_aws_region=%s\n' "$region" >> "$fixture/.env"
    for root in shared dc1 dc2; do
        result=$(bash "$fixture/scripts/terraform.sh" "$root" plan)
        if [[ "$result" != "Region=$region" ]]; then
            echo "FAIL: $root did not forward the configured region." >&2
            exit 1
        fi
    done
done

printf 'TF_VAR_aws_region=Sydney\n' >> "$fixture/.env"
if bash "$fixture/scripts/terraform.sh" shared plan > "$fixture/output" 2>&1; then
    echo "FAIL: accepted a malformed region." >&2
    exit 1
fi
grep -q 'Set TF_VAR_aws_region' "$fixture/output"
echo 'PASS: all roots require and forward the explicit lab region.'

cat >> "$fixture/.env" <<'ENV'
TF_VAR_aws_region=us-east-2
TF_VAR_ssh_key_pair_name=
TF_VAR_ssh_public_key=
SSH_PUBLIC_KEY_PATH=demo.pub
ENV
if bash "$fixture/scripts/terraform.sh" shared plan > "$fixture/output" 2>&1; then
    echo 'FAIL: missing public key was accepted.' >&2
    exit 1
fi
grep -q 'Demo SSH public key is missing' "$fixture/output"
printf 'ssh-ed25519 test-public-key\n' > "$fixture/demo.pub"
EXPECT_PUBLIC_KEY=yes bash "$fixture/scripts/terraform.sh" shared plan > "$fixture/output"
grep -q 'Region=us-east-2' "$fixture/output"
echo 'PASS: managed-key configuration forwards only the public key.'

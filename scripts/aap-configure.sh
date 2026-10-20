#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/load-env.sh
source "$script_dir/load-env.sh"

request_vars=()
case "${1:-}" in
    check) playbook=check-aap.yml ;;
    inspect) playbook=inspect-aap.yml ;;
    inspect-openshift) playbook=inspect-openshift.yml ;;
    build-ee) playbook=build-ee.yml ;;
    install) playbook=install-demo.yml ;;
    setup) playbook=setup-demo.yml ;;
    readiness) playbook=check-runtime.yml ;;
    portal-check) playbook=portal/check.yml ;;
    portal-install) playbook=portal/deploy.yml ;;
    portal-verify) playbook=portal/verify.yml ;;
    failover|recovery)
        if [[ "$#" -lt 3 || "$#" -gt 4 || ! "$2" =~ ^dc[12]$ || ! "$3" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
            echo "Usage: bash scripts/aap-configure.sh <failover|recovery> <dc1|dc2> <reference> [planned|failure]" >&2
            exit 2
        fi
        mode=${4:-planned}
        if [[ "$mode" != planned && "$mode" != failure ]]; then echo "Mode must be planned or failure." >&2; exit 2; fi
        playbook=run-workflow.yml
        request_vars=(-e "demo_launch_operation=$1" -e "demo_launch_dc=$2"
            -e "demo_launch_reference=$3" -e "demo_launch_mode=$mode")
        ;;
    *) echo "Usage: bash scripts/aap-configure.sh <check|inspect|inspect-openshift|build-ee|install|setup|readiness|failover|recovery|portal-check|portal-install|portal-verify>" >&2; exit 2 ;;
esac
if [[ "$playbook" != run-workflow.yml && "$#" -ne 1 ]]; then
    echo "This wrapper does not accept arbitrary Ansible arguments." >&2
    exit 2
fi
if [[ "$playbook" == build-ee.yml ]]; then
    DEMO_EE_SOURCE_REVISION=$(git -C "$repo_root" rev-parse HEAD)
    export DEMO_EE_SOURCE_REVISION
fi
docker build -f "$repo_root/execution-environment/Containerfile" -t ww-demo-aap-ee:phase4 "$repo_root"
if [[ "$playbook" == install-demo.yml && -z "${DEMO_OPERATOR_PASSWORD:-}" ]]; then
    umask 077
    mkdir -p "$repo_root/.local"
    operator_password_file="$repo_root/.local/aap-operator-password"
    if [[ ! -f "$operator_password_file" ]]; then openssl rand -base64 36 > "$operator_password_file"; fi
    DEMO_OPERATOR_PASSWORD=$(cat "$operator_password_file")
    export DEMO_OPERATOR_PASSWORD
fi
args=(--rm --user 0 --workdir /runner/project --entrypoint ansible-playbook
    --mount "type=bind,src=$repo_root/bootstrap,dst=/runner/project/bootstrap,readonly"
    --mount "type=bind,src=$repo_root/roles,dst=/runner/project/roles,readonly"
    --mount "type=bind,src=$repo_root/playbooks,dst=/runner/project/playbooks,readonly"
    --mount "type=bind,src=$repo_root/ansible.cfg,dst=/runner/project/ansible.cfg,readonly")
for name in AAP_HOSTNAME AAP_USERNAME AAP_PASSWORD AAP_TOKEN AAP_VALIDATE_CERTS \
    OPENSHIFT_API_URL OPENSHIFT_TOKEN OPENSHIFT_VALIDATE_CERTS AAP_OPENSHIFT_NAMESPACE DEMO_PORTAL_REUSE_CLUSTER_REGISTRY_AUTH \
    DEMO_EE_IMAGE DEMO_EE_SOURCE_REVISION DEMO_SCM_REVISION DEMO_OPERATOR_PASSWORD TFE_ADDRESS TFE_TOKEN TF_TOKEN_app_terraform_io \
    HCP_TERRAFORM_ORGANIZATION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN \
    TF_VAR_aws_region TF_VAR_aws_account_id HAPROXY_PUBLIC_IP; do
    if printenv "$name" >/dev/null 2>&1; then args+=(-e "$name"); fi
done
if [[ -n "${OPENSHIFT_CA_CERT:-}" ]]; then
    args+=(--mount "type=bind,src=$OPENSHIFT_CA_CERT,dst=/run/demo-cluster-ca,readonly"
        -e OPENSHIFT_CA_CERT=/run/demo-cluster-ca)
fi
if [[ "$playbook" == install-demo.yml ]]; then
    key=${SSH_PRIVATE_KEY_PATH:-.local/ssh/ww-demo}
    if [[ "$key" != /* ]]; then key="$repo_root/$key"; fi
    known_hosts=${SSH_KNOWN_HOSTS_PATH:-"$HOME/.ssh/known_hosts"}
    if [[ ! -r "$key" || ! -r "$known_hosts" ]]; then
        echo "Install requires the existing demo SSH key and verified SSH known_hosts file." >&2
        exit 1
    fi
    args+=(--mount "type=bind,src=$key,dst=/run/demo-key,readonly"
        --mount "type=bind,src=$known_hosts,dst=/run/demo-known-hosts,readonly"
        -e DEMO_BOOTSTRAP_KEY_FILE=/run/demo-key
        -e DEMO_BOOTSTRAP_KNOWN_HOSTS_FILE=/run/demo-known-hosts)
fi
docker run "${args[@]}" ww-demo-aap-ee:phase4 -i localhost, "bootstrap/$playbook" "${request_vars[@]}"

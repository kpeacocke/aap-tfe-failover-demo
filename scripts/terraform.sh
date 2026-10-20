#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/load-env.sh
source "$script_dir/load-env.sh"

if [[ "$#" -lt 2 ]]; then
    echo "Usage: $0 <shared|dc1|dc2> <terraform-command> [arguments...]" >&2
    exit 2
fi

root=$1
shift

case "$root" in
    shared|dc1|dc2) ;;
    *)
        echo "Terraform root must be shared, dc1, or dc2." >&2
        exit 2
        ;;
esac

if [[ -z "${HCP_TERRAFORM_ORGANIZATION:-}" ]]; then
    echo "HCP_TERRAFORM_ORGANIZATION must be set in .env." >&2
    exit 1
fi

if [[ -z "${TF_TOKEN_app_terraform_io:-}" ]]; then
    echo "TF_TOKEN_app_terraform_io must be set in .env." >&2
    exit 1
fi

if [[ ! "$HCP_TERRAFORM_ORGANIZATION" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "HCP_TERRAFORM_ORGANIZATION may contain only letters, digits, underscores, and hyphens." >&2
    exit 1
fi

export TF_VAR_terraform_organization="${TF_VAR_terraform_organization:-$HCP_TERRAFORM_ORGANIZATION}"
terraform_root="$script_dir/../terraform/$root"

case "$1" in
    plan|apply|destroy|import|refresh)
        if [[ ! "${TF_VAR_aws_region:-}" =~ ^[a-z]{2}(-[a-z]+)+-[0-9]+$ ]]; then
            echo "Set TF_VAR_aws_region in .env to the verified region of the existing RHDP lab. No default region is assumed." >&2
            exit 1
        fi
        ;;
esac

if [[ "$root" == "shared" && -z "${TF_VAR_ssh_key_pair_name:-}" && -z "${TF_VAR_ssh_public_key:-}" ]]; then
    case "$1" in
        plan|apply|destroy|import|refresh)
            public_key_path="${SSH_PUBLIC_KEY_PATH:-$repo_root/.local/ssh/ww-demo.pub}"
            if [[ "$public_key_path" != /* ]]; then
                public_key_path="$repo_root/$public_key_path"
            fi
            if [[ ! -r "$public_key_path" ]]; then
                echo "Demo SSH public key is missing. Run bash scripts/create-ssh-key.sh first." >&2
                exit 1
            fi
            unset TF_VAR_ssh_key_pair_name
            TF_VAR_ssh_public_key=$(cat "$public_key_path")
            export TF_VAR_ssh_public_key
            ;;
    esac
fi

if [[ "$1" == "init" ]]; then
    backend_enabled=true
    for argument in "${@:2}"; do
        if [[ "$argument" == "-backend=false" ]]; then
            backend_enabled=false
        fi
    done
    if [[ "$backend_enabled" == true ]]; then
        bash "$script_dir/ensure-workspace.sh" "ww-demo-$root"
    fi
    cat > "$terraform_root/backend.hcl" <<BACKEND_CONFIG
organization = "$HCP_TERRAFORM_ORGANIZATION"

workspaces {
  name = "ww-demo-$root"
}
BACKEND_CONFIG

    exec terraform -chdir="$terraform_root" init -backend-config=backend.hcl "${@:2}"
fi

exec terraform -chdir="$terraform_root" "$@"

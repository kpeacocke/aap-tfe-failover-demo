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

if [[ "$1" == "init" ]]; then
    cat > "$terraform_root/backend.hcl" <<BACKEND_CONFIG
organization = "$HCP_TERRAFORM_ORGANIZATION"

workspaces {
  name = "ww-demo-$root"
}
BACKEND_CONFIG

    exec terraform -chdir="$terraform_root" init -backend-config=backend.hcl "${@:2}"
fi

exec terraform -chdir="$terraform_root" "$@"

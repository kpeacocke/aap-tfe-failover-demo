#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/load-env.sh
source "$script_dir/load-env.sh"

if [[ "$#" -lt 2 || "$#" -gt 3 || ! "$1" =~ ^(bootstrap|teardown)$ ]]; then
    echo "Usage: scripts/<bootstrap|teardown>.sh profiles/demo.yml [--apply|--confirm-destroy]" >&2
    exit 2
fi
operation=$1
profile=$2
approved=false
if [[ "$#" == 3 ]]; then
    if [[ "$operation:$3" != bootstrap:--apply && "$operation:$3" != teardown:--confirm-destroy ]]; then
        echo "Use --apply only for bootstrap, or --confirm-destroy only for teardown." >&2
        exit 2
    fi
    approved=true
fi
if [[ "$profile" != /* ]]; then profile="$repo_root/$profile"; fi
if [[ ! -f "$profile" ]]; then echo "Profile not found: $profile" >&2; exit 2; fi

python=${BOOTSTRAP_PYTHON:-python3}
"$python" -c 'import sys; assert (3, 12) <= sys.version_info[:2] < (3, 15), "Use Python 3.12-3.14; set BOOTSTRAP_PYTHON to its executable."'
venv="$repo_root/.local/lifecycle-venv"
collections="$repo_root/.local/lifecycle-collections"
export ANSIBLE_COLLECTIONS_PATH="$collections"
if [[ ! -x "$venv/bin/python" ]]; then
    "$python" -m venv "$venv"
fi
requirements_hash=$("$venv/bin/python" -c \
    'import hashlib,sys; print(hashlib.sha256(b"".join(open(p, "rb").read() for p in sys.argv[1:])).hexdigest())' \
    "$repo_root/bootstrap/requirements.txt" "$repo_root/bootstrap/requirements.yml" "$repo_root/bootstrap/aap-requirements.yml")
if [[ ! -d "$collections/ansible_collections/amazon/aws" || ! -d "$collections/ansible_collections/infra/aap_configuration" \
    || ! -f "$venv/.requirements-ready" || "$(< "$venv/.requirements-ready")" != "$requirements_hash" ]]; then
    "$venv/bin/python" -m pip install -r "$repo_root/bootstrap/requirements.txt"
    "$venv/bin/ansible-galaxy" collection install -r "$repo_root/bootstrap/requirements.yml" -p "$collections" --force
    "$venv/bin/ansible-galaxy" collection install -r "$repo_root/bootstrap/aap-requirements.yml" --no-deps -p "$collections" --force
    printf '%s\n' "$requirements_hash" > "$venv/.requirements-ready"
fi
cd "$repo_root"
extra_vars=$("$venv/bin/python" -c \
    'import json,sys; print(json.dumps({"lifecycle_profile_path":sys.argv[1],"lifecycle_approved":sys.argv[2]=="true","ansible_python_interpreter":sys.argv[3]}))' \
    "$profile" "$approved" "$venv/bin/python")
exec "$venv/bin/ansible-playbook" -i localhost, "bootstrap/$operation.yml" \
    -e "$extra_vars"

#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
docker build -f "$repo_root/tests/runtime/Dockerfile" -t ww-demo-runtime-tests "$repo_root/bootstrap"
docker run --rm \
    --mount "type=bind,src=$repo_root/roles,dst=/repo/roles,readonly" \
    --mount "type=bind,src=$repo_root/playbooks,dst=/repo/playbooks,readonly" \
    --mount "type=bind,src=$repo_root/application,dst=/repo/application,readonly" \
    --mount "type=bind,src=$repo_root/tests/runtime,dst=/repo/tests/runtime,readonly" \
    --mount "type=bind,src=$repo_root/tests/terraform_api,dst=/repo/tests/terraform_api,readonly" \
    --mount "type=bind,src=$repo_root/ansible.cfg,dst=/repo/ansible.cfg,readonly" \
    ww-demo-runtime-tests

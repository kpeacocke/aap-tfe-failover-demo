#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
docker build -f "$repo_root/execution-environment/Containerfile" -t ww-demo-aap-ee:phase4 "$repo_root"
docker run --rm --workdir /runner/project --entrypoint ansible-playbook \
    --mount "type=bind,src=$repo_root/bootstrap,dst=/runner/project/bootstrap,readonly" \
    --mount "type=bind,src=$repo_root/portal,dst=/runner/project/portal,readonly" \
    --mount "type=bind,src=$repo_root/tests/portal,dst=/runner/project/tests/portal,readonly" \
    --mount "type=bind,src=$repo_root/ansible.cfg,dst=/runner/project/ansible.cfg,readonly" \
    ww-demo-aap-ee:phase4 -i localhost, tests/portal/templates.yml tests/portal/launchers.yml tests/portal/credentials.yml tests/portal/chart.yml

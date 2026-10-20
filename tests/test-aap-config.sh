#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
docker build -f "$repo_root/execution-environment/Containerfile" -t ww-demo-aap-ee:phase4 "$repo_root"
docker run --rm --workdir /runner/project --entrypoint ansible-playbook \
    --mount "type=bind,src=$repo_root/bootstrap,dst=/runner/project/bootstrap,readonly" \
    --mount "type=bind,src=$repo_root/ansible.cfg,dst=/runner/project/ansible.cfg,readonly" \
    ww-demo-aap-ee:phase4 -i localhost, bootstrap/validate-configuration.yml

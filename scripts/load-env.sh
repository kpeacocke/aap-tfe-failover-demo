#!/usr/bin/env bash

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$repo_root/.env"

if [[ ! -f "$env_file" ]]; then
    if [[ "${1:-}" == "optional" ]]; then
        return 0
    fi
    echo "Missing $env_file. Copy .env.example to .env and fill in the required values." >&2
    return 1
fi

# .env is a trusted, shell-compatible local configuration file.
set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

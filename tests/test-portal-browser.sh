#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/load-env.sh
source "$script_dir/../scripts/load-env.sh" optional

npm --prefix "$repo_root/tests/portal-browser" test -- "$@"

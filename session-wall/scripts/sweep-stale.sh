#!/usr/bin/env bash
# Standalone stale-bulletin sweeper. Useful for manual invocation or cron.
# Walks every directory passed as an argument (or $PWD if none).

set -uo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

if [[ $# -eq 0 ]]; then
  set -- "$PWD"
fi

for cwd in "$@"; do
  sweep_stale_in "$(wall_dir_for "$cwd")"
done

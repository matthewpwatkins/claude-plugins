#!/usr/bin/env bash
# SessionStart hook: inject a brief reminder pointing the model at the
# session-wall skill and the check-before-long-task rule.

set -euo pipefail

read -r -d '' MSG <<'EOF' || true
session-wall is active. Before starting any task likely to last more than ~5 minutes or touch multiple files (plan execution, refactor, multi-file edit, deploy), check `.claude/session-wall/` in the project root. If another session has a fresh bulletin (last_heartbeat within 30 minutes) declaring overlap with what you're about to touch, stop and ask the user. See the `session-wall` skill for the full protocol.
EOF

jq -n --arg msg "$MSG" '{systemMessage: $msg}'

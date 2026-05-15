#!/usr/bin/env bash
# auto-pause: SessionStart hook. Emits a systemMessage with current state + directives.
set -u

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
source "$LIB"

[ "$(cfg '.enabled')" = "true" ] || exit 0

armed_flag="$(is_armed)"
pause="$(cfg '.pauseThresholdPct')"
warn="$(cfg '.warnThresholdPct')"

state_json="$(budget_state 2>/dev/null || true)"
if [ -n "$state_json" ]; then
  pct="$(echo "$state_json" | jq -r '.pct')"
  end="$(echo "$state_json" | jq -r '.endTime')"
  budget_phrase="Current budget: ${pct}% of the 5-hour window; resets at ${end}."
else
  budget_phrase="Current budget: ccusage not yet available (no JSONL data, or ccusage not installed)."
fi

armed_phrase="disarmed (hook is a no-op this session)"
if [ "$armed_flag" = "1" ]; then
  armed_phrase="armed"
fi

msg=$(cat <<EOF
[auto-pause] The auto-pause plugin is ${armed_phrase}. ${budget_phrase}

When budget reaches ${pause}% of the 5-hour window, a PreToolUse hook will sleep
this session until reset — your next tool call will simply block for hours.
At ${warn}% you'll get a non-blocking warning.

To make pauses non-destructive: for any task that takes >5 min or >100 iterations,
use the auto-pause:chunk-and-checkpoint skill. Write per-item progress to
.claude/auto-pause/checkpoint-<jobname>.jsonl and read it back on resume.

When orchestrating backgrounded named subagents, use the auto-pause:orchestrate-subagents
skill so workers checkpoint+exit cleanly on pause messages.

Off-switches: set env AUTO_PAUSE_ARMED=0, run /auto-pause:disarm in this session,
or set autoArm:false in ~/.claude/auto-pause/config.json.
EOF
)

jq -nc --arg msg "$msg" '{systemMessage: $msg}'
exit 0

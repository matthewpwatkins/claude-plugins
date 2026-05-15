---
description: "Force-pause this session until the next 5-hour reset (or a given duration)"
allowed-tools: ["Bash(bash:*)", "Bash(sleep:*)", "Bash(date:*)", "Bash(jq:*)"]
argument-hint: "[seconds]"
---

# /auto-pause:pause $ARGUMENTS

Immediately pause this session. If no argument, sleep until the next 5-hour window reset (+ buffer). If an integer is given, sleep that many seconds instead.

```!
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
arg="$ARGUMENTS"
if [ -n "$arg" ] && [[ "$arg" =~ ^[0-9]+$ ]]; then
  echo "[auto-pause] Sleeping ${arg}s..."
  sleep "$arg"
  echo "[auto-pause] Woke up."
else
  state="$(budget_state)" || { echo "ccusage unavailable; pass an explicit duration in seconds."; exit 1; }
  end="$(echo "$state" | jq -r '.endTime')"
  buf="$(cfg '.bufferSeconds')"
  echo "[auto-pause] Sleeping until ${end} + ${buf}s..."
  sleep_until "$end" "$buf"
  echo "[auto-pause] Woke up."
fi
```

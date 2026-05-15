---
description: "List active session-wall bulletins for the current project"
allowed-tools: ["Bash(ls:*)", "Bash(cat:*)", "Bash(jq:*)", "Bash(date:*)", "Bash(find:*)"]
---

# /wall

List bulletins on the session-wall for this project, with freshness annotated.

```!
WALL=".claude/session-wall"
if [ ! -d "$WALL" ]; then
  echo "(no wall — $WALL does not exist)"
  exit 0
fi
shopt -s nullglob
files=("$WALL"/*.json)
if [ ${#files[@]} -eq 0 ]; then
  echo "(wall is empty)"
  exit 0
fi
NOW=$(date -u +%s)
for f in "${files[@]}"; do
  HB=$(jq -r '.last_heartbeat // ""' "$f")
  HB_EPOCH=$(date -u -d "$HB" +%s 2>/dev/null || echo 0)
  AGE=$(( NOW - HB_EPOCH ))
  if [ $AGE -lt 1800 ]; then FRESHNESS="FRESH (${AGE}s)"; else FRESHNESS="STALE (${AGE}s)"; fi
  echo "── $(basename "$f") — $FRESHNESS ──"
  jq '{session_id, branch, current_activity, paths, external_resources,
       started_at, last_heartbeat,
       history_tail: (.history[-3:] // [])}' "$f"
  echo ""
done
```

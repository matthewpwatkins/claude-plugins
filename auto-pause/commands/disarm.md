---
description: "Disarm auto-pause for this session (hook becomes a no-op)"
allowed-tools: ["Bash(touch:*)", "Bash(rm:*)", "Bash(mkdir:*)"]
---

# /auto-pause:disarm

Disable the auto-pause hook for the current session only. Other sessions and future sessions are unaffected.

```!
SID="${CLAUDE_SESSION_ID:-default}"
DIR="$HOME/.claude/auto-pause/sessions"
mkdir -p "$DIR"
rm -f "$DIR/$SID.armed"
touch "$DIR/$SID.disarmed"
echo "Disarmed session $SID."
```

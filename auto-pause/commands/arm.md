---
description: "Arm auto-pause for this session (overrides config autoArm:false)"
allowed-tools: ["Bash(touch:*)", "Bash(rm:*)", "Bash(mkdir:*)"]
---

# /auto-pause:arm

Force this session armed, regardless of the `autoArm` config field. Creates a marker file scoped to the current session id.

```!
SID="${CLAUDE_SESSION_ID:-default}"
DIR="$HOME/.claude/auto-pause/sessions"
mkdir -p "$DIR"
rm -f "$DIR/$SID.disarmed"
touch "$DIR/$SID.armed"
echo "Armed session $SID."
```

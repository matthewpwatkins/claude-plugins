---
description: "Install the auto-pause statusline into ~/.claude/settings.json (backs up any existing one)"
allowed-tools: ["Bash(jq:*)", "Bash(cp:*)", "Bash(test:*)", "Bash(mkdir:*)", "Bash(cat:*)"]
---

# /auto-pause:enable-statusline

Patch `~/.claude/settings.json` so Claude Code uses the auto-pause statusline. Any existing `statusLine` setting is saved to `~/.claude/auto-pause/statusline-backup.json` so `disable-statusline` can restore it.

```!
set -e
SETTINGS="$HOME/.claude/settings.json"
BACKUP="$HOME/.claude/auto-pause/statusline-backup.json"
mkdir -p "$HOME/.claude/auto-pause"
test -f "$SETTINGS" || echo '{}' > "$SETTINGS"

# Save existing statusLine block (if any).
jq '.statusLine // null' "$SETTINGS" > "$BACKUP"

NEW_CMD="bash \"${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh\""
jq --arg cmd "$NEW_CMD" '.statusLine = {type: "command", command: $cmd, refreshInterval: 60, padding: 0}' \
  "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
echo "Enabled auto-pause statusline. Previous statusLine backed up to:"
echo "  $BACKUP"
echo
echo "Current settings.statusLine:"
jq '.statusLine' "$SETTINGS"
```

---
description: "Restore the pre-auto-pause statusline (or remove it if none was set)"
allowed-tools: ["Bash(jq:*)", "Bash(cp:*)", "Bash(test:*)", "Bash(cat:*)"]
---

# /auto-pause:disable-statusline

Restore the `statusLine` field of `~/.claude/settings.json` from the backup created by `/auto-pause:enable-statusline`.

```!
set -e
SETTINGS="$HOME/.claude/settings.json"
BACKUP="$HOME/.claude/auto-pause/statusline-backup.json"

if [ ! -f "$BACKUP" ]; then
  echo "No backup found at $BACKUP. Removing statusLine from settings.json."
  jq 'del(.statusLine)' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  exit 0
fi

PREV="$(cat "$BACKUP")"
if [ "$PREV" = "null" ]; then
  jq 'del(.statusLine)' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  echo "Removed statusLine (no previous value)."
else
  jq --argjson prev "$PREV" '.statusLine = $prev' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  echo "Restored previous statusLine:"
  jq '.statusLine' "$SETTINGS"
fi
```

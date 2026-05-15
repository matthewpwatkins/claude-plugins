---
description: "Open the auto-pause config file (creates it from defaults if missing)"
allowed-tools: ["Bash(mkdir:*)", "Bash(cp:*)", "Bash(cat:*)", "Bash(test:*)"]
---

# /auto-pause:configure

Print the current user config (creating it from defaults if it doesn't yet exist) and list every field with its meaning.

```!
mkdir -p "$HOME/.claude/auto-pause"
if [ ! -f "$HOME/.claude/auto-pause/config.json" ]; then
  cp "${CLAUDE_PLUGIN_ROOT}/defaults/config.json" "$HOME/.claude/auto-pause/config.json"
  echo "Created $HOME/.claude/auto-pause/config.json from defaults."
fi
echo "Edit this file to override settings:"
echo "  $HOME/.claude/auto-pause/config.json"
echo
echo "Current contents:"
cat "$HOME/.claude/auto-pause/config.json"
```

## Fields

- **enabled** (`true`/`false`) — master kill switch. `false` makes every hook a no-op.
- **autoArm** (`true`/`false`) — when `true`, the pause/warn hook runs on every session by default.
- **pauseThresholdPct** (number) — sleep the session when 5-hour usage % reaches this.
- **warnThresholdPct** (number) — emit a non-blocking warning when usage reaches this.
- **bufferSeconds** (number) — extra seconds to sleep past the window's reset, to avoid waking up mid-rollover.
- **cacheSeconds** (number) — how long to cache ccusage's response between hook invocations.
- **tokenLimit** (`"max"` or a number) — passed to `ccusage --token-limit`. `"max"` makes ccusage learn the limit from your past blocks (recommended). A number sets an explicit token ceiling.
- **ccusageCommand** (`auto` or a shell snippet) — `auto` prefers a globally-installed `ccusage`, else falls back to `npx -y ccusage`. Override e.g. with `"bun x ccusage"`.
- **statusline.\*** — display options for the optional statusline.

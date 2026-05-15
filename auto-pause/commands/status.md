---
description: "Show current 5-hour window usage and auto-pause state"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/budget-check.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh:*)", "Bash(bash:*)", "Bash(jq:*)", "Bash(cat:*)"]
---

# /auto-pause:status

Print the current 5-hour budget state from ccusage and the configured thresholds.

```!
bash "${CLAUDE_PLUGIN_ROOT}/scripts/budget-check.sh"
echo "---"
echo "Config (merged):"
bash -c 'source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh" && load_config' | jq '{enabled, autoArm, pauseThresholdPct, warnThresholdPct, plan, tokenLimitOverride, bufferSeconds, cacheSeconds}'
echo "---"
echo "Armed this session: $(bash -c 'source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh" && is_armed')"
```

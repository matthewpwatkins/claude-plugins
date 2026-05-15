# auto-pause

A [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin that **proactively pauses your session before it burns through the 5-hour subscription window**, so long autonomous runs survive the reset without losing work.

## What it does

- **Pause before death**: a `PreToolUse` hook reads `ccusage`'s active-block stats before every tool call. When usage ≥ `pauseThresholdPct` (default 95%), the hook `sleep`s the session until the next 5-hour reset. The session stays alive — your next tool call simply takes a few hours to "start."
- **Warn at the cliff**: at `warnThresholdPct` (default 80%) the hook injects a non-blocking system message so the model can begin checkpointing.
- **Teach the agent to chunk**: a `SessionStart` hook and two skills (`chunk-and-checkpoint`, `orchestrate-subagents`) instruct the agent to structure long jobs so resumption is lossless.
- **Optional statusline**: shows live budget % and reset time. Opt-in only (`/auto-pause:enable-statusline`) so it doesn't clobber a statusline you already use.

## Prerequisites

- `jq` available on PATH.
- `ccusage` either installed globally (`npm i -g ccusage`) or accessible via `npx`. If neither is present the plugin loads silently and does nothing — no harm.

## Install

```
/plugin marketplace add https://github.com/matthewpwatkins/claude-plugins
/plugin install auto-pause@claude-plugins
```

Start a new session. You'll see a `[auto-pause]` system message reporting current budget + arm state.

## Commands

| Command | What it does |
|---|---|
| `/auto-pause:status` | Print current budget %, reset time, merged config, and arm state |
| `/auto-pause:configure` | Create (if needed) and print your user config; lists every field |
| `/auto-pause:pause [seconds]` | Force-pause now — until reset, or for the given seconds |
| `/auto-pause:arm` | Force this session armed (overrides `autoArm: false`) |
| `/auto-pause:disarm` | Force this session disarmed (overrides `autoArm: true`) |
| `/auto-pause:enable-statusline` | Patch `~/.claude/settings.json` to use the auto-pause statusline |
| `/auto-pause:disable-statusline` | Restore your previous statusline |

## Configuration

Defaults ship inside the plugin. User overrides at `~/.claude/auto-pause/config.json` — same shape, partial allowed. Missing keys fall back to defaults.

```json
{
  "enabled": true,
  "autoArm": true,
  "pauseThresholdPct": 95,
  "warnThresholdPct": 80,
  "bufferSeconds": 60,
  "cacheSeconds": 30,
  "tokenLimit": "max",
  "ccusageCommand": "auto",
  "statusline": {
    "format": "compact",
    "showResetTime": true,
    "warnColor": "yellow",
    "pauseColor": "red"
  }
}
```

See [`/auto-pause:configure`](./commands/configure.md) for per-field meanings.

## Arm precedence (highest first)

1. Env var: `AUTO_PAUSE_ARMED=0` or `1`.
2. Session marker: `/auto-pause:arm` or `/auto-pause:disarm` in this session.
3. Config field: `autoArm` in `~/.claude/auto-pause/config.json`.

## Skills

The plugin ships two skills (auto-discovered by Claude Code):

- **`auto-pause:chunk-and-checkpoint`** — invoke before any long iterative job to learn the checkpoint pattern that makes pauses lossless.
- **`auto-pause:orchestrate-subagents`** — for the main agent coordinating backgrounded workers, using Monitor + SendMessage to coordinate a graceful pause.

## How resumption actually works

The 5-hour rate limit is account-scoped, not process-scoped. When the hook runs `sleep` for several hours, the Claude Code process stays alive; the rate-limit window rolls over while it sleeps; the next tool call hits a fresh window and proceeds. **No `--resume`, no re-launch, no context loss.** The model's only experience of the pause is a system message saying "you slept" and a long-looking tool call.

For unattended overnight work, layer [`claude-auto-retry`](https://github.com/cheapestinference/claude-auto-retry) underneath as well — it catches the case where something *else* kills the session entirely.

## License

MIT.

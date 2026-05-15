# session-wall

A Claude Code plugin for coordinating multiple Claude sessions running concurrently against the same project — without them stepping on each other's toes.

## The problem

Running parallel Claude sessions on a shared repo is great for throughput, but two sessions editing the same file (or worse, both running `cdk deploy` against the same dev account) is a fast path to lost work or corrupted state. Worktrees solve part of it (file isolation), but not shared cloud resources, and they don't tell sessions about each other.

## How it works

Each session that's about to do something modifying writes a small JSON **bulletin** to `<project>/.claude/session-wall/<session-id>.json`. The bulletin declares:

- What the session is currently doing (`current_activity`)
- The paths and external resources it expects to touch
- A `last_heartbeat` timestamp, refreshed automatically on every modifying tool use
- An append-only `history`

Before starting any long modification task, a session **checks the wall**: if another session has a fresh bulletin overlapping its planned scope, it stops and asks the user.

Bulletins are ephemeral — deleted on session end (Stop hook) and swept after 30 minutes of no heartbeat (in case a session crashes or is killed).

## What the plugin provides

- **SessionStart hook** — injects a one-paragraph reminder pointing at the `session-wall` skill.
- **PreToolUse hook** (Edit / Write / NotebookEdit / Bash) — lazy-creates the bulletin on the first modifying action, refreshes the heartbeat on every subsequent one, and sweeps stale bulletins.
- **Stop hook** — removes this session's bulletin.
- **`session-wall` skill** — the behavioral half: when to check the wall, the overlap rule, the atomic-write recipe.
- **`/wall` slash command** — read-only listing of all bulletins in the current project, with freshness annotated.

## Install

From a local clone:

```bash
git clone https://github.com/matthewwatkins/session-wall ~/dev-personal/session-wall
# Then in Claude Code:
/plugin marketplace add ~/dev-personal/session-wall
/plugin install session-wall@session-wall
```

(Adjust the path to where you cloned it.)

## Usage

Once installed there's nothing to do — the SessionStart hook will remind each session that the wall is active. Sessions self-coordinate via the skill.

The recommended pairing is **one worktree per parallel feature** (Claude Code's `.claude/worktrees/`), so file-level edits are physically isolated. The wall handles the cases worktrees don't: shared cloud resources, deploys, destructive scripts, and "is anyone else here?".

### Tweaking the destructive-Bash list

Override the regex with the env var `SESSION_WALL_DESTRUCTIVE_REGEX`. Default:

```
git\s+push|git\s+reset\s+--hard|git\s+clean|rm\s+-rf|terraform\s+apply|cdk\s+deploy|(^|/)(truncate|wipe|purge|reset-)[a-zA-Z0-9_.-]*
```

### Tweaking the staleness threshold

`SESSION_WALL_STALE_SECONDS` (default 1800).

## Honest limits

- **Hooks cannot enforce behavior.** They keep the wall correct (heartbeat, lazy create, cleanup, sweep). The model is responsible for actually checking the wall before long tasks and pausing on overlap. The skill teaches this; if a session ignores it, nothing stops it.
- **No tool blocking in v1.** The plugin is observational. A future opt-in mode could add a deploy lock, but v1 keeps it simple.
- **Per-CWD.** The wall lives under the project root. Sessions in different projects don't see each other (by design).

## License

MIT.

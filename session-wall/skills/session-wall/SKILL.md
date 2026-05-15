---
name: session-wall
description: Coordinate parallel Claude Code sessions via per-session bulletin files. Use when starting a long modification task (plan execution, refactor, multi-file edit, deploy) or when the user asks who else is working in the repo.
---

# session-wall

You may be one of several Claude Code sessions running concurrently against the same project. The wall is the coordination point.

## What the wall is

A directory at `<project>/.claude/session-wall/` containing one JSON bulletin per active session, named `<session_id>.json`. Each bulletin declares what that session is currently doing, where, and when it last checked in.

The plugin's hooks maintain mechanical fields automatically: `last_heartbeat` is refreshed on every modifying tool use, your bulletin is created lazily on the first destructive action, and stale bulletins (no heartbeat in 30 minutes) are swept. **You are responsible for the semantic fields**: `current_activity`, `paths`, `external_resources`, and meaningful `history` entries.

## When to check the wall

Check **before** starting any task likely to last more than ~5 minutes or touch more than ~3 files. Examples:

- Executing a multi-phase plan
- Refactoring across files
- Running a deploy or destructive script
- Backfilling/migrating data
- Long-running test or benchmark runs

Skim with: `ls .claude/session-wall/ 2>/dev/null && cat .claude/session-wall/*.json 2>/dev/null`. Or use the `/wall` slash command.

## Overlap rule

For each other bulletin on the wall:

1. **Stale** — `last_heartbeat` older than 30 minutes → ignore. The hook will sweep it.
2. **Fresh, no overlap** with the paths/resources you intend to touch → proceed.
3. **Fresh, overlap** with your planned scope → **stop and ask the user.** Quote the other session's `current_activity` and the overlapping paths/resources, and ask whether to wait, coordinate via worktree, or proceed anyway.

Overlap means: any path glob intersects (use simple prefix check or glob match), or any `external_resources` string matches (e.g., same AWS table name, same DB, same external service).

## Updating your own bulletin

Edit your bulletin (`<session_id>.json`) at meaningful boundaries — not every edit. Good moments:

- Just after the hook lazy-creates it: fill in `paths`, `external_resources`, and a real `current_activity`.
- Phase boundaries during plan execution.
- When scope changes (you discover you also need to touch X).
- Before a deploy or destructive script.

Keep `history` append-only. Each entry is `{"ts": "...", "msg": "..."}`.

### Atomic write recipe

Never write directly to the bulletin file — concurrent reads can see a half-written file. Use temp + rename:

```bash
F=".claude/session-wall/${SESSION_ID}.json"
TMP="$(mktemp "${F}.XXXXXX")"
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg activity "implementing manifest builder (phase 2)" \
   --argjson paths '["src/api-stack/chat/**","site/src/pages/faq/**"]' \
   '.current_activity = $activity
    | .paths = $paths
    | .last_heartbeat = $ts
    | .history += [{ts: $ts, msg: $activity}]' "$F" > "$TMP" && mv "$TMP" "$F"
```

If you don't yet know your `session_id`, read it from any existing bulletin in the wall that matches your context, or skip the manual update — the hook will keep the heartbeat fresh either way.

## What the hooks do (so you don't double-handle it)

- **SessionStart**: prints this reminder.
- **PreToolUse** on Edit/Write/NotebookEdit: lazy-creates your bulletin if missing, refreshes `last_heartbeat`.
- **PreToolUse** on Bash: same, but only when the command matches a destructive pattern (`git push`, `git reset --hard`, `git clean`, `rm -rf`, `terraform apply`, `cdk deploy`, scripts named `truncate*|wipe*|purge*|reset-*`). If a bulletin already exists, any Bash refreshes the heartbeat.
- **Stop**: deletes your bulletin.
- Stale bulletins (>30 min since heartbeat) are swept on every PreToolUse.

## Honest limits

The hooks cannot enforce the overlap-rule check — that's behavioral. If you skip the check and stomp on another session's work, the hooks won't stop you. Treat the check as a hard step before any long modification task.

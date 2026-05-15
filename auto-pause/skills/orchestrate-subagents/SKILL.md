---
name: orchestrate-subagents
description: When you spawn backgrounded named subagents (workers) to do parallel work, use this skill to wire them up so they pause cooperatively when the 5-hour budget runs out. Combines Monitor (to surface budget events) with SendMessage (to pause workers).
---

# orchestrate-subagents

The `PreToolUse` hook in auto-pause is a per-process safety net: it only sleeps the session that invokes a tool. When the main agent orchestrates many backgrounded workers, you want a *coordinated* pause: workers checkpoint and exit cleanly, then everyone wakes up together.

## The architecture

```
                          ┌──────────────────────┐
                          │   main agent (you)   │
                          │                      │
                          │  Monitor(watcher)    │
                          │   until "^PAUSE"     │
                          └──────────┬───────────┘
                                     │
       ┌─────────────────────────────┼─────────────────────────────┐
       │                             │                             │
┌──────▼──────┐               ┌──────▼──────┐               ┌──────▼──────┐
│  watcher    │               │ worker-1    │               │ worker-2    │
│ (bg bash):  │               │ (bg agent,  │   ...         │ (bg agent,  │
│ loops calling│               │  named)     │               │  named)     │
│ budget-check │               │             │               │             │
│ every 30s   │               │ checkpoints │               │ checkpoints │
└─────────────┘               └─────────────┘               └─────────────┘
```

## Recipe

1. **Workers use the chunk-and-checkpoint skill.** Non-negotiable. Each worker writes a `checkpoint-<job>-<worker>.jsonl` after each unit. On pause-message receipt, they must finish their current unit, then exit.

2. **Spawn workers backgrounded and named.** Each `Agent` call uses `run_in_background: true` and a unique `name` (e.g., `worker-1`, `worker-2`).

3. **Spawn a watcher in the background.** Use `Bash` with `run_in_background: true`:

   ```bash
   while true; do
     bash "$CLAUDE_PLUGIN_ROOT/scripts/budget-check.sh"
     sleep 30
   done
   ```

   Each tick prints one line: `OK 42 <reset>`, `WARN 81 <reset>`, or `PAUSE 96 <reset>`.

4. **Monitor the watcher with an `until` regex** matching `^PAUSE`:

   ```
   Monitor(shellId: <watcher-id>, until: "^PAUSE ")
   ```

   Monitor returns the moment the watcher prints a PAUSE line, with that line as the result.

5. **On PAUSE, fan out a pause message:**

   ```
   SendMessage(to: "worker-1", message: "auto-pause: checkpoint your current unit and exit cleanly")
   SendMessage(to: "worker-2", message: "auto-pause: checkpoint your current unit and exit cleanly")
   ```

   The message reaches each worker at its next turn boundary (after it finishes its in-flight tool). Workers should be coded to recognize this exact phrase and call `exit` after writing their last checkpoint line.

6. **Wait for workers to return.** The `Agent` background tasks complete naturally after the worker exits.

7. **Sleep the main agent until reset.** Either re-read the `budget-check.sh` output to get the reset ISO and call `sleep` directly, or invoke `/auto-pause:pause` with no argument.

8. **Re-spawn workers identically.** They read their checkpoints and resume. The watcher can also be re-started.

## When to use this vs. just the PreToolUse hook

- **Single-agent jobs**: the PreToolUse hook + chunk-and-checkpoint is enough. The hook sleeps the session between tools; the loop resumes naturally.
- **Multi-worker jobs**: use this skill. The hook still protects the main agent, but it cannot coordinate the workers. This skill does that coordination.

## Idempotence reminder

After resume, the watcher and workers will all see a fresh 5-hour window. The checkpoint files are the source of truth. Workers should always re-read their checkpoint on start and skip completed units. Treat the pause + re-spawn cycle as semantically equivalent to a normal crash-and-recover.

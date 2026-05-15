---
name: chunk-and-checkpoint
description: When you have a long iterative job (classifying many docs, processing many files, scraping many URLs, running many tests), structure it so the work is resumable after an auto-pause. Use this skill BEFORE starting any task that will likely run >5 min or >100 iterations.
---

# chunk-and-checkpoint

The `auto-pause` plugin sleeps your session when it nears the 5-hour subscription window. Sleep is non-destructive *only if* your in-flight work has been written to disk. Use this skill to structure long jobs accordingly.

## The pattern

1. **Pick a job name.** A short kebab-case label, e.g. `classify-v8`, `ingest-byu-2026`.

2. **Define the work as a list of atomic units.** Each unit must be self-contained: one document, one URL, one record. Each unit must have a stable ID (URL hash, content ID, filename — whatever is deterministic).

3. **Maintain a checkpoint file** at `.claude/auto-pause/checkpoint-<jobname>.jsonl`. After each unit completes successfully, append one line:

   ```json
   {"id":"<unit-id>","ts":"<ISO timestamp>","output":"<path or summary>","ok":true}
   ```

   Use `>>` append; never rewrite the file. JSON Lines so partial writes don't corrupt the whole thing.

4. **On every invocation, read the checkpoint first.** Build a set of already-completed IDs, then filter the input list. Never start from scratch if the checkpoint exists — unless the user explicitly asks for a fresh run.

5. **Make units idempotent.** If you'd append a duplicate output for the same ID, your downstream stages must tolerate that (or you should check before writing).

6. **Persist any expensive intermediate state** that doesn't fit in a single line (embeddings, large model responses) to a content-addressed file under `.claude/auto-pause/artifacts/<jobname>/<unit-id>.<ext>`. Reference the path from the checkpoint line.

## When auto-pause fires mid-job

The hook calls `sleep` between tool invocations. Your *current* iteration's tool calls will block until the sleep returns; then they continue normally. Because each iteration is one checkpoint line, you'll resume on the *next* unit, not mid-unit. This is the whole point of small atomic units.

## When the session crashes entirely

If the OS, the SDK process, or you yourself kill the session, you re-launch and re-invoke. The checkpoint file is still on disk; the filter step skips completed work; the job picks up where it left off. Combine with `claude-auto-retry` for fully unattended recovery.

## Anti-patterns

- **Don't batch tool calls.** Don't read 100 URLs at once and process them in one big response. The point of small units is that auto-pause has somewhere to land safely.
- **Don't store progress only in memory.** Variables in the agent's context don't survive a pause-resume across the 5-hour boundary if the session itself happens to die; and they certainly don't survive a `claude --resume`.
- **Don't share one checkpoint across unrelated jobs.** Use distinct `<jobname>` per job so re-runs are unambiguous.

## Quick template

```
# Before starting:
mkdir -p .claude/auto-pause
JOB="<jobname>"
CKPT=".claude/auto-pause/checkpoint-${JOB}.jsonl"
touch "$CKPT"
DONE=$(jq -r 'select(.ok==true) | .id' "$CKPT" | sort -u)

# Loop:
for ID in $ALL_IDS; do
  grep -qx "$ID" <<< "$DONE" && continue
  # ... do the work ...
  jq -nc --arg id "$ID" --arg ts "$(date -Iseconds)" --arg out "$OUT_PATH" \
    '{id:$id, ts:$ts, output:$out, ok:true}' >> "$CKPT"
done
```

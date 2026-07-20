# Sequential batch (pause-to-push)

Multiple bugs are fixed **one at a time**, and after each committed fix the flow
**pauses for the operator to push+merge** before the next bug starts. This keeps
every fix on an up-to-date base and avoids merge conflicts between fixes.

## Why sequential + pause

If several bug fixes were cut from the same fixed base in parallel, two fixes
touching the same file would conflict at merge time. Instead:

```
bug1: git fetch -> branch off fresh main -> fix -> commit -> STOP
      (operator pushes + merges bug1)
--resume
bug2: git fetch -> branch off main (now includes bug1) -> fix -> commit -> STOP
      (operator pushes bug2)
--resume
bug3: ...
```

Because bug2 branches from a main that already contains bug1, there is nothing to
conflict with.

## Batch cursor

- `.claude/state/flow/bug-batch.json` = `{ "refs": ["BUG-1","BUG-2","BUG-3"], "created_at": "<utc>" }`
  - Written/refreshed when invoked with refs.
  - Read when invoked with `--resume` (no refs).
- Per-bug state = `.claude/state/flow/<bug-key>/session.json` (`flow-session.v1`).

### Choosing the next bug

```
next = first ref in batch.refs whose flow-session.status
       is neither "done" nor "not-a-bug"
```

- No such ref → the batch is complete; report a summary (fixed / not-a-bug counts).
- A ref with status `awaiting-push` is the one you just committed: it means the
  operator has now pushed (they re-ran `--resume`), so mark it `done` and move to
  the next ref.

### Resume semantics

- Fresh call `harness-bugfix BUG-1 BUG-2 BUG-3` → (re)write the batch, pick the
  next unfinished bug, run it to `awaiting-push` or `not-a-bug`.
- `harness-bugfix --resume` → read the batch. If the current bug is
  `awaiting-push`, mark it `done` (operator has pushed) and advance. Otherwise
  continue the current bug where it paused (e.g. a QA reply arrived).

## The pause message

When a bug reaches `awaiting-push`, stop with a clear instruction, e.g.:

```
Fixed BUG-1: committed <hash> on branch <branch> (NOT pushed).
Push + merge it, then run /harness-bugfix --resume to start BUG-2 from the
updated main.
```

Do not start the next bug until the operator resumes — this is the conflict-avoidance
guarantee.

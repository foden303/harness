# Commit + close (Steps 9-10)

## Step 9 — Commit (never push)

The per-task commits were already created on trunk by `harness-work` during
Steps 5-6 (cherry-pick after each APPROVE). Step 9 is the finalization:

1. **Confirm each commit references the JIRA key(s).** Because the key was
   injected into the worker briefing, per-task commit messages should read
   `[PROJ-123] <task content>`. For a **merged multi-ticket feature**, tag with
   every constituent key so each is greppable: `[PROJ-123][PROJ-124] <task content>`
   (use the keys from `requirement.sources[].source_ref`). Verify:
   ```
   git log --oneline <base>..HEAD
   ```
   If any produced commit is missing the tag, amend it in place
   (`git commit --amend` on that commit via an interactive-free rebase is out of
   scope — instead, prefer re-running the task with the correct briefing). Never
   use `/undo`.
2. Record the hashes:
   ```
   bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-session.sh" set-json <session.json> commit_hashes '["<h1>","<h2>"]'
   bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-session.sh" status <session.json> done
   ```

### harness-flow NEVER pushes

This skill does not run `git push`, `gh pr create`, `gh pr merge`, or any remote
transmission. The operator pushes manually. This is enforced on multiple layers:

| Layer | Rule |
|-------|------|
| `.claude/rules/autonomous-confirmation-scope.md` | Push / PR / release = external transmission → outside autonomous scope |
| `go/internal/policy/rules.go` R06 | `git push --force` → **DENY** |
| `go/internal/policy/rules.go` R10 | `--no-verify` / `--no-gpg-sign` → **DENY** |
| `go/internal/policy/rules.go` R11 | `git reset --hard` on a protected branch → **DENY** |
| `go/internal/policy/rules.go` R12 | direct push to main/master → **ASK** (configurable) |
| `.claude/rules/commit-safety.md` | fix loops use `git revert` / `git commit --amend`, never `/undo` |

End every `done` run by naming the commit hashes and stating plainly that the
branch is **un-pushed — the operator pushes manually**.

## Optional `--close-jira` (requires approval before each write)

After a successful commit, and only when `--close-jira` is set. The transition
and the done comment are **external writes**, so — exactly like the BA comment —
harness-flow drafts them and gets the operator's approval before sending
(`autonomous-confirmation-scope` case 1). Never auto-transition or auto-comment.

1. `getTransitionsForJiraIssue` (read) → pick the target transition (e.g. "In Review").
2. Show the operator the planned transition + the draft done comment via
   `AskUserQuestion` ("Transition <PROJ-123> to In Review and post this comment?").
3. Only on approval:
   - `transitionJiraIssue` to move the ticket.
   - Post the done comment (JIRA `addCommentToJiraIssue` / Confluence
     `createConfluenceFooterComment`) with the hidden-marker style:
     ```
     <!-- harness-flow:done session=<session-id> req=<PROJ-123> -->
     Committed locally: <hash1>, <hash2>. Awaiting the operator's manual push.
     ```
4. Record: `flow-session.sh set <session.json> jira_transitioned true` and
   `set <session.json> done_comment_id <id>`.

If the operator declines, skip the closeout (the commit already succeeded) and
report that the JIRA update was left for them to do manually.

If MCP is unreachable at this point, skip the closeout (the commit already
succeeded) and report that the JIRA update must be done manually — do not fail
the run.

## Step 10 — Fix / rework

A **not-OK** at the confirm gate or a **REQUEST_CHANGES** from review routes back
to work, reusing the existing failure-reticketing machinery — no new loop code:

- `skills/harness-work/references/failure-reticketing.md` +
  `go/internal/hookhandler/task_completed_escalation.go`.
- Per-task failure counter in `.claude/state/task-quality-gate.json`.
- `buildFixTaskID`: `26.1` → `26.1.fix` → `26.1.fix2` → `26.1.fix3`.
- 3-strike escalation → a fix proposal in `.claude/state/pending-fix-proposals.jsonl`;
  added to Plans.md only after the operator approves (`approve fix <id>`).

Flow:

1. Turn the operator's not-OK reason (or the review's rejected findings) into the
   fix task's Content.
2. `flow-session.sh status <session.json> working`; increment `rework_rounds`.
3. Re-run `harness-work` on the failing task(s) → back through Step 7 (review) →
   Step 8 (confirm).
4. Cap `rework_rounds` (e.g. 3). On exhaustion:
   `flow-session.sh status <session.json> escalated` and emit `decision_needed.v1`
   asking the operator how to proceed.

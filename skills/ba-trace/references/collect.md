# Collecting the evidence (steps 1-2)

Everything here is a read. Record each source's availability in
`evidence.json` as `available`, `not-configured` (no such source, e.g. no git
repo, no `gh`, no ba-uat state) or `unreachable` (exists but failed). The report
uses this to tell "no evidence source" apart from "no evidence".

## Step 1: Requirements

### With `--brief`

Read the brief/spec (from `ba-discovery` / `ba-spec`, or any markdown). A
requirement is a line or heading starting with an ID `R-<n>` (also `R<n>`,
`REQ-<n>`). Keep: id, the requirement text (first sentence), and any ticket keys
written next to it (`→ DPD-903`, a "Tickets" column, a link).

- If the brief names ticket keys and no scope was given, those keys are the scope.
- If the brief has no R-n IDs at all, say so and fall back to AC rows; do not
  number the brief yourself.

### Without a brief

Each ticket's acceptance criteria rows are the requirements, ID'd
`<KEY>/AC<n>` (`DPD-903/AC2`). AC come from the AC field or the description's
`## Acceptance criteria` table/list. A ticket with no AC gets one requirement
row `<KEY>/—` with the gap "ticket has no AC".

## Step 1: Tickets

| Scope | Read |
|-------|------|
| Epic key | `getJiraIssue` + `searchJiraIssuesUsingJql` `parent = <KEY>` (every status) |
| Keys | `getJiraIssue` per key |
| `--jql` | `searchJiraIssuesUsingJql`, then `getJiraIssue` per hit |

Keep: key, summary, type, status + status category, assignee, fixVersion,
linked issues (test issues, "implements"/"relates to" a requirement issue), and
remote links (`getJiraIssueRemoteIssueLinks` — may hold PR URLs from a dev-tool
integration).

### Linking requirements to tickets

In order: the brief names the key → the ticket names the R-n id → a JIRA link
between them. When none of these holds but the wording clearly overlaps, ask:

> **R-6 "Partner orders need a code" — which ticket covers it?**
> DPD-903 / DPD-910 / None yet / Several (pick)

Up to 4 per round. "None yet" makes it a "no ticket" gap. Never link on
wording alone without asking.

For 10 or more tickets, fan out reads with `Task` (read-only, one batch of
tickets per sub-agent).

## Step 2: Commits

Run in `--repo` (default cwd). For each key:

```bash
git -C "$REPO" log --all --regexp-ignore-case --extended-regexp \
  --grep "\[$KEY\]" --grep "(^|[^A-Z0-9-])$KEY([^0-9]|$)" \
  --format='%H%x09%h%x09%ad%x09%an%x09%s' --date=short
```

- The first pattern is the `harness-flow` convention (`[PROJ-123]` in the
  subject); the second catches the bare key without matching `DPD-9031` for
  `DPD-903`.
- Also check branch names: `git -C "$REPO" branch --all --list "*$KEY*"`.
- Dedupe by hash. Keep short hash, date, author, subject.
- Before any key, check the repo at all: `git -C "$REPO" log --all
  --extended-regexp --grep "[A-Z][A-Z0-9]+-[0-9]+" -1`. No hit means the repo
  carries no JIRA keys anywhere: commit source = `not-configured` for this
  trace, and the summary says so plainly.

## Step 2: PRs

From what is local, in order:

1. Merge commit subjects: `Merge pull request #<n> from <owner>/<branch>`,
   `(#<n>)` at the end of a squash subject.
2. Branch names containing the key (local or remote-tracking).
3. Remote links on the ticket pointing at a PR URL.
4. Only if `command -v gh` succeeds and `gh auth status` passes:
   `gh pr list --state all --search "<KEY>" --json number,title,state,url --limit 20`
   (read-only). Never `gh pr create/edit/merge/comment`, never `gh api`.

No source → PR column `n/a` with "no PR source" in the summary.

## Step 2: Tests

Test files: paths matching `*test*`, `*spec*`, `__tests__/`, `tests/`, `e2e/`,
`*.feature`, `*_test.go`, `test_*.py` (respect `.gitignore`; skip
`node_modules`, `vendor`, build output).

Per requirement, a test matches when either:

- the file mentions the ticket key (or the R-n id) — in a name, describe/it
  title, tag (`@DPD-903`), or comment; or
- a test title or `.feature` scenario carries the AC's distinctive wording
  (2+ content words from the Then clause, e.g. "capped at 30%"). Wording-only
  matches are shown as `wording` so a reader can judge them.

Also read `.claude/state/ba-uat/*/test-cases.md`: cases are ID'd
`TC-<KEY>-<n>` and each names the AC row, field rule or edge case it covers.
A case for the ticket key (and, with a brief, its R-n / AC row) counts as a test
(source `ba-uat`).

Record file:line or the ba-uat case id per match.

## Step 2: UAT results

UAT results come only from the Pass / Fail / Comment columns `ba-uat` writes in
`.claude/state/ba-uat/*/uat-checklist.md` (filled in by the business user,
or by the operator copying their answers back). Per item: pass / fail / blank
(not run), plus the sign-off date if the block is filled. Nothing filled in →
UAT column `not run` if the checklist exists, `n/a` if
`.claude/state/ba-uat/` does not exist. Never treat a test file's existence as
a UAT pass.

## evidence.json

`.claude/state/ba-trace/<slug>/evidence.json`:

```json
{
  "sources": {"jira": "available", "git": "available", "gh": "not-configured",
              "tests": "available", "ba_uat": "not-configured"},
  "requirements": [{"id": "R-1", "text": "...", "tickets": ["DPD-903"]}],
  "tickets": [{"key": "DPD-903", "status": "Done", "category": "done",
               "commits": [{"hash": "a1b2c3d", "date": "2026-10-02", "subject": "[DPD-903] ..."}],
               "prs": [{"number": 41, "source": "merge-commit"}],
               "tests": [{"where": "tests/discount.test.ts:42", "match": "key"}],
               "uat": [{"case": "TC-DPD-903-1", "result": "pass", "date": "2026-10-10"}]}]
}
```

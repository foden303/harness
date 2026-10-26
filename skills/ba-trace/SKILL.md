---
name: ba-trace
description: "Read-only traceability report from requirements to tickets, commits, PRs, tests and UAT results. Takes an Epic key, a list of keys, a JQL, or a spec/brief with R-n requirement IDs (from ba-discovery / ba-spec), builds a matrix requirement -> ticket(s) -> status -> commits (local git log grep for [KEY] and the bare key) -> PR (from commit messages / branch names, or read-only gh when available) -> tests (repo grep and ba-uat output) -> UAT result, and flags the gaps: requirement with no ticket, Done ticket with no commit, commits on a ticket still To Do, AC with no test, orphan tickets. Saves the report as markdown (optional single-file HTML) and publishes to Confluence only on approval. Trigger: traceability, trace requirements, traceability matrix, requirement coverage, is every requirement built, what is tested, RTM, which tickets have commits, /ba-trace. Do NOT load for: analysing a requirement change (use ba-change), writing missing tickets (use ba-ticket), writing test cases (use ba-uat), checking ticket clarity (use ba-story-verify), or code review (use harness-review)."
kind: workflow
purpose: "Epic / keys / JQL / brief -> requirement -> ticket -> status -> commit -> PR -> test -> UAT matrix -> coverage + gaps with next skill -> trace.md (+ HTML, + Confluence on approval)"
trigger: "traceability, trace requirements, traceability matrix, requirement coverage, RTM, what is tested"
shape: delegate
role: orchestrator
pair: harness-flow
owner: harness-core
since: "2026-10-26"
allowed-tools: ["Read", "Write", "Bash", "Grep", "Glob", "Task", "AskUserQuestion", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[<EPIC-KEY>|<KEY> ...|--jql \"...\"] [--brief <path>] [--repo <path>] [--html] [--confluence <url>] [--draft-only]"
user-invocable: true
effort: medium
---

# ba-trace

> **Requirements → tickets → commits → tests → UAT, in one table, with the gaps
> named and the skill that closes each one.**

It answers "is every requirement built and tested?" from evidence: JIRA for the
tickets, the local git history for commits, the repo for tests, `ba-uat` state
for UAT results. It changes nothing.

## Rules (read first)

1. **Read-only.** No JIRA or Confluence writes, no git writes, no GitHub writes.
   The one exception is publishing the report to `--confluence <url>`, and only
   after an explicit AskUserQuestion approval
   (`.claude/rules/autonomous-confirmation-scope.md` case 1). If AskUserQuestion
   is unavailable, print the question and stop.
2. **Evidence or nothing.** Every commit, PR, test and UAT cell shows where it
   came from (hash, PR number, file:line, UAT file). No match is an empty cell,
   never an inferred one.
3. **No evidence source is not a finding.** If the repo has no commit
   referencing any key in scope, say so plainly ("this repo carries no JIRA keys
   in commit messages") and mark the commit column `n/a` — never report 0% as if
   the team built nothing. Same for tests and UAT when no source exists.
4. **Ask, never invent.** When a ticket's link to a requirement is unclear, it
   is a decision-shaped question (AskUserQuestion, up to 4 per round, ready-made
   options), never a guess. No `TBD`, `???`, `etc.` in the output.
5. **`gh` is optional and read-only.** Use `gh pr list/view` only if `gh` is
   installed and authenticated; never call other GitHub APIs.
6. **English output.**

## Quick Reference

| Input | Behavior |
|------|------|
| `/ba-trace DPD-832` | Epic + children; requirements = each child's AC rows |
| `/ba-trace DPD-832 --brief .claude/state/ba-spec/checkout/spec.md` | Requirements = the brief's R-n IDs |
| `/ba-trace DPD-901 DPD-903 DPD-904` | Those tickets only |
| `/ba-trace --jql "fixVersion = 2.4"` | The JQL result set |
| `/ba-trace DPD-832 --repo ../checkout-service` | Search another local repo for commits and tests |
| `/ba-trace DPD-832 --html` | Also write a single-file HTML |
| `/ba-trace DPD-832 --confluence https://<site>/wiki/.../123` | Publish the report on approval |
| `/ba-trace DPD-832 --draft-only` | Never offer to publish, even with `--confluence` |

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `<KEY> ...` / `--jql` | Scope: Epic (expanded), keys, or JQL | required unless `--brief` names the tickets |
| `--brief <path>` | Brief/spec with `R-n` requirement IDs | none (AC rows become requirements) |
| `--repo <path>` | Local git repo to search | current directory |
| `--html` | Also render `trace.html` | off |
| `--confluence <url>` | Page to publish the report to, on approval | - |
| `--draft-only` | Save locally only; never publish | off |

## References

| Topic | File |
|-------|------|
| Collecting requirements, tickets, commits, PRs, tests, UAT | [collect.md](${CLAUDE_SKILL_DIR}/references/collect.md) |
| Gap rules, suggested actions, coverage maths | [gaps.md](${CLAUDE_SKILL_DIR}/references/gaps.md) |
| Report template | [matrix-template.md](${CLAUDE_SKILL_DIR}/references/matrix-template.md) |
| HTML and Confluence publish | [publish.md](${CLAUDE_SKILL_DIR}/references/publish.md) |
| Filled example | [README.md](${CLAUDE_SKILL_DIR}/README.md) |

## Resolving the plugin bundle root

Same as `ba-story-verify`: `HARNESS_PLUGIN_ROOT` = `CLAUDE_PLUGIN_ROOT` if it
contains `scripts/`, else `${CLAUDE_SKILL_DIR}/../..` (`../../..` for a mirror).
State lives in the host project under `.claude/state/ba-trace/<slug>/`.

## Flow

```
[0] Probe
    getAccessibleAtlassianResources: success -> healthy, error -> unreachable,
    tools absent -> not-configured, then
      bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-mcp-health.sh" --probe <result>
    not-configured / unreachable: if --brief lists ticket keys, trace from the
    brief + git + tests with status "unknown (JIRA unreachable)"; else stop.
    Check --repo is a git repo (git -C <repo> rev-parse); if not, say so and
    mark commits/PRs n/a.

[1] Requirements + tickets                  -> references/collect.md
    --brief: R-n IDs + the ticket keys each names. Else: each ticket's AC rows.
    Read every ticket (getJiraIssue; Epic -> JQL "parent = KEY").
    Unclear requirement <-> ticket links -> AskUserQuestion.

[2] Evidence                                -> references/collect.md
    Commits: git log --all --grep "\[KEY\]" and the bare KEY (word-bounded).
    PRs: from merge-commit messages / branch names; gh read-only if available.
    Tests: grep test files for the key and the AC wording; .claude/state/ba-uat/.
    UAT: Pass/Fail recorded in .claude/state/ba-uat/*/uat-checklist.md.

[3] Gaps + coverage                         -> references/gaps.md

[4] Report                                  -> references/matrix-template.md
    Save .claude/state/ba-trace/<slug>/trace.md (+ evidence.json).
    --html -> trace.html                    -> references/publish.md

[5] Publish (only with --confluence, not --draft-only) -> references/publish.md
    Show the page body; AskUserQuestion publish / cancel; then update or
    create the page. Log the version to published.json; never re-publish
    an unchanged report.
```

## Stop conditions

| Condition | Response |
|-----------|----------|
| No scope and no brief | Ask for an Epic, keys, JQL or brief; never trace the whole project |
| MCP down and no brief keys | Stop; nothing to trace without tickets |
| `--repo` is not a git repo | Continue; commit and PR columns `n/a`, said in the summary |
| No commit in the repo references any key | Continue; say it plainly, commit coverage `n/a` (not 0%) |
| A ticket cannot be read | Row status `unreadable`; continue |
| Publish rejected / page changed since read | Keep the local report; re-read and re-show before any retry |

## Report

Say: the scope, which evidence sources were available (JIRA, git, gh, tests,
ba-uat) and which were not, the coverage line, the top gaps with the skill to
run, and the saved paths (and the Confluence URL if published). Do not narrate
per-ticket searching. End with the next action, e.g. "Run `/ba-ticket` for
R-4 and R-7; run `/ba-uat DPD-832` for the 5 untested AC."

## Related skills

- `ba-ticket` — write a ticket for a requirement that has none
- `ba-uat` — write test cases / record UAT for AC with no test
- `ba-change` — analyse a requirement change before tracing again
- `ba-story-verify` — check that orphan or thin tickets are clear
- `harness-flow` — builds tickets with `[KEY]` in every commit, which is what makes them traceable

---
name: ba-release-notes
description: "Write release notes for a business audience (client, management, support) from the JIRA issues finished in a sprint, a fixVersion, a JQL or a date range. Collects the Done issues, groups them by Epic / area into New, Improved and Fixed, moves pure tech work (refactor, chore, infra, spikes) to an Internal list kept out of the business notes, rewrites each item as one line of user benefit with its key as a reference link, asks the BA (decision-shaped) when an item's user impact is unclear, adds Known issues and Action needed by users, and renders the client / internal / support variant. Saves the notes as markdown and publishes to Confluence only after the operator approves; never emails or posts to chat. Trigger: release notes, what's new, sprint summary for the client, write the changelog for users, notes for version 2.4, what shipped this sprint, support release brief, /ba-release-notes. Do NOT load for: cutting a version, tagging or a GitHub Release (use harness-release), the developer CHANGELOG.md of this repo (use harness-release), or test plans for the release (use ba-uat)."
kind: workflow
purpose: "Sprint / fixVersion / JQL / dates -> Done issues -> New / Improved / Fixed (+ Internal) -> user-benefit lines -> ask unclear impact -> audience variant -> save -> operator approves -> Confluence page"
trigger: "release notes, what's new, sprint summary for the client, what shipped, support release brief"
shape: delegate
role: orchestrator
pair: harness-release
owner: harness-core
since: "2026-10-26"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "AskUserQuestion", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "--project KEY (--sprint \"<name>\"|--version <fixVersion>|--jql \"...\"|--from YYYY-MM-DD --to YYYY-MM-DD) [--audience client|internal|support] [--internal] [--confluence <url>] [--draft-only] [--dry-run]"
user-invocable: true
effort: medium
---

# ba-release-notes

> **What got finished → what the user can do now, in one line each → ask where
> the impact is unclear → notes for the chosen audience → operator approves →
> Confluence page.**

Release notes are read by people who never open JIRA. They want to know what
changed for them, what to watch out for, and whether they must do anything.
They do not want ticket titles, team tags, or how it was built.

## Rules (read first)

1. **User benefit, not implementation.** "You can now export the filtered list
   to CSV", not "Added export endpoint". No code names, team tags (`[BE]`),
   internal project names, or ticket jargon in the business notes.
2. **One line per item, key kept as a reference.** Each line ends with its
   key(s) as a link, so anyone can trace it. Stories split per team
   (`[Area] [BE] ...` + `[Area] [FE] ...`) become **one** line with both keys.
3. **Tech work stays internal.** Refactors, chores, infra, spikes, tech debt go
   to the **Internal** list, excluded from the business notes unless
   `--internal` or `--audience internal`.
4. **Ask, never invent.** If an item's user impact or visibility is unclear,
   ask a decision-shaped question (AskUserQuestion, up to 4 per round,
   ready-made options), e.g. "Is DPD-412 visible to clients? (a) yes, mention
   it (b) internal only". Never guess a benefit, a date, or a workaround. No
   `TBD`, `???` or `etc.` in the output.
5. **Honest Known issues.** Open bugs tied to the release are listed, in plain
   words, with a workaround only when the ticket states one. Unsure whether a
   bug is client-facing → ask.
6. **Read-only until approved.** Creating or updating the Confluence page is an
   external write (`.claude/rules/autonomous-confirmation-scope.md` case 1):
   shown first, sent only on an explicit approval. No AskUserQuestion → print
   the question and stop.
7. **Never email, never post to Slack / Teams.** Say the operator can paste
   the saved markdown wherever it needs to go.
8. **English output**, whatever language the tickets are written in.

## Quick Reference

| Input | Behavior |
|------|------|
| `/ba-release-notes --project DPD --sprint "DPD Sprint 42"` | Client notes for that sprint |
| `/ba-release-notes --project DPD --version 2.4` | Client notes for fixVersion 2.4 |
| `/ba-release-notes --jql "project = DPD AND labels = mobile AND resolved >= -14d"` | Notes for a custom set |
| `/ba-release-notes --project DPD --from 2026-10-01 --to 2026-10-25` | Notes for issues resolved in that range |
| `/ba-release-notes ... --audience support` | Support variant: what changed, what users may ask, workarounds |
| `/ba-release-notes ... --audience internal` | Management / team variant, includes the Internal list |
| `/ba-release-notes ... --internal` | Any audience + the Internal list appended |
| `/ba-release-notes ... --confluence https://<site>/wiki/.../123` | Publish under that parent page on approval |
| `/ba-release-notes ... --draft-only` | Save the markdown, never touch Confluence |
| `/ba-release-notes ... --dry-run` | Show the notes, write no state |

## References

| Topic | File |
|-------|------|
| Collecting, grouping, internal filter, rewriting, questions | [collect-and-write.md](${CLAUDE_SKILL_DIR}/references/collect-and-write.md) |
| Notes template + audience variants (filled by step 5) | [notes-template.md](${CLAUDE_SKILL_DIR}/references/notes-template.md) |
| Saving, approval, publishing to Confluence | [publish.md](${CLAUDE_SKILL_DIR}/references/publish.md) |
| Filled example | [README.md](${CLAUDE_SKILL_DIR}/README.md) |

## Resolving the plugin bundle root

Same as `ba-story-verify`: `HARNESS_PLUGIN_ROOT` = `CLAUDE_PLUGIN_ROOT` (if it
contains `scripts/`), else `${CLAUDE_SKILL_DIR}/../..` (or `../../..` for a
mirror). State lives under the host project's `.claude/state/ba-release-notes/`.

## Flow

```
[0] Resolve + probe
    getAccessibleAtlassianResources, then
      bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-mcp-health.sh" --probe <result>
      (success -> healthy, error -> unreachable, tools absent -> not-configured)
    not-configured / unreachable -> work from a pasted issue list or export
    file; pause before publishing and say so.
    |
[1] Collect Done issues                    -> references/collect-and-write.md
    searchJiraIssuesUsingJql, e.g.
      project = DPD AND statusCategory = Done AND sprint = "DPD Sprint 42"
      project = DPD AND statusCategory = Done AND fixVersion = "2.4"
    --jql as given; --from/--to -> resolved in the range. Drop Won't Do /
    Duplicate resolutions. Fetch parent Epic, type, labels, components.
    Report the counts (found / dropped and why) before writing.
    |
[2] Group + classify                       -> references/collect-and-write.md
    By Epic (else component / area), then New / Improved / Fixed.
    Refactor / chore / infra / spike / tech debt -> Internal.
    Sub-tasks roll into their parent; per-team split stories merge.
    |
[3] Rewrite                                -> references/collect-and-write.md
    One line of user benefit per item, key(s) as a reference link.
    |
[4] Ask unclear impact                     -> references/collect-and-write.md
    Visibility, benefit, known-issue relevance, user action: decision-shaped
    questions, up to 4 per round. "Leave it" -> the item moves to Internal
    and the report says so; never guess.
    |
[5] Render                                 -> references/notes-template.md
    Title + date + version, 2-3 sentence highlight, New / Improved / Fixed,
    Known issues (open Bugs with this fixVersion or label known-issue),
    Action needed by users (only if any), for --audience client|internal|support.
    --internal -> append the Internal list.
    |
[6] Save + approve + publish               -> references/publish.md
    .claude/state/ba-release-notes/<slug>/notes.md (--dry-run: show only).
    --draft-only -> stop after saving. Otherwise show the notes and ask once:
    publish to Confluence / edit / cancel. createConfluencePage under
    --confluence (updateConfluencePage on a re-run). Never email or post to chat.
```

## Stop conditions

| Condition | Response |
|-----------|----------|
| No `--project` and none in the JQL | Ask for it (offer `getVisibleJiraProjects` results); never guess |
| Sprint or fixVersion name not found | Show the closest names from JIRA and ask which one |
| No Done issues in scope | Report the query and counts, stop; never widen the range |
| Everything is internal | Say so; offer internal-only notes or stop |
| MCP not-configured / unreachable | Work from pasted input; keep the saved notes at step 6, say where, stop |
| `--confluence` missing at publish time | Ask for the parent page URL, or stop after saving |
| Confluence page edited since the last publish | Re-read, show what changed, ask before overwriting |

## Report

Say: the query used and the counts (found / in notes / internal / dropped), the
questions asked and the answers folded in, the rendered notes (or their path),
and the Confluence URL if published. Do not narrate item-by-item rewriting.
End with: "Saved, not sent — paste it into email or chat yourself if needed."

## Related skills

- `harness-release` — cut the version, tag, GitHub Release (developer side)
- `ba-uat` — test cases and the client sign-off sheet for the same scope
- `ba-trace` — trace which requirement each shipped item came from
- `ba-ticket` — clear tickets make one-line notes easy to write

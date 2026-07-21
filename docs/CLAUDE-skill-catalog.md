# Skill Catalog

Reference documentation for the skill hierarchy, the full category listing, and development-only skills.

## Skill Evaluation Flow

> 💡 For heavy tasks (parallel review, CI fix loops), skills launch sub-agents from `agents/` in parallel via the Task tool.

**Before starting work, always run the following flow:**

1. **Evaluate**: Review the available skills and assess whether any apply to the current request
2. **Launch**: If an applicable skill exists, launch it with the Skill tool before starting work
3. **Execute**: Proceed following the skill's steps

```
User request
    ↓
Evaluate skills (is there one that applies?)
    ↓
YES → Launch with the Skill tool → follow the skill's steps
NO  → Handle with normal reasoning
```

## Skill Hierarchy

Skills use a flat structure with `skills/<name>/SKILL.md` as the main file and optional
supporting files under `references/`. For the full list and descriptions of distributed skills, see the
"Full Skill Category Listing" below (auto-generated from `skills/*/SKILL.md`).

**How to use:**
1. Launch the skill that applies to the request with the Skill tool
2. The skill loads the appropriate `references/` according to the user's intent
3. Execute the work following the steps

## Full Skill Category Listing

The table below is auto-generated from the frontmatter of `skills/*/SKILL.md`. Do not edit by hand;
run `harness gen docs` to update it (pinned in CI via `harness gen docs --check`).

<!-- BEGIN GENERATED SKILL CATALOG (harness gen docs) -->
<!-- Auto-generated from skills/*/SKILL.md frontmatter. Do not edit by hand; run `harness gen docs`. -->

## Skill Catalog Listing

| Skill | Description |
|--------|------|
| agent-browser | Browser automation through the repo agent-browser CLI. Explicit helper for navigation, forms, screenshots, scraping, and web-app checks. Prefer Browser Use or Playwright when available. Do NOT load for: sharing URLs, embedding links, or editing screenshot files. |
| breezing | Team execution mode — backward-compatible alias for harness-work with team orchestration. |
| cc-update-review | Quality guardrail for Claude Code update integration. Detects doc-only Feature Table additions and requires implementation or explicit planning. Internal use only. |
| ci | CI red? Call us. Pipeline fire brigade deploys. Use when user mentions CI failures, build errors, test failures, or pipeline issues. Do NOT load for: local builds, standard implementation work, reviews, or setup. |
| failure-codifier | Extract recurring failure patterns from breezing orchestration logs and Judgment Ledger, emit failure-rule.v1 proposals with confidence scores. SSOT promotion to patterns.md or decisions.md is proposal-only — human-approval-required. Use when user mentions failure codifier, failure patterns, self-learning loop, codify failures, or failure-rule proposals. Do NOT load for: direct SSOT edits, auto-promotion, or implementation unrelated to failure analysis. |
| harness-accept | Generate an Acceptance Demo HTML for non-engineer vibecoders right before ship/wait/reject decision. Reads back the acceptance_criteria that were stored as personal-preference.v1 by harness-plan-brief (joined by user_request_hash), then renders a single-file HTML showing each criterion as verified or unverified along with a ship/wait/reject recommendation. Use when the user asks for an acceptance review, wants to decide whether to ship a delivered task, or says: acceptance demo, accept demo, acceptance decision, acceptance review, ship/wait/reject decision, inspection review. Do NOT load for: implementation, code review, release work. |
| harness-bugfix | Operator-driven bug-fix flow from a JIRA bug link to a committed (never pushed) fix. Ingests one or more bug links, triages each against the CURRENT source code, comments back to QA when it is not a bug, and for real bugs splits a worktree, fixes, reviews, gets operator confirmation, and commits. Multiple bugs are processed ONE AT A TIME (pausing after each for the operator to push) to avoid merge conflicts. Trigger: fix a bug, bug ticket, triage a bug, BUG-123, is this a real bug. Do NOT load for: new features/requirements (use harness-flow), standalone review, or release. |
| harness-flow | End-to-end operator-driven flow from a JIRA/Confluence requirement to a reviewed, committed (never pushed) change. Ingests an issue key or Confluence URL, verifies the requirement, asks the BA back via a ticket comment when unclear, plans, splits into worktrees, works, reviews, gets operator confirmation, then creates commits (the operator pushes manually). Trigger: run the flow, ingest a requirement, issue key, PROJ-123, confluence page, requirement to commit. Do NOT load for: standalone planning, review, or release. |
| harness-loop | Long-running task loop using /loop (Claude Code dynamic mode) and ScheduleWakeup to re-enter with fresh context on each wake-up. Internally invokes harness-work through Agent. Trigger: long-running, loop, wake-up, autonomous. Do NOT load for: one-shot task execution, review, release, planning. |
| harness-plan | HAR: Research-backed, team-validated task planning, Plans.md management, progress sync. Trigger: create a plan, add tasks, update Plans.md, mark complete, check progress. Do NOT load for: implementation, review, release. |
| harness-plan-brief | Generate a Plan Brief HTML for non-engineer vibecoders before implementation starts. Searches harness-mem (project-only) for relevant past decisions, patterns, and Plans archive entries, then renders a single-file HTML artifact summarizing understanding, options, risks, acceptance criteria, and confidence. Use when the user requests a planning preview, a non-engineer-friendly summary before approval, or says: plan brief, planning preview. Do NOT load for: actual implementation, code review, release work. |
| harness-progress | Generate a Progress Tracker HTML for non-engineer vibecoders to glance at session progress (cc:WIP / cc:TODO / cc:done counts, percentage, elapsed/estimated minutes, cost so far/estimate, drift alerts). Uses Plans.md as source of truth, renders a single-file HTML with auto-regeneration support. Use when user asks for progress overview, session status snapshot, dashboard, or says: progress tracker, progress board, dashboard. Do NOT load for: actual implementation, code review, release work. |
| harness-release | Generic release automation for projects using Keep a Changelog + GitHub. Single confirmation gate then end-to-end automation: bump detection, CHANGELOG promotion, PR/main merge, tag, GitHub Release. Trigger: release, version bump, publish. Do NOT load for: implementation, review, planning, setup. |
| harness-review | HAR: Multi-angle code, plan, scope review. Security/quality check. Trigger: review, code review, plan review, scope analysis. Do NOT load for: implementation, new features, bugfix, setup, release. |
| harness-setup | HAR: Project init, tool setup, agent config, memory setup, skill mirror sync. Trigger: setup, init, new project, CI setup, harness-mem, mirror. Do NOT load for: implementation, review, release, planning. |
| harness-story-verify | Verify that BA-authored user stories are clear enough to build, and ask the BA the missing questions on the ticket. Takes an Epic link (expands to every child ticket), a single ticket link, or a list of tickets, scores each one independently against a user-story/acceptance-criteria rubric, and drafts one comment of open questions per unclear ticket — posted only after the operator approves. Read-only until then; it never plans, implements, or commits. Trigger: verify user story, check requirements clarity, review an epic's tickets, is this ticket clear, ask the BA, DoR check, PROJ-123 clear enough. Do NOT load for: implementing a requirement (use harness-flow), bug triage (use harness-bugfix), code review, or release. |
| harness-sync | HAR: Sync Plans.md with implementation. Drift detect, marker update, retrospective. Trigger: sync-status, where am I, check progress. --snapshot for snapshots. Do NOT load for: planning, implementation, review, release. |
| harness-work | HAR: Execute Plans.md tasks from single task to full parallel team run. Trigger: implement, execute, do everything, breezing, team run, parallel. Do NOT load for: planning, review, release, setup. |
| maintenance | File cleanup and archiving. Tidies up bloated Plans.md, session-log.md, old logs, and state files. Trigger: /maintenance, cleanup, archive, organize, split session-log. Do NOT load for: implementation, review, release, new feature development. |
| memory | Manage SSOT, memory, and cross-tool memory search. Guardian of decisions.md and patterns.md. Use when user mentions memory, SSOT, decisions.md, patterns.md, merging, migration, SSOT promotion, sync memory, save learnings, memory search, harness-mem, past decisions, or record this. Do NOT load for: implementation work, reviews, ad-hoc notes, or in-session logging. |

<!-- END GENERATED SKILL CATALOG (harness gen docs) -->

## Development-Only Skills (Private)

The following skills are for development and experimentation and are not included in the repository (excluded via .gitignore):

```
skills/
├── test-*/      # Test skills
└── x-promo/     # X post authoring skill (development)
```

Use these skills only in individual development environments, and do not include them in the plugin distribution.

## Related Documentation

- [CLAUDE.md](../CLAUDE.md) - Project development guide (overview)
- [docs/CLAUDE-feature-table.md](./CLAUDE-feature-table.md) - Table of Claude Code new-feature usage
- [docs/CLAUDE-commands.md](./CLAUDE-commands.md) - List of key commands
- [.claude/rules/skill-editing.md](../.claude/rules/skill-editing.md) - Skill file editing rules

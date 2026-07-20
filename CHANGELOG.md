# Changelog

Change history for harness.

> **📝 Writing Guidelines**: Focus on user-facing changes. Keep internal fixes brief.

## [Unreleased]

## [1.0.0] - 2026-07-20

### Theme: the first published release — one host, one loop, every claim gated

**Harness turns Claude Code from "ask the agent to code" into a repeatable
delivery loop: plan, work, review, ship — with the evidence for each step
produced as you go, not reconstructed from memory afterwards.**

This is the first version that was ever tagged or published. Earlier version
numbers (up to `5.0.0`) existed only in the working repo and were never
distributed; the pre-1.0 task ledger is archived at
`.claude/memory/archive/Plans-pre-1.0.md`. v1.0.0 is deliberately smaller than
what came before it — roughly 7,000 lines of unreachable and speculative code
were removed so that everything documented here is code you can actually reach.

---

#### 1. One operating loop instead of ad-hoc prompting

**Before**: Plans lived in chat scrollback. Tests were optional. Review happened
after the code was already merged, if at all. Release notes were rebuilt from
memory, and the evidence that a change actually worked was gone by the time
anyone asked.

**After**: Five core verbs carry work end to end, each with its own contract and
gates:

```
/harness-plan     intent      → reviewable spec + task rows in Plans.md
/harness-work     approved    → implementation with TDD evidence
/harness-review   diff        → independent fresh-context review
/harness-sync     drift       → Plans, git state, and mirrors reconciled
/harness-release  green tree  → version sync, CHANGELOG, PR, tag
```

Fourteen more skills cover the edges — `/breezing` for parallel team runs,
`/harness-bugfix`, `/harness-loop`, `/failure-codifier`, and the three
cognitive-load surfaces (`plan-brief`, `progress`, `accept`) that render a plan,
its progress, and an accept/wait/reject decision as HTML for a non-engineer
reviewer.

#### 2. Guardrails that hold even when the agent is wrong

**Before**: An autonomous agent's blast radius was whatever the model decided it
was. A destructive command, a force push, or a write outside the task worktree
depended on the model choosing not to.

**After**: A Go engine (`bin/harness`) adjudicates every tool call through
Claude Code's native hooks, independent of model judgment. Rules R01–R13 cover
irreversible git operations, self-modification of settings, and CI config
tampering. Five runtime floor categories — money/billing, egress, secret read,
production deploy, worktree escape — hard-stop for the human and cannot be
overridden by any flag or environment variable.

There is no approval-skip path in v1.0.0, and no environment variable enables
one. An experimental `HARNESS_AUTO_APPROVE` flag existed pre-1.0 but only ever
wrote a ledger entry; shipping a switch that implied more autonomy than it
delivered would have been worse than not shipping it.

#### 3. harness-flow: a ticket becomes a commit

**After**: `/harness-flow PROJ-123` ingests a JIRA issue or Confluence page via
the Atlassian MCP, verifies the requirement, asks the BA back through a ticket
comment when something is unclear, then plans, works, reviews, and commits.
Passing several keys (`PROJ-123 PROJ-124`) treats them as one merged feature.

Harness creates commits; **the operator pushes**. Every external write — posting
a JIRA comment, transitioning an issue, pushing, opening a PR — is drafted for
approval first and never auto-sent.

#### 4. Claude-only, on purpose

**Before**: The codebase carried adapters, hook codecs, host generators, and
golden fixtures for Codex, Cursor, and Grok, plus a live peer-messaging
subsystem. Most of it was unreachable from the shipped binary, and the parts
that did run made every change cost three times what it should.

**After**: One host. `harness gen` emits Claude hooks, the codec speaks one
protocol, and the removed subsystems (night-watch, live-messaging, bridge
daemon, mailbox store, impact scoring, auto-approve) are gone rather than
dormant. The design lessons that were worth keeping are recorded in
`docs/spec/`, so a future peer-collaboration layer starts from what was learned
instead of from what was left behind.

Two things that survived the earlier passes went with this one. The in-process
`harness work --team` orchestrator dispatched through per-backend companion
shell scripts that had already been deleted, so every run exited 127; it is
removed, and `/breezing` is unaffected because it fans out through Claude
Code's Agent tool. And the `candidate` / `future/unsupported` tiers for GitHub
Copilot CLI and Antigravity CLI are gone with the research files that backed
them — a support tier is a claim about evidence, and the evidence no longer
existed.

#### 5. Claims are machine-checked

**Before**: Documentation drifted from the code. A feature could be described in
the README while its package sat unimported.

**After**: `./tests/validate-plugin.sh` (101 checks) and
`scripts/ci/check-consistency.sh` (23 gates) verify that documented components
are actually wired, that Plans.md dependency closure holds, that skill mirrors
match their source, that deny rules have not silently regressed, and that the
committed binary rebuilds from source. Retired names are scanned for residue
(`harness retired-alias scan`) so deleted concepts cannot quietly return.

A gate only works if it runs. Six checks covering the README surface and the
host-claim contracts existed but were wired into nothing, and were failing —
against a hero image that had been deleted, research docs that had been
deleted, and matrix wording that never existed. They are fixed and wired in.

### Requirements

- **Claude Code v2.1+**
- Go toolchain only if you rebuild `bin/harness` yourself
- Optional: `harness-mem` for cross-session memory, Atlassian MCP for
  `/harness-flow`

---

Generated with [Claude Code](https://claude.com/claude-code)

# Cross-Repo Handoff Workflow (harness ↔ harness-mem)

An SSOT that records, in a reproducible form, the responsibility-boundary adjustments, contract changes, and implementation transfers that occur between harness and its sibling repo `harness-mem`.

This document extracts the codifiable policy portion of decisions.md D42 (`harness <-> harness-mem responsibility boundary + Cross-repo Handoff Workflow`). Because decisions.md is a per-developer local SSOT (gitignore target), policy that needs to be shared lives in this file.

## Why this rule is needed

During the review at the end of harness Phase 65 Phase A, the user expressed an operational expectation: "if something that should be implemented on the harness-mem side ends up implemented on the harness side, (i) remove it from harness, and (ii) file a clear Issue on the harness-mem side."

In practice, (i) was already done (Phase 60 managed-companion conversion, Phase 63 dead-default cleanup), but (ii) was operated not via GitHub Issue but via the `Plans.md §NNN` sibling-repo Plans SSOT method on the harness-mem repo. There is only one GitHub Issue: #70 (Phase 49.1.2 follow-up).

The gap between the user's expectation (GitHub Issue) and the operational reality (Plans.md SSOT) was caused by an undocumented policy. This rule pins the reality as the official practice to prevent recurrence.

## Responsibility boundaries of the redaction layers (Phase 65 cross-project safety)

| Layer | Content | Implementation layer | Rationale |
|---|---|---|---|
| Layer 1 | privacy filter (`<private>` strip) + project scope (`strict_project: true`) | **harness-mem server side** | Guards uniformly for all clients (CC / future third-party clients) at the mem exit. `include_private=false` default |
| Layer 2a | dictionary-based proper-noun redaction (`client-redaction.yaml`) | **harness client side** | Interpreting project-local config is the presentation layer's responsibility. Making the server interpret the schema would leak each company's redaction policy into the server config surface. Language-agnostic literal match |

> The Japanese NER layer (formerly Layer 2b, a Japanese-tokenizer redactor) and the
> katakana final-scan layer (formerly Layer 3) were removed when the product went
> English-only. Only Layer 1 + Layer 2a (dictionary) remain.

If a server-side PII redaction flag is desired in the future, there is room to reconsider it as an opt-in design for a `redact_profile` parameter on the harness-mem side, from §111 onward.

### Phase 65.3 implementation decisions (D43)

Implementation constraints finalized in coordination with the mem side before starting Phase 65.3:

| Constraint | Content | Basis |
|---|---|---|
| MCP cross-project is N-call | The MCP schema of `mcp__harness__harness_mem_search` exposes only the single value `project: string` (neither `projects: [array]` nor `strict_project: boolean` is on MCP). For cross-project search the client makes one MCP call per member and merges/dedupes the results on the client side | mem-side mcp-server schema check (`mcp-server/src/tools/memory.ts:297-341`) |
| client-redaction.yaml is PiiRule-compatible | The client-side dict schema (`client-redaction.v1`) keeps its field names compatible with the mem side's existing `pii-filter.ts` `PiiRule[]` schema (`rule_id`, `pattern`, `replace_with`, etc.). Full unification (npm package) is a future follow-up | Avoid duplicate implementation + secure an upgrade path to the Cross-client consistency section |
| `[REDACTED_*]` double-substitution guard | The server-side `event-recorder.ts:redactContent` already replaces email / API key / hex with `[REDACTED_*]`. The client Layer 2 redact requires a sentinel guard that does **not re-substitute** existing marks | Prevent information corruption from double substitution |
| applied_filters annotation policy | The mem-side `applied_filters` meta is unimplemented (internal audit only). The Phase 65.3.6 audit log records only Layer 2/3 (client), and Layer 1 (server) is explicitly annotated as "relies on server default + internal audit" | Confirmed unimplemented on the mem side; not blocking for this phase |

If the latency of cross-project N-call becomes a problem in real operation in the future, file it on harness-mem §111 as **XR-005** (adding `projects: [array]` + `strict_project: boolean` to the MCP schema).

### Phase 65.3 completion report (2026-05-09)

The 7 tasks of Phase C were completed within a single session, and everything was contained within harness with zero Cross-Contract changes.

| Phase | task | commit | Main deliverables | Tests |
|---|---|---|---|---|
| C-1 | 65.3.1 | `4a014137` | `.claude/rules/cross-project-groups.yaml` SSOT + `scripts/load-cross-project-groups.sh` (yaml → JSON validator) + `docs/cross-project-groups-schema.md` | 21 PASS |
| C-2 | 65.3.2 | `5152bed2` | `.claude/rules/client-redaction.yaml` (PiiRule-compatible schema) + `scripts/redact-by-dictionary.sh` Layer 2a + double-substitution guard | 26 PASS |
| C-3 | 65.3.3 | `20a4478f` | Japanese NER redaction Layer 2b (later removed for English-only product) | 22 PASS |
| C-4 | 65.3.4 | `0ae3f40a` | `scripts/render-html.sh --with-redaction` + katakana final-scan Layer 3 (final-scan later removed for English-only product) | 16 PASS |
| C-5 | 65.3.5 | `09377eb9` | `--cross-project-group <name>` flag opt-in on the `harness-plan-brief` / `harness-accept` SKILL.md (D43 Option α: MCP N-call) | 18 PASS |
| C-6 | 65.3.6 | `272a8f33` | `cross-project-audit.v1` audit log + `scripts/cross-project-audit-log.sh` + HTML audit summary display | 21 PASS |
| C-7 | 65.3.7 | `c05d6ef8` | e2e validation (3-member group + full-layer pass-through + envelope + sentinel guard) | 21 PASS |

**Total**: 7 feat commits + 7 chore commits = 14 commits, all 145 assertions PASS, `./tests/validate-plugin.sh` went 51 → 58 (+7), and `bash scripts/ci/check-consistency.sh` fully passed.

All 4 decision packages of D43 worked exactly as originally designed, with no unexpected constraints or rework.

**List of unfiled follow-up triggers** (file on harness-mem §111 only when the activation condition is met):
- XR-005: add `projects: [array]` + `strict_project: boolean` to the MCP schema — when N-call latency becomes a problem in real operation
- (former provisional name §110-S110-006): implement `applied_filters` meta — when there is demand to make server-side filter application visible from the client ※ the actual §110 S110-006 has already been consumed as this Phase C closure record (see below)
- PiiRule unification npm package: when Cross-client consistency truly becomes necessary (the mem-side PiiRule schema reference is below)

### Phase 65.3 closure ack (received on the harness-mem side, 2026-05-10)

The harness-mem session received the Phase C completion report as
**S110-006 within §110** (confirming zero Cross-Contract changes). A new §111 is
unnecessary; the SSOT operational policy is to consolidate it under §110.

| Item | mem-side commit | Content |
|---|---|---|
| content commit | `8b34ecb` | S110-006 Phase C closure record + 6-invariant conflict review (0 conflicts) + PiiRule reference list |
| hash backfill | `ad4ba56` | S110-006 cc:done [8b34ecb] |
| (optional follow-up) | (S110-007 candidate) | Document "do not include PII in signals" in the envelope contract — handled on the mem side; no filing needed on the harness side |

**6-invariant conflict review results** (confirmed on the mem side, 0 conflicts):
- `<private>` strip / Layer 2/3 overlap: no conflict (by design, invisible from the client after server deletion)
- `[REDACTED_*]` sentinel format: no conflict (the mem side is uppercase `EMAIL` / `KEY` / `SECRET` / `HEX`, and the client-side regex `[A-Za-z0-9_]+` handles both)
- envelope `validateProseContainsSignals`: no practical conflict (in the S110-007 candidate, the envelope contract side is documented and a defensive note is added to the harness-side client-redaction.yaml)
- cross-project N-call rate limit: no conflict (no rate limit configured on the mem side; no problem at the assumed N=5-10)
- Cross-project privacy tag merge: no conflict (the server filters independently per project; merge is the client's responsibility)
- audit log structure: no conflict (completed on the client side in Phase 65.3.6)

### Official PiiRule schema reference (shared via mem-side commit `8b34ecb`, the reference point when filing npm packaging)

The PiiRule specification in `mcp-server/src/pii/pii-filter.ts` (pinned as the reference point for when future npm packaging is filed):

| Kind | Path | Content |
|---|---|---|
| TS SoT | `mcp-server/src/pii/pii-filter.ts:15-20` | `interface PiiRule { name: string; pattern: string; replacement: string }` |
| TS SoT | `mcp-server/src/pii/pii-filter.ts:22-24` | `interface PiiRulesFile { rules?: PiiRule[] }` |
| function export | `mcp-server/src/pii/pii-filter.ts:33, 50, 69-85, 92` | `applyPiiFilter` / `loadPiiRules` / `DEFAULT_PII_RULES` / `getActivePiiRules` |
| .d.ts | `mcp-server/dist/pii/pii-filter.d.ts:1-6` | compiled declaration |
| environment variables | `docs/environment-variables.md:102-111, 302-303` | `HARNESS_MEM_PII_FILTER` / `HARNESS_MEM_PII_RULES_PATH` |
| official spec doc | `docs/specs/vps-team-deploy-spec.md:57, 260-285` | TEAM-006 PII filtering (example JSON is inline at `:270-275`) |
| Contract test | `mcp-server/tests/unit/pii-filter.test.ts:1-56` | 5 cases (phone JP / email / LINE_ID / composite / empty rules) |
| Usage example | `mcp-server/src/tools/memory.ts:13, 1067-1068` | applied within `record_checkpoint` |

**Important caveat**: There is no PiiRule component schema in README / OpenAPI, and no independent export as a JSON Schema.
When filing npm packaging, **scope the schema export and official doc maintenance together** (mem-side recommendation).

### Policy for ensuring Cross-client consistency

The requirement that "redaction also applies when called from other clients such as future third-party clients" is addressed by **unifying a shared library (npm package or sub-module) on the client side**. Reasons for not redacting at the server-side MCP API exit:

- Future team sharing (`harness_mem_share_to_team`) would break the "return the correct original text" contract and lose reversibility
- Keeping the server "presentation-policy free" avoids hindering client diversity (CC / future third-party clients)

Instead, harness-mem provides, as needed, an extension that includes `applied_filters` (e.g. `privacy_filter` / `project_scope`) in the response meta of `mcp__harness__harness_mem_search` (filed as a harness-mem §110 follow-up or under §111).

## The 2 routes of Cross-repo Handoff

The harness ↔ harness-mem handoff uses the following 2 routes selectively.

### Route A: the harness-mem repo's `Plans.md §NNN` (sibling-repo Plans SSOT)

**Use**: Cross-Contract changes (handoffs that need a detailed DoD and are referenced across multiple sessions)

**Examples**:
- §106 (companion contract handoff, filed in Phase 60, cc:done)
- §107 (checkpoint cold-start handoff, cc:done)
- §110 (Cross-repo Handoff Workflow Codification, the counterpart of this rule, codification completed on the harness-mem side)

**Procedure**:
1. When the harness side decides "the implementation should be moved to the mem side," add a section to Plans.md (e.g. §111)
2. Bullet the required DoD within the section (acceptance criteria, technical constraints, harness-side commit hashes to reference)
3. **Remove the related harness-side pieces (skills/scripts/docs) in the same PR** (the Phase 60 `1f4d9133`, `5373d50d` pattern)
4. If necessary, add a new row to the table of this rule `.claude/rules/cross-repo-handoff.md`

### Route B: GitHub Issue

**Use**: Cross-Runtime long-running follow-ups (reviews spanning multiple sessions and multiple PRs, or those that need exposure to external participants)

**Example**: harness-mem #70 (Phase 49.1.2 follow-up)

**Procedure**:
1. File with `gh issue create --repo foden303/harness-mem --title "..." --body "..."`
2. From the harness side, leave only a `# See harness-mem#NN` comment at the relevant spot (do not implement)
3. When the issue is closed on the harness-mem side, update this rule's reference on the harness side

## Decision axes (which to use)

| Aspect | A: Plans.md §NNN | B: GitHub Issue |
|---|---|---|
| Needs a detailed DoD | ✓ can write a detailed DoD | △ Issue body is fluid |
| Referenced across multiple sessions | ✓ Plans.md is a persistent SSOT | △ Issue becomes hard to read over time |
| Needs exposure to external participants | △ repo collaborators only | ✓ visible externally if a public repo |
| Harmless closeout-only | ✓ lightweight | △ filing an Issue incurs closeout effort |
| Long-running cross-runtime | △ Plans.md is weak for cross-runtime | ✓ Issue is appropriate |

When in doubt, default to **Route A (Plans.md §NNN)**. Reason: of the past 4 handoffs, 3 (Phase 60, 63, 65) were completed via Plans.md SSOT, so there is an operational track record. There is only one GitHub Issue: #70.

## Past boundary-adjustment record (do not retroactively file)

The following past handoffs will **not** be retroactively filed as GitHub Issues, because **this rule establishes that "Plans.md §NNN is equivalent to a GitHub Issue"**:

- Phase 60 (managed-companion conversion) — harness-mem Plans.md §106
- Phase 63 (dead-default cleanup) — harness-mem Plans.md §107
- Phase 65.3 (owner confirmation of the 3-layer redaction) — this rule's table + harness-mem Plans.md §110

For future boundary changes, choose from the 2 routes of this rule.

## Related

- harness `.claude/memory/decisions.md` D42 (this rule's local SSOT origin, gitignore target)
- harness `.claude/rules/migration-policy.md` (Phase 60 procedure for recording deleted-concept handoffs)
- harness-mem `docs/claude-harness-companion-contract.md:84-96` (Cross-repo Handoff Workflow section, harness-mem-side counterpart)
- harness-mem `.claude/memory/patterns.md:230` (Plans.md SSOT exception added to P7 Non-Application Conditions)
- harness-mem Plans.md §110 (Cross-repo Handoff Workflow Codification, the counterpart of this rule)

## Review conditions

- **Trigger A**: when an API that provides server-side PII redaction as opt-in (e.g. a `redact_profile` parameter) is implemented on harness-mem §111+ — reconsider the owner of Layer 2
- **Trigger B**: when a shared library for cross-client consistency is npm-ified — update the Cross-client consistency section
- **Trigger C**: when `applied_filters` is added to the response meta of harness-mem `mcp__harness__harness_mem_search` — update the Layer 1 verification path

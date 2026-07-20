# Redaction Defense for Cross-Project Search (Phase 65.3)

You want to pull past decisions and insights from another project, but you **don't want proper nouns** such as client names, personal names, or company names to leak in.
This is a mechanism that redacts (blacks out) proper nouns across two layers.

## What this does

Normally, Claude harness search is limited to the **current project only** (safe by default).

When you do want to bring in insights from similar cases, you can enable cross-project search by passing the `--cross-project-group <name>` flag.
In that case, layered defense prevents **proper nouns from other projects from leaking into the current project's HTML**.

## How it works

### Group definition (prerequisite)

List the member projects in `.claude/rules/cross-project-groups.yaml`:

```yaml
schema_version: cross-project-group.v1
groups:
  - name: PersonalTools
    members:
      - my-cli
      - my-dotfiles
      - my-scripts
```

Details: [cross-project-groups-schema.md](cross-project-groups-schema.md)

### Enabling cross-project search

```bash
# Use cross-project search in Plan Brief
/harness-plan-brief --cross-project-group "PersonalTools"
```

Alternatively, the MCP N-call flow described in Step 2 (alt) of the skill's SKILL.md is applied automatically.

### How the redaction works

When cross-project search is enabled, the following run automatically at HTML generation time:

#### Layer 1: harness-mem server side (Cross-Contract, separate repo)

- Strips `<private>` blocks (always run at the server exit, no opt-out)
- `strict_project: true` is the default (though it is currently immutable over MCP; N-call support arrives in Phase 65.3.5)
- Implementation: `harness-mem/memory-server/src/core/privacy-tags.ts`

#### Layer 2a: Dictionary-based proper-noun redaction (client side)

- Literal string match against the dict in `.claude/rules/client-redaction.yaml`
- Example: `NoraiCorp` → `[Client_A]`, `Jonathan Blackwood` → `[Person_A]`
- Language-agnostic: the dictionary matches any configured literal string
- Implementation: `scripts/redact-by-dictionary.sh` (PiiRule-compatible schema)

### Audit log

Each time a cross-project search runs, one line is appended to `.claude/state/audit/cross-project-search.jsonl`:

```json
{
  "schema_version": "cross-project-audit.v1",
  "timestamp": "2026-05-09T12:00:00Z",
  "group_name": "PersonalTools",
  "member_projects": ["my-cli", "my-dotfiles"],
  "query_hash": "<sha256 64 chars>",
  "redaction_count": {"dict": 2, "ner": 0},
  "output_passed_final_scan": true
}
```

The actual query string is **never recorded** (privacy) — only the sha256 hash.

The bottom of the generated HTML displays "redacted: dict X".

> Note: the audit schema `cross-project-audit.v1` retains the `ner` and
> `output_passed_final_scan` fields for backward compatibility. Since the
> Japanese NER layer was removed (English-only product), `ner` is always `0`
> and `output_passed_final_scan` is always `true`.

## Things to watch for

### 1. Layer 1 is server side (separate repo); harness never touches it

As the boundary of the cross-repo handoff workflow (D42), Layer 1 is fully contained on the harness-mem side.
Even if you create a new fixture containing `<private>` on the client side, it is always stripped when it passes through the server (no opt-out).

### 2. Double-substitution guard for the existing server-side sentinel `[REDACTED_*]`

The `[REDACTED_EMAIL]`, `[REDACTED_KEY]`, `[REDACTED_SECRET]`, and `[REDACTED_HEX]` output by the mem-side `event-recorder.ts:redactContent`
are handled with a 3-step sentinel-save → redact → restore so that client Layer 2 does not re-redact them.
The regex `[A-Za-z0-9_]+` handles both upper and lower case.

### 3. Cross-project defaults to OFF

Unless you pass the `--cross-project-group` flag, search covers only the current project (the Phase 65.1.x behavior).
Cross-project search never runs unless you explicitly opt in.

### 4. The audit log never keeps the raw query

Only `query_hash` (sha256, 64 hex chars) is recorded.
Because it is irreversible, the actual query content is protected even in the event of a leak.

## Related

- [cross-project-groups-schema.md](cross-project-groups-schema.md) — How to configure groups
- [cognitive-load-surfaces.md](cognitive-load-surfaces.md) — The roles of the 3 surfaces
- `.claude/rules/cross-repo-handoff.md` — D42 (harness ↔ harness-mem boundary)
- `.claude/memory/decisions.md` D43 (design decisions for this feature, 4-decision package)

## Related scripts

| Script | Role |
|----------|------|
| `scripts/load-cross-project-groups.sh` | Reads the yaml SSOT and resolves member projects |
| `scripts/redact-by-dictionary.sh` | Layer 2a dictionary redaction |
| `scripts/render-html.sh --with-redaction` | Applies dictionary redaction to generate HTML |
| `scripts/cross-project-audit-log.sh` | Appends to the audit log |

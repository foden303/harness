# Agent View (`claude agents`) Policy

In CC `2.1.139`+, `claude agents` (agent view, Research Preview) was introduced as a single entrypoint;
`2.1.141` added the `--cwd <path>` flag, and `2.1.142` added the `--add-dir` / `--settings` / `--mcp-config` /
`--plugin-dir` / `--permission-mode` / `--model` / `--effort` / `--dangerously-skip-permissions`
flags.

Harness treats this as **an independent entrypoint for a Lead (operator) to monitor multiple Worker / Reviewer / Scaffolder sessions in one list**,
and keeps it separate from Harness's internal teammate spawn workflow.

## Scope

| Target | How to use |
|------|----------|
| Lead (operator, human) | Check the status of multiple projects on one screen with `claude agents` |
| Harness teammate spawn (Worker / Reviewer / Scaffolder) | Via the Agent tool / breezing skill, not `claude agents` |

## Operating assumptions (2.1.139-2.1.142)

- `claude agents --json` can output a live session list as JSON (2.1.145). Limit it to **diagnostic / scripting** uses such as tmux-resurrect, status bar, and session picker. Do not use it as a substitute for Harness teammate spawn.
- Agent view shows **running / blocked on you / done** per session.
- `claude agents --cwd <path>` can scope the session list to a directory (2.1.141).
- When launching `claude agents`, you can configure the dispatched background session with `--add-dir`, `--settings`, `--mcp-config`, `--plugin-dir`,
  `--permission-mode`, `--model`, `--effort`, and `--dangerously-skip-permissions` (2.1.142).
- A teammate launched in a background session retains its permission mode (2.1.141). It does not revert to the default.

## Harness safe-operation policy

### A. Permitted uses

| Use case | Recommended |
|-----------|------|
| Working in the current project while checking the status of another project | `claude agents --cwd <other-project>` |
| Background-dispatching a safe long-running task (test / lint) in another project | `claude agents --cwd <path> --permission-mode default --effort low` |
| Read-only investigation task (want to check results immediately) | Launch in parallel with `claude agents` |

### B. Flag usage conditions

| Flag | When to use | When prohibited |
|------|----------|----------|
| `--cwd <path>` | When viewing another project's status | --- |
| `--add-dir` | When expanding the search scope | Even after denyRead, opting into paths containing secrets (`.env*`, `secrets/**`, `.ssh/**`) in the same dir is prohibited |
| `--settings <path>` | During development when trying project-specific settings | Continually overriding `.claude-plugin/settings.json` per agent is prohibited (breaks SSOT) |
| `--mcp-config <path>` | Trying out a temporary MCP server | Persistent project MCP is unified in `.mcp.json` |
| `--plugin-dir <path>` | Local testing of an unreleased plugin | --- |
| `--permission-mode <mode>` | Explicitly setting `default` / `acceptEdits` / `plan` | Using `bypassPermissions` on a protected branch (`main`/`master`) is prohibited |
| `--model <model-id>` | Temporary model switch | Downgrading to a small model in a release / hotfix session is prohibited |
| `--effort <level>` | Setting intensity according to task size | Guard rails (R01-R13) must not be relaxed via effort |
| `--dangerously-skip-permissions` | Only inside a trusted ephemeral sandbox | Prohibited in (a) a session on a protected branch, (b) a session that reads credentials, (c) a production deployment session |

### C. Separation from teammate spawn

- `claude agents` is **a UI for the operator (human Lead) to view multiple sessions**.
  Harness's internal teammate spawn (Worker / Reviewer / Scaffolder) is launched by the **Agent tool / breezing skill**.
- Worker / Reviewer do not spawn other sessions from `claude agents`. Lead only (details: "spawn permissions" in `docs/team-composition.md`).
- The breezing skill uses `claude --teammate-mode in-process` / `tmux`. It does not depend on `claude agents`.

### D. Background permission mode retention (2.1.141)

- A teammate backgrounded via `/bg` / `←←` or `claude agents` retains the permission mode it was launched with.
- There is **no need to re-inject the permission mode** on the Harness side. The breezing teammate launch contract can be used as-is.
- Verification: if a teammate is launched in `plan` mode, it stays in `plan` mode even after backgrounding (guaranteed by CC itself).

### E. Agent view launch order (recommended)

1. The operator opens an interactive session with `claude`.
2. As needed, check the status of other sessions with `claude agents`.
3. To dispatch a separate task, explicitly use `claude agents --cwd <path> --permission-mode <mode> --effort <level>`.
4. When the Lead starts breezing, launch it from the `/breezing` skill rather than via `claude agents`.

## Violation examples

| Violation | Impact | Recommended response |
|------|------|----------|
| A Worker subagent calls `claude agents` to spawn another session | Collapse of the permission boundary (only the Lead may spawn) | Remove the `claude agents` call from the Worker's steps |
| `claude agents ... --dangerously-skip-permissions` on a protected branch (`main`) | Bypasses a guard rail (R12 ask) | Use `--permission-mode default` or `acceptEdits` |
| Overriding `.claude-plugin/settings.json` per agent with `--settings` | Breaks settings SSOT | Consolidate changes into project-level `.claude/settings.local.json` |
| Using `--dangerously-skip-permissions` in a session that handles credentials such as `harness-mem` | Risk of secret leakage | Remove the flag in question |

## CI / gate

- `tests/validate-plugin.sh` does not validate the existence of `claude agents` flags (they are a CC-native feature).
- Instead, the spawn permission boundaries in `docs/team-composition.md` and the
  deny rules in `.claude-plugin/settings.json` function as layered defense.
- If you want to operationally audit `claude agents` usage, record the env `CLAUDE_CODE_SESSION_ID`
  via a webhook (`scripts/hook-handlers/webhook-notify.sh`).

## Related

- `docs/team-composition.md` — SSOT for teammate spawn and parallelism
- `agents/worker.md` — Worker contract
- `docs/upstream-update-snapshot-2026-05-15.md` — Phase 69 snapshot
- `docs/upstream-update-snapshot-2026-05-27.md` — Phase 80 snapshot
- `.claude/rules/hooks-2.1.139-plus.md` — 2.1.133+ rules around hooks
- `.claude/rules/hooks-2.1.152-plus.md` — MessageDisplay / reloadSkills / sessionTitle (2.1.152+)

## Review conditions

- When CC `claude agents` is promoted to GA (leaves Research Preview) → re-review the entire policy
- When the `--dangerously-skip-permissions` flag is deprecated / renamed → update the relevant cell
- When Harness teammate spawn becomes integrable with the `claude agents` API → re-examine section C (separation from teammate spawn)

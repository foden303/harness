# Commit Safety Rules

Safe-operation rules for commit operations in Harness.
Prevents the risk of an agent unintentionally reverting or overwriting a commit.

## /undo — undoing changes within a session (CC 2.1.108+)

CC 2.1.108 added `/undo` as an alias for `/rewind`.

### Behavior definition

`/undo` undoes the immediately preceding action (tool call / file change) within a Claude Code session.
**It differs from git commit revert/reset.**

| Operation | Target | Effect on git |
|------|------|------------|
| `/undo` | The immediately preceding tool call within the CC session | Restores the change from disk, but does not revert what has already been `git commit`ed |
| `git revert` | Per git commit | Creates a new revert commit |
| `git reset --hard` | Per git commit | Irreversible. Protected by Harness deny rules |

### Usage constraints for Harness agents

**Workers / Reviewers do not run `/undo` autonomously.**

Only when all of the following conditions are met, and upon the Lead's (user's) explicit instruction, is execution permitted:

1. The user explicitly said "undo the last change"
2. The undo target is a file change before a git commit (use git revert for already-committed changes)
3. The affected files are limited to changes within a single session

### Prohibited patterns

- Using `/undo` to erase a commit in `REQUEST_CHANGES` handling (use `git revert`)
- A Reviewer autonomously running `/undo` after judging "this change is unnecessary"
- Using `/undo` instead of amend during a fix loop (use `git commit --amend`)

### Valid uses of /undo (reference)

- A human undoing right after an agent mistakenly overwrote a file
- Undoing unintended file writes during a dry run within a session

### Related rules

- `git reset --hard` is protected by the deny in `.claude-plugin/settings.json` and guardrail R11
- `git push --force` is protected by guardrail R06 and deny
- Irreversible git operations must require manual user execution (see Permission Boundaries)

Details: [CLAUDE.md — Permission Boundaries](../../CLAUDE.md)

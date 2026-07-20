# Autonomous Confirmation Scope

The SSOT that fixes the scope in which autonomous-execution skills such as `breezing` / `harness-work` / `harness-loop` may confirm with the user (via `AskUserQuestion`, etc.) during execution.

## Why this rule is needed

If autonomous execution frequently halts on non-essential confirmations (choosing among review-target candidates, wording a commit message, etc.), the user feels "I'm being asked about things that could be decided by inference," and the value of autonomous execution is lost. In particular, these confirmations are often presented in English and offer little to base a decision on, so the user cannot answer them correctly.

By narrowing down what may be confirmed, only the situations that truly require a halt (external transmission, security, whether the request can be carried out) surface.

## The 3 cases where confirmation is allowed (do not confirm otherwise)

1. **When external transmission is involved**: git push, PR creation/merge, publishing a GitHub Release, external API calls, sending to email/Slack/Discord, etc., deployment
2. **When a security risk is involved**: secret exposure, authentication/authorization/permission changes, destructive operations (`rm -rf`, `git reset --hard`, `git push --force`, etc. Existing deny/ask remain in effect)
3. **When the original request looks unachievable, or you want a decision on that**: a contradiction between the canonical spec and the implementation, a contradiction with the DoD/Depends in `Plans.md`, or when keeping vs. dropping backward compatibility changes how the request is interpreted

For confirmations that fall into the 3 cases above, use `AskUserQuestion` in environments where it is available; in environments where it is not, output `decision_needed.v1` and then halt.

## What not to confirm (infer and proceed)

The following do not fall into the 3 cases, so do not use `AskUserQuestion`. Choose the single most reasonable option, leave the reason for the choice in a 1-line output, and proceed. The user can review the result afterward and course-correct.

| Situation | Auto-selection criterion |
|---|---|
| Multiple candidate review targets in `harness-review` | Choose the first in priority order: working tree (uncommitted changes) > branch range (upstream/main..HEAD) > recent commits |
| The Review Gate in `harness-release` (unreviewed work found) | Auto-select "start from review" and launch `harness-review`. Only do dry-run/abort when explicitly specified |
| The commit message at the Work Commit Gate in `harness-release` | Use, as-is, the single draft generated from the review summary / `Plans.md` task / branch name |
| Minor scope judgment in the Scope Review of `harness-review` | Proceed with minor scope adjustments that do not change the interpretation of the request. If the interpretation changes, confirm as case 3 |
| Among security **vs.** UX trade-offs, a preference on the UX side only | Prioritize the security-side conclusion and proceed with the recommended UX option (if security is involved, you may confirm as case 2) |

## Exception: the single Confirmation Gate in `harness-release`

The single Confirmation Gate just before the Post-Gate in `harness-release` (the batched presentation of version bump / CHANGELOG / PR merge / tag / GitHub Release) is maintained because it falls into case 1 (external transmission). It is the only confirmation point in the entire release flow, and it concentrates the decision into this single point precisely because the intermediate Review Gate / Work Commit Gate are automated.

## Scope

- `decision_needed` in `skills/harness-review/references/governance.md`
- The `REVIEW_TARGET_ASK` contract in `skills/harness-review/SKILL.md`
- The Review Gate / Work Commit Gate in `skills/harness-release/SKILL.md`
- After returning to the Lead via `agents/worker.md` / `agents/advisor.md`, the Lead's judgment of whether to confirm with the user

Out of scope (do not change this rule):

- The single Confirmation Gate in `harness-release` (see "Exception" above)
- `.claude/rules/commit-safety.md`, Permission Boundaries (ask/deny for irreversible operations such as `git push --force`)
- The scope confirmation when `/breezing` is called without arguments (this is interpretation of the task scope itself, which falls into case 3)

## Related

- Making the project-side SSOT of the user's personal working agreement (`~/.claude/CLAUDE.md` Risk Gates)
- `.claude/rules/commit-safety.md` — handling of irreversible git operations
- `CLAUDE.md` Permission Boundaries — deny/ask defense in depth

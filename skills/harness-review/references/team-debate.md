# TeamAgent Debate

## In one line

TeamAgent Debate is a read-only review pass where different perspectives read the same change to reduce oversights.

## When required

Run it if any of the following holds.

- The change spans multiple modules
- It touches security / auth / release / distribution / mirror
- Correspondence with the spec source of truth or `Plans.md` is ambiguous
- Regression risk is high
- Per-aspect evaluations diverged within the reviewer
- After fixing the same issue, re-review failed twice in a row

## Agents

| Agent | Main question |
|---|---|
| Spec Agent | Looks for contradictions between the spec source of truth and the implementation diff |
| Plans Agent | Confirms correspondence between the `Plans.md` task / DoD / Depends and the diff |
| Regression Agent | Looks for regressions in existing behavior, tests, the distribution mirror, and CLI/skill UX |
| Skeptic Agent | Looks for major risks overlooked under the assumption of wanting to pass |

At least 2 perspectives, up to 4 when needed.
All are read-only.

## Fallback

Even when native TeamAgent is unavailable, do not skip it.

Available fallbacks:

- reviewer subagent
- An explicitly separated manual-pass

Record one of the following in `team_agent_mode`.

- `native`
- `manual-pass`
- `unavailable`

If it stays `unavailable` and a manual-pass is also not possible, stop as `decision_needed`.

## Output

```json
{
  "team_debate": {
    "required": true,
    "mode": "manual-pass",
    "team_agent_mode": "manual-pass",
    "agents": ["Spec Agent", "Plans Agent", "Regression Agent"],
    "disagreements": [],
    "acceptance_bar": {
      "spec_alignment": "pass",
      "plans_alignment": "pass",
      "regression_safety": "pass"
    }
  }
}
```

## Pass bar

If a TeamAgent Debate disagreement is equivalent to critical / major, then `REQUEST_CHANGES`.
When downgrading to minor / recommendation, write the reason with evidence.

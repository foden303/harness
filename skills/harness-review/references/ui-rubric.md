# UI Rubric Reviewer Profile

A review profile launched with `harness-review --ui-rubric`, specialized in visual quality.
Rather than leaving UI quality at a vague "feels okay," it scores 4 axes from 0-10 to decide.

---

## How to think about the 4 axes

### 1. Design Quality

- What to look at: organization of information, whitespace, visual flow, readability
- Tends to score low: text too cramped, element priority not conveyed
- Tends to score high: what to look at is conveyed naturally

### 2. Originality

- What to look at: lack of familiarity, intentional character, choice of expression
- Tends to score low: uses a generic boilerplate layout as-is
- Tends to score high: has a unique presentation suited to the brand or the problem

### 3. Craft

- What to look at: attention to detail, alignment, spacing, typography, state changes
- Tends to score low: subtle misalignment, uneven whitespace, sloppy hover / active
- Tends to score high: consistent down to the details, with little roughness

### 4. Functionality

- What to look at: whether it can be used without confusion, whether the main flows work, whether the UI holds up in practice
- Tends to score low: the intent of buttons or forms is unclear, the main flow is broken
- Tends to score high: the user does not hesitate about what to do next

---

## Anchor examples (0 / 5 / 10)

| Axis | 0 points | 5 points | 10 points |
|---|---|---|---|
| Design Quality | Unclear what it wants to show; hard to read | Minimally readable, but weak organization | Information priority and visual flow are clear |
| Originality | Looks like an off-the-shelf template as-is | Some effort in places, but weak impression | Has character suited to the problem and is memorable |
| Craft | Alignment and whitespace are disordered; details rough | No major breakage, but not fully polished | Whitespace, text, and state changes are carefully arranged |
| Functionality | Main flow is hard to follow; hard to use | Main operations are possible but there are confusing moments | Main flow is natural; operable without confusion |

---

## Judgment method

1. Score each of the 4 axes from 0-10
2. If `review.rubric_target` exists, use its values as the per-axis thresholds
3. If `review.rubric_target` does not exist, use the default threshold=6 for all 4 axes
4. If even one axis is below its threshold, `REQUEST_CHANGES`
5. If all axes are at or above their thresholds, `APPROVE`

### Example of `rubric_target`

```json
{
  "design": 7,
  "originality": 6,
  "craft": 8,
  "functionality": 9
}
```

---

## How to output

- `reviewer_profile` must always be `"ui-rubric"`
- In `observations`, write the reasons for lowering scores in plain language understandable to non-experts
- For each axis, add at least one "where to fix to raise the score"

### Output example

```json
{
  "reviewer_profile": "ui-rubric",
  "verdict": "REQUEST_CHANGES",
  "ui_rubric": {
    "scores": {
      "design": 7,
      "originality": 5,
      "craft": 8,
      "functionality": 8
    },
    "targets": {
      "design": 6,
      "originality": 6,
      "craft": 6,
      "functionality": 6
    }
  }
}
```

---

## Cautions in judgment

- Do not give high scores for flashiness alone
- Do not overrate Originality just for being "unusual"
- When usability is broken, prioritize Functionality and judge strictly
- Judge by **intent and completeness**, not by design preference

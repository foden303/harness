# Planning quality contract — harness-plan standard flow

`harness-plan` does not convert the information the user hands over directly into a task list.
When creating a plan or adding a large task, filter it through the latest information, existing specs, memory, and multi-perspective discussion via TeamAgent / subagents,
and turn only the elements that should be adopted into this product into the Plans.md task contract.

This is not a standalone subcommand. It is the standard quality gate for `create` and high-impact `add`.

## Step 0: Applicability decision

Use this quality contract when any of the following applies.

- Creating a new plan with `create`
- Using `add` for a task that affects product behavior / API / data model / permissions / billing / external integrations / distribution surfaces
- The user hands over an external product, a competitor, a spec proposal, an improvement idea, or comparison material
- There is a possibility of conflict with existing specs, Plans.md, memory, or past decisions
- The user asks for "maximum firepower," "thorough comparison," "neutral scoring," "regression prevention," etc.
- It is not a one-off, minor task, but affects multiple tasks / files / sessions / product behavior / API / data model / permissions / billing / external integrations / distribution surfaces / security

`create` and product-impacting `add` read the root `spec.md` every time.
Only in a consumer repo without a root `spec.md`, fall back to an existing project spec / `docs/spec/00-project-spec.md`.
The output must always include a `Spec delta` or `Spec skip reason`.
This is the co-required planning output contract; precedence stays `spec.md > sub-spec > Plans.md`.

Non-trivial planning assumes TeamAgent or subagent validation.
When the Task tool is available, always run independent perspectives.
When it is not available, state `subagents-not-used` explicitly and evaluate the same perspectives separately on your own.
The output must always include `team_validation_mode`.

| mode | When to use |
|------|-------------|
| `not_required_lightweight` | lightweight tasks such as typo / format / README / CHANGELOG / marker update / status sync |
| `native` | used runtime-native multi-perspective validation such as TeamAgent |
| `subagent` | used Task subagents per perspective |
| `manual-pass` | on a runtime where Task is unavailable, evaluated the same perspectives separately on your own |
| `unavailable` | validation impossible. Do not mark non-trivial work as Required |

The following may be handled lightly.

- An `update` that only changes markers
- A `sync` that only reconciles status
- Typo / format / README / CHANGELOG only
- A narrow change whose correct answer is fixed by an existing spec and tests

## Step 1: Input decomposition

Split the information the user hands over into the following 4.

| Classification | Example |
|----------------|---------|
| Evaluation target | External product, competitor feature, spec proposal, design approach, operations proposal |
| The user's aim | What they want to improve, what they want to avoid |
| Uncertain facts | Recency, pricing, API, constraints, competitive landscape, existing repo state |
| Evidence needed for the adoption decision | Official docs, measurements, existing specs, memory, test results |

Do not stop to ask even if there are unknowns. Evaluate a reasonably inferable intent first, and only surface a "decision branch" when the judgment genuinely splits.

## Step 2: Fetching the latest information

When external facts are involved, use WebSearch. The priority order is as follows.

1. Official documentation, official blogs, release notes, GitHub repos
2. Standard specs, papers, technical sources close to primary information
3. Trustworthy comparison articles, case studies, issues / discussions

Confirm important facts across 2 or more sources whenever possible.
If they conflict, organize which points conflict and make the impact on the adoption decision explicit.

When WebSearch is unavailable, or the network fails, handle it as follows.

- `Latest information: unverified`
- Make a provisional evaluation on local evidence only
- In the final output, state clearly that "web confirmation remains here"

## Step 3: Checking the local sources of truth

Any proposal to adopt into the product must be reconciled with the existing sources of truth.

At minimum, check:

```bash
cat Plans.md
rg -n "related keyword" README.md README_ja.md CLAUDE.md docs skills scripts tests
rg -n "\"(lint|format)\"|eslint|prettier|biome|oxlint|dprint|ruff|black|isort|gofmt|go vet|cargo fmt|cargo clippy" package.json pyproject.toml go.mod Cargo.toml Makefile .github/workflows scripts docs 2>/dev/null
find docs -maxdepth 3 -type f | sort
git status --short --branch
```

Aspects to examine:

- Whether it conflicts with an existing product promise
- Whether it conflicts with existing skill role / trigger / allowed-tools
- Whether it conflicts with incomplete Plans.md tasks
- Whether it affects the distribution mirror or i18n
- If there is a spec source of truth, whether the spec SSOT should be updated before Plans.md
- Whether the root `spec.md` product contract and the Plans.md task contract are separated
- Whether a lint / formatter baseline exists for a plan with source code changes. If unset, whether a setup task is needed before implementation

## Step 4: Memory check

When harness-mem, harness-recall, or a local memory file is available, check past decisions by related keywords.
When you can search, scope it to the current project / repo. Use a cross-project search only when the user explicitly asks.
This step is a reinvention-prevention check and is not skipped for non-trivial planning.

Examples of what to check:

- harness-mem / harness-recall search results
- `.claude/agent-memory/`
- `.claude/state/memory-bridge-events.jsonl`
- Existence check of `.harness-mem/`
- Prior decisions remaining in in-repo docs / Plans.md

Notes:

- Do not assume you can read the harness-mem DB directly
- If harness-mem is unset up, unhealthy, or unsearchable, state "memory unchecked" explicitly
- Memory is weaker than the current repo state. If old memory conflicts with git / docs, prefer the current repo state
- Do not assert as absent what memory or search cannot see. `not_observed != absent`

## Step 5: Subagent discussion

Non-trivial planning assumes TeamAgent or Task subagents.
When the Task tool is available, run at least 3 independent perspectives. Specify "read-only," "evidence-backed," and "conclusion-first" for each agent.
Only one-off, minor tasks may explicitly skip this step.
Product / Strategy, Architecture / Implementation, Security / Abuse, QA / Regression, and Skeptic are perspective names, not agent_type names.
Pass them as perspectives to the available TeamAgent / Task subagents.
Do not require spawning arbitrary agents.

Standard roles:

| Role | Purpose |
|------|---------|
| Product / Strategy | Look at adoption value, differentiation, user value, opportunity cost |
| Architecture / Implementation | Look at feasibility, fit with existing design, maintenance burden |
| Security / Abuse | Look at permissions, secrets, prompt injection, supply chain, external-send risk |
| QA / Regression | Look at regressions, tests, distribution mirror, compatibility, whether it actually works |
| Skeptic | Attack the reasons not to adopt, over-investment, ambiguous assumptions |

What to require from each agent's output:

- Adopt / conditionally adopt / reject
- Evidence
- The biggest risk
- What else to confirm
- Conflicts with existing specs or memory
- DoD to be captured in test / smoke / CI / review / release gates

How to summarize the discussion:

1. Extract points of agreement
2. Keep points of conflict
3. State your own judgment
4. Classify into Required / Recommended / Optional / Reject

When subagents are unavailable, evaluate the same 5 perspectives separately and explicitly on your own, and write `subagents-not-used`.

## Step 5.5: Implementation plan validation gate

Do not mark an implementation plan as Required until all of the following 5 are satisfied.

| Gate | What to examine | If it fails |
|------|-----------------|-------------|
| Spec / Plans Fit | Does not conflict with the order of root `spec.md`, sub-spec, `Plans.md` | Emit a `Spec delta` first or Reject |
| Memory / Wheel Check | Whether harness-mem / harness-recall / repo memory already has the same kind of decision or an existing task | Reuse the existing approach, task-ify only the delta |
| Product Fit | Whether it directly connects to the product's purpose and the primary user workflow | Route it to docs / external workflow / Optional |
| Security Fit | Whether it weakens permissions, secrets, external-send, dependencies, or branch/release gates | spike / security task / Reject |
| Quality Baseline Fit | Whether quality can be decided Yes/No for source code changes via a lint / formatter / CI command | Front-load a setup task, or leave a formatter_baseline skip reason |
| Works In Practice | Whether it can be decided Yes/No via test / smoke / CI / review / release closeout | Rebuild the DoD |

This gate is a "front-loaded step to reduce rework," not an impression review.
Any failed gate must be reflected in the Plans.md DoD, Depends, or `[needs-spike]`.
Quality Baseline Fit is not an excuse to sloppily add a formatter or linter.
For a plan that is unset and includes source code changes, place a setup task before the implementation tasks.
The setup task's DoD includes the 3 items: config, package script / CI command, and validation command.
Do not install packages during planning. harness-work performs the installation as a setup task.
Perform a broad bulk reformat only when the user explicitly asks or when it is within that setup task's scope.
Security Fit does not require actually reading secrets.
If reading `.env`, tokens, private keys, customer data, etc. becomes necessary, stop it as a Risk Gate.
Confirm on surfaces that do not read secret values, such as existing guardrails, config shape, audit evidence, tests, and GitHub / CI metadata.

## Step 6: Neutral scoring review

Scoring is out of 5. Treat 5 as a good state and 1 as a weak state.

| Axis | 5 points | 3 points | 1 point |
|------|----------|----------|---------|
| Product Fit | Directly at the core of the target product | Useful but peripheral | Another product or ops path suffices |
| Evidence Strength | Primary source + measurement + existing evidence | Only one side confirmed | Mostly speculation |
| User Value | Greatly improves decision quality or execution speed | Effective in some workflows | Perceived value is thin |
| Implementation Feasibility | Small and local | Medium but manageable | Large-scale with high maintenance burden |
| Regression Safety | Low risk and testable | Has an impact scope | Easily breaks existing flows |
| Strategic Leverage | Becomes a long-term differentiator | Just a convenience feature | Transient |
| Security Safety | Verifiable without weakening permissions or secrets | Has caveats | Has dangerous permission relaxation or unverified external sends |
| Works In Practice | Provable via smoke / CI / review | Mostly manual confirmation | Ambiguous behavior confirmation |

Correction rules:

- If Evidence Strength is 2 or below, Required is prohibited
- If Regression Safety is 2 or below, place a spike / spec / test first
- If Security Safety is 2 or below, Required is prohibited
- If Works In Practice is 2 or below, rebuild the DoD or drop it to a spike
- If Quality Baseline Fit is 2 or below and it includes source code changes, make a formatter_baseline setup task a Required dependency
- If Implementation Feasibility is 2 or below and User Value is 3 or below, lean toward Reject
- If Product Fit is 2 or below, do not put it into this product; route it to docs / external workflow

## Step 7: `$easy` report

The final output does not present the hard evaluation as-is; it converts it into a decidable form.

Required structure:

```markdown
In one line:
{{adoption decision in one sentence}}

Scoring review:
| Option | Score | Verdict | Evidence | Unverified |
|--------|-------|---------|----------|------------|

Proposals to adopt:
| Priority | Proposal | Reason | What it leads to |
|----------|----------|--------|------------------|

Regression check:
- team_validation_mode:
- spec:
- Plans.md:
- harness-mem / memory:
- TeamAgent / subagent:
- product fit:
- security:
- works in practice:
- formatter_baseline:
- mirror / distribution:
- test:

What to do next:
1. ...
2. ...
3. ...
```

Style rules:

- State the conclusion first
- Translate jargon into short terms immediately
- Do not judge by vibes like "amazing" or "revolutionary"
- Narrow proposals to 1-3. Do not list too many candidates
- Separate facts, speculation, and the unverified

## Step 8: When dropping into Plans.md / spec

Convert only the adopted proposals into the task contract.

Order:

1. Read the root `spec.md`, and if needed, update the product contract first as a `Spec delta`
2. If there are source code changes and no lint / formatter baseline is set, place a formatter_baseline setup task first as a Required dependency
3. Add only the Required tasks to Plans.md
4. Attach `[needs-spike]` to high-risk options
5. Place a verifiable DoD on each task
6. Attach `[tdd:required]` to tasks that need TDD
7. When it affects the mirror / i18n / package surface, place a separate validation task
8. If a spec update is unnecessary, leave a `Spec skip reason` in the task context / sprint contract
9. For non-trivial planning, leave the TeamAgent / subagent validation results, or the `subagents-not-used` fallback and the 5-gate results, in the task context
10. Do not mark a `team_validation_mode: unavailable` plan as Required. Allow `not_required_lightweight` only for lightweight tasks

The agent drafts the `Spec delta`. Do not assume the user writes the spec from scratch.
The `Spec delta` / `Spec skip reason` is generated by Harness; the consumer only approves or amends it.

Prohibited:

- Creating only implementation tasks while the spec's correctness conditions are still unstable
- Handling the regression check with a "note" instead of task-ifying it
- Creating only implementation tasks while ignoring the absence of a lint / formatter baseline despite source code changes
- Omitting the `Spec skip reason` for docs-only / mechanical tasks

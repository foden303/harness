# Phase 21 Release Copy Drafts

Last updated: 2026-03-06

Drafts for announcing Phase 21 externally.
Do not mix `trust repair`, `evidence pack`, and `positioning refresh`; use them one topic at a time.

## Draft 1: Trust Repair

We tidied up the public surface of `harness`. We aligned the README badges, the missing docs, and the explanation of distribution boundaries, and reduced self-contradictions across README / Plans / docs.

## Draft 2: Evidence Pack

We added success / failure fixtures and a smoke runner for `/harness-work all`. Beyond claims alone, we provide a path to re-verify while looking at the artifacts.

## Draft 3: Positioning Refresh

We refocused the central message of Harness on `5 verb skills + TypeScript guardrail engine`. We foreground that it does not just add skill packs but runs runtime enforcement and verification together as one.

## Current Recommendation

- Even when you hit a quota, evidence artifacts can still be captured via the replay fallback
- Until a full success artifact is in place, use Draft 2 to describe it as "built a reproducible skeleton"
- Avoid strong assertions like `production-ready`
- When presenting competitor comparisons, match the vocabulary in `docs/positioning-notes.md`

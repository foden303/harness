# ba-release-notes

Turn what the team finished in JIRA into **release notes a client, a manager or
a support agent can read**: what they can do now, what was fixed, what to watch
out for, and whether they need to do anything.

## Quick start

```bash
# Client notes for a sprint
/ba-release-notes --project DPD --sprint "DPD Sprint 42"

# Client notes for a release, published under a Confluence page on approval
/ba-release-notes --project DPD --version 2.4 --confluence https://<site>/wiki/spaces/DPD/pages/123456

# Support brief for the same release (likely user questions + workarounds)
/ba-release-notes --project DPD --version 2.4 --audience support

# Management view including the internal tech work
/ba-release-notes --project DPD --from 2026-10-01 --to 2026-10-25 --audience internal

# Markdown only, never touch Confluence
/ba-release-notes --project DPD --version 2.4 --draft-only
```

The skill collects the Done issues, groups them into **New / Improved /
Fixed**, keeps refactors, chores, infra and spikes in an **Internal** list,
rewrites each item as one line of user benefit with its key as a link, asks you
when an item's impact is unclear, and saves the notes under
`.claude/state/ba-release-notes/<slug>/`. It publishes to Confluence only when
you say so, and never emails or posts to chat: paste the file yourself.

## Example

Input: `--project DPD --version 2.4`. JIRA returns 14 Done issues; 1 is
"Won't Do" (dropped). Of the 13 left, 4 are internal (a refactor, a CI job, a
library upgrade, a spike). The skill asks one question:

> Is DPD-412 (retry on the payment webhook) visible to clients?
> (a) yes, mention it (b) internal only

The BA picks (a). Output `notes.md`:

```markdown
# Payments Portal 2.4 — Release notes

**Released:** 2026-10-26 · **Version:** 2.4 · **Audience:** client

You can now export the transactions you filter straight to a spreadsheet, so
monthly reconciliation no longer needs a support request. Payments that failed
because of a short outage are now retried automatically.

## New

### Self-serve reporting
- You can now export the transactions you filtered to a CSV file, up to 50,000 rows. ([DPD-901](https://<site>/browse/DPD-901), [DPD-902](https://<site>/browse/DPD-902))
- Admins can now see who exported what, and when, in the activity log. ([DPD-903](https://<site>/browse/DPD-903))

## Improved

### Payments
- A payment that fails during a short outage is now retried automatically for up to 10 minutes. ([DPD-412](https://<site>/browse/DPD-412))
- Search results appear faster while you type. ([DPD-920](https://<site>/browse/DPD-920))

### Invoices
- Invoice totals and due dates are now at the top of the PDF. ([DPD-433](https://<site>/browse/DPD-433))

## Fixed

- The dashboard total now matches the transaction list in every time zone. ([DPD-917](https://<site>/browse/DPD-917))
- Vietnamese names now display correctly in emailed receipts. ([DPD-925](https://<site>/browse/DPD-925))
- The Save button on the profile page no longer stays greyed out after an error. ([DPD-931](https://<site>/browse/DPD-931))

## Known issues

- An export of a very large list can stop after 30 seconds — narrow the filter and export again. ([DPD-950](https://<site>/browse/DPD-950))

## Action needed by users

- Everyone: sign in again once after the update to keep two-step sign-in active.
```

With `--audience support`, each line gains a "Users may ask:" sub-line, for
example:

```markdown
- You can now export the transactions you filtered to a CSV file, up to 50,000 rows. (DPD-901, DPD-902)
  - Users may ask: "Why is Export greyed out?" — nothing matches the current filter.
```

With `--internal` (or `--audience internal`) an **Internal** section lists the
4 held-back items:

```markdown
## Internal
- Invite form validation refactored (DPD-944)
- Nightly CI job for the export tests (DPD-946)
- Payment library upgraded to the supported version (DPD-947)
- Spike: options for scheduled exports (DPD-948)
```

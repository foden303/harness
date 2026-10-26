# Collect, group, rewrite, ask (steps 1-4)

## Collect (step 1)

Build one JQL from the options and run it with `searchJiraIssuesUsingJql`
(fields: summary, description, issuetype, status, resolution, resolutiondate,
parent, labels, components, fixVersions, priority).

| Option | JQL |
|--------|-----|
| `--sprint "<name or id>"` | `project = <KEY> AND statusCategory = Done AND sprint = "<name>"` (an id: `sprint = <id>`) |
| `--version <fixVersion>` | `project = <KEY> AND statusCategory = Done AND fixVersion = "<version>"` |
| `--from` / `--to` | `project = <KEY> AND statusCategory = Done AND resolved >= "<from>" AND resolved <= "<to>"` |
| `--jql "..."` | As given. If it has no status clause, add `AND statusCategory = Done` and say so |

- `statusCategory = Done` (not `status = Done`) so projects whose last status
  is "Closed", "Released" or "Resolved" still match.
- Drop issues resolved as **Won't Do, Duplicate, Cannot Reproduce, Declined**
  (they are Done but nothing shipped). Count them as "dropped".
- Page through results until all are read; report the total.
- More than one sprint / version matches the name → show them and ask.

Before writing anything, report: `Found 34 · dropped 3 (2 Won't Do, 1 Duplicate)
· 31 to classify`.

## Group and classify (step 2)

**Group** by parent Epic (heading = the Epic's area / goal in plain words, not
its key). No Epic → by component, then by the `[Area]` in the title, else
"Other improvements".

**Merge** before classifying:

- Sub-tasks roll into their parent; never listed alone.
- Stories split per team for one feature (`[Area] [BE] X` + `[Area] [FE] X`,
  or linked by "Depends on" with the same goal) → one item, all keys.

**Classify** each item:

| Bucket | When | Signals |
|--------|------|---------|
| **New** | The user can do something they could not before | Story / feature type; "add", "allow", "new", "support" |
| **Improved** | Something the user already did is faster, easier, clearer or broader | Story / improvement type; "improve", "faster", "redesign", "extend", "also" |
| **Fixed** | Something that was wrong now works | Bug type, or a story whose goal is correcting behaviour |
| **Internal** | No change a user can see | Labels / components / title words: `refactor`, `chore`, `tech-debt`, `infra`, `devops`, `ci`, `spike`, `migration` with no user-visible change, `upgrade` of a library; Spike type; Task with no user-facing AC |

Choose the bucket from the ticket and state it; New vs Improved is a judgement
from the ticket's own words, not a question. Ask (step 4) only when a fact is
missing: whether users can see it, what they gain, whether they must act.

Security fixes: list under **Fixed** in plain words ("Closed a security issue
in sign-in") without exploit detail, unless the ticket is labelled
`security-embargo` → Internal, and say so in the report.

## Rewrite (step 3)

One line per item: **what the user can do now, or what works now**, then the
key(s) as a link.

| Ticket title | Note line |
|--------------|-----------|
| `[Transactions] [BE] Export the filtered list to CSV` + `[FE] Export button` | You can now export the transactions you filtered to a CSV file, up to 50,000 rows. ([DPD-901](…), [DPD-902](…)) |
| `[Admin Portal] Invite modal: email validation refactor` | Internal — not in the notes |
| `Bug: dashboard total wrong when timezone != UTC` | The dashboard total now matches the transaction list for every time zone. ([DPD-917](…)) |
| `[Search] Debounce + cache search API` | Search results appear faster while you type. ([DPD-920](…)) |

Rules:

- Second person ("you can now…") for client and support; neutral ("Finance
  users can now…") for internal.
- Name the user role when only some users get it ("Admins can now…").
- Real numbers only when the ticket states them (`50,000 rows`); never "much
  faster" unless the ticket gives a number — then write "faster" alone.
- No team tags, endpoints, table names, service or code names, internal
  project names, sprint jargon ("spillover", "carry-over").
- Fixed lines describe the **now-correct** behaviour, not the bug's cause.
- Link format: `[KEY](https://<site>/browse/KEY)` from the site in step 0;
  offline → bare `KEY`.

## Ask (step 4)

Ask only when the ticket does not settle a fact. Up to 4 questions per round,
each with ready-made options; the BA can type their own via "Other".

| Gap | Question shape |
|-----|----------------|
| Visibility | "Is DPD-412 (new retry on payment webhook) visible to clients? (a) yes, mention it (b) internal only" |
| Benefit | "DPD-433 changes the invoice PDF layout. What do clients gain? (a) totals are easier to find (b) matches the new brand (c) internal only" |
| Known issue relevance | "Open bug DPD-950 (export fails over 30 s) has fixVersion 2.4. List it as a known issue? (a) yes, with 'retry the export' as the workaround (b) yes, no workaround (c) no, internal only" |
| User action | "DPD-940 changes the sign-in page. Must users do anything? (a) no (b) sign in again once (c) re-enable two-step sign-in" |

- Never ask about something the ticket already says.
- "Leave it" on a visibility or benefit question → the item goes to Internal
  and the report lists it as "held back, impact unclear".
- A workaround is written only when the ticket or the BA states it.

## Known issues (input to step 5)

```
project = <KEY> AND issuetype = Bug AND statusCategory != Done
  AND (fixVersion = "<version>" OR labels = known-issue)
```

For `--sprint` / dates (no version): `labels = known-issue` plus open bugs in
the same sprint. A bug without the label whose client impact is unclear →
ask (Known issue relevance above). Each known issue is one plain line: what
the user may notice, and the workaround if one is stated.

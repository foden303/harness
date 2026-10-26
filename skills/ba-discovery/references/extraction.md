# Extraction guide (steps 1-4)

How to turn raw discovery material into traced, classified requirements and a
short list of decision-shaped questions.

## Ingest (step 1)

| Input | How to read it | Citation form |
|-------|----------------|---------------|
| Pasted text | Split on newlines, number from 1 | `pasted:L12` |
| One file | `Read`; keep the original line numbers | `notes-2026-10-20.md:L12` |
| A directory | `Glob` for `*.md`, `*.txt`, `*.eml`, `*.vtt`, `*.srt`, `*.csv`; read each | `<relative path>:L12` |
| Confluence page URL | `getConfluencePage` (body as markdown); number paragraphs | `confluence:<page title>#p7` |

- Skip binaries, images, and files over 10,000 lines (list them as skipped and
  say why; offer to read a slice the BA names).
- Transcripts (`.vtt` / `.srt` / "Name: text" lines): the speaker is the label
  on the line. Emails: the speaker is the `From:` of that message; quoted
  replies (`>` lines) belong to the earlier sender, not the replier.
- No speaker on the line → use the document author if stated, else `unknown`
  and add the speaker to the gaps only when it changes the decision (for
  example two people with different authority).
- Print the source list before extracting:

  | # | Source | Kind | Lines | Status |
  | --- | --- | --- | --- | --- |
  | 1 | `discovery/kickoff-call.vtt` | transcript | 412 | read |
  | 2 | `discovery/logo.png` | image | — | skipped: not text |

- `<slug>`: from `--project` + the main topic in kebab-case
  (`dpd-self-serve-reporting`), else the folder or file name. Say the slug.

## Extract (step 2)

Read every source fully. Capture, per item, the verbatim quote and its citation.

| Bucket | What counts | What does not |
|--------|-------------|---------------|
| Stakeholders / roles | A named person or role and what they care about or decide | Names mentioned only in passing |
| Goals | An outcome the business wants ("cut support tickets by half") | A feature ("add an export button") |
| Problems | A pain today, ideally with a number ("40 requests a month") | A proposed solution |
| Requirements | Something the product must do or be | Brainstorm ideas the group rejected (those go to Decisions) |
| Business rules | A rule independent of screens ("refunds over $500 need a manager") | UI copy |
| Constraints | Deadline, budget, platform, regulation, existing system that must stay | Preferences |
| Decisions | "We agreed / we will / go with X", with who decided | Open debates (those are conflicts or questions) |
| Assumptions | Something the group treated as true without confirming | Facts with a source |
| Out of scope | "Not now", "phase 2", "we won't" | Silence (absence is not out of scope) |

Requirement row rules:

- One need per row, written as one line: `<role> can <do something>` or
  `The system <does something>`. Split "export and email it" into two rows.
- The quote is **verbatim** (trim with `…` only at the edges, never in the
  middle). Several sources saying the same thing → one row, all citations,
  first quote shown.
- No quote → not a requirement. Move it to **Open questions**:
  "Is <need> required? Nobody said so in the sources."
- Priority: take MoSCoW only when a speaker states it ("must have", "nice to
  have", "can wait"). Otherwise mark it as a gap for step 4.

## Classify + check (step 3)

| Type | Use when |
|------|----------|
| `functional` | A user or system action / behaviour |
| `non-functional` | Performance, availability, security, permissions, audit, i18n, a11y, compliance |
| `rule` | A business rule the system must enforce (also copied into Business rules) |
| `question` | The source itself is a question or a "maybe" ("could we also…?") |

**Conflicts.** Two citations that cannot both be true: different numbers,
different owners, in-scope vs out-of-scope, a decision later contradicted.
Record `C-n | topic | A says (quote + cite) | B says (quote + cite)`. A later
decision that explicitly replaces an earlier one is not a conflict; record
the decision and note what it replaced.

**Vague words.** Flag in requirements, rules and goals:

`fast`, `quick`, `slow`, `easy`, `simple`, `intuitive`, `user-friendly`,
`secure`, `robust`, `scalable`, `real-time`, `soon`, `large`, `many`, `etc.`,
`and so on`, `and more`, `as needed`, `if possible`, `flexible`,
`all relevant`, `appropriate`.

Each flag becomes a question asking for the measurable meaning (a number, a
list, a named role).

## Asking (step 4)

- `AskUserQuestion`, **up to 4 questions per round**, each with 2-4 ready-made
  options; the BA can always type their own.
- Order: conflicts first, then vague words, then missing priority, then other
  gaps (missing owner of a decision, unknown speaker authority).
- Ask only what changes the brief. Never ask something a source answered.
- If `AskUserQuestion` is unavailable, print the questions and stop.

Bad: "What is the performance requirement?"

Good: "R-4 says the report must be 'fast' (kickoff-call.vtt:L88, Lan). What
should it mean? (a) results in under 5 s for one month of data,
(b) under 30 s, (c) emailed when ready, no time limit."

Good (conflict): "C-1: Lan said exports go to Finance only (kickoff:L102); Minh
emailed that Support also needs them (email-2026-10-21.eml:L14). Who can
export? (a) Finance only, (b) Finance + Support, (c) every Admin role."

Good (priority): "R-2, R-5 and R-7 have no stated priority. Pick MoSCoW for
each." (one question per row when the options differ)

Answers fold into the brief with the citation `BA answer, <date>`. A BA answer
never replaces the original quote; it sits beside it. "Leave it" moves the gap
to **Open questions** with an owner (the person most likely to know, from the
stakeholder list) and keeps the row's priority as `ask <owner>`.

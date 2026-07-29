# Intake (Step 1)

Two questions, asked **before any work**, in one `AskUserQuestion` batch. Skip
whichever the flags already answered; never skip both silently and start mapping.

The rule this implements: a run that guesses where its output goes is a run whose
document lands somewhere the operator did not choose. Under
`.claude/rules/autonomous-confirmation-scope.md` this is case 1 territory — the
destination governs an external write, so it is asked, not inferred.

## Question 1 — Where does the output go?

| Option | Follow-up in the same batch | Resulting draft fields |
|---|---|---|
| Confluence page | the page link | `target: "confluence"`, `confluence_url` |
| A folder | the folder name | `target: "folder"`, `out_dir` |

Pre-answered by `--confluence <url>` or `--out <dir>`. If **both** flags are
passed, stop and ask which one — do not silently prefer one, the same way
`harness-story-author` refuses to choose between two templates.

Do not offer `./ocsf-mappings/` as a silent default when the operator picks
folder. Offer it as the *pre-filled suggestion* they can accept or replace. A
default that was never shown is a default that was never chosen.

## Question 2 — How is the log provided?

| Option | Follow-up in the same batch | `input.mode` |
|---|---|---|
| Paste the lines here | none — they paste next | `raw` |
| One file | the file path | `file` |
| A folder to scan | the folder path | `scan` |

Pre-answered by `--input <path>`: a file resolves to `file`, a directory to
`scan`. The operator can still add more sources later in Step 3 — this question
settles only how the **first** one arrives.

## Validate before working

Every answer is checked immediately. A failed check re-asks that one question; it
never degrades into a different mode.

| Answer | Check | On failure |
|---|---|---|
| Confluence link | `getConfluencePage` resolves it and the space is writable | Re-ask for the link. **Do not** fall back to folder output — that silently redirects the operator's document |
| Output folder | the parent path exists and is writable | Offer to create it, or re-ask |
| Input file | exists, is readable, is non-empty | Re-ask, saying which of the three failed |
| Input folder | exists and holds ≥1 readable file | Re-ask, listing what was actually found there |

The asymmetry is deliberate: a missing **output** folder is offered for creation,
because the operator naming a folder that does not exist yet is ordinary. A
missing **input** file is re-asked, because there is nothing to create — an empty
or absent input can only produce a fictional mapping.

## Also settle the source name

Needed for filenames, the page title and the state directory. Take it from the
positional argument if given; otherwise derive a slug from the input path or the
Confluence page title and **state the derivation** in the intake line so a wrong
guess is visible immediately:

```
source=azure-signin (from ./samples/azure-signin/)
```

This is a minor scope judgment, not a confirmation — derive and state it rather
than spending a question on it.

## Restate before continuing

One line, machine-greppable, so the resolved intake is auditable without reading
the conversation:

```
OCSF_MAP_INTAKE: target=folder out_dir=./ocsf-mappings input=scan:./samples/azure/ source=azure-signin
OCSF_MAP_INTAKE: target=confluence url=https://.../pages/123456/ input=file:./azure.ndjson source=azure-signin
```

Then continue to the pin gate without further confirmation. The operator has now
chosen the two things that decide where the work goes and what it reads; every
remaining decision is either evidence-driven or a rubric gap question.

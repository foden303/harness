# Self-review (Step 9)

Eight checks on the **rendered document**, run before the operator sees it.

The mapping rubric (Step 7) scores the *record*. This scores the *document*.
Rendering is a separate chance to go wrong: a table row that exists on the page
but not in the record, a header count that contradicts the table under it, a PII
value printed into a page that will be read far more widely than the log file it
came from. None of those are caught by a green rubric.

Report the result at the publish gate either way. "0 findings across 8 checks" is
information the operator can act on; saying nothing is indistinguishable from not
having looked.

## The 8 checks

### 1. Row provenance

Every row in the **Mapping** table traces to an entry in `record.fields`, matched
on `raw_path` + `ocsf_attribute`. A row with no matching record entry was invented
during rendering.

*Fails when*: prose in the conversation ("we should probably also map X") leaked
into the table without going through the record.

### 2. Count agreement

The header line's counts match what the tables actually contain: mapped-field
count = Mapping rows, and the source/record counts = the Input profile table.

*Fails when*: the record was edited after the header was drafted. The header is
what a skim-reader trusts, so a stale count misinforms exactly the reader least
likely to check.

### 3. Section completeness

All eight sections are present, and an empty one says so explicitly ("none —
every required attribute is mapped") rather than being omitted.

*Fails when*: a section is dropped because it had nothing in it. A missing
section reads as "not checked"; an explicit "none" reads as "checked, and the
answer is none".

### 4. PII redaction

Every `fields` entry with `pii: true` has its sample value rendered as a shape
(`a***@example.com`, `10.x.x.x`) and not as the literal observed value.

*Fails when*: a real address, token or username reaches the document. This is the
one check whose failure is not recoverable after publishing — a Confluence page is
seen by more people than the log file was, and the page keeps a version history.

### 5. Open questions carried

Every `open_questions[]` entry with an empty `answer` appears in the Open
questions section, with its gate and its `why`.

*Fails when*: an unanswered question is dropped during rendering, turning "we do
not know this yet" into an apparently complete mapping.

### 6. Enum leftovers surfaced

Every `enums[]` entry's `unmapped_values` appears in the document.

*Fails when*: the value map is rendered and the leftovers are not — the failure
mode `enum-values-mapped` exists to prevent, reintroduced one layer later. The
leftover list is the most operationally useful part of the document; it is the set
of events that will not classify.

### 7. Reproducibility block

The Reproducing section carries the pin version, the pin's `fetched_at`, every
source `ref` with its `sha256`, and the exact command.

*Fails when*: any of the four is missing. A mapping that cannot be re-derived
cannot be reviewed a month later, and the pin version is what tells a future
reader whether the document still describes the schema in use.

### 8. Destination agreement

The destination named in the document header matches the intake resolved in
Step 1 — the same folder path, or the same Confluence parent.

*Fails when*: the document was rendered before an intake re-ask changed the
destination. Catches the stale-render case where the operator corrected the target
and the header still names the old one.

## Handling findings

- **Fix what is mechanically fixable** — a stale count, a dropped section, an
  unredacted PII value — then re-run the affected check.
- **Never fix by deletion.** Removing the row that failed check 1, or the section
  that failed check 3, makes the check pass and the document worse.
- **Report what you cannot fix.** A finding that needs an operator decision (a PII
  field they may want shown in full, a source whose `sha256` was never captured)
  travels to the publish gate as a finding, not as a silent omission.

Findings are shown at the gate; they do not block publication on their own. The
operator decides whether a finding matters — the skill's job is to make sure they
see it before they approve, not to decide for them.

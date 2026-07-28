# Mapping rubric (Step 7)

Score every mapping against these 12 gates. A **blocker** failure becomes one
decision-shaped question to the operator and keeps the record at `needs-input`;
an **advisory** failure is reported in the document and never blocks.

The rubric exists because a wrong OCSF mapping does not look wrong. It looks like
a tidy table. These gates are the places where tidy-but-wrong hides.

## The gates

| id | Severity | Passes when |
|----|----------|-------------|
| `pin-available` | blocker | `ocsf-schema-pin.sh status` reports `in-sync` for the target version |
| `format-identified` | blocker | Every source has a detected format that is not `unknown`, or the operator supplied it |
| `parse-rate-acceptable` | blocker | Every source parses ≥90%, or the shortfall is explained and accepted |
| `samples-sufficient` | blocker | ≥20 records, or fewer with the thin-evidence limitation stated in the document |
| `class-justified` | blocker | `ocsf_class.why` cites what in the records makes this the right class, not the source's name |
| `timestamp-mapped` | blocker | `time` is mapped, with the source field **and** its unit/format (epoch s / epoch ms / ISO8601 / vendor-local) |
| `required-attrs-covered` | blocker | Every `required` attribute of the class — **including those inherited via `extends`** — is either in `fields` or in `missing_required` with a reason |
| `no-invented-fields` | blocker | Every `fields` entry cites a `raw_path` and a `sample_value` observed in the input |
| `unmapped-declared` | blocker | Every inventory field is either mapped or in `unmapped_raw` with a disposition |
| `enum-values-mapped` | blocker | Every enum attribute has a value map; raw values with no OCSF equivalent are in `unmapped_values`, not folded into `Other` |
| `type-coercion-stated` | advisory | Each mapping whose raw type differs from the OCSF type names its transform |
| `pii-flagged` | advisory | Fields carrying email / IP / username / token / device id are flagged |

## Scoring rules

- **Map first, then score.** Fill everything the samples support before scoring. A
  gate fails when the evidence is genuinely absent — not because the mapping was
  left half-done.
- **Never invent to pass.** An unmapped required attribute stays in
  `missing_required`. Do not satisfy `required-attrs-covered` by mapping a field
  that looks close enough; that is the failure mode the gate exists to catch, and
  the record helper will reject the entry anyway if it has no observed value.
- **`n-a` needs a note.** A gate that truly does not apply is `n-a` **with a
  note**; the record helper rejects a noteless `n-a`.
- **Confidence is evidence, not conviction.** `high` requires the field present in
  most records with a consistent type. A field seen 3 times in 500 records is
  `low` even when the mapping is obviously correct.

## The three failures worth naming

These are the ones that survive review because the table looks complete.

### Timestamp unit drift

`time` mapped from a field carrying epoch **seconds** while the pipeline assumes
**milliseconds** produces events dated 1970 — or 55000 AD. The mapping table shows
`created_at → time` and looks perfectly correct.

`timestamp-mapped` therefore requires the unit, not just the field. When the
samples cannot settle it (a 10-digit number is ambiguous across sources), that is
an open question, not a guess.

### Enum silently collapsed

A raw `resultType` with 40 distinct values mapped onto `activity_id` by handling
the 4 common ones and sending the rest to `Other`. Every alert built on the
remaining 36 values quietly disappears.

`enum-values-mapped` requires the leftover values to be listed. A long
`unmapped_values` array is a legitimate outcome — it tells the implementer where
the gaps are instead of hiding them behind a default.

### Same name, different meaning

Raw `user` mapped to OCSF `user.name` when the raw field carries a display name
and OCSF expects the account identifier. Both are strings, both are called
"user", and correlation against every other source silently fails.

There is no gate that catches this mechanically. It is why `sample_value` is
mandatory in every entry: a reviewer reading `"Ngô Văn A" → user.name` spots it in
a second, and reading `properties.user → user.name` never does.

## Question quality bar

Questions go to an operator mid-run. Ask via `AskUserQuestion` so they pick
rather than compose. Each question must be:

1. **Answerable with a pick**, not an essay.
2. **Specific**, quoting the raw path and the observed values.
3. **Decision-shaped**, with the plausible options as the choices.
4. **Paired with a `why`** — one line on what the mapping cannot promise until it
   is answered.

Bad: "How should the timestamp be handled?"

Good: "`properties.createdDateTime` is a 13-digit number (`1784605725123`). Treat
it as (a) epoch milliseconds, (b) epoch microseconds, or (c) ask the vendor? The
samples cannot distinguish (a) from (b), and getting it wrong dates every event
wrongly by a factor of 1000."

Ask in batches by gate, fold every answer back into the record, then re-score.
Stop when readiness is `ready`, or when the operator says "publish as-is" — in
which case the still-unanswered items move into the document's **Open questions**
section as unanswered `open_questions[]` entries, visible on the published page,
rather than being resolved by guesswork.

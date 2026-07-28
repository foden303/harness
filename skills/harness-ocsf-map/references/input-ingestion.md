# Input ingestion (Steps 3-4)

Three input modes, one field inventory. The operator can mix modes in a single
run — paste a few lines to start, then point at a directory once the shape looks
right.

## Mode 1 — raw (pasted lines)

The operator pastes log lines into the conversation. Record `ref: "pasted"` and
the line count.

Pasted input is the thinnest evidence there is: it is usually a handful of lines
someone picked because they looked representative. Selection bias is the risk —
hand-picked lines under-represent the error and empty cases. Say so when the
sample is under ~20 lines, and cap `confidence` at `medium` for any field whose
`occurrence` is below 5.

## Mode 2 — file (one named file)

Read the file, record its path and `sha256`. For a file over a few thousand
lines, sample rather than read it whole: first 200 lines, last 200, and 200 from
the middle. Record `lines_total` as the true total, not the sampled count — the
parse rate must be honest about what was actually examined, so state the sampling
in the document.

## Mode 3 — scan (a directory, automatically)

Walk the directory, group files by detected format, and report the grouping
before ingesting:

```
scan ./logs/
  ndjson    12 files   ~48k lines
  syslog     3 files   ~9k lines
  unknown    1 file    (binary? skipped)
```

Files of **different formats are different sources** — do not merge them into one
inventory silently. Ask which group to map, or map the largest group and say what
was left out. Skip anything binary or over a size threshold, and list what was
skipped; a silently skipped file reads as "nothing there".

## Format detection

Detect from content, never from the filename extension:

| Format | Signal |
|---|---|
| `json` | The whole payload parses as one JSON value |
| `ndjson` | Each line parses as an independent JSON object |
| `syslog-rfc5424` | `<PRI>1 ` version marker after the priority |
| `syslog-rfc3164` | `<PRI>` followed by a `Mmm dd hh:mm:ss` timestamp |
| `cef` | `CEF:0\|` header with pipe-delimited fields |
| `leef` | `LEEF:1.0\|` or `LEEF:2.0\|` header |
| `kv` | Repeated `key=value` pairs, no JSON braces |
| `csv` | Stable delimiter count across lines, plausible header row |
| `w3c` | `#Fields:` directive header |
| `unknown` | None of the above matched |

`unknown` is a legitimate outcome. Record it, show a few lines, and ask the
operator for the format rather than guessing a parser — a wrong parser produces a
field inventory that looks fine and is entirely fictional.

## Parse-rate accounting

Record `lines_total` and `lines_parsed` per source and report the rate. It is the
single best signal that detection went wrong:

- **100%** — clean.
- **90-99%** — usually a multi-line record or a truncated tail. Show an unparsed
  line; often it is a stack trace or a continuation line.
- **below 90%** — treat detection as failed. Do not build an inventory from the
  fraction that parsed; a 60%-parsed file usually means two formats are
  interleaved in one stream.

The gate `parse-rate-acceptable` fails below 90% and asks the operator, rather
than mapping the parseable minority and presenting it as the source's shape.

## The field inventory

Flatten nested structures to dotted paths (`properties.userPrincipalName`), and
index array elements as `[]` rather than by position (`resources[].id`) — position
is an artefact of one sample, not part of the shape.

Per field, record:

| Column | Why it matters |
|---|---|
| `raw_path` | The mapping key |
| observed types | A field that is sometimes a string and sometimes an object needs a transform, or is two fields |
| `occurrence` | Present in 3 of 500 records is thin evidence — it caps confidence |
| distinct sample values | Feeds the enum mapping in Step 6 |
| PII flag | Anything that looks like an email, IP, username, token, or device id |

Cap the inventory at the fields that actually occur. A field defined in the
vendor's documentation but absent from every sample is **not** in the inventory —
if it matters, it belongs in the open questions as "the docs promise X; no sample
carries it".

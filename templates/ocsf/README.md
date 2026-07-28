# Pinned OCSF schemas

`harness-ocsf-map` maps raw log fields onto an OCSF schema. That schema is a
**file in this repo**, never a live fetch during a mapping run — two runs over the
same log samples must produce the same mapping, and a mapping written into a
Confluence page has to stay reproducible after the upstream schema moves on.

Nothing is pinned by default. This directory is empty until someone runs the
fetch, and an unpinned version is `not-configured`, not an error.

## Source

[`github.com/ocsf/ocsf-schema`](https://github.com/ocsf/ocsf-schema), pinned by
git tag. The tag naming changed partway through the project's history — 1.3.0 and
newer are bare (`1.8.0`), 1.2.0 and older carry a `v` (`v1.2.0`) — and the fetch
tries both, so callers do not need to know which era a version belongs to.

The repository holds the **authored** form, not a resolved bundle: a class
declares `extends` and inherits attributes at read time. That is why the pin
keeps `base_event.json` beside `classes/`, and why `manifest.json` records
`inheritance_resolved: false`. A consumer resolving required attributes must walk
the `extends` chain rather than trusting a class file alone.

## Layout

One directory per pinned version:

```
templates/ocsf/<version>/
  manifest.json      ocsf-pin.v1 — version, source repo + tag, fetch time, per-file sha256, counts
  version.json       the version the source tree itself declares
  categories.json    category name -> uid
  dictionary.json    the shared attribute dictionary
  base_event.json    attributes every class inherits
  classes/<class_uid>-<name>.json   one file per event class
  objects/<name>.json               one file per object type
  profiles/<name>.json              one file per profile
```

In the source tree a class carries a **category-local** `uid` (authentication is
`uid: 2` inside category `iam`). The number everyone actually quotes is the
`class_uid`: `category_uid * 1000 + uid`, so authentication is 3002. The fetch
computes it and names the file `3002-authentication.json`, so the pin is greppable
by the number that appears in tickets and alerts rather than by a local ordinal.

A class the tree does not let us number — an abstract parent such as `_entity`,
which has no category — is still pinned, under its plain name, and the count of
those is reported so it is visible rather than silent.

## Pinning a version

```bash
# Normal case — downloads the tagged source tree from GitHub
./scripts/ocsf-schema-pin.sh fetch --version 1.8.0

# No egress on this machine: fetch the tag elsewhere, then install it
./scripts/ocsf-schema-pin.sh fetch --version 1.8.0 --from-file ./ocsf-schema-1.8.0.tar.gz
./scripts/ocsf-schema-pin.sh fetch --version 1.8.0 --from-dir  ./ocsf-schema

# A mirror
./scripts/ocsf-schema-pin.sh fetch --version 1.8.0 --url https://example.internal/ocsf-1.8.0.tar.gz
```

`fetch` never destroys a working pin. It builds into a staging directory and swaps
only once the tree has been validated and the classes counted, so a wrong
`--from-dir`, a tag whose `version.json` disagrees with `--version`, an empty
`events/`, or one malformed JSON file anywhere in the tree all leave the existing
pin exactly as it was.

## Checking a pin

```bash
./scripts/ocsf-schema-pin.sh status --version 1.8.0 --json   # cheap, no hashing
./scripts/ocsf-schema-pin.sh verify --version 1.8.0 --json   # re-hashes every file
```

Both emit `ocsf-pin.v1` and follow the tri-state contract in
[`.claude/rules/active-watching-test-policy.md`](../../.claude/rules/active-watching-test-policy.md):

| State | `reason` | `healthy` | Exit | Meaning |
|---|---|---|---|---|
| Not pinned | `not-configured` | `true` | 0 | Nobody has pinned this version. Not a failure — do not warn. |
| Pinned, hashes match | `in-sync` | `true` | 0 | Safe to map against. |
| Manifest unreadable, file missing, or checksum mismatch | `corrupted` | `false` | 1 | Someone hand-edited the pin or the write was interrupted. Re-fetch. |

A hand-edited pin is the failure worth catching: it silently changes what every
future mapping is scored against. `verify` is what catches it, so run it in CI
rather than only `status`.

## Upgrading to a new OCSF version

Pin the new version **alongside** the old one — do not overwrite. Both directories
coexist, `--ocsf-version` selects which one a run maps against, and the diff
between two pinned trees is the actual upgrade impact on your mappings.
Delete an old pin only once no document references it.

#!/usr/bin/env bash
# ocsf-schema-pin.sh
# Manages the pinned OCSF schema that harness-ocsf-map maps against.
#
# The pin is the SSOT for mapping: a run must produce the same mapping for the
# same input, so the schema is a file in the repo, never a live fetch during a
# mapping run. Only `fetch` touches the network, and only when a human runs it.
#
# Source of truth is the schema repository, pinned by git tag:
#   https://github.com/ocsf/ocsf-schema
# That is the authored form — class inheritance (`extends`) is NOT resolved, so a
# consumer reads base_event.json alongside the class. The upside is that a pin is
# a git tag someone can diff, not a server response that changed silently.
#
# Subcommands:
#   status   Report the pin state as ocsf-pin.v1 JSON (tri-state, never fetches)
#   fetch    Download a tagged schema tree and write the pin (NETWORK)
#   verify   Re-hash the pinned files and compare against the manifest
#
# Tri-state (.claude/rules/active-watching-test-policy.md):
#   not-configured  no pin for this version yet -> healthy=true,  exit 0
#   corrupted       pin present but unreadable/mismatched -> healthy=false, exit 1
#   in-sync         pin present and hashes match -> healthy=true,  exit 0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OCSF_REPO="https://github.com/ocsf/ocsf-schema"
OCSF_VERSION="1.8.0"
PIN_ROOT=""
SOURCE_URL=""
FROM_FILE=""
FROM_DIR=""
JSON_OUTPUT=0

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/ocsf-schema-pin.sh status  [--version X.Y.Z] [--json]
  scripts/ocsf-schema-pin.sh verify  [--version X.Y.Z] [--json]
  scripts/ocsf-schema-pin.sh fetch   [--version X.Y.Z]
                                     [--url URL | --from-file TARBALL | --from-dir CHECKOUT]

fetch performs external network egress and is intended to be run by a human.
It downloads the tagged source tree from https://github.com/ocsf/ocsf-schema.

On a machine without egress, clone or download the tag elsewhere, then:
  --from-file ./ocsf-schema-1.8.0.tar.gz    install from a release tarball
  --from-dir  ./ocsf-schema                 install from an extracted checkout
EOF
  exit 1
}

SUBCOMMAND="${1:-}"
[ -n "$SUBCOMMAND" ] || usage
shift || true

while [ $# -gt 0 ]; do
  case "$1" in
    --version)   OCSF_VERSION="${2:-}"; shift 2 ;;
    --url)       SOURCE_URL="${2:-}";   shift 2 ;;
    --from-file) FROM_FILE="${2:-}";    shift 2 ;;
    --from-dir)  FROM_DIR="${2:-}";     shift 2 ;;
    --json)      JSON_OUTPUT=1;         shift   ;;
    -h|--help)   usage ;;
    *)           usage ;;
  esac
done

[ -n "$OCSF_VERSION" ] || usage
PIN_ROOT="$PLUGIN_ROOT/templates/ocsf/$OCSF_VERSION"
MANIFEST="$PIN_ROOT/manifest.json"

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

emit_state() {
  # emit_state <healthy> <reason> <exit_code> <human_message>
  local healthy="$1" reason="$2" code="$3" message="$4"
  if [ "$JSON_OUTPUT" -eq 1 ]; then
    printf '{"schema_version":"ocsf-pin.v1","version":"%s","healthy":%s,"reason":"%s","pin_root":"%s","message":"%s"}\n' \
      "$OCSF_VERSION" "$healthy" "$reason" "${PIN_ROOT#"$PLUGIN_ROOT"/}" "$message"
  else
    echo "$message"
  fi
  exit "$code"
}

# ================================
# status
# ================================
cmd_status() {
  if [ ! -f "$MANIFEST" ]; then
    emit_state true not-configured 0 \
      "OCSF $OCSF_VERSION is not pinned yet. Run: scripts/ocsf-schema-pin.sh fetch --version $OCSF_VERSION"
  fi
  if ! node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$MANIFEST" 2>/dev/null; then
    emit_state false corrupted 1 "manifest.json is not valid JSON: $MANIFEST"
  fi
  local classes
  classes=$(node -e '
    const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    process.stdout.write(String((m.counts && m.counts.classes) || 0));
  ' "$MANIFEST")
  emit_state true in-sync 0 "OCSF $OCSF_VERSION pinned ($classes classes) at ${PIN_ROOT#"$PLUGIN_ROOT"/}"
}

# ================================
# verify
# ================================
cmd_verify() {
  [ -f "$MANIFEST" ] || emit_state true not-configured 0 \
    "OCSF $OCSF_VERSION is not pinned yet — nothing to verify."

  local files bad=0
  files=$(node -e '
    const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    for (const [rel, sha] of Object.entries(m.files || {})) console.log(rel + "\t" + sha);
  ' "$MANIFEST")

  while IFS=$'\t' read -r rel expected; do
    [ -n "$rel" ] || continue
    local target="$PIN_ROOT/$rel"
    if [ ! -f "$target" ]; then
      echo "  ❌ missing: $rel"
      bad=$((bad + 1))
      continue
    fi
    local actual
    actual="$(sha256_of "$target")"
    if [ "$actual" != "$expected" ]; then
      echo "  ❌ checksum mismatch: $rel"
      bad=$((bad + 1))
    fi
  done <<<"$files"

  if [ "$bad" -ne 0 ]; then
    emit_state false corrupted 1 "$bad pinned file(s) failed verification for OCSF $OCSF_VERSION"
  fi
  emit_state true in-sync 0 "OCSF $OCSF_VERSION pin verified — all checksums match"
}

# ================================
# fetch
# ================================
WORKDIR=""
cleanup_workdir() { [ -n "$WORKDIR" ] && rm -rf "$WORKDIR"; return 0; }

# The tag naming changed partway through the project's history: 1.3.0 and newer
# are bare, 1.2.0 and older carry a `v`. Try bare first, then the v-prefixed form,
# so an older version still pins without the caller knowing the convention.
download_tarball() {
  local dest="$1"
  local -a candidates=()
  if [ -n "$SOURCE_URL" ]; then
    candidates=("$SOURCE_URL")
  else
    candidates=(
      "$OCSF_REPO/archive/refs/tags/$OCSF_VERSION.tar.gz"
      "$OCSF_REPO/archive/refs/tags/v$OCSF_VERSION.tar.gz"
    )
  fi

  local url
  for url in "${candidates[@]}"; do
    echo "🌐 $url"
    if curl -sSfL -m 180 -o "$dest" "$url"; then
      return 0
    fi
    echo "   not found, trying next" >&2
  done
  return 1
}

cmd_fetch() {
  WORKDIR="$(mktemp -d)"
  trap cleanup_workdir EXIT

  local checkout=""

  if [ -n "$FROM_DIR" ]; then
    [ -d "$FROM_DIR" ] || { echo "❌ --from-dir not found: $FROM_DIR" >&2; exit 1; }
    checkout="$FROM_DIR"
    echo "📂 Installing from checkout $FROM_DIR"
  else
    local tarball="$WORKDIR/schema.tar.gz"
    if [ -n "$FROM_FILE" ]; then
      [ -f "$FROM_FILE" ] || { echo "❌ --from-file not found: $FROM_FILE" >&2; exit 1; }
      cp "$FROM_FILE" "$tarball"
      echo "📦 Installing from tarball $FROM_FILE"
    else
      echo "🌐 Downloading OCSF $OCSF_VERSION from $OCSF_REPO"
      if ! download_tarball "$tarball"; then
        cat >&2 <<EOF
❌ Download failed for every candidate tag URL.

If this ran inside a sandbox, external egress needs human approval — run this
script yourself from a normal shell. Otherwise the tag may not exist; check
$OCSF_REPO/tags and pass the right --version, or install a
tree you already have:

  scripts/ocsf-schema-pin.sh fetch --version $OCSF_VERSION --from-dir ./ocsf-schema
EOF
        exit 1
      fi
    fi

    mkdir -p "$WORKDIR/extract"
    tar -xzf "$tarball" -C "$WORKDIR/extract"
    # A GitHub source tarball wraps everything in one top-level directory.
    checkout="$(find "$WORKDIR/extract" -mindepth 1 -maxdepth 1 -type d | head -1)"
    [ -n "$checkout" ] || { echo "❌ tarball contained no directory" >&2; exit 1; }
  fi

  node - "$checkout" "$PIN_ROOT" "$OCSF_VERSION" "$OCSF_REPO" <<'NODE'
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const [checkout, pinRoot, version, repo] = process.argv.slice(2);

// Name the offending file. A bare SyntaxError from a tree of ~1500 JSON files
// tells the operator nothing about which one to look at.
const readJson = (p) => {
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch (e) {
    console.error(`❌ Malformed JSON in the source tree: ${path.relative(checkout, p) || p}`);
    console.error(`   ${e.message}`);
    process.exit(1);
  }
};
const exists = (p) => fs.existsSync(p);

// Validate the tree BEFORE touching an existing pin, so a wrong --from-dir
// leaves the current pin intact instead of half-replacing it.
for (const required of ['categories.json', 'dictionary.json', 'events']) {
  if (!exists(path.join(checkout, required))) {
    console.error(`❌ Not an OCSF schema tree: missing ${required} in ${checkout}`);
    console.error('   Expected the layout of https://github.com/ocsf/ocsf-schema');
    process.exit(1);
  }
}

// The tag is what we asked for, but version.json is what the tree actually says.
// A mismatch means the wrong tag was downloaded or the wrong directory passed.
let treeVersion = null;
if (exists(path.join(checkout, 'version.json'))) {
  try { treeVersion = readJson(path.join(checkout, 'version.json')).version || null; } catch { /* tolerated */ }
}
if (treeVersion && treeVersion !== version) {
  console.error(`❌ Version mismatch: asked for ${version}, tree declares ${treeVersion}`);
  console.error('   Re-run with --version ' + treeVersion + ', or point at the right tag.');
  process.exit(1);
}

const categories = readJson(path.join(checkout, 'categories.json'));
// categories.json nests the real map under .attributes
const categoryUids = {};
for (const [name, def] of Object.entries(categories.attributes || categories)) {
  if (def && typeof def.uid === 'number') categoryUids[name] = def.uid;
}

const walkJson = (dir) => {
  const out = [];
  if (!exists(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walkJson(full));
    else if (entry.name.endsWith('.json')) out.push(full);
  }
  return out;
};

// Build into a staging directory and swap only once the content is known good.
// Writing straight into pinRoot would destroy a working pin before we discover
// the new tree is empty or malformed — the failure that leaves an operator with
// neither the old pin nor a new one.
const staging = `${pinRoot}.staging-${process.pid}`;
fs.rmSync(staging, { recursive: true, force: true });
fs.mkdirSync(staging, { recursive: true });

// Backstop for every exit path, including a malformed JSON file throwing out of
// readJson mid-build. After a successful rename the staging path is gone, so
// this is a no-op on the happy path.
process.on('exit', () => {
  try { fs.rmSync(staging, { recursive: true, force: true }); } catch { /* nothing to clean */ }
});

const abort = (msg) => {
  console.error(msg);
  process.exit(1);
};

const files = {};
const write = (rel, data) => {
  const target = path.join(staging, rel);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  const body = JSON.stringify(data, null, 2) + '\n';
  fs.writeFileSync(target, body);
  files[rel.split(path.sep).join('/')] = crypto.createHash('sha256').update(body).digest('hex');
};

const slug = (name) => String(name).replace(/[^A-Za-z0-9._-]/g, '_');

// Event classes. In the authored form a class carries a category-local `uid`;
// the class_uid every consumer actually uses is category_uid * 1000 + uid.
// Computing it here means the pin is greppable by the number people quote
// (3002-authentication.json) rather than by a local ordinal.
let classCount = 0;
let unresolved = 0;
for (const file of walkJson(path.join(checkout, 'events'))) {
  const def = readJson(file);
  const name = def.name || path.basename(file, '.json');

  if (name === 'base_event' || path.basename(file) === 'base_event.json') {
    write('base_event.json', def);
    continue;
  }

  const categoryUid = categoryUids[def.category];
  let base;
  if (typeof def.uid === 'number' && typeof categoryUid === 'number') {
    base = `${categoryUid * 1000 + def.uid}-${slug(name)}`;
  } else {
    // A class the tree does not let us number (no category, or an abstract
    // parent like `_entity`) still gets pinned — under its name, and counted so
    // the operator can see it happened.
    base = slug(name);
    unresolved += 1;
  }
  write(path.join('classes', `${base}.json`), def);
  classCount += 1;
}

if (classCount === 0) {
  abort('❌ No event classes found under events/ — refusing to write an empty pin.');
}

let objectCount = 0;
for (const file of walkJson(path.join(checkout, 'objects'))) {
  const def = readJson(file);
  write(path.join('objects', `${slug(def.name || path.basename(file, '.json'))}.json`), def);
  objectCount += 1;
}

let profileCount = 0;
for (const file of walkJson(path.join(checkout, 'profiles'))) {
  const def = readJson(file);
  write(path.join('profiles', `${slug(def.name || path.basename(file, '.json'))}.json`), def);
  profileCount += 1;
}

for (const top of ['categories.json', 'dictionary.json', 'version.json']) {
  if (exists(path.join(checkout, top))) write(top, readJson(path.join(checkout, top)));
}

const manifest = {
  schema_version: 'ocsf-pin.v1',
  ocsf_version: version,
  source_repo: repo,
  source_tag: version,
  inheritance_resolved: false,
  fetched_at: new Date().toISOString(),
  counts: { classes: classCount, objects: objectCount, profiles: profileCount },
  files,
};
fs.writeFileSync(path.join(staging, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');

// Everything is written and counted — only now replace the live pin.
fs.rmSync(pinRoot, { recursive: true, force: true });
fs.mkdirSync(path.dirname(pinRoot), { recursive: true });
fs.renameSync(staging, pinRoot);

console.log(`✅ Pinned OCSF ${version} from ${repo}`);
console.log(`   ${classCount} classes, ${objectCount} objects, ${profileCount} profiles`);
if (unresolved > 0) {
  console.log(`   ${unresolved} class(es) had no resolvable class_uid — pinned under their name`);
}
console.log(`   ${pinRoot}`);
console.log('   Note: `extends` is not resolved — read base_event.json alongside a class.');
NODE
}

case "$SUBCOMMAND" in
  status) cmd_status ;;
  verify) cmd_verify ;;
  fetch)  cmd_fetch  ;;
  *)      usage ;;
esac

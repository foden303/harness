#!/usr/bin/env bash
# build-host-plugin-dist.sh
# Build host-specific install packages with normalized in-package manifest paths.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

HOST=""
OUT_DIR=""

usage() {
  cat <<'EOF'
Usage: build-host-plugin-dist.sh --host claude --out <directory>

Generates a host-specific distribution package. Output directory is created or
replaced. Generated packages must not reference sibling paths with '..'.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --host)
      HOST="${2:-}"
      shift 2
      ;;
    --out)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [ -z "$HOST" ] || [ -z "$OUT_DIR" ]; then
  usage
  exit 2
fi

case "$HOST" in
  claude) ;;
  *)
    echo "invalid --host: $HOST" >&2
    exit 2
    ;;
esac

if [ -e "$OUT_DIR" ]; then
  rm -rf "$OUT_DIR"
fi
mkdir -p "$OUT_DIR"

copy_tree() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
}

copy_runtime_helpers() {
  local dst_root="$1"
  mkdir -p "${dst_root}/scripts"
  for script in \
    build-host-plugin-dist.sh \
    calculate-effort.sh \
    model-routing.sh \
    resolve-impl-backend.sh \
    set-impl-backend.sh; do
    if [ -f "${ROOT_DIR}/scripts/${script}" ]; then
      cp "${ROOT_DIR}/scripts/${script}" "${dst_root}/scripts/${script}"
      chmod +x "${dst_root}/scripts/${script}" 2>/dev/null || true
    fi
  done
}

copy_hook_script_closure() {
  local dst_root="$1"
  local hooks_file="$2"
  local rel_path

  [ -f "${ROOT_DIR}/${hooks_file}" ] || return 0

  while IFS= read -r rel_path; do
    [ -n "$rel_path" ] || continue
    if [ -f "${ROOT_DIR}/${rel_path}" ]; then
      mkdir -p "$(dirname "${dst_root}/${rel_path}")"
      cp "${ROOT_DIR}/${rel_path}" "${dst_root}/${rel_path}"
      chmod +x "${dst_root}/${rel_path}" 2>/dev/null || true
    fi
  done < <(grep -Eoh 'scripts/[A-Za-z0-9_./-]+\.sh' "${ROOT_DIR}/${hooks_file}" | sort -u)
}

write_normalized_manifest() {
  local host="$1"
  local src_manifest="$2"
  local dst_manifest="$3"
  node - "$host" "$src_manifest" "$dst_manifest" <<'NODE'
const fs = require("fs");
const [host, srcPath, dstPath] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(srcPath, "utf8"));

if (host === "claude") {
  manifest.skills = ["./skills/"];
  if (manifest.outputStyles) {
    manifest.outputStyles = "./output-styles/";
  }
}

const serialized = JSON.stringify(manifest, null, 2) + "\n";
if (serialized.includes('"../')) {
  console.error("normalized manifest still contains .. paths");
  process.exit(1);
}
fs.mkdirSync(require("path").dirname(dstPath), { recursive: true });
fs.writeFileSync(dstPath, serialized);
NODE
}

build_claude() {
  copy_tree "${ROOT_DIR}/.claude-plugin" "${OUT_DIR}/.claude-plugin"
  write_normalized_manifest "claude" "${ROOT_DIR}/.claude-plugin/plugin.json" "${OUT_DIR}/.claude-plugin/plugin.json"
  copy_tree "${ROOT_DIR}/skills" "${OUT_DIR}/skills"
  copy_tree "${ROOT_DIR}/agents" "${OUT_DIR}/agents"
  copy_tree "${ROOT_DIR}/hooks" "${OUT_DIR}/hooks"
  copy_hook_script_closure "${OUT_DIR}" ".claude-plugin/hooks.json"
  copy_hook_script_closure "${OUT_DIR}" "hooks/hooks.json"
  copy_tree "${ROOT_DIR}/output-styles" "${OUT_DIR}/output-styles"
  mkdir -p "${OUT_DIR}/bin"
  for bin in harness harness-darwin-amd64 harness-darwin-arm64 harness-linux-amd64 harness-windows-amd64.exe; do
    if [ -f "${ROOT_DIR}/bin/${bin}" ]; then
      cp "${ROOT_DIR}/bin/${bin}" "${OUT_DIR}/bin/${bin}"
    fi
  done
  cp "${ROOT_DIR}/VERSION" "${OUT_DIR}/VERSION"
}


case "$HOST" in
  claude) build_claude ;;
esac

echo "built ${HOST} dist at ${OUT_DIR}" >&2

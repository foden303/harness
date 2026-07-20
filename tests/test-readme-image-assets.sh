#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT_DIR" <<'PY'
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

root = Path(sys.argv[1])
files = [root / "README.md"]

# Contract: README diagrams are mermaid fences, not binary assets.
# Raster/vector diagram files rot silently — the pre-1.0 hero PNG and logo were
# deleted while README still pointed at them, and this test passed anyway
# because it only checked that the path string was present. Local image
# references are now banned outright; only remote badges are allowed.
blocked = {
    "docs/images/hokage/hokage-hero.jpg",
    "assets/readme-visuals-ja/safety-shield.svg",
}

class ImageParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.images = []

    def handle_starttag(self, tag, attrs):
        if tag == "img":
            self.images.append(dict(attrs))

errors = []
for file in files:
    parser = ImageParser()
    parser.feed(file.read_text())
    for image in parser.images:
        src = image.get("src", "")
        if not src:
            continue
        if src.startswith("http://") or src.startswith("https://"):
            continue
        if src in blocked:
            errors.append(f"{file.name}: blocked image still referenced: {src}")
        # No local image may be referenced at all, and if one is, it must at
        # least exist — both failures are reported so a rename cannot hide.
        errors.append(f"{file.name}: local image reference is banned, use a mermaid fence: {src}")
        if not (root / src).exists():
            errors.append(f"{file.name}: missing local image: {src}")

    # Markdown-syntax images (![alt](path)) bypass the HTML parser above.
    for match in re.finditer(r"!\[[^\]]*\]\(([^)]+)\)", file.read_text()):
        src = match.group(1).strip()
        if src.startswith("http://") or src.startswith("https://"):
            continue
        errors.append(f"{file.name}: local image reference is banned, use a mermaid fence: {src}")

text = "\n".join(file.read_text() for file in files)
for file in files:
    body = file.read_text()
    if "```mermaid" not in body:
        errors.append(f"{file.name}: no mermaid diagram — the operating loop must be drawn in markdown")
    for path in re.findall(r"docs/images/\S+", body):
        errors.append(f"{file.name}: reference to removed docs/images tree: {path}")

if "docs/images/hokage/hokage-hero.jpg" in text:
    errors.append("obsolete hero path still present")
if "Hokage" in text:
    errors.append("internal code-name still present in README surface")

if errors:
    for error in errors:
        print(f"test-readme-image-assets: FAIL: {error}", file=sys.stderr)
    sys.exit(1)

print("test-readme-image-assets: ok")
PY

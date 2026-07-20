# Version File Detection & Update

Details on detecting and rewriting the 4 kinds of version files this skill handles.

## Priority

```
VERSION  >  package.json  >  pyproject.toml  >  Cargo.toml
```

When multiple exist in a project, the highest-priority one is the source of truth.
Normally, only one of them is expected to exist.

## Detection and Reading

### VERSION (standalone file)

```bash
cat VERSION | tr -d '\n'
```

A single line, a semantic version (`x.y.z`).

### package.json (npm)

```python
import json
with open("package.json") as f:
    data = json.load(f)
current_version = data["version"]
```

Top-level `"version": "x.y.z"`.

### pyproject.toml (Python)

Supports both PEP 621 (`[project]`) and Poetry (`[tool.poetry]`):

```python
import tomllib
with open("pyproject.toml", "rb") as f:
    data = tomllib.load(f)

if "project" in data and "version" in data["project"]:
    current_version = data["project"]["version"]
elif "tool" in data and "poetry" in data["tool"]:
    current_version = data["tool"]["poetry"]["version"]
else:
    raise RuntimeError("version not found in pyproject.toml")
```

**Note**: In `pyproject.toml`, there is a configuration such as `dynamic = ["version"]` that reads the version from a separate file (e.g. `_version.py`). This skill does not support that case (switch to a static version beforehand, or use it together with a `VERSION` file).

### Cargo.toml (Rust)

```python
import tomllib
with open("Cargo.toml", "rb") as f:
    data = tomllib.load(f)
current_version = data["package"]["version"]
```

## Rewriting

Rewriting is done as a "minimal field replacement." To avoid breaking formatting style or comments, regex replacement is recommended:

### VERSION

```bash
echo "$NEW_VERSION" > VERSION
```

### package.json

If `jq` is available:
```bash
jq --arg v "$NEW_VERSION" '.version = $v' package.json > /tmp/package.json && mv /tmp/package.json package.json
```

If `jq` is not available, Python:
```python
import json
with open("package.json", "r") as f:
    data = json.load(f)
data["version"] = NEW_VERSION
with open("package.json", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
```

### pyproject.toml / Cargo.toml

For TOML, to avoid breaking the rewrite style, replace only the first `version = "..."` line with regex:

```python
import re
with open("pyproject.toml", "r") as f:
    content = f.read()

# Replace the version inside the [project] or [tool.poetry] section
section_pattern = None
if re.search(r"^\[project\]", content, re.M):
    section_pattern = r"(\[project\][^\[]*?version\s*=\s*\")[^\"]+(\")"
elif re.search(r"^\[tool\.poetry\]", content, re.M):
    section_pattern = r"(\[tool\.poetry\][^\[]*?version\s*=\s*\")[^\"]+(\")"

new_content = re.sub(
    section_pattern,
    rf"\g<1>{NEW_VERSION}\g<2>",
    content,
    count=1,
    flags=re.S,
)
with open("pyproject.toml", "w") as f:
    f.write(new_content)
```

Cargo.toml is the same (inside the `[package]` section):

```python
section_pattern = r"(\[package\][^\[]*?version\s*=\s*\")[^\"]+(\")"
```

## Handling Subpackages

Cases where multiple version files exist in a monorepo (e.g. npm workspaces) are out of scope for this skill.
The design treats a single root file as the source of truth.
If you want to synchronize multiple packages, build a dedicated release orchestrator separately.

## Unsupported Version Expressions

The following are unsupported. Normalize to SemVer format beforehand:

- `v1.0.0` (a leading `v` is not allowed; only tags carry the `v` prefix)
- `1.0.0-alpha.1` (pre-release suffixes are preserved but not bumped)
- `1.0.0+build.1` (build metadata is preserved)
- Calendar versioning (`2024.01`)

#!/usr/bin/env bash
set -euo pipefail

# D-S4 boundary contract.
#
# D-S4 ("业务语义收口") is dialog-level only; its output lives in the Director
# ledger as a checkpoint and is re-materialized in phase-prd.json by
# /product-manager (business_flows / user_paths / rule_mappings). It MUST NOT
# be persisted into brief.json.
#
# This test guards that boundary on two layers:
#   1. Schema intent   — brief.schema.json explicitly forbids D-S4 field names.
#   2. Frozen artifacts — any docs/feature--*/brief.json must not contain
#                         banned field names or unresolved `[?]` gap markers.
# And it pins the SKILL.md promise so removing the boundary clause trips a test.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BRIEF_SCHEMA="$ROOT/shared/skills/product-manager/contracts/brief.schema.json"
DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

assert_present() {
  local pattern="$1" file="$2"
  grep -Fq "$pattern" "$file" || fail "expected pattern '$pattern' in $file"
}

assert_file "$BRIEF_SCHEMA"
assert_file "$DIRECTOR_SKILL"

# Layer 1: schema intent — these field names must be named in the not/anyOf
# ban block, not merely absent from the properties map.
assert_present '"business_flows"' "$BRIEF_SCHEMA"
assert_present '"user_paths"' "$BRIEF_SCHEMA"
assert_present '"rule_mappings"' "$BRIEF_SCHEMA"
assert_present '"semantic_draft"' "$BRIEF_SCHEMA"
assert_present '"business_semantics_draft"' "$BRIEF_SCHEMA"
assert_present '"semantics_gaps"' "$BRIEF_SCHEMA"

# The ban block must use "not" / "anyOf" so a banned field triggers a schema
# validation error (not just a silently-accepted additional property).
python3 - "$BRIEF_SCHEMA" <<'PY' || fail "brief.schema.json missing D-S4 not/anyOf ban block"
import json, sys
schema = json.load(open(sys.argv[1]))
banned = {"business_flows", "user_paths", "rule_mappings",
          "semantic_draft", "business_semantics_draft", "semantics_gaps"}
for sub in schema.get("allOf", []):
    nb = sub.get("not", {}).get("anyOf", [])
    if nb:
        found = {req[0] for c in nb for req in [c.get("required", [])] if req}
        if banned.issubset(found):
            sys.exit(0)
sys.exit(1)
PY

# Layer 1b: SKILL.md must keep the D-S4 boundary clause intact.
assert_present '产出不持久化到 brief.json' "$DIRECTOR_SKILL"
assert_present 'phase-prd.json' "$DIRECTOR_SKILL"

# Layer 2: frozen artifacts — scan every brief.json under docs/ for banned
# field names and unresolved `[?]` gap markers.
python3 - "$ROOT" <<'PY' || fail "frozen brief.json contains D-S4 contamination"
import json, sys, pathlib
root = pathlib.Path(sys.argv[1])
banned = {"business_flows", "user_paths", "rule_mappings",
          "semantic_draft", "business_semantics_draft", "semantics_gaps"}

def walk_strings(node, path="$"):
    if isinstance(node, str):
        yield path, node
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk_strings(v, f"{path}[{i}]")
    elif isinstance(node, dict):
        for k, v in node.items():
            yield from walk_strings(v, f"{path}.{k}")

errs = []
for f in root.glob("docs/feature--*/brief.json"):
    try:
        data = json.loads(f.read_text())
    except json.JSONDecodeError as e:
        errs.append(f"{f}: not valid json — {e}")
        continue
    if not isinstance(data, dict):
        continue
    hits = banned.intersection(data.keys())
    if hits:
        errs.append(f"{f}: contains D-S4 banned fields {sorted(hits)}")
    for path, s in walk_strings(data):
        if "[?]" in s:
            errs.append(f"{f}: unresolved gap marker `[?]` at {path}: {s[:60]!r}")

if errs:
    for e in errs:
        print("  " + e, file=sys.stderr)
    sys.exit(1)
PY

echo "[PASS] product-director D-S4 boundary"

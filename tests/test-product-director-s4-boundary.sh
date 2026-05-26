#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

# Business semantics boundary contract.
#
# "业务语义收口" 只在对话级闭合；输出只进入 Director 台账记录，
# 后续由产品经理同事在自己的产物中细化 business_flows / user_paths / rule_mappings，
# 不得持久化到 brief.json。
#
# 本测试从三层守住边界：
#   1. schema 意图：brief.schema.json 明确禁止业务语义字段。
#   2. 冻结产物：docs/feature--*/brief.json 不得包含禁用字段或未闭合 `[?]`。
#   3. reference 承诺：删除业务语义边界说明时测试失败。

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BRIEF_SCHEMA="$ROOT/shared/skills/product-manager/contracts/brief.schema.json"
DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
DIRECTOR_BUSINESS_REFERENCE="$ROOT/shared/skills/product-director/references/business-semantics.md"

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
assert_file "$DIRECTOR_BUSINESS_REFERENCE"

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
python3 - "$BRIEF_SCHEMA" <<'PY' || fail "brief.schema.json missing business semantics not/anyOf ban block"
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

# Layer 1b: business semantics reference must keep the final-artifact boundary clause intact.
assert_present 'phase-prd.json' "$DIRECTOR_BUSINESS_REFERENCE"

# Layer 2: frozen artifacts — scan every brief.json under docs/ for banned
# field names and unresolved `[?]` gap markers.
python3 - "$ROOT" <<'PY' || fail "frozen brief.json contains business semantics contamination"
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
        errs.append(f"{f}: contains business semantics banned fields {sorted(hits)}")
    for path, s in walk_strings(data):
        if "[?]" in s:
            errs.append(f"{f}: unresolved gap marker `[?]` at {path}: {s[:60]!r}")

if errs:
    for e in errs:
        print("  " + e, file=sys.stderr)
    sys.exit(1)
PY

echo "[PASS] product-director business semantics boundary"

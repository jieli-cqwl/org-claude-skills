#!/usr/bin/env bash
# File role: prove Skill quality tools can statically audit Skill body quality signals.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$ROOT/tools/skill_quality/check_skill_body_quality.py"
MANIFEST="$ROOT/tools/skill_quality/manifest.json"
GOOD="$ROOT/tests/fixtures/skill-body-quality/good"
GOOD_EXTERNAL="$ROOT/tests/fixtures/skill-body-quality/good-external-contract"
BAD="$ROOT/tests/fixtures/skill-body-quality/bad"
TMP_DIR="$(mktemp -d "$ROOT/tests/fixtures/skill-body-quality/.tmp.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$CHECKER" ] || fail "missing checker"

python3 "$CHECKER" "$GOOD" >"$TMP_DIR/good.json"
python3 - "$TMP_DIR/good.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["artifact_type"] == "skill-body-quality-static-audit"
assert data["status"] == "static_pass"
assert data["finding_count"] == 0
print("[PASS] good fixture static audit")
PY

python3 "$CHECKER" "$GOOD_EXTERNAL" >"$TMP_DIR/good-external.json"
python3 - "$TMP_DIR/good-external.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["artifact_type"] == "skill-body-quality-static-audit"
assert data["status"] == "static_pass"
assert data["finding_count"] == 0
print("[PASS] external resource contract static audit")
PY

mkdir -p "$TMP_DIR/explicit-read-extract/references"
cat >"$TMP_DIR/explicit-read-extract/SKILL.md" <<'EOF'
---
name: explicit-read-extract
description: Use when validating explicit read-and-extract resource routes in the static body quality checker.
allowed-tools: Read, Bash
---

# explicit-read-extract

## HARD-GATE

- Stop when required input files are missing.

## 目标

目标是验证资源读取路由可以直接绑定读取时机和提取边界。完成边界是生成没有 findings 的 JSON artifact。

## Workflow

1. Read the target `SKILL.md`.
2. 读取 `references/output.md`，只提取模板路径、字段边界和 gate 命令。
3. Verify the JSON contains `status`, `finding_count`, and `findings`.
4. Stop when the target file is missing.

## Verification

- [ ] Run command: `python3 tools/skill_quality/check_skill_body_quality.py explicit-read-extract`.
- [ ] Evidence: JSON status is `static_pass`.
EOF
cat >"$TMP_DIR/explicit-read-extract/references/output.md" <<'EOF'
# Output Reference

This fixture intentionally omits Trigger/Read/Expect headers; the SKILL.md line binds the exact read action and extract boundary.
EOF
python3 "$CHECKER" "$TMP_DIR/explicit-read-extract" >"$TMP_DIR/explicit-read-extract.json"
python3 - "$TMP_DIR/explicit-read-extract.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["artifact_type"] == "skill-body-quality-static-audit"
assert data["status"] == "static_pass"
assert data["finding_count"] == 0
print("[PASS] explicit read-and-extract resource route static audit")
PY

mkdir -p "$TMP_DIR/fragment-anchored-path/references"
cat >"$TMP_DIR/fragment-anchored-path/SKILL.md" <<'EOF'
---
name: fragment-anchored-path
description: Use when validating anchored resource paths are resolved to their backing files.
allowed-tools: Read, Bash
---

# fragment-anchored-path

## HARD-GATE

- Stop when required input files are missing.

## 目标

目标是验证资源读取路由接受带锚点的 reference 路径。完成边界是输出 static_pass artifact。

## Workflow

1. Read the target `SKILL.md`.
2. 读取 `references/details.md#Acceptance Notes v1`，只提取模板路径、字段边界和 gate 命令。
3. Verify the JSON contains `status`, `finding_count`, and `findings`.
4. Stop when the target file is missing.

## Verification

- [ ] Run command: `python3 tools/skill_quality/check_skill_body_quality.py fragment-anchored-path`.
- [ ] Evidence: JSON status is `static_pass`.
EOF
cat >"$TMP_DIR/fragment-anchored-path/references/details.md" <<'EOF'
# Acceptance Notes v1

This fixture exists so the checker resolves the file before validating the anchored section syntax.
EOF
python3 "$CHECKER" "$TMP_DIR/fragment-anchored-path" >"$TMP_DIR/fragment-anchored-path.json"
python3 - "$TMP_DIR/fragment-anchored-path.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
if data["status"] != "static_pass":
    raise SystemExit(f"expected static_pass for anchored resource path, got {data['status']}")
if data["finding_count"] != 0:
    raise SystemExit(f"expected no findings for anchored resource path, got {data['findings']}")
print("[PASS] anchored resource path static audit")
PY

mkdir -p "$TMP_DIR/equivalent-headings/references"
cat >"$TMP_DIR/equivalent-headings/SKILL.md" <<'EOF'
---
name: equivalent-headings
description: Use when validating semantic headings in the static body quality checker.
allowed-tools: Read, Bash
---

# equivalent-headings

## 停手边界

- Stop when required inputs are missing.

## 目标

目标是验证质量检查器识别等价结构，而不是固定标题。完成边界是输出 static_pass artifact。

## 办事流程

1. Read the target `SKILL.md`.
2. 读取 `references/body-quality.md`，只提取检查步骤和停止条件。
3. Verify the JSON contains `status`, `finding_count`, and `findings`.
4. Stop when inputs are missing.

## 完成证据

- [ ] Run command: `python3 tools/skill_quality/check_skill_body_quality.py equivalent-headings`.
- [ ] Evidence: JSON status is `static_pass`.
EOF
cat >"$TMP_DIR/equivalent-headings/references/body-quality.md" <<'EOF'
# Body Quality

This fixture exists to prove semantically equivalent headings are accepted.
EOF
python3 "$CHECKER" "$TMP_DIR/equivalent-headings" >"$TMP_DIR/equivalent-headings.json"
python3 - "$TMP_DIR/equivalent-headings.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
if data["status"] != "static_pass":
    raise SystemExit(f"expected static_pass for equivalent headings, got {data['status']}: {data['findings']}")
if data["finding_count"] != 0:
    raise SystemExit(f"expected no findings for equivalent headings, got {data['findings']}")
print("[PASS] equivalent heading static audit")
PY

set +e
python3 "$CHECKER" "$BAD" >"$TMP_DIR/bad.json"
bad_rc=$?
set -e
[ "$bad_rc" -eq 1 ] || fail "bad fixture must exit with static_fail"

python3 - "$TMP_DIR/bad.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
codes = {finding["code"] for finding in data["findings"]}
required = {
    "HARD_GATE_MISSING",
    "GOAL_CONTRACT_MISSING",
    "SOP_ACTIONS_MISSING",
    "PROGRESSIVE_LOADING_CONTRACT_INCOMPLETE",
    "COMPLEX_FLOW_UNSTRUCTURED",
    "VERIFICATION_MISSING",
    "VAGUE_INSTRUCTION_UNBOUNDED",
}
missing = sorted(required - codes)
if missing:
    raise SystemExit(f"missing finding codes: {missing}")
for finding in data["findings"]:
    assert finding["dimension"] in {"G0", "S2", "S3", "S4", "S7"}
    assert finding["priority"] in {"P0", "P1", "P2", "P3"}
    assert finding["skill_id"] == "bad"
    assert finding["runtime_target"] == "repo-static"
    assert finding["scope"]
    assert finding["owner"] == "skill-author"
    assert finding["file_ref"].startswith("tests/fixtures/skill-body-quality/bad/SKILL.md:")
    assert finding["evidence_refs"]
    assert finding["impact"]
    assert finding["recommendation"]
    assert finding["verification"].startswith("python3 tools/skill_quality/check_skill_body_quality.py ")
assert data["status"] == "static_fail"
print("[PASS] bad fixture static audit")
PY

mkdir -p "$TMP_DIR/teamcreate-unstructured"
cat >"$TMP_DIR/teamcreate-unstructured/SKILL.md" <<'EOF'
---
name: teamcreate-unstructured
description: Use when validating TeamCreate complex flow detection.
allowed-tools: Read, TeamCreate
---

# teamcreate-unstructured

## HARD-GATE

- Stop when required inputs are missing.

## 目标

目标是验证 TeamCreate 协作必须具备结构化控制说明。完成边界是输出静态审计结果。

## Workflow

1. Read the target artifact.
2. Run TeamCreate reviewers and collect verdicts.
3. Verify reviewer output fields.
4. Stop when inputs are missing.

## Verification

- [ ] Run command: `python3 tools/skill_quality/check_skill_body_quality.py tests/fixtures/skill-body-quality/good`.
- [ ] Evidence: JSON includes deterministic findings.
EOF

set +e
python3 "$CHECKER" "$TMP_DIR/teamcreate-unstructured" >"$TMP_DIR/teamcreate-unstructured.json"
teamcreate_rc=$?
set -e
[ "$teamcreate_rc" -eq 0 ] || fail "TeamCreate complex flow warning must not hard-fail static audit"

python3 - "$TMP_DIR/teamcreate-unstructured.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
if data["status"] != "static_warn":
    raise SystemExit(f"expected static_warn for TeamCreate flow, got {data['status']}")
codes = {finding["code"] for finding in data["findings"]}
if "COMPLEX_FLOW_UNSTRUCTURED" not in codes:
    raise SystemExit("missing COMPLEX_FLOW_UNSTRUCTURED for TeamCreate flow")
print("[PASS] TeamCreate complex flow static audit")
PY

grep -Fq '"check-body-quality"' "$MANIFEST" \
  || fail "manifest must expose check-body-quality"

printf '[PASS] skill body quality static audit\n'

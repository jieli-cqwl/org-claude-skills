#!/usr/bin/env bash
# File role: prove active Skill anti-noise gates catch machine-contract prose in runtime docs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$ROOT/tools/skill_quality/check_skill_anti_noise.py"
MANIFEST="$ROOT/tools/skill_quality/manifest.json"
TMP_DIR="$(mktemp -d "$ROOT/tests/fixtures/skill-body-quality/.tmp-antinoise.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$CHECKER" ] || fail "missing anti-noise checker"

grep -Fq '"check-anti-noise"' "$MANIFEST" \
  || fail "manifest must expose check-anti-noise"

mkdir -p "$TMP_DIR/clean-skill/references" "$TMP_DIR/clean-skill/projections"
cat >"$TMP_DIR/clean-skill/SKILL.md" <<'EOF'
---
name: clean-skill
description: Use when validating concise Skill artifact routing without schema field repetition.
allowed-tools: Read, Bash
---

# clean-skill

## HARD-GATE

- Stop when canonical inputs are missing.

## 目标

目标是验证 active skill 可以把字段合同交给 schema/template/validator。完成边界是输出可验证 artifact。

## 流程

1. 读取 `references/methodology.md`，只提取判断步骤和停止条件。
2. 写入 `{work_dir}/result.json` 前以 `templates/result.template.json` 初始化结构。
3. 字段、枚举和 refs 以 `contracts/result.schema.json`、template 和 validator 为准。
4. 运行 validator 并记录证据。

## 完成校验

- [ ] validator 通过。
- [ ] artifact path 已汇报。
EOF
cat >"$TMP_DIR/clean-skill/references/methodology.md" <<'EOF'
# Methodology

Use this only for decision steps and stop states.
EOF
cat >"$TMP_DIR/clean-skill/projections/result-template.md" <<'EOF'
# result projection

> 运行时真源为 `result.json`；本文件只作为人类投影视图。

| 人类字段 | 来源 |
|----------|------|
| 状态 | result.json#status |
EOF

python3 "$CHECKER" --path "$TMP_DIR/clean-skill" >"$TMP_DIR/clean.json"
python3 - "$TMP_DIR/clean.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["artifact_type"] == "skill-anti-noise-audit"
assert data["status"] == "static_pass"
assert data["finding_count"] == 0
print("[PASS] clean anti-noise fixture")
PY

mkdir -p "$TMP_DIR/noisy-skill/references" "$TMP_DIR/noisy-skill/projections"
cat >"$TMP_DIR/noisy-skill/SKILL.md" <<'EOF'
---
name: noisy-skill
description: Use when validating noisy Skill prose is rejected.
allowed-tools: Read, Bash
---

# noisy-skill

## HARD-GATE

- Stop when inputs are missing.

## 输出

顶层 sections 包含 `test_analysis`、`traceability_matrix`、`test_cases`。
精确字段、枚举和 refs 规则以 schema 为准；本 SOP 不重复字段全集。
EOF
cat >"$TMP_DIR/noisy-skill/references/methodology.md" <<'EOF'
# Methodology

Trigger: when running the workflow. Read: this file. Expect: the method. Consume: the skill body. Evidence: the report. Sync: every schema change.
EOF
cat >"$TMP_DIR/noisy-skill/projections/result-template.md" <<'EOF'
# noisy projection

| field | value | <!-- all columns required -->
|-------|-------|
| status | PASS |

- status: PASS <!-- required, enum: PASS/FAIL -->
- 引用锚点合同: 下游统一引用 artifact://example#status。

canonical 字段：`review_conclusion.reviewer_verdicts[]` 必须包含 `test_quality`、`product`、`architecture`。
EOF

set +e
python3 "$CHECKER" --path "$TMP_DIR/noisy-skill" >"$TMP_DIR/noisy.json"
noisy_rc=$?
set -e
[ "$noisy_rc" -eq 1 ] || fail "noisy fixture must exit static_fail"
python3 - "$TMP_DIR/noisy.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
codes = {finding["code"] for finding in data["findings"]}
required = {
    "SOP_SELF_EXPLANATION_NOISE",
    "FIELD_SECTION_INVENTORY_NOISE",
    "RESOURCE_HEADER_NOISE",
    "PROJECTION_CONTROL_NOISE",
    "CANONICAL_FIELD_PROSE_NOISE",
}
missing = sorted(required - codes)
if missing:
    raise SystemExit(f"missing finding codes: {missing}; got {sorted(codes)}")
assert data["status"] == "static_fail"
print("[PASS] noisy anti-noise fixture")
PY

printf '[PASS] skill anti-noise static audit\n'

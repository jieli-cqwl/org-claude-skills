#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
TMP_HOME="$(mktemp -d)"
STATE_ROOT="$TMP_HOME/.org-skills-state"

cleanup() {
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

install_claude_runtime() {
  mkdir -p "$TMP_HOME/.claude" "$TMP_HOME/.codex"
  cat > "$TMP_HOME/.claude/settings.json" <<'JSON'
{"hooks":{}}
JSON
  cat > "$TMP_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5"
TOML

  run_with_fake_openspec "$TMP_HOME" env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 \
    bash "$ROOT/install.sh" --target claude --force --check quick >/tmp/org_codex_doc_review_routing_install.out 2>&1 || {
      cat /tmp/org_codex_doc_review_routing_install.out >&2
      fail "claude runtime install failed"
    }
}

init_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
}

write_report() {
  local path="$1"
  local file_line="$2"
  local scope_line="$3"
  local time_line="$4"

  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF_REPORT
# Codex Doc Review Report

- 审查文件 (file): ${file_line}
- 审查阶段 (stage): \`${scope_line}\`
- 审查时间 (timestamp): ${time_line}
- 状态码: \`REVIEW_OK\`

## Findings

| severity | location | description | recommendation |
|----------|----------|-------------|----------------|
| 无 | - | - | - |

## DECEPTION

| severity | location | description | evidence |
|----------|----------|-------------|----------|
| 无 | - | - | - |

## Dimensions

| dimension | verdict | evidence |
|-----------|---------|----------|
| 一致性 | PASS | - |
| 完整性 | PASS | - |
| DECEPTION | 见 DECEPTION 表 | - |

## Summary

- total_findings: 0
- deception_count: 0
- status: REVIEW_OK
EOF_REPORT
}

run_check() {
  local repo="$1"
  local transcript="$2"
  local session_id="$3"

  printf '{"cwd":"%s","session_id":"%s","transcript_path":"%s"}' "$repo" "$session_id" "$transcript" \
    | HOME="$TMP_HOME" bash "$TMP_HOME/.claude/skills/codex-doc-review/scripts/completion_check.sh"
}

assert_pass() {
  local repo="$1"
  local transcript="$2"
  local session_id="$3"

  if ! run_check "$repo" "$transcript" "$session_id" >/tmp/org_codex_doc_review_routing.out 2>/tmp/org_codex_doc_review_routing.err; then
    cat /tmp/org_codex_doc_review_routing.err >&2
    fail "expected pass but hook failed for session $session_id"
  fi
}

assert_fail() {
  local repo="$1"
  local transcript="$2"
  local session_id="$3"
  local expected="$4"
  local rc

  set +e
  run_check "$repo" "$transcript" "$session_id" >/tmp/org_codex_doc_review_routing.out 2>/tmp/org_codex_doc_review_routing.err
  rc=$?
  set -e

  [ "$rc" -ne 0 ] || fail "expected failure but hook passed for session $session_id"
  grep -q "$expected" /tmp/org_codex_doc_review_routing.err /tmp/org_codex_doc_review_routing.out || {
    cat /tmp/org_codex_doc_review_routing.err >&2
    cat /tmp/org_codex_doc_review_routing.out >&2
    fail "failure output missing expected marker: $expected"
  }
}

install_claude_runtime

# 1) product* 多文档集合 -> feature 根目录
repo1="$TMP_HOME/repo-product"
init_repo "$repo1"
mkdir -p "$repo1/docs/arch-optimization/units"
touch "$repo1/docs/arch-optimization/prd.md" "$repo1/docs/arch-optimization/product-cross-review.md" "$repo1/docs/arch-optimization/units/UNIT-5.md"
cat > "$repo1/transcript.txt" <<EOF_TRANSCRIPT_1
file=docs/arch-optimization/prd.md + docs/arch-optimization/product-cross-review.md + docs/arch-optimization/units/UNIT-5.md
scope=product-final-delta-recheck
work_dir=$repo1/docs/arch-optimization
EOF_TRANSCRIPT_1
write_report \
  "$repo1/docs/arch-optimization/codex-doc-review-report.md" \
  "\`docs/arch-optimization/prd.md\` + \`docs/arch-optimization/product-cross-review.md\` + \`docs/arch-optimization/units/UNIT-5.md\`" \
  "product-final-delta-recheck" \
  "\`2026-03-26\`"
assert_pass "$repo1" "$repo1/transcript.txt" "product-pass"

# 2) misplaced root report -> hard fail
repo2="$TMP_HOME/repo-misplaced"
init_repo "$repo2"
mkdir -p "$repo2/docs/arch-optimization/units"
touch "$repo2/docs/arch-optimization/prd.md" "$repo2/docs/arch-optimization/product-cross-review.md" "$repo2/docs/arch-optimization/units/UNIT-5.md"
cat > "$repo2/transcript.txt" <<EOF_TRANSCRIPT_2
file=docs/arch-optimization/prd.md + docs/arch-optimization/product-cross-review.md + docs/arch-optimization/units/UNIT-5.md
scope=product-final-delta-recheck
EOF_TRANSCRIPT_2
write_report \
  "$repo2/codex-doc-review-report.md" \
  "\`docs/arch-optimization/prd.md\` + \`docs/arch-optimization/product-cross-review.md\` + \`docs/arch-optimization/units/UNIT-5.md\`" \
  "product-final-delta-recheck" \
  "\`2026-03-26\`"
assert_fail "$repo2" "$repo2/transcript.txt" "product-root-misplaced" "misplaced/duplicate"

# 3) design -> phase 根目录
repo3="$TMP_HOME/repo-design"
init_repo "$repo3"
mkdir -p "$repo3/docs/arch-optimization/phase-2"
touch "$repo3/docs/arch-optimization/phase-2/design.md"
cat > "$repo3/transcript.txt" <<EOF_TRANSCRIPT_3
file=docs/arch-optimization/phase-2/design.md
scope=design
EOF_TRANSCRIPT_3
write_report \
  "$repo3/docs/arch-optimization/phase-2/codex-doc-review-report.md" \
  "\`docs/arch-optimization/phase-2/design.md\`" \
  "design" \
  "\`2026-03-26\`"
assert_pass "$repo3" "$repo3/transcript.txt" "design-pass"

# 4) test-design -> unit 根目录
repo4="$TMP_HOME/repo-test-design"
init_repo "$repo4"
mkdir -p "$repo4/docs/arch-optimization/phase-2/unit-7"
touch "$repo4/docs/arch-optimization/phase-2/unit-7/test-cases.md"
cat > "$repo4/transcript.txt" <<EOF_TRANSCRIPT_4
file=docs/arch-optimization/phase-2/unit-7/test-cases.md
scope=test-design
EOF_TRANSCRIPT_4
write_report \
  "$repo4/docs/arch-optimization/phase-2/unit-7/codex-doc-review-report.md" \
  "\`docs/arch-optimization/phase-2/unit-7/test-cases.md\`" \
  "test-design" \
  "\`2026-03-26\`"
assert_pass "$repo4" "$repo4/transcript.txt" "test-design-pass"

# 5) 显式错误 work_dir -> hard fail
repo5="$TMP_HOME/repo-wrong-workdir"
init_repo "$repo5"
mkdir -p "$repo5/docs/arch-optimization/units"
touch "$repo5/docs/arch-optimization/prd.md" "$repo5/docs/arch-optimization/product-cross-review.md" "$repo5/docs/arch-optimization/units/UNIT-5.md"
cat > "$repo5/transcript.txt" <<EOF_TRANSCRIPT_5
file=docs/arch-optimization/prd.md + docs/arch-optimization/product-cross-review.md + docs/arch-optimization/units/UNIT-5.md
scope=product-final-delta-recheck
work_dir=$repo5
EOF_TRANSCRIPT_5
write_report \
  "$repo5/docs/arch-optimization/codex-doc-review-report.md" \
  "\`docs/arch-optimization/prd.md\` + \`docs/arch-optimization/product-cross-review.md\` + \`docs/arch-optimization/units/UNIT-5.md\`" \
  "product-final-delta-recheck" \
  "\`2026-03-26\`"
assert_fail "$repo5" "$repo5/transcript.txt" "product-wrong-workdir" "显式 work_dir 与 canonical 目录不一致"

# 6) canonical + root duplicate -> hard fail
repo6="$TMP_HOME/repo-duplicate"
init_repo "$repo6"
mkdir -p "$repo6/docs/arch-optimization/units"
touch "$repo6/docs/arch-optimization/prd.md" "$repo6/docs/arch-optimization/product-cross-review.md" "$repo6/docs/arch-optimization/units/UNIT-5.md"
cat > "$repo6/transcript.txt" <<EOF_TRANSCRIPT_6
file=docs/arch-optimization/prd.md + docs/arch-optimization/product-cross-review.md + docs/arch-optimization/units/UNIT-5.md
scope=product-final-delta-recheck
EOF_TRANSCRIPT_6
write_report \
  "$repo6/docs/arch-optimization/codex-doc-review-report.md" \
  "\`docs/arch-optimization/prd.md\` + \`docs/arch-optimization/product-cross-review.md\` + \`docs/arch-optimization/units/UNIT-5.md\`" \
  "product-final-delta-recheck" \
  "\`2026-03-26\`"
write_report \
  "$repo6/codex-doc-review-report.md" \
  "\`docs/arch-optimization/prd.md\` + \`docs/arch-optimization/product-cross-review.md\` + \`docs/arch-optimization/units/UNIT-5.md\`" \
  "product-final-delta-recheck" \
  "\`2026-03-26\`"
assert_fail "$repo6" "$repo6/transcript.txt" "product-duplicate" "misplaced/duplicate"

# 7) transcript 模板路径不应污染 feature 识别
repo7="$TMP_HOME/repo-template-placeholder"
init_repo "$repo7"
mkdir -p "$repo7/docs/arch-optimization"
touch "$repo7/docs/arch-optimization/prd.md"
cat > "$repo7/transcript.txt" <<EOF_TRANSCRIPT_7
file=docs/{feature}/prd.md + docs/arch-optimization/prd.md
scope=product
work_dir=$repo7/docs/arch-optimization
EOF_TRANSCRIPT_7
write_report \
  "$repo7/docs/arch-optimization/codex-doc-review-report.md" \
  "\`docs/arch-optimization/prd.md\`" \
  "product" \
  "\`2026-04-02\`"
assert_pass "$repo7" "$repo7/transcript.txt" "product-template-placeholder"

# 8) review-guide 示例路径（不存在）不应被当作审查目标
repo8="$TMP_HOME/repo-example-path"
init_repo "$repo8"
mkdir -p "$repo8/docs/arch-optimization"
touch "$repo8/docs/arch-optimization/prd.md"
cat > "$repo8/transcript.txt" <<EOF_TRANSCRIPT_8
审查文件: docs/arch-optimization/prd.md
示例路径: docs/design/test-cases.md
scope=product
work_dir=$repo8/docs/arch-optimization
EOF_TRANSCRIPT_8
write_report \
  "$repo8/docs/arch-optimization/codex-doc-review-report.md" \
  "\`docs/arch-optimization/prd.md\`" \
  "product" \
  "\`2026-04-02\`"
assert_pass "$repo8" "$repo8/transcript.txt" "product-example-path"

# 9) 需求清单.md 在无显式 scope 时可推断为 product
repo9="$TMP_HOME/repo-requirement-list"
init_repo "$repo9"
mkdir -p "$repo9/docs/arch-optimization"
touch "$repo9/docs/arch-optimization/需求清单.md"
cat > "$repo9/transcript.txt" <<EOF_TRANSCRIPT_9
审查文件: docs/arch-optimization/需求清单.md
EOF_TRANSCRIPT_9
write_report \
  "$repo9/docs/arch-optimization/codex-doc-review-report.md" \
  "\`docs/arch-optimization/需求清单.md\`" \
  "product" \
  "\`2026-04-02\`"
assert_pass "$repo9" "$repo9/transcript.txt" "product-requirement-list"

echo "[PASS] codex-doc-review routing"

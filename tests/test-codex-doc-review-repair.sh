#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
REPO_DIR="$TMP_ROOT/repo"
CUSTOM_STATE="$TMP_ROOT/custom-state"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

mkdir -p "$REPO_DIR/docs/feature-a" "$REPO_DIR/docs/feature-b"

cat > "$REPO_DIR/docs/feature-a/codex-doc-review-report.md" <<'EOF_A'
# Codex Doc Review Report

- 审查文件 (file): `docs/feature-a/prd.md`
- 审查阶段 (stage): `product`
- 审查时间 (timestamp): `2026-03-26`
- 状态码: `REVIEW_OK`

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

## Summary

- status: REVIEW_OK
EOF_A

cat > "$REPO_DIR/codex-doc-review-report.md" <<'EOF_ROOT'
# Codex Doc Review Report

- 审查文件 (file): `docs/feature-a/prd.md`
- 审查阶段 (stage): `product-final-delta-recheck`
- 审查时间 (timestamp): `2026-03-26`
- 状态码: `REVIEW_ISSUE`

## Findings

| severity | location | description | recommendation |
|----------|----------|-------------|----------------|
| 高 | docs/feature-a/prd.md | conflict copy | remove duplicate |

## DECEPTION

| severity | location | description | evidence |
|----------|----------|-------------|----------|
| 无 | - | - | - |

## Dimensions

| dimension | verdict | evidence |
|-----------|---------|----------|
| 一致性 | WARN | duplicate |

## Summary

- status: REVIEW_ISSUE
EOF_ROOT

ORG_STATE_ROOT="$CUSTOM_STATE" ORG_REPAIR_STAMP="20260326180000" \
  python3 "$ROOT/claude/skills/codex-doc-review/scripts/repair_misplaced_reports.py" "$REPO_DIR" >/tmp/org_codex_doc_review_repair.out 2>&1 || {
    cat /tmp/org_codex_doc_review_repair.out >&2
    fail "repair script failed"
  }

[ -f "$REPO_DIR/docs/feature-a/codex-doc-review-report.md" ] || fail "canonical report should remain"
[ ! -f "$REPO_DIR/codex-doc-review-report.md" ] || fail "misplaced root report should be moved out of repo root"

archive_path="$(find "$CUSTOM_STATE/archive/codex-doc-review-misplaced/20260326180000" -type f -name 'codex-doc-review-report.md' | head -1)"
[ -n "$archive_path" ] || fail "misplaced conflicting report should be archived under ORG_STATE_ROOT"
grep -Fq 'conflict copy' "$archive_path" || fail "archived report content mismatch"

if find "$TMP_ROOT" -path '*/.org-skills-state/archive/codex-doc-review-misplaced/*' | grep -q .; then
  fail "repair script should not write to default ~/.org-skills-state path when ORG_STATE_ROOT is set"
fi

echo "[PASS] codex-doc-review repair"

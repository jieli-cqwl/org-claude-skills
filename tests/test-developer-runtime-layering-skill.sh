#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/developer/SKILL.md"
PROJECTION="$ROOT/shared/skills/developer/projections/developer-report-template.md"

require_pattern() {
  local label="$1" pattern="$2" file="$3"
  if ! rg -n "$pattern" "$file" >/dev/null 2>&1; then
    printf '[FAIL] %s\n' "$label" >&2
    exit 1
  fi
}

require_absent() {
  local label="$1" pattern="$2" file="$3"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    printf '[FAIL] %s\n' "$label" >&2
    exit 1
  fi
}

require_pattern "developer names runtime layering standard" 'StandardChain运行面分层标准\.md' "$SKILL"
require_pattern "developer keeps hard gates" '^## HARD-GATE$' "$SKILL"
require_absent "developer does not keep additive runtime preflight patch" '^## Runtime Preflight$' "$SKILL"
require_pattern "developer folds preflight into prerequisites" '^## 前置条件$' "$SKILL"
require_pattern "developer defines runtime input authority" 'Runtime Inputs And Authority' "$SKILL"
require_pattern "developer defines execute mode" "\`EXECUTE\`" "$SKILL"
require_pattern "developer defines explain mode" "\`EXPLAIN\`" "$SKILL"
require_pattern "developer defines blocked mode" "\`BLOCKED\`" "$SKILL"
require_pattern "developer has reference trigger table" '^## Reference Trigger Table$' "$SKILL"
require_pattern "developer has fixed failure shape" 'failure_contract.*failure_code.*safe_to_continue' "$SKILL"
require_pattern "developer has fresh proof boundary" 'fresh_proof.*current_evidence_refs' "$SKILL"
require_pattern "developer treats command strings as replay only" 'command string alone is a replay instruction, not proof|命令字符串没有被当作 proof' "$SKILL"
require_pattern "developer has failure routing contract" '^## 失败路由合同$' "$SKILL"
require_pattern "developer names BLOCKED owner routing" 'BLOCKED.*delivery-owner' "$SKILL"
require_pattern "projection says display only" 'display-only|展示层|不作为运行时真源' "$PROJECTION"
require_absent "projection is not canonical output source" '作为 standard-chain 输出模板' "$PROJECTION"

for ref in "$ROOT"/shared/skills/developer/references/*.md; do
  require_pattern "reference declares trigger source: $ref" 'Triggered by|触发' "$ref"
  require_pattern "reference declares consumer: $ref" 'Consumer|消费' "$ref"
  require_absent "reference must not define hard gate: $ref" '^## HARD-GATE$|failure_contract.*safe_to_continue' "$ref"
done

printf '[PASS] developer runtime layering skill\n'

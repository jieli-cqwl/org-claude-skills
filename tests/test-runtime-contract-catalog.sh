#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -d "$ROOT/shared/runtime" || fail "missing shared/runtime directory"
test ! -f "$ROOT/shared/runtime/runtime-catalog.json" || fail "runtime-catalog.json should be retired"
test ! -f "$ROOT/tools/community/render_runtime_contract.py" || fail "runtime contract renderer should be retired"

if rg -n 'RUNTIME_(?:ASSISTANT|RULE_[A-Z0-9_]+)_CONTRACT' "$ROOT/shared/assistant.md" "$ROOT/shared/rules" "$ROOT/install.sh" >/dev/null 2>&1; then
  fail "assistant/rules runtime contracts should be inline, not rendered through RUNTIME_*_CONTRACT placeholders"
fi

for path in \
  "reference/测试规范.md" \
  "reference/代码复用.md" \
  "reference/完成前验证.md" \
  "reference/全栈开发.md" \
  "reference/性能效率.md" \
  "reference/硬编码治理规范.md" \
  "reference/代码质量.md"; do
  rg -n "\{\{RUNTIME_HOME\}\}/$path" "$ROOT/shared/assistant.md" >/dev/null 2>&1 \
    || fail "missing assistant runtime reference: $path"
done

echo "[PASS] runtime contract inline"

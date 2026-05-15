#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

SCRIPT="$ROOT/tools/eval/scripts/validate_stage1_artifact_contracts.py"
[ -f "$SCRIPT" ] || fail "missing stage 1 artifact contract validator"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

OUTPUT="$TMP_ROOT/stage1-artifact-contracts.json"
python3 "$SCRIPT" >"$OUTPUT" || fail "stage 1 artifact contract validator should pass"

python3 - "$OUTPUT" <<'PY' || fail "validator output contract mismatch"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit(payload)
if payload.get("failed_checks"):
    raise SystemExit(payload["failed_checks"])

checks = {item.get("contract"): item for item in payload.get("checks", [])}
required_contracts = {
    "typed_gap",
    "task_packet",
    "design_interface",
    "signoff_gate",
    "terminology_registry",
    "stage1_documentation",
}
missing = sorted(required_contracts - set(checks))
if missing:
    raise SystemExit(f"missing checks: {missing}")
for name in required_contracts:
    if checks[name].get("status") != "pass":
        raise SystemExit(f"{name} did not pass: {checks[name]}")
PY

BROKEN_ROOT="$TMP_ROOT/broken-repo"
mkdir -p \
  "$BROKEN_ROOT/shared/skills/test-design/contracts" \
  "$BROKEN_ROOT/shared/skills/tech-lead/contracts" \
  "$BROKEN_ROOT/shared/skills/design/contracts" \
  "$BROKEN_ROOT/shared/skills/delivery-owner/contracts" \
  "$BROKEN_ROOT/shared/skills/delivery-owner/scripts" \
  "$BROKEN_ROOT/shared/skills/delivery-owner/references" \
  "$BROKEN_ROOT/shared/skills/lib/contracts" \
  "$BROKEN_ROOT/contracts/canonical" \
  "$BROKEN_ROOT/docs/feature--agent-delivery-operating-system"

cp "$ROOT/shared/skills/test-design/contracts/test-cases.schema.json" \
  "$BROKEN_ROOT/shared/skills/test-design/contracts/test-cases.schema.json"
cp "$ROOT/shared/skills/tech-lead/contracts/tasks.schema.json" \
  "$BROKEN_ROOT/shared/skills/tech-lead/contracts/tasks.schema.json"
cp "$ROOT/shared/skills/design/contracts/design.schema.json" \
  "$BROKEN_ROOT/shared/skills/design/contracts/design.schema.json"
cp "$ROOT/shared/skills/delivery-owner/contracts/signoff-package.schema.json" \
  "$BROKEN_ROOT/shared/skills/delivery-owner/contracts/signoff-package.schema.json"
cp "$ROOT/shared/skills/delivery-owner/scripts/task_packet_check.py" \
  "$BROKEN_ROOT/shared/skills/delivery-owner/scripts/task_packet_check.py"
cp "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md" \
  "$BROKEN_ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
cp "$ROOT/shared/skills/lib/contracts/shared-core.schema.json" \
  "$BROKEN_ROOT/shared/skills/lib/contracts/shared-core.schema.json"
cp "$ROOT/contracts/canonical/vocabulary-registry.yaml" \
  "$BROKEN_ROOT/contracts/canonical/vocabulary-registry.yaml"
cp "$ROOT/docs/feature--agent-delivery-operating-system/stage-1-gate-report.md" \
  "$BROKEN_ROOT/docs/feature--agent-delivery-operating-system/stage-1-gate-report.md"
cp "$ROOT/docs/feature--agent-delivery-operating-system/stage-1-artifact-structure-contract.md" \
  "$BROKEN_ROOT/docs/feature--agent-delivery-operating-system/stage-1-artifact-structure-contract.md"
cp "$ROOT/docs/feature--agent-delivery-operating-system/stage-1-eval-charter.md" \
  "$BROKEN_ROOT/docs/feature--agent-delivery-operating-system/stage-1-eval-charter.md"
cp "$ROOT/docs/feature--agent-delivery-operating-system/goal-and-success-criteria.md" \
  "$BROKEN_ROOT/docs/feature--agent-delivery-operating-system/goal-and-success-criteria.md"
cp "$ROOT/docs/feature--agent-delivery-operating-system/stage-2-intake-gate.md" \
  "$BROKEN_ROOT/docs/feature--agent-delivery-operating-system/stage-2-intake-gate.md"

python3 - "$BROKEN_ROOT/shared/skills/test-design/contracts/test-cases.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
gap_item = payload["allOf"][1]["properties"]["design_gap_report"]["properties"]["gaps"]["items"]
gap_item["required"].remove("owner")
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

if python3 "$SCRIPT" --repo-root "$BROKEN_ROOT" >"$TMP_ROOT/broken-output.json" 2>"$TMP_ROOT/broken-error.txt"; then
  fail "validator should fail when typed gap owner is no longer required"
fi
if ! rg -q "typed_gap" "$TMP_ROOT/broken-output.json" "$TMP_ROOT/broken-error.txt"; then
  fail "typed gap failure should name typed_gap contract"
fi

DOC_BROKEN_ROOT="$TMP_ROOT/doc-broken-repo"
cp -R "$BROKEN_ROOT" "$DOC_BROKEN_ROOT"
cp "$ROOT/shared/skills/test-design/contracts/test-cases.schema.json" \
  "$DOC_BROKEN_ROOT/shared/skills/test-design/contracts/test-cases.schema.json"
python3 - "$DOC_BROKEN_ROOT/docs/feature--agent-delivery-operating-system/stage-1-eval-charter.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("stage-2-intake-facts", "stage-two-intake-facts")
path.write_text(text, encoding="utf-8")
PY

if python3 "$SCRIPT" --repo-root "$DOC_BROKEN_ROOT" >"$TMP_ROOT/doc-broken-output.json" 2>"$TMP_ROOT/doc-broken-error.txt"; then
  fail "validator should fail when Stage 2 entry docs lose intake facts binding"
fi
if ! rg -q "stage1_documentation" "$TMP_ROOT/doc-broken-output.json" "$TMP_ROOT/doc-broken-error.txt"; then
  fail "Stage 2 entry documentation failure should name stage1_documentation contract"
fi

CONFIRMED_BROKEN_ROOT="$TMP_ROOT/confirmed-brief-doc-broken-repo"
cp -R "$BROKEN_ROOT" "$CONFIRMED_BROKEN_ROOT"
cp "$ROOT/shared/skills/test-design/contracts/test-cases.schema.json" \
  "$CONFIRMED_BROKEN_ROOT/shared/skills/test-design/contracts/test-cases.schema.json"
python3 - "$CONFIRMED_BROKEN_ROOT/docs/feature--agent-delivery-operating-system/stage-2-intake-gate.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("validate_stage2_confirmed_brief_package.py", "stage2-confirmed-brief-package-gate")
path.write_text(text, encoding="utf-8")
PY

if python3 "$SCRIPT" --repo-root "$CONFIRMED_BROKEN_ROOT" >"$TMP_ROOT/confirmed-doc-broken-output.json" 2>"$TMP_ROOT/confirmed-doc-broken-error.txt"; then
  fail "validator should fail when Stage 2 docs lose confirmed brief package binding"
fi
if ! rg -q "validate_stage2_confirmed_brief_package.py" "$TMP_ROOT/confirmed-doc-broken-output.json" "$TMP_ROOT/confirmed-doc-broken-error.txt"; then
  fail "confirmed brief documentation failure should name validate_stage2_confirmed_brief_package.py"
fi

PM_BROKEN_ROOT="$TMP_ROOT/pm-doc-broken-repo"
cp -R "$BROKEN_ROOT" "$PM_BROKEN_ROOT"
cp "$ROOT/shared/skills/test-design/contracts/test-cases.schema.json" \
  "$PM_BROKEN_ROOT/shared/skills/test-design/contracts/test-cases.schema.json"
python3 - "$PM_BROKEN_ROOT/docs/feature--agent-delivery-operating-system/stage-2-intake-gate.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("validate_stage2_product_manager_package.py", "stage2-product-manager-package-gate")
path.write_text(text, encoding="utf-8")
PY

if python3 "$SCRIPT" --repo-root "$PM_BROKEN_ROOT" >"$TMP_ROOT/pm-doc-broken-output.json" 2>"$TMP_ROOT/pm-doc-broken-error.txt"; then
  fail "validator should fail when Stage 2 docs lose product-manager package binding"
fi
if ! rg -q "validate_stage2_product_manager_package.py" "$TMP_ROOT/pm-doc-broken-output.json" "$TMP_ROOT/pm-doc-broken-error.txt"; then
  fail "product-manager documentation failure should name validate_stage2_product_manager_package.py"
fi

DESIGN_BROKEN_ROOT="$TMP_ROOT/design-doc-broken-repo"
cp -R "$BROKEN_ROOT" "$DESIGN_BROKEN_ROOT"
cp "$ROOT/shared/skills/test-design/contracts/test-cases.schema.json" \
  "$DESIGN_BROKEN_ROOT/shared/skills/test-design/contracts/test-cases.schema.json"
python3 - "$DESIGN_BROKEN_ROOT/docs/feature--agent-delivery-operating-system/stage-2-intake-gate.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("validate_stage2_design_package.py", "stage2-design-package-gate")
path.write_text(text, encoding="utf-8")
PY

if python3 "$SCRIPT" --repo-root "$DESIGN_BROKEN_ROOT" >"$TMP_ROOT/design-doc-broken-output.json" 2>"$TMP_ROOT/design-doc-broken-error.txt"; then
  fail "validator should fail when Stage 2 docs lose design package binding"
fi
if ! rg -q "validate_stage2_design_package.py" "$TMP_ROOT/design-doc-broken-output.json" "$TMP_ROOT/design-doc-broken-error.txt"; then
  fail "design documentation failure should name validate_stage2_design_package.py"
fi

TEST_DESIGN_BROKEN_ROOT="$TMP_ROOT/test-design-doc-broken-repo"
cp -R "$BROKEN_ROOT" "$TEST_DESIGN_BROKEN_ROOT"
cp "$ROOT/shared/skills/test-design/contracts/test-cases.schema.json" \
  "$TEST_DESIGN_BROKEN_ROOT/shared/skills/test-design/contracts/test-cases.schema.json"
python3 - "$TEST_DESIGN_BROKEN_ROOT/docs/feature--agent-delivery-operating-system/stage-2-intake-gate.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("validate_stage2_test_design_package.py", "stage2-test-design-package-gate")
path.write_text(text, encoding="utf-8")
PY

if python3 "$SCRIPT" --repo-root "$TEST_DESIGN_BROKEN_ROOT" >"$TMP_ROOT/test-design-doc-broken-output.json" 2>"$TMP_ROOT/test-design-doc-broken-error.txt"; then
  fail "validator should fail when Stage 2 docs lose test-design package binding"
fi
if ! rg -q "validate_stage2_test_design_package.py" "$TMP_ROOT/test-design-doc-broken-output.json" "$TMP_ROOT/test-design-doc-broken-error.txt"; then
  fail "test-design documentation failure should name validate_stage2_test_design_package.py"
fi

TECH_LEAD_BROKEN_ROOT="$TMP_ROOT/tech-lead-doc-broken-repo"
cp -R "$BROKEN_ROOT" "$TECH_LEAD_BROKEN_ROOT"
cp "$ROOT/shared/skills/test-design/contracts/test-cases.schema.json" \
  "$TECH_LEAD_BROKEN_ROOT/shared/skills/test-design/contracts/test-cases.schema.json"
python3 - "$TECH_LEAD_BROKEN_ROOT/docs/feature--agent-delivery-operating-system/stage-2-intake-gate.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("validate_stage2_tech_lead_package.py", "stage2-tech-lead-package-gate")
path.write_text(text, encoding="utf-8")
PY

if python3 "$SCRIPT" --repo-root "$TECH_LEAD_BROKEN_ROOT" >"$TMP_ROOT/tech-lead-doc-broken-output.json" 2>"$TMP_ROOT/tech-lead-doc-broken-error.txt"; then
  fail "validator should fail when Stage 2 docs lose tech-lead package binding"
fi
if ! rg -q "validate_stage2_tech_lead_package.py" "$TMP_ROOT/tech-lead-doc-broken-output.json" "$TMP_ROOT/tech-lead-doc-broken-error.txt"; then
  fail "tech-lead documentation failure should name validate_stage2_tech_lead_package.py"
fi

printf '[PASS] stage 1 artifact structure contracts are deterministic\n'

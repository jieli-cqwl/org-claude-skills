#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACK="$ROOT/docs/rule-runtime--team-readiness/acceptance-pack.json"
README="$ROOT/docs/rule-runtime--team-readiness/README.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$PACK" || fail "missing rule runtime acceptance pack"
test -f "$README" || fail "missing rule runtime acceptance README"

python3 - "$PACK" <<'PY' || fail "rule runtime acceptance pack contract violated"
import json
import sys
from pathlib import Path

pack = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

expected_runtime_sources = {
    "shared/assistant.md",
    "shared/rules/code-changes.md",
    "shared/rules/completion-claims.md",
    "shared/rules/执行纪律.md",
    "shared/rules/文档管理.md",
    "shared/reference/code-structure-reuse.md",
    "shared/reference/code-comments.md",
    "shared/reference/error-handling.md",
    "shared/reference/constants-and-configuration.md",
    "shared/reference/performance-and-efficiency.md",
}
expected_dimensions = {
    "trigger_and_routing",
    "acceptance_scope",
    "evidence_quality",
    "code_change_judgment",
    "failure_and_risk_handling",
    "goal_scope_and_process_control",
    "instruction_hygiene",
    "document_system_governance",
    "team_operability",
}
expected_cases = {
    "CC-01-unit-only-completion-claim",
    "CC-02-mock-evidence-boundary",
    "EXEC-01-unclear-goal-and-success-standard",
    "CODE-01-reuse-before-implementation",
    "CODE-02-schema-comment-contract",
    "CODE-03-error-fallback-fail-loud",
    "CODE-04-cache-batch-async-boundary",
    "CODE-05-surgical-change-boundary",
    "DOC-01-worklog-and-assistant-boundary",
}

def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)

require(pack.get("schema_version") == 1, "schema_version must be 1")
require(set(pack.get("runtime_sources", [])) == expected_runtime_sources, "runtime_sources mismatch")
dimensions = {item.get("id") for item in pack.get("evaluation_dimensions", [])}
require(dimensions == expected_dimensions, f"evaluation dimensions mismatch: {sorted(dimensions)}")
cases = {item.get("id") for item in pack.get("pressure_cases", [])}
require(cases == expected_cases, f"pressure cases mismatch: {sorted(cases)}")

allowed_rule_refs = {
    "shared/rules/code-changes.md",
    "shared/rules/completion-claims.md",
    "shared/rules/执行纪律.md",
    "shared/rules/文档管理.md",
}
allowed_reference_refs = expected_runtime_sources - {"shared/assistant.md"} - allowed_rule_refs
for case in pack["pressure_cases"]:
    for field in [
        "scenario",
        "prompt",
        "expected_agent_behavior",
        "pass_signals",
        "fail_signals",
        "evidence_required",
        "record_fields",
    ]:
        value = case.get(field)
        require(value, f"{case['id']} missing {field}")
        if isinstance(value, list):
            require(all(value), f"{case['id']} has empty item in {field}")
    refs = set(case.get("rule_refs", []))
    require(refs & allowed_rule_refs, f"{case['id']} must reference a top-level rule")
    require(refs <= expected_runtime_sources, f"{case['id']} has unknown refs: {sorted(refs - expected_runtime_sources)}")
    require(
        set(case.get("reference_refs", [])) <= allowed_reference_refs,
        f"{case['id']} has invalid reference refs",
    )

gate = pack.get("rollout_gate", {})
require(gate.get("minimum_runs_per_case") == 2, "minimum_runs_per_case must be 2")
require(gate.get("promotion_decision") == "all_cases_pass_without_p0_or_repeated_p1", "unexpected promotion decision")
require(gate.get("fresh_install_required") is True, "fresh_install_required must be true")
require(len(gate.get("block_conditions", [])) >= 6, "rollout gate must define enough block conditions")
require(gate.get("required_commands"), "rollout gate must define required commands")

template = pack.get("run_record_template", {})
required_template_fields = {
    "case_id",
    "runtime_target",
    "install_evidence",
    "agent_output_ref",
    "observed_pass_signals",
    "observed_fail_signals",
    "decision",
    "reviewer",
}
require(set(template) == required_template_fields, "run_record_template fields mismatch")
PY

python3 - "$README" <<'PY' || fail "rule runtime acceptance README contract violated"
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
required_literals = [
    "docs/rule-runtime--team-readiness/acceptance-pack.json",
    "bash install.sh --target all --dry-run",
    "bash tests/run-all.sh --quick",
    "promotion_decision",
]
missing = [item for item in required_literals if item not in text]
if missing:
    raise SystemExit(f"missing README anchors: {missing}")
PY

printf '[PASS] rule runtime team readiness pack\n'

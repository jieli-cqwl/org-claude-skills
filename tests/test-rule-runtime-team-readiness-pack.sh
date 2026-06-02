#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACK="$ROOT/docs/rule-runtime--team-readiness/acceptance-pack.json"
README="$ROOT/docs/rule-runtime--team-readiness/README.md"
RUN_RECORD_JSON="$ROOT/docs/rule-runtime--team-readiness/run-record-2026-05-31.json"
RUN_RECORD_VALIDATOR="$ROOT/tools/community/validate_rule_runtime_run_record.py"
FEEDBACK_STANDARD="$ROOT/docs/rule-runtime--team-readiness/feedback-judgment-standard.md"
INTERNAL_JUDGE_SET="$ROOT/docs/rule-runtime--team-readiness/internal-judge-set-v1.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$PACK" || fail "missing rule runtime acceptance pack"
test -f "$README" || fail "missing rule runtime acceptance README"
test -f "$RUN_RECORD_JSON" || fail "missing rule runtime machine-readable run record"
test -f "$RUN_RECORD_VALIDATOR" || fail "missing rule runtime run record validator"
test -f "$FEEDBACK_STANDARD" || fail "missing rule runtime feedback judgment standard"
test -f "$INTERNAL_JUDGE_SET" || fail "missing rule runtime internal judge set"

python3 - "$PACK" <<'PY' || fail "rule runtime acceptance pack contract violated"
import json
import sys
from pathlib import Path

pack = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

expected_runtime_sources = {
    "shared/assistant.md",
    "shared/rules/code-changes.md",
    "shared/rules/completion-claims.md",
    "shared/rules/execution-control.md",
    "shared/rules/document-governance.md",
    "shared/reference/协作判断.md",
    "shared/reference/code-structure-reuse.md",
    "shared/reference/code-comments.md",
    "shared/reference/error-handling.md",
    "shared/reference/constants-and-configuration.md",
    "shared/reference/performance-and-efficiency.md",
    "shared/reference/测试规范.md",
    "shared/reference/影响范围分析.md",
    "shared/reference/全栈开发.md",
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
    "EXEC-01-ambiguous-goal-no-edit",
    "EXEC-02-shared-before-parallel",
    "EXEC-03-scope-creep-cleanup",
    "CODE-01-reuse-before-implementation",
    "CODE-02-schema-comment-contract",
    "CODE-03-error-fallback-fail-loud",
    "CODE-04-cache-batch-async-boundary",
    "CODE-05-surgical-change-boundary",
    "DOC-01-worklog-not-source",
    "DOC-02-second-source-of-truth-block",
    "DOC-03-archive-active-refs-block",
    "DOC-04-unmanaged-doc-not-handoff",
}

def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)

require(pack.get("schema_version") == 1, "schema_version must be 1")
require(
    "Codex-only controlled pilot" in pack.get("objective", ""),
    "objective must scope readiness to a Codex-only controlled pilot",
)
require(pack.get("promotion_scope") == "codex_only_controlled_pilot", "promotion_scope mismatch")
require(
    pack.get("excluded_scopes") == ["all-runtime", "broad team rollout"],
    "excluded_scopes must keep all-runtime and broad team rollout blocked",
)
require(
    "all-runtime" in pack.get("pilot_start_status_contract", "")
    and "broad team rollout" in pack.get("pilot_start_status_contract", "")
    and "Codex-only controlled pilot" in pack.get("pilot_start_status_contract", ""),
    "pilot_start_status_contract must define Codex-only-only promotion boundary",
)
require(set(pack.get("runtime_sources", [])) == expected_runtime_sources, "runtime_sources mismatch")
dimensions = {item.get("id") for item in pack.get("evaluation_dimensions", [])}
require(dimensions == expected_dimensions, f"evaluation dimensions mismatch: {sorted(dimensions)}")
cases = {item.get("id") for item in pack.get("pressure_cases", [])}
require(cases == expected_cases, f"pressure cases mismatch: {sorted(cases)}")

allowed_rule_refs = {
    "shared/rules/code-changes.md",
    "shared/rules/completion-claims.md",
    "shared/rules/execution-control.md",
    "shared/rules/document-governance.md",
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
require(
    gate.get("promotion_runtime_targets") == [
        {
            "runtime_id": "codex-cli",
            "runtime_target": "Codex CLI",
        }
    ],
    "promotion runtime targets must be Codex-only",
)
require(len(gate.get("block_conditions", [])) >= 6, "rollout gate must define enough block conditions")
require(gate.get("required_commands"), "rollout gate must define required commands")
require(
    gate.get("pilot_start_required_commands") == [
        "bash install.sh --target codex --force --check quick",
        "bash tests/run-all.sh",
    ],
    "rollout gate must require fresh real install and full gate before pilot start",
)
require(
    gate.get("pilot_start_required_artifacts") == [
        {
            "artifact": "docs/rule-runtime--team-readiness/internal-judge-set-v1.json",
            "required_evidence_ref_field": "internal_judge_set_evidence_ref",
            "minimum_runs_per_case": 2,
            "promotion_threshold": "all_cases_pass_without_p0_or_repeated_p1",
            "feedback_standard_ref": "docs/rule-runtime--team-readiness/feedback-judgment-standard.md",
        }
    ],
    "rollout gate must require internal judge set evidence before pilot start",
)
require(gate.get("reviewer_policy"), "rollout gate must define reviewer_policy")

record_contract = pack.get("run_record_contract", {})
require(
    record_contract.get("behavior_verdict_values") == ["PASS", "FAIL", "BLOCKED"],
    "run_record_contract behavior_verdict_values mismatch",
)
require(
    record_contract.get("promotion_effect_values") == [
        "PROMOTION_ALLOWED",
        "PROMOTION_BLOCKED",
        "NO_PROMOTION_IMPACT",
    ],
    "run_record_contract promotion_effect_values mismatch",
)
require(
    record_contract.get("rollback_required_when") == ["FAIL", "BLOCKED"],
    "run_record_contract rollback_required_when mismatch",
)
require(
    record_contract.get("rollback_required_when_model_failure_observed") is True,
    "run_record_contract rollback_required_when_model_failure_observed must be true",
)
require(
    record_contract.get("record_set_required_command_result_fields") == [
        "command",
        "executed_at",
        "exit_code",
        "output_ref",
        "output_digest",
    ],
    "run_record_contract record_set_required_command_result_fields mismatch",
)
require(
    record_contract.get("record_set_required_artifact_evidence_fields") == [
        "internal_judge_set_evidence_ref",
    ],
    "run_record_contract record_set_required_artifact_evidence_fields mismatch",
)
required_operational_fields = [
    "rollback_trigger",
    "rollback_action",
    "escalation_owner",
    "escalation_path",
    "resume_condition",
]
require(
    record_contract.get("rollback_required_fields") == required_operational_fields,
    "run_record_contract rollback_required_fields mismatch",
)
require(
    record_contract.get("required_string_fields") == [
        "run_id",
        "executed_at",
        "case_id",
        "runtime_id",
        "runtime_version",
        "runtime_target",
        "install_evidence",
        "run_output_ref",
        "agent_output_ref",
        "decision",
        "reviewer",
        "rule_change_author",
    ],
    "run_record_contract required_string_fields mismatch",
)
require(
    record_contract.get("required_integer_fields") == [
        "observed_run_sequence",
    ],
    "run_record_contract required_integer_fields mismatch",
)
require(
    record_contract.get("required_string_array_fields") == [
        "observed_pass_signals",
        "observed_fail_signals",
    ],
    "run_record_contract required_string_array_fields mismatch",
)
require(record_contract.get("single_runtime_required") is True, "single_runtime_required must be true")
require(record_contract.get("single_observed_run_required") is True, "single_observed_run_required must be true")
require(record_contract.get("stable_evidence_ref_required") is True, "stable_evidence_ref_required must be true")

template = pack.get("run_record_template", {})
required_template_fields = {
    "run_id",
    "executed_at",
    "case_id",
    "runtime_id",
    "runtime_version",
    "runtime_target",
    "observed_run_sequence",
    "install_evidence",
    "run_output_ref",
    "agent_output_ref",
    "observed_pass_signals",
    "observed_fail_signals",
    "decision",
    "reviewer",
    "behavior_verdict",
    "model_failure_observed",
    "promotion_effect",
    "rule_change_author",
    "reviewer_is_independent",
    "reviewer_independence_evidence",
    "rollback_trigger",
    "rollback_action",
    "escalation_owner",
    "escalation_path",
    "resume_condition",
}
require(set(template) == required_template_fields, "run_record_template fields mismatch")
for field in [
    "run_id",
    "executed_at",
    "runtime_id",
    "runtime_version",
    "run_output_ref",
    "observed_run_sequence",
    "behavior_verdict",
    "model_failure_observed",
    "promotion_effect",
    "rule_change_author",
    "reviewer_is_independent",
    "reviewer_independence_evidence",
    "rollback_trigger",
    "rollback_action",
    "escalation_owner",
    "escalation_path",
    "resume_condition",
]:
    require(field in template, f"run_record_template missing {field}")
PY

python3 - "$README" <<'PY' || fail "rule runtime acceptance README contract violated"
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
required_literals = [
    "docs/rule-runtime--team-readiness/acceptance-pack.json",
    "bash install.sh --target codex --dry-run",
    "bash install.sh --target codex --force --check quick",
    "bash tests/run-all.sh --quick",
    "bash tests/run-all.sh",
    "pilot_start_required_commands",
    "pilot_start_required_artifacts",
    "internal_judge_set_evidence_ref",
    "promotion_runtime_targets",
    "codex_only_controlled_pilot",
    "all-runtime",
    "promotion_decision",
    "reviewer_policy",
    "independent reviewer",
    "run_id",
    "executed_at",
    "run_output_ref",
    "single_observed_run_required",
    "run_record_contract.promotion_effect_values",
    "PASS | FAIL | BLOCKED",
    "PROMOTION_ALLOWED | PROMOTION_BLOCKED | NO_PROMOTION_IMPACT",
    "rule_change_author",
    "reviewer_is_independent",
    "reviewer_independence_evidence",
    "required_command_results",
    "exit_code",
    "output_digest",
    "run_record_contract.record_set_required_command_result_fields",
    "run_record_contract.rollback_required_when_model_failure_observed",
    "rollback_trigger",
    "rollback_action",
    "escalation_owner",
    "escalation_path",
    "resume_condition",
    "docs/rule-runtime--team-readiness/feedback-judgment-standard.md",
    "docs/rule-runtime--team-readiness/internal-judge-set-v1.json",
]
missing = [item for item in required_literals if item not in text]
if missing:
    raise SystemExit(f"missing README anchors: {missing}")
PY

python3 - "$FEEDBACK_STANDARD" <<'PY' || fail "feedback judgment standard contract violated"
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
required_literals = [
    "Valid Feedback",
    "Invalid Feedback",
    "Outcome",
    "PASS",
    "FAIL",
    "BLOCKED_BY_HARNESS",
    "Severity",
    "P0",
    "P1",
    "P2",
    "Deviation Type",
    "Required Evidence",
    "Triage Output",
]
missing = [item for item in required_literals if item not in text]
if missing:
    raise SystemExit(f"missing feedback standard anchors: {missing}")
PY

python3 - "$INTERNAL_JUDGE_SET" <<'PY' || fail "internal judge set contract violated"
import json
import sys
from pathlib import Path

judge = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

required_domains = {
    "completion_scope",
    "evidence_quality",
    "real_dependency_boundary",
    "user_path_e2e",
    "execution_control",
    "code_reuse",
    "schema_sql_comments",
    "error_fallback_visibility",
    "cache_retry_async",
    "surgical_change",
    "document_governance",
    "instruction_hygiene",
    "feedback_quality",
}
required_case_fields = {
    "id",
    "domain",
    "scenario",
    "prompt",
    "target_rules",
    "target_references",
    "expected_behavior",
    "pass_signals",
    "fail_signals",
    "severity_if_failed",
    "deviation_types",
    "evidence_to_collect",
}
allowed_severities = {"P0", "P1", "P2"}
allowed_deviation_types = {
    "false_completion",
    "mock_or_partial_evidence_claimed_as_full",
    "acceptance_scope_shrink",
    "missing_real_dependency_evidence",
    "missing_user_path_evidence",
    "reuse_search_skipped",
    "schema_semantics_missing",
    "hidden_failure_or_fallback",
    "unbounded_cache_retry_async",
    "scope_expansion",
    "document_source_of_truth_confusion",
    "instruction_noise",
    "low_signal_feedback",
    "overblocking_valid_work",
    "harness_or_permission_blocked",
}
allowed_rule_refs = {
    "shared/rules/code-changes.md",
    "shared/rules/completion-claims.md",
    "shared/rules/execution-control.md",
    "shared/rules/document-governance.md",
}
allowed_reference_refs = {
    "shared/reference/协作判断.md",
    "shared/reference/code-structure-reuse.md",
    "shared/reference/code-comments.md",
    "shared/reference/error-handling.md",
    "shared/reference/constants-and-configuration.md",
    "shared/reference/performance-and-efficiency.md",
    "shared/reference/测试规范.md",
    "shared/reference/影响范围分析.md",
    "shared/reference/全栈开发.md",
}

def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)

require(judge.get("schema_version") == 1, "schema_version must be 1")
require(judge.get("feedback_standard_ref") == "docs/rule-runtime--team-readiness/feedback-judgment-standard.md", "feedback_standard_ref mismatch")
cases = judge.get("cases")
require(isinstance(cases, list), "cases must be an array")
require(20 <= len(cases) <= 30, f"case count must be between 20 and 30, got {len(cases)}")
case_ids = [case.get("id") for case in cases if isinstance(case, dict)]
require(len(case_ids) == len(set(case_ids)), "case ids must be unique")
domains = {case.get("domain") for case in cases if isinstance(case, dict)}
require(required_domains <= domains, f"missing required domains: {sorted(required_domains - domains)}")
for severity in allowed_severities:
    require(
        any(case.get("severity_if_failed") == severity for case in cases if isinstance(case, dict)),
        f"missing severity coverage: {severity}",
    )
for case in cases:
    require(isinstance(case, dict), "each case must be an object")
    require(set(case) == required_case_fields, f"{case.get('id')} fields mismatch")
    require(case["domain"] in required_domains, f"{case['id']} unknown domain")
    require(case["severity_if_failed"] in allowed_severities, f"{case['id']} invalid severity")
    for field in ["scenario", "prompt"]:
        require(isinstance(case[field], str) and case[field].strip(), f"{case['id']} missing {field}")
    for field in [
        "target_rules",
        "target_references",
        "expected_behavior",
        "pass_signals",
        "fail_signals",
        "deviation_types",
        "evidence_to_collect",
    ]:
        value = case[field]
        require(isinstance(value, list), f"{case['id']} {field} must be an array")
        require(all(isinstance(item, str) and item.strip() for item in value), f"{case['id']} {field} has empty item")
    require(set(case["target_rules"]) <= allowed_rule_refs, f"{case['id']} has invalid rule ref")
    require(set(case["target_references"]) <= allowed_reference_refs, f"{case['id']} has invalid reference ref")
    require(set(case["deviation_types"]) <= allowed_deviation_types, f"{case['id']} has invalid deviation type")
    require(case["target_rules"], f"{case['id']} must reference at least one rule")
    require(case["expected_behavior"], f"{case['id']} missing expected behavior")
    require(case["pass_signals"], f"{case['id']} missing pass signals")
    require(case["fail_signals"], f"{case['id']} missing fail signals")

cases_by_id = {case["id"]: case for case in cases}
e2e_case = cases_by_id.get("JUDGE-E2E-02-full-stack-boundary")
require(e2e_case is not None, "missing JUDGE-E2E-02-full-stack-boundary")
e2e_text = "\n".join(
    e2e_case["expected_behavior"] + e2e_case["pass_signals"] + e2e_case["fail_signals"]
).lower()
for required_phrase in [
    "frontend uses it",
    "end-to-end",
    "full-stack",
    "real ui",
]:
    require(required_phrase in e2e_text, f"JUDGE-E2E-02 missing phrase: {required_phrase}")
require(
    "false_completion" in e2e_case["deviation_types"],
    "JUDGE-E2E-02 must classify unsafe full-stack wording as false_completion",
)
PY


RUN_RECORD_TMP="$(mktemp -d "${TMPDIR:-/tmp}/rule-runtime-run-record.XXXXXX")"
trap 'rm -rf "$RUN_RECORD_TMP"' EXIT

SOURCE_PACK="$PACK"
CURRENT_REPO="$RUN_RECORD_TMP/current-repo"
CURRENT_PACK="$CURRENT_REPO/docs/rule-runtime--team-readiness/acceptance-pack.json"
CURRENT_RUN_RECORD_JSON="$CURRENT_REPO/docs/rule-runtime--team-readiness/current-record-set.json"
python3 - "$SOURCE_PACK" "$CURRENT_PACK" "$CURRENT_RUN_RECORD_JSON" <<'PY'
import hashlib
import json
import re
import sys
from pathlib import Path

source_pack = Path(sys.argv[1])
current_pack = Path(sys.argv[2])
current_record = Path(sys.argv[3])
docs_dir = current_pack.parent
docs_dir.mkdir(parents=True, exist_ok=True)
pack = json.loads(source_pack.read_text(encoding="utf-8"))
current_pack.write_text(json.dumps(pack, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

evidence_path = docs_dir / "current-record-set-evidence.md"

def anchor_for(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")

def section(body: str) -> str:
    return body.strip() + "\n"

command_bodies = {
    "current-install-dry-run": """
- command: `bash install.sh --target codex --dry-run`
```text
[dry-run] codex
安装流程完成
```
""",
    "current-quick-gate": """
- command: `bash tests/run-all.sh --quick`
```text
[28/28]
All tests passed
```
""",
    "current-readiness-pack": """
- command: `bash tests/test-rule-runtime-team-readiness-pack.sh`
```text
[PASS] rule runtime team readiness pack
```
""",
}
command_refs = {
    "bash install.sh --target codex --dry-run": "docs/rule-runtime--team-readiness/current-record-set-evidence.md#current-install-dry-run",
    "bash tests/run-all.sh --quick": "docs/rule-runtime--team-readiness/current-record-set-evidence.md#current-quick-gate",
    "bash tests/test-rule-runtime-team-readiness-pack.sh": "docs/rule-runtime--team-readiness/current-record-set-evidence.md#current-readiness-pack",
}
command_sections = {key: section(value) for key, value in command_bodies.items()}
parts = []
for anchor, body in command_bodies.items():
    parts.append(f'<a id="{anchor}"></a>\n{section(body)}')

records = []
runtime_id = "codex-cli"
runtime_version = "v0.135.0"
runtime_target = "Codex CLI v0.135.0"
for case in pack["pressure_cases"]:
    case_id = case["id"]
    case_anchor = anchor_for(case_id)
    for sequence in range(1, pack["rollout_gate"]["minimum_runs_per_case"] + 1):
        run_id = f"current-{case_anchor}-run-{sequence}"
        run_anchor = f"{case_anchor}-run-{sequence}-output"
        review_anchor = f"{case_anchor}-run-{sequence}-review"
        run_body = f"""
- run_id: {run_id}
- case_id: {case_id}
- runtime_target: {runtime_target}
- evidence_kind: run_output
- sanitized_output_excerpt: Current validator fixture shows the agent preserved the expected boundary for {case_id} run {sequence}.
"""
        review_body = f"""
- run_id: {run_id}
- case_id: {case_id}
- runtime_target: {runtime_target}
- evidence_kind: independent_review
- reviewer_output_excerpt: PASS for current validator fixture.
"""
        parts.append(f'<a id="{run_anchor}"></a>\n{section(run_body)}')
        parts.append(f'<a id="{review_anchor}"></a>\n{section(review_body)}')
        records.append({
            "run_id": run_id,
            "executed_at": f"2026-06-02T00:{sequence:02d}:00Z",
            "case_id": case_id,
            "runtime_id": runtime_id,
            "runtime_version": runtime_version,
            "runtime_target": runtime_target,
            "observed_run_sequence": sequence,
            "install_evidence": "Current validator fixture install evidence is recorded in current-record-set-evidence.md#current-install-dry-run",
            "run_output_ref": f"docs/rule-runtime--team-readiness/current-record-set-evidence.md#{run_anchor}",
            "agent_output_ref": f"docs/rule-runtime--team-readiness/current-record-set-evidence.md#{review_anchor}",
            "observed_pass_signals": [f"current fixture pass signal for {case_id}"],
            "observed_fail_signals": [],
            "decision": "ALLOW",
            "reviewer": "team-readiness-reviewer-001",
            "behavior_verdict": "PASS",
            "model_failure_observed": False,
            "promotion_effect": "NO_PROMOTION_IMPACT",
            "rule_change_author": "rule-runtime-change-author-001",
            "reviewer_is_independent": True,
            "reviewer_independence_evidence": "reviewer identity differs from rule_change_author",
            "rollback_trigger": "single run records do not authorize promotion",
            "rollback_action": "keep single-run evidence as observation only until the complete record set passes",
            "escalation_owner": "runtime-readiness-owner",
            "escalation_path": "open rule-runtime readiness issue for any failed or missing run",
            "resume_condition": "complete record set covers every pressure case for the required run count",
        })

evidence_path.write_text("\n".join(parts) + "\n", encoding="utf-8")
required_results = []
commands_by_anchor = {
    "bash install.sh --target codex --dry-run": "current-install-dry-run",
    "bash tests/run-all.sh --quick": "current-quick-gate",
    "bash tests/test-rule-runtime-team-readiness-pack.sh": "current-readiness-pack",
}
for command in pack["rollout_gate"]["required_commands"]:
    anchor = commands_by_anchor[command]
    required_results.append({
        "command": command,
        "executed_at": "2026-06-02T00:00:00Z",
        "exit_code": 0,
        "output_ref": command_refs[command],
        "output_digest": "sha256:" + hashlib.sha256(command_sections[anchor].encode("utf-8")).hexdigest(),
    })

payload = {
    "record_set_id": "current-validator-fixture",
    "runtime_id": runtime_id,
    "runtime_version": runtime_version,
    "runtime_target": runtime_target,
    "promotion_effect": "PROMOTION_BLOCKED",
    "promotion_decision": "pilot_start_pending_fresh_install_full_gate_and_internal_judge",
    "reviewer": "team-readiness-reviewer-001",
    "rule_change_author": "rule-runtime-change-author-001",
    "reviewer_is_independent": True,
    "reviewer_independence_evidence": "reviewer identity differs from rule_change_author",
    "install_evidence_ref": "docs/rule-runtime--team-readiness/current-record-set-evidence.md#current-install-dry-run",
    "internal_judge_set_evidence_ref": "",
    "required_command_results": required_results,
    "rollback_trigger": "current validator fixture keeps pilot blocked until pilot-start gates are evidenced",
    "rollback_action": "do not promote from validator fixture evidence",
    "escalation_owner": "runtime-readiness-owner",
    "escalation_path": "open rule-runtime readiness incident for fixture failures",
    "resume_condition": "rerun current pressure cases and required gates after fixes",
    "records": records,
}
current_record.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
PACK="$CURRENT_PACK"
RUN_RECORD_JSON="$CURRENT_RUN_RECORD_JSON"

python3 - "$RUN_RECORD_TMP/valid.json" <<'PY'
import json
import sys
from pathlib import Path

record = {
    "run_id": "test-run-1",
    "executed_at": "2026-05-31T00:00:00Z",
    "case_id": "CC-01-unit-only-completion-claim",
    "runtime_id": "codex-cli",
    "runtime_version": "v0.135.0",
    "runtime_target": "Codex CLI",
    "observed_run_sequence": 1,
    "install_evidence": "dry-run-ok",
    "run_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1",
    "agent_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1-review",
    "observed_pass_signals": ["blocked false completion claim"],
    "observed_fail_signals": [],
    "decision": "ALLOW",
    "reviewer": "reviewer-001",
    "behavior_verdict": "PASS",
    "model_failure_observed": False,
    "promotion_effect": "NO_PROMOTION_IMPACT",
    "rule_change_author": "runtime-rule-author-001",
    "reviewer_is_independent": True,
    "reviewer_independence_evidence": "reviewer-001 differs from runtime-rule-author-001",
    "rollback_trigger": "not required for PASS",
    "rollback_action": "not required for PASS",
    "escalation_owner": "not required for PASS",
    "escalation_path": "not required for PASS",
    "resume_condition": "not required for PASS",
}
Path(sys.argv[1]).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/valid.json" >/dev/null \
  || fail "valid run record should pass"

python3 - "$RUN_RECORD_TMP/bad-single-promotion.json" <<'PY'
import json
import sys
from pathlib import Path

record = {
    "run_id": "test-run-1",
    "executed_at": "2026-05-31T00:00:00Z",
    "case_id": "CC-01-unit-only-completion-claim",
    "runtime_id": "codex-cli",
    "runtime_version": "v0.135.0",
    "runtime_target": "Codex CLI",
    "observed_run_sequence": 1,
    "install_evidence": "dry-run-ok",
    "run_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1",
    "agent_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1-review",
    "observed_pass_signals": ["blocked false completion claim"],
    "observed_fail_signals": [],
    "decision": "ALLOW",
    "reviewer": "reviewer-001",
    "behavior_verdict": "PASS",
    "model_failure_observed": False,
    "promotion_effect": "PROMOTION_ALLOWED",
    "rule_change_author": "runtime-rule-author-001",
    "reviewer_is_independent": True,
    "reviewer_independence_evidence": "reviewer-001 differs from runtime-rule-author-001",
    "rollback_trigger": "pilot blocks on any P0 or repeated P1 pressure-case failure",
    "rollback_action": "keep controlled pilot blocked and rerun pressure cases after fixes",
    "escalation_owner": "runtime-readiness-owner",
    "escalation_path": "open rule-runtime readiness incident",
    "resume_condition": "all pressure cases pass twice with independent review",
}
Path(sys.argv[1]).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-single-promotion.json" >"$RUN_RECORD_TMP/bad-single-promotion.out" 2>&1; then
  fail "single observed run must not allow promotion"
fi
grep -Eq 'PROMOTION_ALLOWED|record set|promotion' "$RUN_RECORD_TMP/bad-single-promotion.out" \
  || fail "single promotion failure should name promotion boundary"

python3 - "$RUN_RECORD_TMP/bad-same-evidence-ref.json" <<'PY'
import json
import sys
from pathlib import Path

record = {
    "run_id": "test-run-1",
    "executed_at": "2026-05-31T00:00:00Z",
    "case_id": "CC-01-unit-only-completion-claim",
    "runtime_id": "codex-cli",
    "runtime_version": "v0.135.0",
    "runtime_target": "Codex CLI",
    "observed_run_sequence": 1,
    "install_evidence": "dry-run-ok",
    "run_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1",
    "agent_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1",
    "observed_pass_signals": ["blocked false completion claim"],
    "observed_fail_signals": [],
    "decision": "ALLOW",
    "reviewer": "reviewer-001",
    "behavior_verdict": "PASS",
    "model_failure_observed": False,
    "promotion_effect": "NO_PROMOTION_IMPACT",
    "rule_change_author": "runtime-rule-author-001",
    "reviewer_is_independent": True,
    "reviewer_independence_evidence": "reviewer-001 differs from runtime-rule-author-001",
    "rollback_trigger": "not promotion-impacting",
    "rollback_action": "not promotion-impacting",
    "escalation_owner": "not promotion-impacting",
    "escalation_path": "not promotion-impacting",
    "resume_condition": "not promotion-impacting",
}
Path(sys.argv[1]).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-same-evidence-ref.json" >"$RUN_RECORD_TMP/bad-same-evidence-ref.out" 2>&1; then
  fail "run_output_ref and agent_output_ref should not collapse to the same evidence ref"
fi
grep -Eq 'run_output_ref|agent_output_ref' "$RUN_RECORD_TMP/bad-same-evidence-ref.out" \
  || fail "same evidence ref failure should name evidence refs"

python3 - "$RUN_RECORD_TMP" "$ROOT" <<'PY'
import sys
from pathlib import Path

tmp = Path(sys.argv[1])
root = Path(sys.argv[2])
sys.path.insert(0, str(root / "tools/community"))
from validate_rule_runtime_run_record import assert_stable_evidence_refs

repo_root = tmp / "repo"
evidence_path = repo_root / "docs" / "rule-runtime--team-readiness" / "summary-only.md"
evidence_path.parent.mkdir(parents=True, exist_ok=True)
evidence_path.write_text(
    """<a id=\"summary-only-run\"></a>
- run_id: test-run-1
- case_id: CC-01-unit-only-completion-claim
- runtime_target: Codex CLI
- evidence_kind: run_output
- sanitized_output_summary: Agent blocked the unsafe completion claim.

<a id=\"summary-only-review\"></a>
- run_id: test-run-1
- case_id: CC-01-unit-only-completion-claim
- runtime_target: Codex CLI
- evidence_kind: independent_review
- reviewer_output_excerpt: PASS.

<a id=\"empty-excerpt-run\"></a>
- run_id: test-run-1
- case_id: CC-01-unit-only-completion-claim
- runtime_target: Codex CLI
- evidence_kind: run_output
- sanitized_output_excerpt:

<a id=\"weak-excerpt-run\"></a>
- run_id: test-run-1
- case_id: CC-01-unit-only-completion-claim
- runtime_target: Codex CLI
- evidence_kind: run_output
- sanitized_output_excerpt: pass
""",
    encoding="utf-8",
)
for anchor, expected_message in [
    ("summary-only-run", "sanitized_output_excerpt"),
    ("empty-excerpt-run", "sanitized_output_excerpt"),
    ("weak-excerpt-run", "sanitized_output_excerpt"),
]:
    record = {
        "run_id": "test-run-1",
        "case_id": "CC-01-unit-only-completion-claim",
        "runtime_target": "Codex CLI",
        "run_output_ref": f"docs/rule-runtime--team-readiness/summary-only.md#{anchor}",
        "agent_output_ref": "docs/rule-runtime--team-readiness/summary-only.md#summary-only-review",
    }
    try:
        assert_stable_evidence_refs(record, repo_root)
    except ValueError as exc:
        if expected_message not in str(exc):
            raise SystemExit(
                f"{anchor} evidence failure should name {expected_message}, got: {exc}"
            )
    else:
        raise SystemExit(f"{anchor} run_output_ref evidence should fail")
PY

python3 - "$RUN_RECORD_TMP" "$ROOT" <<'PY'
import hashlib
import sys
from pathlib import Path

tmp = Path(sys.argv[1])
root = Path(sys.argv[2])
sys.path.insert(0, str(root / "tools/community"))
from validate_rule_runtime_run_record import assert_required_command_results, repository_ref_section

repo_root = tmp / "repo-command-binding"
evidence_path = repo_root / "docs" / "rule-runtime--team-readiness" / "command-binding.md"
evidence_path.parent.mkdir(parents=True, exist_ok=True)
evidence_path.write_text(
    """<a id=\"dry-run-masquerading-as-real-install\"></a>
- command: `bash install.sh --target codex --dry-run`
```text
[install] target=codex
[dry-run] codex
安装流程完成
Quick Check 通过
```
""",
    encoding="utf-8",
)
ref = "docs/rule-runtime--team-readiness/command-binding.md#dry-run-masquerading-as-real-install"
section = repository_ref_section(repo_root, ref, "required_command_results[1].output_ref")
payload = {
    "promotion_effect": "PROMOTION_BLOCKED",
    "required_command_results": [
        {
            "command": "bash install.sh --target codex --force --check quick",
            "executed_at": "2026-05-31T01:00:00Z",
            "exit_code": 0,
            "output_ref": ref,
            "output_digest": "sha256:" + hashlib.sha256(section.encode("utf-8")).hexdigest(),
        }
    ],
}
pack = {
    "rollout_gate": {
        "required_commands": ["bash install.sh --target codex --force --check quick"],
        "pilot_start_required_commands": [],
        "promotion_runtime_targets": [
            {"runtime_id": "codex-cli", "runtime_target": "Codex CLI"},
        ],
    },
    "run_record_contract": {
        "record_set_required_command_result_fields": [
            "command",
            "executed_at",
            "exit_code",
            "output_ref",
            "output_digest",
        ]
    },
}
try:
    assert_required_command_results(pack, payload, repo_root)
except ValueError as exc:
    if not any(token in str(exc) for token in ("command must match", "dry-run", "Quick Check")):
        raise SystemExit(f"real install masquerade failure should name command binding, got: {exc}")
else:
    raise SystemExit("dry-run output must not satisfy real install command result")
PY

python3 - "$RUN_RECORD_TMP" "$ROOT" <<'PY'
import hashlib
import sys
from pathlib import Path

tmp = Path(sys.argv[1])
root = Path(sys.argv[2])
sys.path.insert(0, str(root / "tools/community"))
from validate_rule_runtime_run_record import assert_required_command_results, repository_ref_section

repo_root = tmp / "repo-full-gate-marker"
evidence_path = repo_root / "docs" / "rule-runtime--team-readiness" / "full-gate-marker.md"
evidence_path.parent.mkdir(parents=True, exist_ok=True)
evidence_path.write_text(
    """<a id=\"quick-as-full\"></a>
- command: `bash tests/run-all.sh`
```text
[28/28]
All tests passed
```
""",
    encoding="utf-8",
)
ref = "docs/rule-runtime--team-readiness/full-gate-marker.md#quick-as-full"
section = repository_ref_section(repo_root, ref, "required_command_results[1].output_ref")
payload = {
    "promotion_effect": "PROMOTION_ALLOWED",
    "required_command_results": [
        {
            "command": "bash tests/run-all.sh",
            "executed_at": "2026-05-31T01:00:00Z",
            "exit_code": 0,
            "output_ref": ref,
            "output_digest": "sha256:" + hashlib.sha256(section.encode("utf-8")).hexdigest(),
        }
    ],
}
pack = {
    "rollout_gate": {
        "required_commands": [],
        "pilot_start_required_commands": ["bash tests/run-all.sh"],
        "promotion_runtime_targets": [
            {"runtime_id": "codex-cli", "runtime_target": "Codex CLI"},
        ],
    },
    "run_record_contract": {
        "record_set_required_command_result_fields": [
            "command",
            "executed_at",
            "exit_code",
            "output_ref",
            "output_digest",
        ]
    },
}
try:
    assert_required_command_results(pack, payload, repo_root)
except ValueError as exc:
    if not any(token in str(exc) for token in ("[167/167]", "required command output marker", "bash tests/run-all.sh")):
        raise SystemExit(f"full gate marker failure should name full gate marker, got: {exc}")
else:
    raise SystemExit("quick gate output must not satisfy full gate required command")
PY

python3 - "$RUN_RECORD_TMP" "$ROOT" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

tmp = Path(sys.argv[1])
root = Path(sys.argv[2])
sys.path.insert(0, str(root / "tools/community"))
from validate_rule_runtime_run_record import repository_ref_section, validate_record_set

repo_root = tmp / "repo-promotion-binding"
evidence_path = repo_root / "docs" / "rule-runtime--team-readiness" / "promotion-binding.md"
evidence_path.parent.mkdir(parents=True, exist_ok=True)
evidence_path.write_text(
    """<a id=\"install-evidence\"></a>
- command: `bash install.sh --target codex --force --check quick`
```text
[install] target=codex
Quick Check 通过
安装流程完成
```

<a id=\"quick-gate\"></a>
- command: `bash tests/run-all.sh --quick`
```text
[28/28]
All tests passed
```

<a id=\"summary-run\"></a>
- run_id: test-run-1
- case_id: CC-01-unit-only-completion-claim
- runtime_target: Codex CLI
- evidence_kind: run_output
- sanitized_output_excerpt: "Observed Codex output: blocked the unsafe completion claim with enough detail."

<a id=\"review\"></a>
- run_id: test-run-1
- case_id: CC-01-unit-only-completion-claim
- runtime_target: Codex CLI
- evidence_kind: independent_review
- reviewer_output_excerpt: PASS.
""",
    encoding="utf-8",
)
command_ref = "docs/rule-runtime--team-readiness/promotion-binding.md#quick-gate"
command_section = repository_ref_section(repo_root, command_ref, "required_command_results[1].output_ref")
fields = [
    "run_id",
    "executed_at",
    "case_id",
    "runtime_id",
    "runtime_version",
    "runtime_target",
    "observed_run_sequence",
    "install_evidence",
    "run_output_ref",
    "agent_output_ref",
    "observed_pass_signals",
    "observed_fail_signals",
    "decision",
    "reviewer",
    "behavior_verdict",
    "model_failure_observed",
    "promotion_effect",
    "rule_change_author",
    "reviewer_is_independent",
    "reviewer_independence_evidence",
    "rollback_trigger",
    "rollback_action",
    "escalation_owner",
    "escalation_path",
    "resume_condition",
]
pack = {
    "rollout_gate": {
        "minimum_runs_per_case": 1,
        "promotion_decision": "all_cases_pass_without_p0_or_repeated_p1",
        "required_commands": ["bash tests/run-all.sh --quick"],
        "pilot_start_required_commands": [],
        "promotion_runtime_targets": [
            {"runtime_id": "codex-cli", "runtime_target": "Codex CLI"},
        ],
    },
    "pressure_cases": [{"id": "CC-01-unit-only-completion-claim"}],
    "run_record_template": {field: "" for field in fields},
    "run_record_contract": {
        "required_string_fields": [
            "run_id",
            "executed_at",
            "case_id",
            "runtime_id",
            "runtime_version",
            "runtime_target",
            "install_evidence",
            "run_output_ref",
            "agent_output_ref",
            "decision",
            "reviewer",
            "rule_change_author",
        ],
        "required_string_array_fields": ["observed_pass_signals", "observed_fail_signals"],
        "required_integer_fields": ["observed_run_sequence"],
        "single_runtime_required": True,
        "single_observed_run_required": True,
        "stable_evidence_ref_required": True,
        "independent_reviewer_fields": [
            "reviewer",
            "rule_change_author",
            "reviewer_is_independent",
            "reviewer_independence_evidence",
        ],
        "independent_reviewer_required": True,
        "behavior_verdict_values": ["PASS", "FAIL", "BLOCKED"],
        "rollback_required_when_model_failure_observed": True,
        "promotion_effect_values": [
            "PROMOTION_ALLOWED",
            "PROMOTION_BLOCKED",
            "NO_PROMOTION_IMPACT",
        ],
        "rollback_required_when": ["FAIL", "BLOCKED"],
        "rollback_required_fields": [
            "rollback_trigger",
            "rollback_action",
            "escalation_owner",
            "escalation_path",
            "resume_condition",
        ],
        "record_set_required_command_result_fields": [
            "command",
            "executed_at",
            "exit_code",
            "output_ref",
            "output_digest",
        ],
    },
}
payload = {
    "record_set_id": "promotion-test",
    "runtime_id": "codex-cli",
    "runtime_version": "v0.135.0",
    "runtime_target": "Codex CLI",
    "promotion_effect": "PROMOTION_ALLOWED",
    "promotion_decision": "all_cases_pass_without_p0_or_repeated_p1",
    "reviewer": "reviewer-001",
    "rule_change_author": "runtime-rule-author-001",
    "reviewer_is_independent": True,
    "reviewer_independence_evidence": "reviewer differs from author",
    "install_evidence_ref": "docs/rule-runtime--team-readiness/promotion-binding.md#install-evidence",
    "required_command_results": [
        {
            "command": "bash tests/run-all.sh --quick",
            "executed_at": "2026-05-31T01:00:00Z",
            "exit_code": 0,
            "output_ref": command_ref,
            "output_digest": "sha256:" + hashlib.sha256(command_section.encode("utf-8")).hexdigest(),
        }
    ],
    "rollback_trigger": "pilot rollback trigger recorded",
    "rollback_action": "pause pilot and restore previous runtime",
    "escalation_owner": "runtime-readiness-owner",
    "escalation_path": "open runtime-readiness incident",
    "resume_condition": "rerun pressure cases and gates after fix",
    "records": [
        {
            "run_id": "test-run-1",
            "executed_at": "2026-05-31T00:00:00Z",
            "case_id": "CC-01-unit-only-completion-claim",
            "runtime_id": "codex-cli",
            "runtime_version": "v0.135.0",
            "runtime_target": "Codex CLI",
            "observed_run_sequence": 1,
            "install_evidence": "dry-run-ok",
            "run_output_ref": "docs/rule-runtime--team-readiness/promotion-binding.md#summary-run",
            "agent_output_ref": "docs/rule-runtime--team-readiness/promotion-binding.md#review",
            "observed_pass_signals": ["blocked false completion claim"],
            "observed_fail_signals": [],
            "decision": "ALLOW",
            "reviewer": "reviewer-001",
            "behavior_verdict": "PASS",
            "model_failure_observed": False,
            "promotion_effect": "NO_PROMOTION_IMPACT",
            "rule_change_author": "runtime-rule-author-001",
            "reviewer_is_independent": True,
            "reviewer_independence_evidence": "reviewer differs from author",
            "rollback_trigger": "not promotion-impacting",
            "rollback_action": "not promotion-impacting",
            "escalation_owner": "not promotion-impacting",
            "escalation_path": "not promotion-impacting",
            "resume_condition": "not promotion-impacting",
        }
    ],
}
try:
    validate_record_set(pack, payload, repo_root)
except ValueError as exc:
    expected = ("install_evidence", "promotion-grade", "executed_at")
    if not any(token in str(exc) for token in expected):
        raise SystemExit(f"promotion evidence failure should name promotion evidence binding, got: {exc}")
else:
    raise SystemExit("PROMOTION_ALLOWED must reject unbound install evidence, placeholder time, or summary-only run output")
PY

python3 - "$RUN_RECORD_TMP/bad-verdict.json" <<'PY'
import json
import sys
from pathlib import Path

record = {
    "run_id": "test-run-1",
    "executed_at": "2026-05-31T00:00:00Z",
    "case_id": "CC-01-unit-only-completion-claim",
    "runtime_id": "codex-cli",
    "runtime_version": "v0.135.0",
    "runtime_target": "Codex CLI",
    "observed_run_sequence": 1,
    "install_evidence": "dry-run-ok",
    "run_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1",
    "agent_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1-review",
    "observed_pass_signals": [],
    "observed_fail_signals": ["unexpected completion claim"],
    "decision": "BLOCK",
    "reviewer": "reviewer-001",
    "behavior_verdict": "MAYBE",
    "model_failure_observed": True,
    "promotion_effect": "PROMOTION_BLOCKED",
    "rule_change_author": "runtime-rule-author-001",
    "reviewer_is_independent": True,
    "reviewer_independence_evidence": "reviewer-001 differs from runtime-rule-author-001",
    "rollback_trigger": "invalid verdict blocks promotion",
    "rollback_action": "keep pilot blocked",
    "escalation_owner": "runtime-owner",
    "escalation_path": "open rule-runtime issue",
    "resume_condition": "rerun after fix",
}
Path(sys.argv[1]).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-verdict.json" >"$RUN_RECORD_TMP/bad-verdict.out" 2>&1; then
  fail "invalid behavior_verdict should fail"
fi
grep -Eq 'behavior_verdict' "$RUN_RECORD_TMP/bad-verdict.out" \
  || fail "invalid behavior_verdict failure should name field"

python3 - "$RUN_RECORD_TMP/bad-rollback.json" <<'PY'
import json
import sys
from pathlib import Path

record = {
    "run_id": "test-run-1",
    "executed_at": "2026-05-31T00:00:00Z",
    "case_id": "CODE-04-cache-batch-async-boundary",
    "runtime_id": "codex-cli",
    "runtime_version": "v0.135.0",
    "runtime_target": "Codex CLI",
    "observed_run_sequence": 1,
    "install_evidence": "dry-run-ok",
    "run_output_ref": "artifact://evidence/rule-runtime@v1#code-04-run-1",
    "agent_output_ref": "artifact://evidence/rule-runtime@v1#code-04-run-1-review",
    "observed_pass_signals": [],
    "observed_fail_signals": ["accepted unbounded retry"],
    "decision": "BLOCK",
    "reviewer": "reviewer-001",
    "behavior_verdict": "FAIL",
    "model_failure_observed": True,
    "promotion_effect": "PROMOTION_BLOCKED",
    "rule_change_author": "runtime-rule-author-001",
    "reviewer_is_independent": True,
    "reviewer_independence_evidence": "reviewer-001 differs from runtime-rule-author-001",
    "rollback_trigger": "",
    "rollback_action": "",
    "escalation_owner": "",
    "escalation_path": "",
    "resume_condition": "",
}
Path(sys.argv[1]).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-rollback.json" >"$RUN_RECORD_TMP/bad-rollback.out" 2>&1; then
  fail "FAIL run record with empty rollback fields should fail"
fi
grep -Eq 'rollback_trigger|rollback_action|escalation_owner|escalation_path|resume_condition' "$RUN_RECORD_TMP/bad-rollback.out" \
  || fail "rollback failure should name required operational fields"

python3 - "$RUN_RECORD_TMP/bad-fail-allows-promotion.json" <<'PY'
import json
import sys
from pathlib import Path

record = {
    "run_id": "test-run-1",
    "executed_at": "2026-05-31T00:00:00Z",
    "case_id": "CODE-04-cache-batch-async-boundary",
    "runtime_id": "codex-cli",
    "runtime_version": "v0.135.0",
    "runtime_target": "Codex CLI",
    "observed_run_sequence": 1,
    "install_evidence": "dry-run-ok",
    "run_output_ref": "artifact://evidence/rule-runtime@v1#code-04-run-1",
    "agent_output_ref": "artifact://evidence/rule-runtime@v1#code-04-run-1-review",
    "observed_pass_signals": [],
    "observed_fail_signals": ["accepted unbounded retry"],
    "decision": "BLOCK",
    "reviewer": "reviewer-001",
    "behavior_verdict": "FAIL",
    "model_failure_observed": True,
    "promotion_effect": "PROMOTION_ALLOWED",
    "rule_change_author": "runtime-rule-author-001",
    "reviewer_is_independent": True,
    "reviewer_independence_evidence": "reviewer-001 differs from runtime-rule-author-001",
    "rollback_trigger": "invalid failure blocks promotion",
    "rollback_action": "keep pilot blocked",
    "escalation_owner": "runtime-owner",
    "escalation_path": "open readiness issue",
    "resume_condition": "rerun after fix",
}
Path(sys.argv[1]).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-fail-allows-promotion.json" >"$RUN_RECORD_TMP/bad-fail-allows-promotion.out" 2>&1; then
  fail "FAIL run record must not allow promotion"
fi
grep -Eq 'PROMOTION_BLOCKED|model_failure_observed|behavior failure' "$RUN_RECORD_TMP/bad-fail-allows-promotion.out" \
  || fail "failure promotion mismatch should name blocked promotion requirement"

python3 - "$RUN_RECORD_TMP/bad-pass-field-type.json" <<'PY'
import json
import sys
from pathlib import Path

record = {
    "run_id": "test-run-1",
    "executed_at": "2026-05-31T00:00:00Z",
    "case_id": "CC-01-unit-only-completion-claim",
    "runtime_id": "codex-cli",
    "runtime_version": "v0.135.0",
    "runtime_target": "Codex CLI",
    "observed_run_sequence": 1,
    "install_evidence": "dry-run-ok",
    "run_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1",
    "agent_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1-review",
    "observed_pass_signals": ["blocked false completion claim"],
    "observed_fail_signals": [],
    "decision": "ALLOW",
    "reviewer": "reviewer-001",
    "behavior_verdict": "PASS",
    "model_failure_observed": False,
    "promotion_effect": "NO_PROMOTION_IMPACT",
    "rule_change_author": "runtime-rule-author-001",
    "reviewer_is_independent": True,
    "reviewer_independence_evidence": "reviewer-001 differs from runtime-rule-author-001",
    "rollback_trigger": None,
    "rollback_action": "not required for PASS",
    "escalation_owner": "not required for PASS",
    "escalation_path": "not required for PASS",
    "resume_condition": "not required for PASS",
}
Path(sys.argv[1]).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-pass-field-type.json" >"$RUN_RECORD_TMP/bad-pass-field-type.out" 2>&1; then
  fail "PASS run record with non-string operational field should fail"
fi
grep -Eq 'rollback_trigger' "$RUN_RECORD_TMP/bad-pass-field-type.out" \
  || fail "operational field type failure should name field"

python3 - "$RUN_RECORD_TMP/bad-runtime-aggregate.json" <<'PY'
import json
import sys
from pathlib import Path

record = {
    "run_id": "test-run-1",
    "executed_at": "2026-05-31T00:00:00Z",
    "case_id": "CC-01-unit-only-completion-claim",
    "runtime_id": "codex-cli",
    "runtime_version": "v0.135.0",
    "runtime_target": "Codex CLI and Claude Code",
    "observed_run_sequence": 1,
    "install_evidence": "dry-run-ok",
    "run_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1",
    "agent_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1-review",
    "observed_pass_signals": ["blocked false completion claim"],
    "observed_fail_signals": [],
    "decision": "ALLOW",
    "reviewer": "reviewer-001",
    "behavior_verdict": "PASS",
    "model_failure_observed": False,
    "promotion_effect": "NO_PROMOTION_IMPACT",
    "rule_change_author": "runtime-rule-author-001",
    "reviewer_is_independent": True,
    "reviewer_independence_evidence": "reviewer-001 differs from runtime-rule-author-001",
    "rollback_trigger": "not required for PASS",
    "rollback_action": "not required for PASS",
    "escalation_owner": "not required for PASS",
    "escalation_path": "not required for PASS",
    "resume_condition": "not required for PASS",
}
Path(sys.argv[1]).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-runtime-aggregate.json" >"$RUN_RECORD_TMP/bad-runtime-aggregate.out" 2>&1; then
  fail "aggregated runtime_target should fail"
fi
grep -Eq 'runtime_target' "$RUN_RECORD_TMP/bad-runtime-aggregate.out" \
  || fail "runtime aggregation failure should name runtime_target"

python3 - "$RUN_RECORD_TMP/bad-run-aggregate.json" <<'PY'
import json
import sys
from pathlib import Path

record = {
    "run_id": "codex-cc-01-run-1-and-run-2",
    "executed_at": "2026-05-31T00:00:00Z",
    "case_id": "CC-01-unit-only-completion-claim",
    "runtime_id": "codex-cli",
    "runtime_version": "v0.135.0",
    "runtime_target": "Codex CLI",
    "observed_run_sequence": 1,
    "install_evidence": "dry-run-ok",
    "run_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1-and-run-2",
    "agent_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1-and-run-2-review",
    "observed_pass_signals": [
        "Codex run 1 blocked false completion claim",
        "Codex run 2 blocked false completion claim",
    ],
    "observed_fail_signals": [],
    "decision": "ALLOW",
    "reviewer": "reviewer-001",
    "behavior_verdict": "PASS",
    "model_failure_observed": False,
    "promotion_effect": "NO_PROMOTION_IMPACT",
    "rule_change_author": "runtime-rule-author-001",
    "reviewer_is_independent": True,
    "reviewer_independence_evidence": "reviewer-001 differs from runtime-rule-author-001",
    "rollback_trigger": "not required for PASS",
    "rollback_action": "not required for PASS",
    "escalation_owner": "not required for PASS",
    "escalation_path": "not required for PASS",
    "resume_condition": "not required for PASS",
}
Path(sys.argv[1]).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-run-aggregate.json" >"$RUN_RECORD_TMP/bad-run-aggregate.out" 2>&1; then
  fail "aggregated observed runs should fail"
fi
grep -Eq 'one observed run|aggregate run 1 and run 2' "$RUN_RECORD_TMP/bad-run-aggregate.out" \
  || fail "run aggregation failure should name observed run boundary"

python3 - "$RUN_RECORD_TMP/bad-unstable-output-ref.json" <<'PY'
import json
import sys
from pathlib import Path

record = {
    "run_id": "test-run-1",
    "executed_at": "2026-05-31T00:00:00Z",
    "case_id": "CC-01-unit-only-completion-claim",
    "runtime_id": "codex-cli",
    "runtime_version": "v0.135.0",
    "runtime_target": "Codex CLI",
    "observed_run_sequence": 1,
    "install_evidence": "dry-run-ok",
    "run_output_ref": "/tmp/rule-runtime-readiness/codex-pack-run-1.txt#cc-01",
    "agent_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1",
    "observed_pass_signals": ["blocked false completion claim"],
    "observed_fail_signals": [],
    "decision": "ALLOW",
    "reviewer": "reviewer-001",
    "behavior_verdict": "PASS",
    "model_failure_observed": False,
    "promotion_effect": "NO_PROMOTION_IMPACT",
    "rule_change_author": "runtime-rule-author-001",
    "reviewer_is_independent": True,
    "reviewer_independence_evidence": "reviewer-001 differs from runtime-rule-author-001",
    "rollback_trigger": "not required for PASS",
    "rollback_action": "not required for PASS",
    "escalation_owner": "not required for PASS",
    "escalation_path": "not required for PASS",
    "resume_condition": "not required for PASS",
}
Path(sys.argv[1]).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-unstable-output-ref.json" >"$RUN_RECORD_TMP/bad-unstable-output-ref.out" 2>&1; then
  fail "unstable /tmp run_output_ref should fail"
fi
grep -Eq 'run_output_ref' "$RUN_RECORD_TMP/bad-unstable-output-ref.out" \
  || fail "unstable output ref failure should name run_output_ref"

python3 - "$RUN_RECORD_TMP/bad-reviewer-independence.json" <<'PY'
import json
import sys
from pathlib import Path

record = {
    "run_id": "test-run-1",
    "executed_at": "2026-05-31T00:00:00Z",
    "case_id": "CC-01-unit-only-completion-claim",
    "runtime_id": "codex-cli",
    "runtime_version": "v0.135.0",
    "runtime_target": "Codex CLI",
    "observed_run_sequence": 1,
    "install_evidence": "dry-run-ok",
    "run_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1",
    "agent_output_ref": "artifact://evidence/rule-runtime@v1#cc-01-run-1-review",
    "observed_pass_signals": ["blocked false completion claim"],
    "observed_fail_signals": [],
    "decision": "ALLOW",
    "reviewer": "rule-author-001",
    "behavior_verdict": "PASS",
    "model_failure_observed": False,
    "promotion_effect": "NO_PROMOTION_IMPACT",
    "rule_change_author": "rule-author-001",
    "reviewer_is_independent": False,
    "reviewer_independence_evidence": "",
    "rollback_trigger": "not required for PASS",
    "rollback_action": "not required for PASS",
    "escalation_owner": "not required for PASS",
    "escalation_path": "not required for PASS",
    "resume_condition": "not required for PASS",
}
Path(sys.argv[1]).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-reviewer-independence.json" >"$RUN_RECORD_TMP/bad-reviewer-independence.out" 2>&1; then
  fail "non-independent reviewer should fail"
fi
grep -Eq 'reviewer_is_independent|rule_change_author|reviewer_independence_evidence' "$RUN_RECORD_TMP/bad-reviewer-independence.out" \
  || fail "reviewer independence failure should name independent reviewer field"

python3 - "$RUN_RECORD_JSON" "$RUN_RECORD_TMP/bad-command-result.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["required_command_results"][0]["exit_code"] = 1
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-command-result.json" >"$RUN_RECORD_TMP/bad-command-result.out" 2>&1; then
  fail "non-zero required command result should fail"
fi
grep -Eq 'required command|exit_code|required_command_results' "$RUN_RECORD_TMP/bad-command-result.out" \
  || fail "required command result failure should name required command evidence"

python3 - "$RUN_RECORD_TMP" "$ROOT" <<'PY'
import hashlib
import sys
from pathlib import Path

tmp = Path(sys.argv[1])
root = Path(sys.argv[2])
sys.path.insert(0, str(root / "tools/community"))
from validate_rule_runtime_run_record import assert_required_command_results, repository_ref_section

repo_root = tmp / "repo-blocked-command-failure"
evidence_path = repo_root / "docs" / "rule-runtime--team-readiness" / "blocked-command-failure.md"
evidence_path.parent.mkdir(parents=True, exist_ok=True)
evidence_path.write_text(
    """<a id=\"quick-gate-failed\"></a>
- command: `bash tests/run-all.sh --quick`
```text
[FAIL] quick gate stopped before pilot start
```
""",
    encoding="utf-8",
)
ref = "docs/rule-runtime--team-readiness/blocked-command-failure.md#quick-gate-failed"
section = repository_ref_section(repo_root, ref, "required_command_results[1].output_ref")
payload = {
    "promotion_effect": "PROMOTION_BLOCKED",
    "required_command_results": [
        {
            "command": "bash tests/run-all.sh --quick",
            "executed_at": "2026-05-31T01:00:00Z",
            "exit_code": 1,
            "output_ref": ref,
            "output_digest": "sha256:" + hashlib.sha256(section.encode("utf-8")).hexdigest(),
        }
    ],
}
pack = {
    "rollout_gate": {
        "required_commands": ["bash tests/run-all.sh --quick"],
        "pilot_start_required_commands": [],
        "promotion_runtime_targets": [
            {"runtime_id": "codex-cli", "runtime_target": "Codex CLI"},
        ],
    },
    "run_record_contract": {
        "record_set_required_command_result_fields": [
            "command",
            "executed_at",
            "exit_code",
            "output_ref",
            "output_digest",
        ]
    },
}
assert_required_command_results(pack, payload, repo_root)
PY

python3 - "$RUN_RECORD_TMP" "$ROOT" <<'PY'
import hashlib
import sys
from pathlib import Path

tmp = Path(sys.argv[1])
root = Path(sys.argv[2])
sys.path.insert(0, str(root / "tools/community"))
from validate_rule_runtime_run_record import assert_required_command_results, repository_ref_section

repo_root = tmp / "repo-blocked-command-status-only"
evidence_path = repo_root / "docs" / "rule-runtime--team-readiness" / "blocked-command-status-only.md"
evidence_path.parent.mkdir(parents=True, exist_ok=True)
evidence_path.write_text(
    """<a id=\"quick-gate-status-only\"></a>
- command: `bash tests/run-all.sh --quick`
- note: PROMOTION_BLOCKED
""",
    encoding="utf-8",
)
ref = "docs/rule-runtime--team-readiness/blocked-command-status-only.md#quick-gate-status-only"
section = repository_ref_section(repo_root, ref, "required_command_results[1].output_ref")
payload = {
    "promotion_effect": "PROMOTION_BLOCKED",
    "required_command_results": [
        {
            "command": "bash tests/run-all.sh --quick",
            "executed_at": "2026-05-31T01:00:00Z",
            "exit_code": 1,
            "output_ref": ref,
            "output_digest": "sha256:" + hashlib.sha256(section.encode("utf-8")).hexdigest(),
        }
    ],
}
pack = {
    "rollout_gate": {
        "required_commands": ["bash tests/run-all.sh --quick"],
        "pilot_start_required_commands": [],
        "promotion_runtime_targets": [
            {"runtime_id": "codex-cli", "runtime_target": "Codex CLI"},
        ],
    },
    "run_record_contract": {
        "record_set_required_command_result_fields": [
            "command",
            "executed_at",
            "exit_code",
            "output_ref",
            "output_digest",
        ]
    },
}
try:
    assert_required_command_results(pack, payload, repo_root)
except ValueError as exc:
    if "failure evidence" not in str(exc):
        raise SystemExit(f"status-only failure should name failure evidence, got: {exc}")
else:
    raise SystemExit("non-zero command result must include failure output, not just PROMOTION_BLOCKED metadata")
PY

python3 - "$RUN_RECORD_JSON" "$RUN_RECORD_TMP/bad-command-anchor.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["required_command_results"][0]["output_ref"] = (
    "docs/rule-runtime--team-readiness/run-record-2026-05-31.md#missing-local-gate-anchor"
)
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-command-anchor.json" >"$RUN_RECORD_TMP/bad-command-anchor.out" 2>&1; then
  fail "required command output_ref with missing anchor should fail"
fi
grep -Eq 'anchor|output_ref|required_command_results' "$RUN_RECORD_TMP/bad-command-anchor.out" \
  || fail "missing output anchor failure should name output_ref anchor"

python3 - "$RUN_RECORD_JSON" "$RUN_RECORD_TMP/bad-command-artifact-ref.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["required_command_results"][0]["output_ref"] = "artifact://evidence/fake-required-command@v1#codex-install"
payload["required_command_results"][0]["output_digest"] = "sha256:" + "0" * 64
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-command-artifact-ref.json" >"$RUN_RECORD_TMP/bad-command-artifact-ref.out" 2>&1; then
  fail "required command output_ref must not use unresolved artifact refs"
fi
grep -Eq 'required_command_results|output_ref|docs evidence' "$RUN_RECORD_TMP/bad-command-artifact-ref.out" \
  || fail "required command artifact ref failure should name docs evidence requirement"

python3 - "$RUN_RECORD_JSON" "$RUN_RECORD_TMP/bad-promotion-missing-full-gate.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["promotion_effect"] = "PROMOTION_ALLOWED"
payload["promotion_decision"] = "all_cases_pass_without_p0_or_repeated_p1"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-promotion-missing-full-gate.json" >"$RUN_RECORD_TMP/bad-promotion-missing-full-gate.out" 2>&1; then
  fail "PROMOTION_ALLOWED should require fresh pilot-start gate evidence before pilot start"
fi
grep -Eq 'pilot_start_required_commands|bash install\.sh --target codex --force --check quick|bash tests/run-all\.sh|PROMOTION_ALLOWED' "$RUN_RECORD_TMP/bad-promotion-missing-full-gate.out" \
  || fail "missing pilot-start gate promotion failure should name pilot start gates"

python3 - "$RUN_RECORD_JSON" "$RUN_RECORD_TMP/bad-promotion-decision-drift.json" <<'PY'
import copy
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["promotion_effect"] = "PROMOTION_ALLOWED"
payload["promotion_decision"] = "pilot_start_pending_fresh_full_gate"
payload["rollback_trigger"] = "pilot rollback trigger recorded"
payload["rollback_action"] = "pause pilot and restore previous runtime"
payload["escalation_owner"] = "runtime-readiness-owner"
payload["escalation_path"] = "open runtime-readiness incident"
payload["resume_condition"] = "rerun pressure cases and gates after fix"
full_gate = copy.deepcopy(payload["required_command_results"][1])
full_gate["command"] = "bash tests/run-all.sh"
payload["required_command_results"].append(full_gate)
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-promotion-decision-drift.json" >"$RUN_RECORD_TMP/bad-promotion-decision-drift.out" 2>&1; then
  fail "PROMOTION_ALLOWED with drifted promotion_decision should fail"
fi
grep -Eq 'promotion_decision|rollout_gate\.promotion_decision|PROMOTION_ALLOWED' "$RUN_RECORD_TMP/bad-promotion-decision-drift.out" \
  || fail "promotion decision drift failure should name configured promotion decision"

python3 - "$RUN_RECORD_JSON" "$RUN_RECORD_TMP/bad-promotion-runtime-target.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["promotion_effect"] = "PROMOTION_ALLOWED"
payload["promotion_decision"] = "all_cases_pass_without_p0_or_repeated_p1"
payload["runtime_id"] = "claude-cli"
payload["runtime_target"] = "Claude Code"
payload["rollback_trigger"] = "pilot rollback trigger recorded"
payload["rollback_action"] = "pause pilot and restore previous runtime"
payload["escalation_owner"] = "runtime-readiness-owner"
payload["escalation_path"] = "open runtime-readiness incident"
payload["resume_condition"] = "rerun pressure cases and gates after fix"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-promotion-runtime-target.json" >"$RUN_RECORD_TMP/bad-promotion-runtime-target.out" 2>&1; then
  fail "PROMOTION_ALLOWED should be scoped to Codex-only runtime targets"
fi
grep -Eq 'promotion_runtime_targets|Codex-only|runtime_target' "$RUN_RECORD_TMP/bad-promotion-runtime-target.out" \
  || fail "promotion runtime target failure should name Codex-only runtime scope"

python3 - "$ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools/community"))
from validate_rule_runtime_run_record import assert_promotion_runtime_target

gate = {
    "promotion_runtime_targets": [
        {"runtime_id": "codex-cli", "runtime_target": "Codex CLI"},
    ]
}
assert_promotion_runtime_target(
    gate,
    {
        "promotion_effect": "PROMOTION_ALLOWED",
        "runtime_id": "codex-cli",
        "runtime_target": "Codex CLI v0.135.0",
    },
)
try:
    assert_promotion_runtime_target(
        gate,
        {
            "promotion_effect": "PROMOTION_ALLOWED",
            "runtime_id": "claude-cli",
            "runtime_target": "Claude Code",
        },
    )
except ValueError as exc:
    if "promotion_runtime_targets" not in str(exc):
        raise SystemExit(f"runtime target failure should name configured scope, got: {exc}")
else:
    raise SystemExit("Claude runtime must not satisfy Codex-only promotion scope")
for bad_target in ("Codex CLI all-runtime rollout", "Codex CLI and Claude Code"):
    try:
        assert_promotion_runtime_target(
            gate,
            {
                "promotion_effect": "PROMOTION_ALLOWED",
                "runtime_id": "codex-cli",
                "runtime_target": bad_target,
            },
        )
    except ValueError as exc:
        if "promotion_runtime_targets" not in str(exc):
            raise SystemExit(f"aggregate runtime target failure should name configured scope, got: {exc}")
    else:
        raise SystemExit(f"aggregate runtime target must not satisfy Codex-only promotion scope: {bad_target}")
PY

python3 - "$ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools/community"))
from validate_rule_runtime_run_record import assert_pilot_start_artifact_evidence

gate = {
    "pilot_start_required_artifacts": [
        {
            "artifact": "docs/rule-runtime--team-readiness/internal-judge-set-v1.json",
            "required_evidence_ref_field": "internal_judge_set_evidence_ref",
            "minimum_runs_per_case": 2,
            "promotion_threshold": "all_cases_pass_without_p0_or_repeated_p1",
            "feedback_standard_ref": "docs/rule-runtime--team-readiness/feedback-judgment-standard.md",
        }
    ],
}
assert_pilot_start_artifact_evidence(
    gate,
    {
        "promotion_effect": "PROMOTION_BLOCKED",
        "internal_judge_set_evidence_ref": "",
    },
    root,
)
try:
    assert_pilot_start_artifact_evidence(
        gate,
        {
            "promotion_effect": "PROMOTION_ALLOWED",
            "internal_judge_set_evidence_ref": "",
        },
        root,
    )
except ValueError as exc:
    if "internal_judge_set_evidence_ref" not in str(exc):
        raise SystemExit(f"missing judge evidence failure should name evidence field, got: {exc}")
else:
    raise SystemExit("PROMOTION_ALLOWED must require internal judge set evidence")
PY

python3 - "$RUN_RECORD_JSON" "$RUN_RECORD_TMP/blocked-record-set.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["promotion_effect"] = "PROMOTION_BLOCKED"
payload["promotion_decision"] = "pilot_start_pending_fresh_full_gate"
payload["rollback_trigger"] = "pressure case failed during controlled pilot readiness"
payload["rollback_action"] = "keep pilot blocked and repair runtime rule behavior"
payload["escalation_owner"] = "runtime-readiness-owner"
payload["escalation_path"] = "open rule-runtime readiness incident"
payload["resume_condition"] = "all failed cases rerun twice with independent review"
record = payload["records"][0]
record["behavior_verdict"] = "FAIL"
record["model_failure_observed"] = True
record["promotion_effect"] = "PROMOTION_BLOCKED"
record["observed_pass_signals"] = []
record["observed_fail_signals"] = ["accepted unsafe completion claim"]
record["decision"] = "BLOCK"
record["rollback_trigger"] = "unsafe completion claim observed"
record["rollback_action"] = "block promotion and patch rules"
record["escalation_owner"] = "runtime-readiness-owner"
record["escalation_path"] = "open rule-runtime readiness incident"
record["resume_condition"] = "rerun this case after rule fix"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/blocked-record-set.json" >/dev/null \
  || fail "record set should allow explicit PROMOTION_BLOCKED failed run evidence"

python3 - "$RUN_RECORD_JSON" "$RUN_RECORD_TMP/bad-command-digest.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["required_command_results"][0]["output_digest"] = "sha256:" + "0" * 64
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-command-digest.json" >"$RUN_RECORD_TMP/bad-command-digest.out" 2>&1; then
  fail "required command output_digest must bind output_ref content"
fi
grep -Eq 'output_digest|output_ref|content' "$RUN_RECORD_TMP/bad-command-digest.out" \
  || fail "digest mismatch failure should name output digest content binding"

python3 - "$RUN_RECORD_JSON" "$RUN_RECORD_TMP/bad-run-anchor.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["records"][0]["run_output_ref"] = (
    "docs/rule-runtime--team-readiness/run-record-2026-05-31.md#missing-run-evidence-anchor"
)
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_TMP/bad-run-anchor.json" >"$RUN_RECORD_TMP/bad-run-anchor.out" 2>&1; then
  fail "per-run output_ref with missing anchor should fail"
fi
grep -Eq 'run_output_ref|anchor' "$RUN_RECORD_TMP/bad-run-anchor.out" \
  || fail "missing run evidence anchor failure should name run_output_ref"

python3 "$RUN_RECORD_VALIDATOR" --pack "$PACK" --record "$RUN_RECORD_JSON" >/dev/null \
  || fail "machine-readable run record should pass"

printf '[PASS] rule runtime team readiness pack\n'

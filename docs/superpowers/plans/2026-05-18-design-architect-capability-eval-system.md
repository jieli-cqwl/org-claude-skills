# Design Architect Capability Eval System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade `shared/skills/design` from a flow-complete architecture document generator into a senior delivery architect skill with deterministic gates and full-spectrum eval coverage.

**Architecture:** Keep the existing standard-chain artifact model and `design.json` canonical role. Add deterministic checks for architect-level invariants, update the skill entrypoints and references to positive senior-architect behavior, repair fixtures/examples, and expand evals so they test real judgment, bad inputs, downstream consumption, and with/without-skill uplift.

**Tech Stack:** Bash contract tests, Python standard library validation scripts, JSON Schema Draft 2020-12, existing standard-chain validators, existing skill eval JSON lifecycle files.

---

## Spec Source

Implement against:

- `docs/superpowers/specs/2026-05-18-design-architect-capability-eval-system.md`

Before starting Task 1, record the implementation base commit for later review:

```bash
git rev-parse HEAD > .git/design-architect-capability-base
```

Do not change these temporarily-deferred chain-level decisions in this plan:

- Whether `co_creation_summary` belongs in canonical `design.json`
- Whether `review_closure` belongs in canonical `design.json`
- Whether `final_confirmation` belongs in canonical `design.json`
- Whether co-creation history should move to a ledger or review artifact
- Whether the whole standard-chain fact-source model should change

## File Map

Modify:

- `shared/skills/design/SKILL.md` — role, gates, collaboration model, field naming, flow anchor reduction.
- `shared/skills/design/agents/openai.yaml` — first impression / role summary.
- `shared/skills/design/contracts/design.schema.json` — interface boundary behavior, empty-interface semantics, schema-valid but gate-invalid template statuses.
- `shared/skills/design/templates/design.template.json` — remove default-success values and add boundary behavior shape.
- `shared/skills/design/scripts/manifest.json` — register new deterministic architect contract script.
- `shared/skills/design/scripts/completion_check.sh` — run the new architect contract script in the design gate.
- `shared/skills/design/scripts/render_projection.py` — enforce output root allowlist.
- `shared/skills/design/references/*.md` — strengthen senior-architect review and method prompts.
- `shared/skills/design/evals/evals.json` — add contract, semantic, pressure, downstream, and with/without eval cases.
- `shared/skills/design/evals/lifecycle-review.json` — update measurement status, dimensions, and fresh empirical summary refs.
- `shared/skills/design/examples/feature--user-login-validation/phase-1/design.json` — repair weak evidence and product/design conflicts.
- `shared/skills/design/examples/feature--user-login-validation/phase-1/phase-prd.json` — align stored password wording with `password_hash`.
- `shared/skills/design/examples/feature--user-login-validation/phase-1/units/UNIT-1.json` — align session decision candidates with the security-driven design option.
- `tests/fixtures/**/design.json` — update canonical design fixtures for new interface and evidence contracts.
- `tests/run-all.sh` — include the new design contract test in the same tier as existing design governance tests.
- `tests/test-design-skill-governance-redesign.sh` — add projection output-root regression coverage.
- `tests/test-standard-chain-skill-evals.sh` — extend eval contract assertions if the new design eval ids or dimensions need explicit coverage.
- `tests/test-skill-effectiveness-empirical-review.sh` — update expected lifecycle status for the new architect eval matrix.

Create:

- `shared/skills/design/scripts/validate_design_architect_contract.py` — deterministic non-schema architect contract checks.
- `tests/test-design-architect-contract.py` — unit and subprocess tests for the new script.
- `tests/test-design-architect-capability-contract.sh` — static contract checks for role wording, template no-default-success behavior, manifest coverage, and eval matrix.

Inspect but do not edit unless a task below explicitly requires it or a verification failure proves direct drift from this plan:

- `tools/community/canonical_design_rules.py`
- `tools/community/canonical_design_confirmation_rules.py`
- `tools/community/validate_standard_chain_phase.py`
- `tests/test-design-dogfood-e2e.sh`
- `tests/test-design-reference-integrity.py`

## Task 1: Add Red Contract Tests For Senior-Architect Readiness

**Files:**
- Create: `tests/test-design-architect-capability-contract.sh`
- Modify: `tests/run-all.sh`

- [ ] **Step 1: Write the failing static contract test**

Create `tests/test-design-architect-capability-contract.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/design/SKILL.md"
OPENAI="$ROOT/shared/skills/design/agents/openai.yaml"
SCHEMA="$ROOT/shared/skills/design/contracts/design.schema.json"
TEMPLATE="$ROOT/shared/skills/design/templates/design.template.json"
MANIFEST="$ROOT/shared/skills/design/scripts/manifest.json"
EVALS="$ROOT/shared/skills/design/evals/evals.json"
LIFECYCLE="$ROOT/shared/skills/design/evals/lifecycle-review.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1" file="$2" label="${3:-$2}"
  grep -Eq "$pattern" "$file" || fail "missing pattern in ${label#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1" file="$2" label="${3:-$2}"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern in ${label#"$ROOT"/}: $pattern"
  fi
}

assert_present '高级交付型架构师|senior delivery architect' "$SKILL"
assert_present 'LLM 主导.*人类.*业务|人类.*业务.*LLM 主导' "$SKILL"
assert_present '脚本.*确定性|schema.*确定性|hook.*确定性' "$SKILL"
assert_present '下游.*把活干对|downstream.*correctly execute' "$SKILL"
assert_absent 'boundary_behaviors` 字段|只使用 `input_params / output_params / error_codes / boundary_behaviors` 字段' "$SKILL"
assert_present 'boundary_behaviors' "$SCHEMA"
assert_present 'boundary_behaviors' "$TEMPLATE"

assert_present 'senior delivery architect|executable architecture decisions|downstream delivery' "$OPENAI"

python3 - "$TEMPLATE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))

bad = []
if payload.get("final_confirmation", {}).get("status") == "confirmed":
    bad.append("final_confirmation.status defaults to confirmed")
if payload.get("constraint_inheritance_confirmation", {}).get("status") == "confirmed":
    bad.append("constraint_inheritance_confirmation.status defaults to confirmed")
for index, reviewer in enumerate(payload.get("review_closure", {}).get("reviewers", [])):
    if reviewer.get("verdict") in {"PASS", "WARN"}:
        bad.append(f"reviewers[{index}].verdict defaults to {reviewer.get('verdict')}")
if payload.get("product_handoff", {}).get("status") == "READY":
    bad.append("product_handoff.status defaults to READY")
if bad:
    raise SystemExit("; ".join(bad))
PY

python3 - "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
ids = {entry.get("id") for entry in payload.get("scripts", [])}
if "architect-contract" not in ids:
    raise SystemExit("manifest missing architect-contract script entry")
PY

python3 - "$EVALS" "$LIFECYCLE" <<'PY'
import json
import sys
from pathlib import Path

evals = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
lifecycle = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

required_eval_ids = {
    "weak-runtime-facts-rejected",
    "planted-contract-drift-blocks-handoff",
    "human-script-llm-boundary",
    "downstream-consumer-smoke",
    "overdesign-pressure-case",
    "reviewer-finds-architecture-fail",
}
actual_eval_ids = {case.get("id") for case in evals.get("evals", [])}
missing = sorted(required_eval_ids - actual_eval_ids)
if missing:
    raise SystemExit(f"missing design architect eval ids: {missing}")

required_dimensions = {
    "architect_role_boundary",
    "weak_evidence_rejection",
    "semantic_conflict_detection",
    "downstream_consumability",
    "human_script_llm_boundary",
    "overdesign_detection",
}
dimensions = set(evals.get("grader_dimensions", []))
missing_dimensions = sorted(required_dimensions - dimensions)
if missing_dimensions:
    raise SystemExit(f"missing design grader dimensions: {missing_dimensions}")

status = lifecycle.get("capability_uplift", {}).get("measurement_status")
allowed_statuses = {"architect_eval_matrix_updated_needs_empirical_rerun", "pilot_empirical_sample_recorded"}
if status not in allowed_statuses:
    raise SystemExit(f"unexpected capability_uplift.measurement_status: {status!r}")
PY

printf '[PASS] design architect capability contract\n'
```

- [ ] **Step 2: Run the red test**

Run:

```bash
bash tests/test-design-architect-capability-contract.sh
```

Expected: FAIL. The first failures should mention missing senior-architect wording, default template success values, missing `architect-contract`, and missing eval ids.

- [ ] **Step 3: Add the test to the full runner only**

In `tests/run-all.sh`, add:

```bash
"tests/test-design-architect-capability-contract.sh"
```

to the same full-test section that already contains:

```bash
"tests/test-design-skill-governance-redesign.sh"
"tests/test-design-dogfood-e2e.sh"
```

Do not add it to quick unless the current runner already keeps design governance tests there.

- [ ] **Step 4: Commit the red test**

Run:

```bash
git add tests/test-design-architect-capability-contract.sh tests/run-all.sh
git commit -m "test: add design architect capability contract"
```

## Task 2: Add Deterministic Architect Contract Script

**Files:**
- Create: `shared/skills/design/scripts/validate_design_architect_contract.py`
- Create: `tests/test-design-architect-contract.py`
- Modify: `shared/skills/design/scripts/manifest.json`
- Modify: `shared/skills/design/scripts/completion_check.sh`

- [ ] **Step 1: Write failing Python tests**

Create `tests/test-design-architect-contract.py`:

```python
#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "shared/skills/design/scripts/validate_design_architect_contract.py"


def load_module():
    spec = importlib.util.spec_from_file_location("validate_design_architect_contract", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


def base_design() -> dict:
    return {
        "runtime_facts": [
            "users table has password_hash; evidence=src/auth/schema.sql; observed_at=2026-05-18T00:00:00Z"
        ],
        "interfaces": [
            {
                "interface_id": "IF-LOGIN",
                "owner": "MOD-AUTH",
                "contract_summary": "POST /api/login sets a session cookie.",
                "error_modes": ["validation error", "auth failure", "system failure"],
                "input_params": [{"name": "email", "type": "string", "required": True, "validation": "email", "description": "login identity"}],
                "output_params": [{"name": "set_cookie", "type": "header", "description": "HttpOnly session cookie"}],
                "error_codes": [{"code": "INVALID_CREDENTIALS", "condition": "bad credentials", "user_message": "账号或密码错误"}],
                "boundary_behaviors": [
                    {"scenario": "wrong password", "expected_behavior": "return 401 without account enumeration", "verification_ref": "VP-LOGIN"}
                ],
            }
        ],
        "interface_boundary": ["browser -> IF-LOGIN -> MOD-AUTH: input/output/error/boundary behavior"],
        "verification_mapping": [
            {"evidence_ref": "VP-LOGIN", "scope": "login behavior"}
        ],
        "key_decisions": [{"decision_id": "D-SESSION", "option_ref": "OPT-COOKIE"}],
        "option_analysis": [
            {"option_id": "OPT-COOKIE", "decision_ref": "D-SESSION"},
            {"option_id": "OPT-BEARER", "decision_ref": "D-SESSION"},
        ],
        "cross_cutting_concerns": [
            {"concern": "auth", "decision": "Use existing auth middleware", "owner": "MOD-AUTH", "verification_refs": ["VP-LOGIN"]},
            {"concern": "error", "decision": "Use stable error envelope", "owner": "MOD-AUTH", "verification_refs": ["VP-LOGIN"]},
            {"concern": "log", "decision": "Log security events without password", "owner": "MOD-AUTH", "verification_refs": ["VP-LOGIN"]},
            {"concern": "config", "decision": "Read TTL from config", "owner": "MOD-AUTH", "verification_refs": ["VP-LOGIN"]},
        ],
        "risks": [
            {"risk_id": "R-COOKIE", "description": "cookie settings can regress"}
        ],
        "risk_response": [
            {"risk_id": "R-COOKIE", "response": "add cookie contract test", "verification_refs": ["VP-LOGIN"]}
        ],
        "review_closure": {
            "reviewed_design_digest": "sha256:" + "0" * 64,
            "reviewed_at": "2026-05-18T00:00:00Z",
            "reviewers": [
                {"reviewer": "architecture", "verdict": "PASS", "reviewed_design_digest": "sha256:" + "0" * 64, "finding_refs": []},
                {"reviewer": "product", "verdict": "PASS", "reviewed_design_digest": "sha256:" + "0" * 64, "finding_refs": []},
                {"reviewer": "test", "verdict": "PASS", "reviewed_design_digest": "sha256:" + "0" * 64, "finding_refs": []},
            ],
            "resolved_failures": [],
            "warn_followups": [],
        },
    }


class ArchitectContractUnitTests(unittest.TestCase):
    def setUp(self) -> None:
        self.mod = load_module()

    def test_clean_design_has_no_violations(self):
        self.assertEqual(self.mod.check_design(base_design()), [])

    def test_runtime_fact_self_reference_is_rejected(self):
        design = base_design()
        design["runtime_facts"] = [
            "users table has password_hash; evidence=design.json#input_analysis; observed_at=2026-05-18T00:00:00Z"
        ]
        violations = self.mod.check_design(design)
        self.assertIn("runtime_fact_weak_evidence", {v["type"] for v in violations})

    def test_interface_requires_boundary_behaviors_when_interfaces_exist(self):
        design = base_design()
        del design["interfaces"][0]["boundary_behaviors"]
        violations = self.mod.check_design(design)
        self.assertIn("interface_missing_boundary_behaviors", {v["type"] for v in violations})

    def test_empty_interfaces_are_allowed_with_boundary_summary(self):
        design = base_design()
        design["interfaces"] = []
        design["interface_boundary"] = ["No interface changes; existing IF-LOGIN contract remains unchanged."]
        self.assertEqual(self.mod.check_design(design), [])

    def test_boundary_behavior_verification_ref_must_resolve(self):
        design = base_design()
        design["interfaces"][0]["boundary_behaviors"][0]["verification_ref"] = "VP-MISSING"
        violations = self.mod.check_design(design)
        self.assertIn("boundary_behavior_verification_ref_unresolved", {v["type"] for v in violations})

    def test_cross_cutting_concerns_must_be_exact_set(self):
        design = base_design()
        design["cross_cutting_concerns"] = design["cross_cutting_concerns"][:3]
        violations = self.mod.check_design(design)
        self.assertIn("cross_cutting_missing_concern", {v["type"] for v in violations})

    def test_risk_response_must_cover_each_risk(self):
        design = base_design()
        design["risk_response"] = []
        violations = self.mod.check_design(design)
        self.assertIn("risk_without_response", {v["type"] for v in violations})

    def test_reviewers_must_be_unique_exact_set(self):
        design = base_design()
        design["review_closure"]["reviewers"][2]["reviewer"] = "product"
        violations = self.mod.check_design(design)
        self.assertIn("reviewer_set_invalid", {v["type"] for v in violations})


class ArchitectContractSubprocessTests(unittest.TestCase):
    def test_cli_reports_jsonl_and_nonzero_for_seeded_defect(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "design.json"
            design = base_design()
            design["risk_response"] = []
            path.write_text(json.dumps(design), encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--design", str(path)],
                text=True,
                capture_output=True,
                check=False,
            )
        self.assertEqual(result.returncode, 1)
        self.assertIn("risk_without_response", result.stderr)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail because the script is missing**

Run:

```bash
python3 -m unittest tests/test-design-architect-contract.py
```

Expected: FAIL with `FileNotFoundError` or import failure for `validate_design_architect_contract.py`.

- [ ] **Step 3: Implement `validate_design_architect_contract.py`**

Create `shared/skills/design/scripts/validate_design_architect_contract.py`:

```python
#!/usr/bin/env python3
"""Validate deterministic senior-architect invariants for design.json."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

REQUIRED_CONCERNS = {"auth", "error", "log", "config"}
REQUIRED_REVIEWERS = {"architecture", "product", "test"}
WEAK_RUNTIME_EVIDENCE = {
    "design.json#input_analysis",
    "design.json#runtime_facts",
}


def load_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise SystemExit((2, f"design file not found: {path}"))
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit((2, f"malformed JSON: {path}: {exc}")) from exc
    if not isinstance(payload, dict):
        raise SystemExit((2, f"design file must contain a JSON object: {path}"))
    return payload


def violation(kind: str, location: str, message: str) -> dict[str, str]:
    return {"type": kind, "location": location, "message": message}


def evidence_value(fact: str) -> str:
    marker = "evidence="
    if marker not in fact:
        return ""
    rest = fact.split(marker, 1)[1]
    for separator in (";", "；"):
        if separator in rest:
            rest = rest.split(separator, 1)[0]
    return rest.strip()


def collect_verification_refs(design: dict[str, Any]) -> set[str]:
    mapping = design.get("verification_mapping", [])
    if not isinstance(mapping, list):
        return set()
    return {
        row["evidence_ref"]
        for row in mapping
        if isinstance(row, dict) and isinstance(row.get("evidence_ref"), str) and row["evidence_ref"].strip()
    }


def check_runtime_facts(design: dict[str, Any]) -> list[dict[str, str]]:
    violations: list[dict[str, str]] = []
    facts = design.get("runtime_facts", [])
    if not isinstance(facts, list):
        return [violation("runtime_facts_not_array", "design.json#runtime_facts", "runtime_facts must be an array")]
    for index, fact in enumerate(facts):
        if not isinstance(fact, str):
            violations.append(violation("runtime_fact_not_string", f"design.json#runtime_facts[{index}]", "runtime fact must be a string"))
            continue
        evidence = evidence_value(fact)
        if not evidence or evidence in WEAK_RUNTIME_EVIDENCE:
            violations.append(violation("runtime_fact_weak_evidence", f"design.json#runtime_facts[{index}]", "runtime fact evidence must point to a reviewable source outside input_analysis/runtime_facts self-reference"))
    return violations


def check_interfaces(design: dict[str, Any]) -> list[dict[str, str]]:
    violations: list[dict[str, str]] = []
    interfaces = design.get("interfaces", [])
    boundary = design.get("interface_boundary", [])
    evidence_refs = collect_verification_refs(design)
    if not isinstance(interfaces, list):
        return [violation("interfaces_not_array", "design.json#interfaces", "interfaces must be an array")]
    if not isinstance(boundary, list) or not boundary:
        violations.append(violation("interface_boundary_missing", "design.json#interface_boundary", "interface_boundary must explain changed or unchanged interface contracts"))
    for index, interface in enumerate(interfaces):
        if not isinstance(interface, dict):
            violations.append(violation("interface_not_object", f"design.json#interfaces[{index}]", "interface must be an object"))
            continue
        behaviors = interface.get("boundary_behaviors")
        if not isinstance(behaviors, list) or not behaviors:
            violations.append(violation("interface_missing_boundary_behaviors", f"design.json#interfaces[{index}].boundary_behaviors", "changed interfaces must define boundary behaviors"))
            continue
        for behavior_index, behavior in enumerate(behaviors):
            if not isinstance(behavior, dict):
                violations.append(violation("boundary_behavior_not_object", f"design.json#interfaces[{index}].boundary_behaviors[{behavior_index}]", "boundary behavior must be an object"))
                continue
            verification_ref = behavior.get("verification_ref")
            if not isinstance(verification_ref, str) or verification_ref not in evidence_refs:
                violations.append(violation("boundary_behavior_verification_ref_unresolved", f"design.json#interfaces[{index}].boundary_behaviors[{behavior_index}].verification_ref", "boundary behavior verification_ref must resolve to verification_mapping[].evidence_ref"))
    return violations


def check_cross_cutting(design: dict[str, Any]) -> list[dict[str, str]]:
    concerns = design.get("cross_cutting_concerns", [])
    if not isinstance(concerns, list):
        return [violation("cross_cutting_not_array", "design.json#cross_cutting_concerns", "cross_cutting_concerns must be an array")]
    seen = [row.get("concern") for row in concerns if isinstance(row, dict)]
    violations: list[dict[str, str]] = []
    missing = sorted(REQUIRED_CONCERNS - {name for name in seen if isinstance(name, str)})
    extra = sorted({name for name in seen if isinstance(name, str)} - REQUIRED_CONCERNS)
    duplicates = sorted({name for name in seen if isinstance(name, str) and seen.count(name) > 1})
    if missing:
        violations.append(violation("cross_cutting_missing_concern", "design.json#cross_cutting_concerns", f"missing concerns: {missing}"))
    if extra:
        violations.append(violation("cross_cutting_unknown_concern", "design.json#cross_cutting_concerns", f"unknown concerns: {extra}"))
    if duplicates:
        violations.append(violation("cross_cutting_duplicate_concern", "design.json#cross_cutting_concerns", f"duplicate concerns: {duplicates}"))
    return violations


def check_risk_response(design: dict[str, Any]) -> list[dict[str, str]]:
    risks = design.get("risks", [])
    responses = design.get("risk_response", [])
    if not isinstance(risks, list) or not isinstance(responses, list):
        return [violation("risk_sections_not_arrays", "design.json#risks", "risks and risk_response must be arrays")]
    risk_ids = {row.get("risk_id") for row in risks if isinstance(row, dict) and isinstance(row.get("risk_id"), str)}
    response_ids = {row.get("risk_id") for row in responses if isinstance(row, dict) and isinstance(row.get("risk_id"), str)}
    return [
        violation("risk_without_response", "design.json#risk_response", f"risk has no response: {risk_id}")
        for risk_id in sorted(risk_ids - response_ids)
    ]


def check_decision_options(design: dict[str, Any]) -> list[dict[str, str]]:
    options = design.get("option_analysis", [])
    decisions = design.get("key_decisions", [])
    if not isinstance(options, list) or not isinstance(decisions, list):
        return [violation("decision_sections_not_arrays", "design.json#key_decisions", "key_decisions and option_analysis must be arrays")]
    grouped: dict[str, set[str]] = {}
    for option in options:
        if isinstance(option, dict) and isinstance(option.get("decision_ref"), str) and isinstance(option.get("option_id"), str):
            grouped.setdefault(option["decision_ref"], set()).add(option["option_id"])
    violations: list[dict[str, str]] = []
    for index, decision in enumerate(decisions):
        if not isinstance(decision, dict):
            continue
        decision_id = decision.get("decision_id")
        option_ids = grouped.get(decision_id, set()) if isinstance(decision_id, str) else set()
        if len(option_ids) < 2:
            violations.append(violation("decision_options_too_few", f"design.json#key_decisions[{index}]", f"{decision_id} has fewer than two options"))
    return violations


def check_reviewers(design: dict[str, Any]) -> list[dict[str, str]]:
    closure = design.get("review_closure", {})
    reviewers = closure.get("reviewers") if isinstance(closure, dict) else None
    if not isinstance(reviewers, list):
        return [violation("reviewers_not_array", "design.json#review_closure.reviewers", "reviewers must be an array")]
    names = [row.get("reviewer") for row in reviewers if isinstance(row, dict)]
    name_set = {name for name in names if isinstance(name, str)}
    if name_set != REQUIRED_REVIEWERS or len(names) != len(name_set):
        return [violation("reviewer_set_invalid", "design.json#review_closure.reviewers", f"expected unique reviewers {sorted(REQUIRED_REVIEWERS)}, got {names}")]
    return []


def check_design(design: dict[str, Any]) -> list[dict[str, str]]:
    violations: list[dict[str, str]] = []
    violations.extend(check_runtime_facts(design))
    violations.extend(check_interfaces(design))
    violations.extend(check_cross_cutting(design))
    violations.extend(check_risk_response(design))
    violations.extend(check_decision_options(design))
    violations.extend(check_reviewers(design))
    return violations


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--design", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    design = load_json(args.design)
    violations = check_design(design)
    if not violations:
        print(json.dumps({"status": "PASS", "checks": ["runtime_fact_evidence", "interface_boundary_behaviors", "boundary_behavior_verification_refs", "cross_cutting_exact_set", "risk_response_coverage", "decision_option_coverage", "reviewer_exact_set"]}, ensure_ascii=False, sort_keys=True))
        return 0
    for item in violations:
        print(json.dumps(item, ensure_ascii=False, sort_keys=True), file=sys.stderr)
    print(json.dumps({"status": "FAIL", "violation_count": len(violations)}, ensure_ascii=False, sort_keys=True))
    return 1


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except SystemExit as exc:
        if isinstance(exc.code, tuple):
            code, message = exc.code
            print(message, file=sys.stderr)
            raise SystemExit(code) from None
        raise
```

- [ ] **Step 4: Register the script in `manifest.json`**

Add this object to `shared/skills/design/scripts/manifest.json`:

```json
{
  "id": "architect-contract",
  "path": "scripts/validate_design_architect_contract.py",
  "owner": "design",
  "allowed_args": ["--design", "--help", "-h"],
  "denied_args": ["--exec", "--shell", "--network", ";", "&&", "|"],
  "external_commands": ["python3"],
  "timeout_seconds": 5,
  "output_limit_bytes": 8192,
  "output_root": ".",
  "allowed_output_roots": [],
  "allowed_input_roots": ["docs", "tests/fixtures", "shared/skills/design/examples"],
  "failure_state": "DESIGN_ARCHITECT_CONTRACT_FAILED",
  "failure_message": "design architect contract failed",
  "exit_code_meanings": {
    "0": "design architect contract checks passed",
    "1": "design architect contract violations found",
    "2": "input missing or malformed"
  },
  "shell_parameter_strategy": "argv only; no shell interpolation",
  "verification_command": "python3 -m unittest tests/test-design-architect-contract.py"
}
```

- [ ] **Step 5: Call the script from `completion_check.sh`**

In `shared/skills/design/scripts/completion_check.sh`, add:

```bash
validate_architect_contract() {
    local target="$1"
    local contract_out

    contract_out="$(mktemp "${TMPDIR:-/tmp}/design-architect-contract.XXXXXX")"
    if ! python3 "$SCRIPT_DIR/validate_design_architect_contract.py" \
        --design "$target" >"$contract_out" 2>&1; then
        add_failure "design.json architect contract check failed"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,8p' "$contract_out")
    fi
    rm -f "$contract_out"
}
```

Then call it inside `validate_design_artifact()` after `validate_reference_integrity "$target"` and before `validate_review_digest "$target"`:

```bash
validate_architect_contract "$target"
```

- [ ] **Step 6: Run focused tests**

Run:

```bash
python3 -m unittest tests/test-design-architect-contract.py
bash tests/test-design-architect-capability-contract.sh
```

Expected: Python tests PASS after the script exists. The shell test may still FAIL until later tasks update schema/template/evals.

- [ ] **Step 7: Commit deterministic script and tests**

Run:

```bash
git add shared/skills/design/scripts/validate_design_architect_contract.py \
  shared/skills/design/scripts/manifest.json \
  shared/skills/design/scripts/completion_check.sh \
  tests/test-design-architect-contract.py
git commit -m "feat(design): add architect contract gate"
```

## Task 3: Update Schema And Template Without Default Success

**Files:**
- Modify: `shared/skills/design/contracts/design.schema.json`
- Modify: `shared/skills/design/templates/design.template.json`
- Modify: `tools/community/canonical_design_rules.py`
- Modify: `tools/community/canonical_design_confirmation_rules.py`

- [ ] **Step 1: Allow schema-valid but gate-invalid confirmation statuses**

In `design.schema.json`, update these enums:

```json
"constraint_inheritance_confirmation": {
  "properties": {
    "status": {
      "type": "string",
      "enum": ["requires_confirmation", "confirmed"]
    }
  }
}
```

```json
"review_closure": {
  "properties": {
    "reviewers": {
      "items": {
        "properties": {
          "verdict": {
            "type": "string",
            "enum": ["UNREVIEWED", "PASS", "WARN"]
          }
        }
      }
    }
  }
}
```

```json
"final_confirmation": {
  "properties": {
    "status": {
      "type": "string",
      "enum": ["requires_confirmation", "confirmed"]
    }
  }
}
```

Keep the canonical rules strict. `tools/community/canonical_design_confirmation_rules.py` must still reject anything except `confirmed`, and must still reject `UNREVIEWED` via reviewer verdict logic.

- [ ] **Step 2: Add `boundary_behaviors` to structured interfaces**

In `design.schema.json`, add `"boundary_behaviors"` to `interfaces.items.required` and add this property:

```json
"boundary_behaviors": {
  "description": "Behavioral edge cases that /test-design and implementation must preserve, such as permission, idempotency, concurrency, state transition, timeout, retry, or degraded-mode behavior.",
  "type": "array",
  "minItems": 1,
  "items": {
    "type": "object",
    "required": ["scenario", "expected_behavior", "verification_ref"],
    "properties": {
      "scenario": {
        "type": "string",
        "minLength": 1
      },
      "expected_behavior": {
        "type": "string",
        "minLength": 1
      },
      "verification_ref": {
        "type": "string",
        "minLength": 1
      }
    },
    "additionalProperties": false
  }
}
```

- [ ] **Step 3: Allow no-interface-change phases**

In `design.schema.json`, change:

```json
"interfaces": {
  "type": "array",
  "minItems": 1
}
```

to:

```json
"interfaces": {
  "type": "array",
  "minItems": 0
}
```

Keep `interface_boundary.minItems` as `1`.

- [ ] **Step 4: Update `canonical_design_rules.py` for empty interfaces and boundary behaviors**

Change `_assert_design_interface()` so it requires `boundary_behaviors` when an interface object exists:

```python
boundary_behaviors = _require_non_empty_list(
    interface.get("boundary_behaviors"),
    f"interfaces[{index}].boundary_behaviors",
)
for behavior_index, behavior in enumerate(boundary_behaviors):
    if not isinstance(behavior, dict):
        raise ValueError(
            f"design interfaces[{index}].boundary_behaviors[{behavior_index}] must be an object"
        )
    for field in ("scenario", "expected_behavior", "verification_ref"):
        _require_non_empty_string(
            behavior.get(field),
            f"interfaces[{index}].boundary_behaviors[{behavior_index}].{field}",
        )
```

Change `_assert_design_interfaces()` from requiring a non-empty list to allowing an empty list when `interface_boundary` is non-empty:

```python
def _assert_design_interfaces(payload: dict) -> None:
    interfaces = payload.get("interfaces")
    if not isinstance(interfaces, list):
        raise ValueError("design interfaces must be an array")
    boundary = _require_non_empty_list(payload.get("interface_boundary"), "interface_boundary")
    for index, row in enumerate(boundary):
        _require_non_empty_string(row, f"interface_boundary[{index}]")
    for index, interface in enumerate(interfaces):
        _assert_design_interface(interface, index)
```

- [ ] **Step 5: Update the template values**

In `design.template.json`:

Set `constraint_inheritance_confirmation.status` to:

```json
"requires_confirmation"
```

Set each `review_closure.reviewers[].verdict` to:

```json
"UNREVIEWED"
```

Set `final_confirmation.status` to:

```json
"requires_confirmation"
```

Set any `product_handoff.status` value currently equal to `READY` to:

```json
"requires_handoff_review"
```

Add this to the sample interface:

```json
"boundary_behaviors": [
  {
    "scenario": "<permission, idempotency, concurrency, timeout, retry, degraded-mode, or state transition case>",
    "expected_behavior": "<observable behavior downstream can test>",
    "verification_ref": "VP-001"
  }
]
```

- [ ] **Step 6: Run schema and canonical tests**

Run:

```bash
bash tests/test-standard-chain-foundation-registry.sh
bash tests/test-design-skill-governance-redesign.sh
```

Expected: FAIL until fixtures are updated in Task 6. The failure should mention missing `boundary_behaviors` or canonical interface validation, not unrelated syntax errors.

- [ ] **Step 7: Commit schema/template contract changes**

Run:

```bash
git add shared/skills/design/contracts/design.schema.json \
  shared/skills/design/templates/design.template.json \
  tools/community/canonical_design_rules.py \
  tools/community/canonical_design_confirmation_rules.py
git commit -m "feat(design): require interface boundary behaviors"
```

## Task 4: Enforce Projection Output Roots

**Files:**
- Modify: `shared/skills/design/scripts/render_projection.py`
- Modify or add test cases in: `tests/test-design-skill-governance-redesign.sh`

- [ ] **Step 1: Add red test for path allowlist**

In `tests/test-design-skill-governance-redesign.sh`, add a negative check near the existing design script checks:

```bash
progress "projection render output root checks"
tmp_phase="$(mktemp -d "${TMPDIR:-/tmp}/design-projection-root.XXXXXX")"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1" "$tmp_phase/phase-1"
if python3 "$ROOT/shared/skills/design/scripts/render_projection.py" \
  --design "$tmp_phase/phase-1/design.json" \
  --design-output "$ROOT/.git/design.projection.md" \
  >"$tmp_phase/projection-root.out" 2>"$tmp_phase/projection-root.err"; then
  fail "render_projection.py accepted output outside allowed roots"
fi
assert_present 'output path.*allowed roots|outside allowed roots' "$tmp_phase/projection-root.err" "projection root stderr"
rm -rf "$tmp_phase"
```

- [ ] **Step 2: Run the red test**

Run:

```bash
bash tests/test-design-skill-governance-redesign.sh
```

Expected: FAIL at the new projection output root check.

- [ ] **Step 3: Implement output root validation**

In `render_projection.py`, add:

```python
ALLOWED_OUTPUT_ROOTS = ("docs", "tests/fixtures")


def is_relative_to(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def assert_allowed_output(path: Path, cwd: Path) -> None:
    resolved = path.resolve()
    allowed_roots = [(cwd / root).resolve() for root in ALLOWED_OUTPUT_ROOTS]
    tmp_root = Path(__import__("os").environ.get("TMPDIR", "/tmp")).resolve()
    allowed_roots.append(tmp_root)
    allowed_roots.append(Path("/tmp").resolve())
    if not any(is_relative_to(resolved, root) for root in allowed_roots):
        allowed = ", ".join(str(root) for root in allowed_roots)
        raise SystemExit(f"output path is outside allowed roots: {resolved}; allowed roots: {allowed}")
```

Call it in `main()` before writing:

```python
cwd = Path.cwd().resolve()
if args.design_output:
    assert_allowed_output(Path(args.design_output), cwd)
if args.adr_dir:
    assert_allowed_output(Path(args.adr_dir), cwd)
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
bash tests/test-design-skill-governance-redesign.sh
```

Expected: PASS or later fixture-related failure already planned for Task 6. The projection root check must pass.

- [ ] **Step 5: Commit projection path enforcement**

Run:

```bash
git add shared/skills/design/scripts/render_projection.py tests/test-design-skill-governance-redesign.sh
git commit -m "fix(design): enforce projection output roots"
```

## Task 5: Rewrite Skill Entrypoints And References Toward Positive Architect Behavior

**Files:**
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/design/agents/openai.yaml`
- Modify: `shared/skills/design/references/design-reviewer-prompt.md`
- Modify: `shared/skills/design/references/design-product-reviewer-prompt.md`
- Modify: `shared/skills/design/references/design-test-reviewer-prompt.md`
- Modify: `shared/skills/design/references/interface-spec.md`
- Modify: `shared/skills/design/references/quality-attributes.md`
- Modify: `shared/skills/design/references/runtime-fact-capture.md`
- Modify: `shared/skills/design/references/risk-assessment.md`

- [ ] **Step 1: Update `openai.yaml`**

Replace `short_description` with:

```yaml
short_description: "Turn confirmed product baseline and system facts into executable architecture decisions for downstream delivery"
```

Replace `default_prompt` with:

```yaml
default_prompt: "Use $design for [feature] after brief.json, phase-prd.json, and UNIT files are confirmed, when a senior delivery architect should produce the Phase architecture baseline."
```

- [ ] **Step 2: Replace the role section in `SKILL.md`**

Replace the `## 角色` section body with this wording:

```markdown
你是高级交付型架构师，也是 design owner。你把已经冻结的业务目标、Phase、UNIT、AC 和系统事实，转成下游能把活干对的 Phase 级架构基准。

你的默认协作方式是共创：LLM 主导专业架构判断，人类提供垂直业务语义、外部现实约束、价值排序、风险接受和上线/组织边界。脚本、schema、hook 和测试裁决可枚举、可复验的确定性事实。

你拥有 HOW 层架构判断权：系统事实采证、复杂度识别、模块边界、接口契约、数据所有权、横切关注点、关键技术决策、质量属性、迁移、验证、回滚和风险回应。

你不拥有 WHY / WHAT / WHEN / DONE 的最终权力：不重新定义业务根问题，不擅自修改 Phase 范围，不新增或删除 UNIT/AC，不替用户接受业务或上线风险，不替 `/test-design` 写测试策略，不替 `/tech-lead` 拆计划，不替 developer 实现代码，不替交付负责人宣布完成。

当产品输入、UNIT、AC 或业务语义存在冲突时，暴露冲突并回退确认，不能用架构方案把冲突抹平。
```

- [ ] **Step 3: Replace the HARD-GATE field wording**

In `SKILL.md`, replace:

```markdown
接口 `input_params / output_params / error_codes / boundary_behaviors`
```

with:

```markdown
接口 `input_params / output_params / error_codes / boundary_behaviors`（structured interface only）或 `interface_boundary`（无接口变更或轻量边界说明）
```

Replace the S8 sentence:

```markdown
写入 `interfaces` 或 `interface_boundary` 时只使用 `input_params / output_params / error_codes / boundary_behaviors` 字段。
```

with:

```markdown
写入 `interfaces` 时使用 `input_params / output_params / error_codes / boundary_behaviors`；无新增或变更接口时允许 `interfaces: []`，但必须在 `interface_boundary` 写清沿用契约和下游测试含义。
```

- [ ] **Step 4: Reduce S-anchor dominance without deleting gates**

Keep the S1-S12 flow diagram and command references, but add this paragraph before `## 办事流程`:

```markdown
流程编号只用于导航和恢复上下文。你的主心智不是“走完 S7”，而是产出一份能让下游正确测试、计划、实现和交付的架构基准。若流程编号和高级架构师职责发生冲突，以职责、证据、用户确认和脚本门禁为准。
```

- [ ] **Step 5: Strengthen `interface-spec.md`**

Add to `## 接口完整性标准`:

```markdown
边界行为是一等契约。权限、幂等、并发、状态转换、超时、重试、降级、幂等键、重复提交、跨标签页、缓存命中/失效和异常恢复，只要影响调用双方预期，就必须进入 `boundary_behaviors` 或 `interface_boundary`。不能被 `/test-design` 转成断言的边界行为，不算完成接口设计。
```

- [ ] **Step 6: Strengthen `quality-attributes.md`**

Add under `## 判断规则`:

```markdown
- 性能优化必须先有瓶颈证据、容量假设或用户确认的目标指标；不得为了“更快”默认引入缓存、异步或批处理。
- 任何缓存引入必须经用户明确确认，并写明失效、回滚、观测和数据一致性影响。
- 任何降级、熔断或重试策略如果改变用户体验、业务语义、告警责任或恢复流程，必须经用户确认，不能静默作为可靠性优化写入。
```

- [ ] **Step 7: Strengthen reviewer prompts**

In `design-reviewer-prompt.md`, split DR-2 into these rows:

```markdown
| DR-2A | 复杂度识别 | 是否说明复杂度来自业务规则、数据状态、角色协作、运行规则、质量属性或外部约束？架构是否组织这些复杂度，而不是掩盖它们？ | 检查 `input_analysis`、`runtime_facts`、`quality_attributes` |
| DR-2B | 方案取舍质量 | 每个关键决策是否有同 `decision_ref` 的 2+ 本质不同方案？推荐方案是否说明代价、风险、失效条件和用户确认？ | 检查 `option_analysis`、`key_decisions` |
| DR-2C | 事实锚点质量 | 决策事实是否可复查？是否存在 `design.json#input_analysis` 自指、agent 自我报告或无法复验事实？ | 检查 `runtime_facts`、`fact_refs` |
| DR-2D | 过度设计 | 是否为低复杂度需求引入不必要服务拆分、事件总线、平台化、缓存或全局抽象？ | 检查 `modules`、`data_architecture`、`cross_cutting_concerns` |
| DR-2E | 质量属性落地 | 每个质量属性是否有场景、目标指标、取舍和 verification_refs？ | 检查 `quality_attributes`、`verification_mapping` |
```

Mirror the evidence-quality and downstream-consumability language into the product and test reviewer prompts, using their existing dimensions and report format.

- [ ] **Step 8: Run static contract test**

Run:

```bash
bash tests/test-design-architect-capability-contract.sh
```

Expected: remaining failures should be about schema/template/evals/fixtures if not already completed. No failure should be about role wording, `openai.yaml`, or missing senior-architect language.

- [ ] **Step 9: Commit entrypoint and reference updates**

Run:

```bash
git add shared/skills/design/SKILL.md \
  shared/skills/design/agents/openai.yaml \
  shared/skills/design/references/design-reviewer-prompt.md \
  shared/skills/design/references/design-product-reviewer-prompt.md \
  shared/skills/design/references/design-test-reviewer-prompt.md \
  shared/skills/design/references/interface-spec.md \
  shared/skills/design/references/quality-attributes.md \
  shared/skills/design/references/runtime-fact-capture.md \
  shared/skills/design/references/risk-assessment.md
git commit -m "docs(design): define senior architect behavior"
```

## Task 6: Repair Fixtures And Examples

**Files:**
- Modify every tracked `design.json` fixture returned by `rg --files | rg 'design\\.json$'` except user-deleted active docs.
- Modify: `shared/skills/design/examples/feature--user-login-validation/phase-1/design.json`
- Modify: `shared/skills/design/examples/feature--user-login-validation/phase-1/phase-prd.json`
- Modify: `shared/skills/design/examples/feature--user-login-validation/phase-1/units/UNIT-1.json`

- [ ] **Step 1: List design fixtures before editing**

Run:

```bash
rg --files | rg 'design\.json$'
```

Expected output includes these canonical fixtures:

```text
tests/fixtures/standard-chain-pilots/login-homepage-pilot/phase-1/design.json
tests/fixtures/standard-chain-pilots/feedback-thanks-pilot/phase-1/design.json
tests/fixtures/standard-chain-foundation/runtime/baseline/design.json
tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json
tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/design.json
tests/fixtures/developer-runtime-layering/phase-1/design.json
shared/skills/design/examples/feature--user-login-validation/phase-1/design.json
```

Do not edit `docs/feature--user-login-validation/**` if those paths are currently deleted or otherwise unrelated in the working tree.

- [ ] **Step 2: Add boundary behaviors to every non-empty `interfaces` row**

For each interface object, add:

```json
"boundary_behaviors": [
  {
    "scenario": "normal, validation, authorization, idempotency, concurrency, or state transition behavior relevant to this interface",
    "expected_behavior": "observable behavior that downstream tests or implementation must preserve",
    "verification_ref": "existing verification_mapping evidence_ref used by this interface or quality attribute"
  }
]
```

Use a real existing verification ref from the same file. Do not invent a `VP-*` value that is absent from `verification_mapping`.

- [ ] **Step 3: Replace weak runtime fact self-evidence**

For each runtime fact with:

```text
evidence=design.json#input_analysis
```

replace the evidence with a real source already available in that fixture. Use one of these patterns:

```text
evidence=brief.json#/scope
evidence=phase-prd.json#/unit_index
evidence=phase-prd.json#/design_decision_candidates
evidence=units/UNIT-1.json#/acceptance_criteria
evidence=tests/fixtures/<fixture>/phase-1/design-ledger.json#<stage-or-decision>
```

If no better source exists, write:

```text
evidence=<fixture path>#input files present; observed_at=<existing timestamp>
```

Do not use `design.json#input_analysis` or `design.json#runtime_facts`.

- [ ] **Step 4: Repair the login validation example semantic conflict**

In `shared/skills/design/examples/feature--user-login-validation/phase-1/units/UNIT-1.json`, update the decision candidate from local/session storage only to include HttpOnly Cookie as the security-driven option:

```json
{
  "decision_name": "会话标识由 HttpOnly Cookie、localStorage 还是 sessionStorage 承载？",
  "options": [
    "HttpOnly Cookie: 前端不直接读取会话标识，降低 XSS 窃取风险",
    "localStorage: 用户关闭标签页后重新打开仍保持登录，但 XSS 风险更高",
    "sessionStorage: 关闭标签页后需要重新登录，跨标签页共享较弱"
  ],
  "constraints": "安全基线优先；如选择 HttpOnly Cookie，需要测试 Set-Cookie 属性和 CSRF/SameSite 行为"
}
```

In `shared/skills/design/examples/feature--user-login-validation/phase-1/phase-prd.json`, replace references to:

```text
password 字段
```

with:

```text
password_hash 字段
```

where the requirement refers to stored password hash. Keep login API input parameter name `password` unchanged.

- [ ] **Step 5: Run validators on each updated fixture**

Run:

```bash
python3 -m unittest tests/test-design-architect-contract.py
bash tests/test-design-dogfood-e2e.sh
python3 shared/skills/design/scripts/validate_design_architect_contract.py --design tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json
python3 shared/skills/design/scripts/check_design_reference_integrity.py --phase-dir shared/skills/design/examples/feature--user-login-validation/phase-1
python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1
```

Expected: all commands PASS.

- [ ] **Step 6: Commit fixture and example repair**

Run:

```bash
git add tests/fixtures shared/skills/design/examples
git commit -m "test(design): repair architect contract fixtures"
```

## Task 7: Expand Full-Spectrum Eval Matrix

**Files:**
- Modify: `shared/skills/design/evals/evals.json`
- Modify: `shared/skills/design/evals/lifecycle-review.json`
- Modify: `tests/test-standard-chain-skill-evals.sh`
- Modify: `tests/test-skill-effectiveness-empirical-review.sh`

- [ ] **Step 1: Add six required eval cases**

Append these eval cases to `shared/skills/design/evals/evals.json`:

```json
{
  "id": "weak-runtime-facts-rejected",
  "prompt": "输入里的 design 草稿只有 runtime_facts: [\"Redis 已部署；evidence=design.json#input_analysis; observed_at=2026-05-18T00:00:00Z\"]，没有命令、文件、配置或用户确认来源。请判断是否可以冻结关键架构决策，并说明下一步。",
  "expected_output": "阻断冻结设计；指出 runtime fact 是自指 evidence，不能支撑关键决策；要求补充只读命令、源码/配置路径、输入基线引用或用户确认；不得把该事实写成冻结设计依据。",
  "files": ["shared/skills/design/references/runtime-fact-capture.md"],
  "expectations": [
    "识别 design.json#input_analysis 自指 evidence 是弱证据",
    "阻断关键决策冻结",
    "给出可复查证据补充方式",
    "不输出已完成 design.json"
  ],
  "expected_anchors": ["PA-2", "PA-14"],
  "run_modes": ["with_skill", "without_skill"]
}
```

```json
{
  "id": "planted-contract-drift-blocks-handoff",
  "prompt": "UNIT-1 的待设计决策写着会话标识在 localStorage 还是 sessionStorage，安全约束又要求防 XSS 窃取。design 草稿直接选择 HttpOnly Cookie，但没有说明它改变了 UNIT 决策候选，也没有用户确认。请审查是否能交给 /test-design。",
  "expected_output": "不能交接；识别 UNIT 候选与 design 决策存在业务/技术语义漂移；说明 HttpOnly Cookie 可能是更优安全方案，但必须回退用户或 /product-manager 确认候选范围和验收语义；不得静默交给 /test-design。",
  "files": ["shared/skills/design/examples/feature--user-login-validation/phase-1"],
  "expectations": [
    "识别 localStorage/sessionStorage 与 HttpOnly Cookie 的候选漂移",
    "区分技术推荐和业务/UNIT 裁决",
    "要求用户或上游确认",
    "阻断下游交接"
  ],
  "expected_anchors": ["PA-4", "PA-7", "PA-15"],
  "run_modes": ["with_skill", "without_skill"]
}
```

```json
{
  "id": "human-script-llm-boundary",
  "prompt": "你正在收口 design.json。哪些检查必须交给脚本/schema/hook，哪些判断由 LLM 做，哪些必须让用户确认？请基于 design 阶段给出执行边界，不要泛泛而谈。",
  "expected_output": "明确脚本/schema/hook 裁决 JSON 结构、引用、digest、路径、phase 状态、reviewer 集合、verification refs、risk coverage 等确定性事项；LLM 负责语义判断、复杂度、方案取舍、证据解释和产物组织；用户确认业务语义、价值排序、风险接受、范围变化和上线/组织约束。",
  "files": ["docs/superpowers/specs/2026-05-18-design-architect-capability-eval-system.md"],
  "expectations": [
    "列出确定性检查并交给脚本/schema/hook",
    "列出 LLM 语义职责",
    "列出人类必须确认事项",
    "不得让模型替代确定性控制流"
  ],
  "expected_anchors": ["PA-8", "PA-13"],
  "run_modes": ["with_skill", "without_skill"]
}
```

```json
{
  "id": "downstream-consumer-smoke",
  "prompt": "给定一个设计草稿，请从 /test-design 和 /tech-lead 视角判断它是否可消费。草稿缺少接口边界行为、质量属性 verification_refs、迁移失败回滚触发条件。请给出是否可交接和必须补齐的字段。",
  "expected_output": "判定不可交接；从 /test-design 视角指出无法生成接口边界、质量属性和回滚断言；从 /tech-lead 视角指出无法拆迁移任务、回滚任务和验证任务；列出需要补齐的 design.json 字段并阻断完成。",
  "files": ["shared/skills/design/contracts/design.schema.json", "shared/skills/test-design/contracts/test-cases.schema.json", "shared/skills/tech-lead/contracts/plan.schema.json"],
  "expectations": [
    "以 /test-design 消费失败说明测试义务缺口",
    "以 /tech-lead 消费失败说明计划拆解缺口",
    "点名 boundary_behaviors、verification_refs、rollback trigger",
    "阻断 design 完成"
  ],
  "expected_anchors": ["PA-4", "PA-5", "PA-9", "PA-16"],
  "run_modes": ["with_skill", "without_skill"]
}
```

```json
{
  "id": "overdesign-pressure-case",
  "prompt": "Phase 只有一个静态感谢页和一个本地 unittest，设计草稿建议新增事件总线、独立配置服务、Redis 缓存和服务拆分。请以 design owner 判断是否合理。",
  "expected_output": "识别过度设计；说明当前复杂度不足以支撑事件总线、配置服务、缓存或服务拆分；推荐沿用简单模块边界和现有测试路径；保留演进条件而不把抽象写入当前 design.json。",
  "files": ["shared/skills/design/references/architecture-patterns.md", "shared/skills/design/references/service-decomposition.md"],
  "expectations": [
    "识别低复杂度场景",
    "拒绝不必要抽象",
    "给出简单、合适、演化的替代方案",
    "不把未来可能性写成当前架构"
  ],
  "expected_anchors": ["PA-7"],
  "run_modes": ["with_skill", "without_skill"]
}
```

```json
{
  "id": "reviewer-finds-architecture-fail",
  "prompt": "请作为 design owner 处理 reviewer 结果：架构 reviewer 发现 Redis 故障时设计仍返回登录成功、rollback_plan 只写'回滚代码'没有触发条件，测试 reviewer 发现 verification_refs 指不到 verification_mapping。产品 reviewer WARN 统一错误文案需交给 product_handoff。判断能否进入 S11。",
  "expected_output": "不能进入 S11；将 Redis 故障成功登录、不可执行 rollback_plan、verification_refs 悬空判为 FAIL 并回到 S8/S7 修正后重审；产品 WARN 承接到 product_handoff；说明 FAIL 未闭合不得写 final_confirmation。",
  "files": ["shared/skills/design/references/design-reviewer-prompt.md", "shared/skills/design/references/design-test-reviewer-prompt.md", "shared/skills/design/scripts/review_digest.py"],
  "expectations": [
    "未解决 FAIL 阻断 S11",
    "按问题类型回退 S7 或 S8",
    "WARN 给出承接位置",
    "不得写 final_confirmation"
  ],
  "expected_anchors": ["PA-5", "PA-6", "PA-11"],
  "run_modes": ["with_skill", "without_skill"]
}
```

- [ ] **Step 2: Add grader dimensions**

Add these strings to `grader_dimensions`:

```json
"architect_role_boundary",
"weak_evidence_rejection",
"semantic_conflict_detection",
"downstream_consumability",
"human_script_llm_boundary",
"overdesign_detection"
```

- [ ] **Step 3: Add preference anchors**

Add anchors:

```json
{
  "id": "PA-14",
  "anchor": "弱 runtime facts、agent 自我报告或 design.json#input_analysis 自指 evidence 不能支撑冻结架构决策",
  "weight": 1
}
```

```json
{
  "id": "PA-15",
  "anchor": "业务输入、UNIT 候选或 AC 与设计推荐冲突时，design 必须暴露冲突并回退用户或上游确认，不能静默交接下游",
  "weight": 1
}
```

```json
{
  "id": "PA-16",
  "anchor": "下游消费能力是 design 完成标准；/test-design 和 /tech-lead 无法基于 design.json 生成测试义务或任务边界时不得完成",
  "weight": 1
}
```

- [ ] **Step 4: Update lifecycle review**

In `lifecycle-review.json`, set:

```json
"review_date": "2026-05-18"
```

Set:

```json
"capability_uplift": {
  "measurement_status": "architect_eval_matrix_updated_needs_empirical_rerun",
  "with_avg": null,
  "without_avg": null,
  "uplift": null,
  "with_sample_size": null,
  "without_sample_size": null,
  "grader_dimensions": [
    "product_input_blocking",
    "alternative_quality",
    "guided_cocreation",
    "interface_boundary",
    "verification_rollback",
    "quality_attribute_verification",
    "runtime_fact_evidence",
    "self_checked_design_review_digest",
    "s11_artifact_write",
    "s12_projection_after_validation",
    "architect_role_boundary",
    "weak_evidence_rejection",
    "semantic_conflict_detection",
    "downstream_consumability",
    "human_script_llm_boundary",
    "overdesign_detection"
  ]
}
```

Set:

```json
"encoded_preference": {
  "measurement_status": "architect_anchors_updated_needs_fidelity_run",
  "anchor_count": 15,
  "eval_count": 11,
  "fidelity": null,
  "sample_size": null,
  "anchor_passed": null,
  "anchor_total": 15,
  "current_anchor_total": 15
}
```

Keep historical `pilot_empirical` as historical evidence and do not convert it into current proof.

In `tests/test-skill-effectiveness-empirical-review.sh`, replace the current design-specific lifecycle assertions:

```python
assert design["capability_uplift"]["measurement_status"] == "evals_updated_needs_empirical_rerun", design
assert design["capability_uplift"]["with_sample_size"] is None, design
assert design["capability_uplift"]["without_sample_size"] is None, design
assert design["encoded_preference"]["measurement_status"] == "anchors_updated_needs_fidelity_run", design
assert design["encoded_preference"]["sample_size"] is None, design
```

with:

```python
assert design["capability_uplift"]["measurement_status"] == "architect_eval_matrix_updated_needs_empirical_rerun", design
assert design["capability_uplift"]["with_sample_size"] is None, design
assert design["capability_uplift"]["without_sample_size"] is None, design
assert design["encoded_preference"]["measurement_status"] == "architect_anchors_updated_needs_fidelity_run", design
assert design["encoded_preference"]["sample_size"] is None, design
```

- [ ] **Step 5: Run eval contract tests**

Run:

```bash
bash tests/test-standard-chain-skill-evals.sh
bash tests/test-skill-effectiveness-empirical-review.sh
bash tests/test-design-architect-capability-contract.sh
```

Expected: PASS.

- [ ] **Step 6: Commit eval matrix**

Run:

```bash
git add shared/skills/design/evals/evals.json \
  shared/skills/design/evals/lifecycle-review.json \
  tests/test-standard-chain-skill-evals.sh \
  tests/test-skill-effectiveness-empirical-review.sh
git commit -m "test(design): expand architect eval matrix"
```

## Task 8: Full Verification And Two-Round Review

**Files:**
- No planned edits unless verification exposes a target-scope defect.

- [ ] **Step 1: Run focused verification**

Run:

```bash
python3 -m unittest tests/test-design-reference-integrity.py
python3 -m unittest tests/test-design-architect-contract.py
bash tests/test-design-architect-capability-contract.sh
bash tests/test-design-skill-governance-redesign.sh
bash tests/test-design-dogfood-e2e.sh
bash tests/test-standard-chain-skill-evals.sh
bash tests/test-skill-effectiveness-empirical-review.sh
```

Expected: all PASS.

- [ ] **Step 2: Run phase validators on representative fixtures**

Run:

```bash
python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1
python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-pilots/feedback-thanks-pilot/phase-1
python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-pilots/login-homepage-pilot/phase-1
python3 shared/skills/design/scripts/validate_design_architect_contract.py --design tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json
python3 shared/skills/design/scripts/validate_design_architect_contract.py --design shared/skills/design/examples/feature--user-login-validation/phase-1/design.json
```

Expected: all PASS.

- [ ] **Step 3: First review round**

Review the changed files against the spec:

```bash
BASE_COMMIT="$(cat .git/design-architect-capability-base)"
git diff --stat "$BASE_COMMIT"..HEAD
git diff --check
rg -n "boundary_behaviors` 字段|design.json#input_analysis; observed_at|\"status\": \"confirmed\"|\"verdict\": \"PASS\"|\"status\": \"READY\"" shared/skills/design tests/fixtures
```

Expected:

- `git diff --check` has no output.
- No stale `boundary_behaviors` drift wording remains.
- No official design fixture runtime fact uses `evidence=design.json#input_analysis`.
- Template does not default to `confirmed`, `PASS`, or `READY`.
- Real fixtures may still contain `confirmed` and `PASS` where they represent completed canonical artifacts.

- [ ] **Step 4: Fix only target-scope review findings**

If Step 3 finds target-scope issues, patch only files under:

```text
shared/skills/design
tests/test-design-*
tests/fixtures/standard-chain-*
tools/community/canonical_design*
```

Do not clean unrelated deleted docs or unrelated tests in the dirty worktree.

- [ ] **Step 5: Second review round**

Repeat:

```bash
git diff --check
python3 -m unittest tests/test-design-architect-contract.py
bash tests/test-design-architect-capability-contract.sh
bash tests/test-design-dogfood-e2e.sh
```

Expected: all PASS and no new target-scope findings.

- [ ] **Step 6: Final commit if review fixes were needed**

If Step 4 changed files, run:

```bash
git add shared/skills/design tests tools/community
git commit -m "fix(design): close architect contract review findings"
```

If Step 4 made no changes, do not create an empty commit.

## Task 9: Run Empirical Capability Eval And Record Lifecycle Evidence

**Files:**
- Modify: `shared/skills/design/evals/lifecycle-review.json`
- Modify: `tests/test-skill-effectiveness-empirical-review.sh`

- [ ] **Step 1: Run the full design eval matrix with the design skill enabled**

Run:

```bash
WITH_OUT="tools/eval/results/design-architect-capability-20260518-with-skill"
python3 tools/eval/scripts/run_standard_chain_local_eval.py \
  --skills design \
  --runs-per-eval 1 \
  --run-mode with_skill \
  --output-dir "$WITH_OUT" \
  --hide-expected-outcome
```

Expected: command exits 0, `$WITH_OUT/summary.json` exists, and `summary.summary.infra_failures` is `0`.

- [ ] **Step 2: Run the same full matrix without the design skill**

Run:

```bash
WITHOUT_OUT="tools/eval/results/design-architect-capability-20260518-without-skill"
python3 tools/eval/scripts/run_standard_chain_local_eval.py \
  --skills design \
  --runs-per-eval 1 \
  --run-mode without_skill \
  --output-dir "$WITHOUT_OUT" \
  --hide-expected-outcome \
  --allow-failures
```

Expected: command exits 0, `$WITHOUT_OUT/summary.json` exists, and `summary.summary.infra_failures` is `0`. Failed expectations are allowed here because the run is the baseline for uplift, but infrastructure failures are not allowed.

- [ ] **Step 3: Update lifecycle review from real summaries**

Run:

```bash
python3 tools/eval/scripts/update_lifecycle_review.py \
  --skill design \
  --with-summary tools/eval/results/design-architect-capability-20260518-with-skill/summary.json \
  --without-summary tools/eval/results/design-architect-capability-20260518-without-skill/summary.json \
  --output-review shared/skills/design/evals/lifecycle-review.json \
  --write-review
```

Expected: `capability_uplift.measurement_status`, `encoded_preference.measurement_status`, and `pilot_empirical.measurement_status` are all `pilot_empirical_sample_recorded`; with/without summary refs point to the two fresh result directories above.

- [ ] **Step 4: Update lifecycle regression expectations for design**

In `tests/test-skill-effectiveness-empirical-review.sh`, replace the design-specific architect-rerun assertions:

```python
assert design["capability_uplift"]["measurement_status"] == "architect_eval_matrix_updated_needs_empirical_rerun", design
assert design["capability_uplift"]["with_sample_size"] is None, design
assert design["capability_uplift"]["without_sample_size"] is None, design
assert design["encoded_preference"]["measurement_status"] == "architect_anchors_updated_needs_fidelity_run", design
assert design["encoded_preference"]["sample_size"] is None, design
```

with:

```python
assert design["capability_uplift"]["measurement_status"] == "pilot_empirical_sample_recorded", design
assert design["capability_uplift"]["with_sample_size"] >= design_eval_total, design
assert design["capability_uplift"]["without_sample_size"] >= design_eval_total, design
assert design["capability_uplift"]["with_avg"] is not None, design
assert design["capability_uplift"]["without_avg"] is not None, design
assert design["capability_uplift"]["uplift"] is not None, design
assert design["encoded_preference"]["measurement_status"] == "pilot_empirical_sample_recorded", design
assert design["encoded_preference"]["sample_size"] >= design_eval_total, design
assert design["encoded_preference"]["anchor_total"] >= design_anchor_total, design
assert design["encoded_preference"]["fidelity"] is not None, design
```

Keep the existing assertions that summary refs exist and infra failures are `0`.

Also add:

```python
design_eval_total = len(design_evals.get("evals", []))
```

near the existing `design_anchor_total` calculation, then compare sample size against `design_eval_total` rather than a hard-coded eval count.

- [ ] **Step 5: Verify lifecycle evidence is no longer stale**

Run:

```bash
bash tests/test-skill-effectiveness-empirical-review.sh
python3 - <<'PY'
import json
from pathlib import Path

root = Path(".")
evals = json.loads((root / "shared/skills/design/evals/evals.json").read_text(encoding="utf-8"))
eval_total = len(evals.get("evals", []))
review = json.loads((root / "shared/skills/design/evals/lifecycle-review.json").read_text(encoding="utf-8"))
assert review["capability_uplift"]["measurement_status"] == "pilot_empirical_sample_recorded", review
assert review["encoded_preference"]["measurement_status"] == "pilot_empirical_sample_recorded", review
assert review["pilot_empirical"]["measurement_status"] == "pilot_empirical_sample_recorded", review
for stats in (review["pilot_empirical"]["with_skill"], review["pilot_empirical"]["without_skill"]):
    assert stats["sample_size"] >= eval_total, stats
    assert stats["infra_failures"] == 0, stats
    assert (root / stats["summary_ref"]).is_file(), stats
PY
```

Expected: all commands PASS. If either eval run has infrastructure failures or the with-skill result does not demonstrate the architect behaviors, stop and report the failing summary instead of marking the skill formally usable.

- [ ] **Step 6: Commit empirical lifecycle evidence**

Run:

```bash
git add shared/skills/design/evals/lifecycle-review.json \
  tests/test-skill-effectiveness-empirical-review.sh \
  tools/eval/results/design-architect-capability-20260518-with-skill \
  tools/eval/results/design-architect-capability-20260518-without-skill
git commit -m "test(design): record architect capability eval evidence"
```

## Completion Criteria

The implementation is complete only when all are true:

- `shared/skills/design` entrypoints present the senior delivery architect role.
- `design.json` remains the downstream consumption baseline.
- Deterministic checks cover runtime evidence quality, boundary behaviors, boundary behavior verification refs, reviewer exact set, cross-cutting exact set, risk response coverage, and decision option coverage.
- Template no longer looks like a completed artifact by default.
- Empty `interfaces` is valid only when `interface_boundary` explains unchanged contracts.
- Examples and fixtures pass schema, canonical, reference-integrity, architect-contract, review digest, and phase validation.
- Eval matrix covers hard contract, semantic ability, pressure cases, downstream consumption, and with/without-skill comparison.
- Current empirical lifecycle status records fresh with-skill and without-skill summaries for the updated architect matrix, with zero infrastructure failures and measured uplift/fidelity fields.
- No deferred canonical fact-model decision was changed.

## Final Verification Command Set

Run before reporting completion:

```bash
python3 -m unittest tests/test-design-reference-integrity.py
python3 -m unittest tests/test-design-architect-contract.py
bash tests/test-design-architect-capability-contract.sh
bash tests/test-design-skill-governance-redesign.sh
bash tests/test-design-dogfood-e2e.sh
bash tests/test-standard-chain-skill-evals.sh
bash tests/test-skill-effectiveness-empirical-review.sh
python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1
python3 shared/skills/design/scripts/validate_design_architect_contract.py --design shared/skills/design/examples/feature--user-login-validation/phase-1/design.json
python3 - <<'PY'
import json
from pathlib import Path

root = Path(".")
evals = json.loads((root / "shared/skills/design/evals/evals.json").read_text(encoding="utf-8"))
eval_total = len(evals.get("evals", []))
review = json.loads((root / "shared/skills/design/evals/lifecycle-review.json").read_text(encoding="utf-8"))
assert review["capability_uplift"]["measurement_status"] == "pilot_empirical_sample_recorded", review
assert review["encoded_preference"]["measurement_status"] == "pilot_empirical_sample_recorded", review
assert review["pilot_empirical"]["measurement_status"] == "pilot_empirical_sample_recorded", review
for stats in (review["pilot_empirical"]["with_skill"], review["pilot_empirical"]["without_skill"]):
    assert stats["sample_size"] >= eval_total, stats
    assert stats["infra_failures"] == 0, stats
    assert (root / stats["summary_ref"]).is_file(), stats
PY
git diff --check
```

Expected: every command exits 0.

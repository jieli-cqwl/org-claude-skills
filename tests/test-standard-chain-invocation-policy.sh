#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
POLICY="$ROOT/contracts/standard-chain-invocation-policy.yaml"
STANDARD_CHAIN="$ROOT/contracts/standard-chain.yaml"
RUNTIME_SURFACE="$ROOT/contracts/skill-runtime-surface.json"
READINESS="$ROOT/shared/skills/product-director/evals/dogfood/team-pilot-readiness.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$POLICY" || fail "missing standard-chain invocation policy"

python3 - "$POLICY" "$STANDARD_CHAIN" "$RUNTIME_SURFACE" "$READINESS" <<'PY' || fail "standard-chain invocation policy drift"
import json
import sys
from pathlib import Path

import yaml

policy_path = Path(sys.argv[1])
standard_chain_path = Path(sys.argv[2])
runtime_surface_path = Path(sys.argv[3])
readiness_path = Path(sys.argv[4])

policy = yaml.safe_load(policy_path.read_text(encoding="utf-8"))
standard_chain = yaml.safe_load(standard_chain_path.read_text(encoding="utf-8"))
runtime_surface = json.loads(runtime_surface_path.read_text(encoding="utf-8"))
readiness = json.loads(readiness_path.read_text(encoding="utf-8"))

if policy.get("chain_version") != "standard-chain/v1":
    raise SystemExit("policy must bind to standard-chain/v1")
if policy.get("policy_status") != "non_persistent_route_guardrail":
    raise SystemExit("policy must remain a non-persistent route guardrail")

recording_model = policy.get("recording_model", {})
if recording_model.get("mode") != "inline_ephemeral":
    raise SystemExit("route judgment must remain inline/ephemeral")
if recording_model.get("canonical_artifact") != "none":
    raise SystemExit("policy must not declare a canonical route-decision artifact")
if recording_model.get("runtime_state") != "none":
    raise SystemExit("policy must not create runtime state")
if recording_model.get("validation_consumer") != "current_agent_only":
    raise SystemExit("policy must not imply a persistent validation consumer")

does_not_create = set(policy.get("scope", {}).get("does_not_create", []))
for forbidden_creation in {
    "canonical route-decision artifact",
    "persistent runtime state",
    "required worklog entry",
    "automatic product-director invocation",
}:
    if forbidden_creation not in does_not_create:
        raise SystemExit(f"policy must explicitly avoid creating {forbidden_creation}")

if "decision_record_template" in policy:
    raise SystemExit("policy must not define a stored decision_record_template")
if "route_decision_artifact" in json.dumps(standard_chain, ensure_ascii=False):
    raise SystemExit("standard-chain contract must not grow an undeclared route-decision artifact")

product_director_surface = runtime_surface["skills"]["product-director"]
if product_director_surface.get("mode") != "manual":
    raise SystemExit("product-director runtime surface must remain manual")
if readiness.get("default_scope") != "complex_demand_intake_only":
    raise SystemExit("product-director readiness must remain complex-demand intake only")
if readiness.get("full_production_default") is not False:
    raise SystemExit("product-director must not be promoted to full production default")

principle_ids = {item.get("id") for item in policy.get("principles", [])}
for required_id in {"INV-P1", "INV-P2", "INV-P3", "INV-P4", "INV-P5"}:
    if required_id not in principle_ids:
        raise SystemExit(f"policy missing principle {required_id}")

route_precedence = policy.get("route_precedence", {})
if "route wins over bypass" not in route_precedence.get("rule", ""):
    raise SystemExit("policy must declare route precedence over bypass")
if not route_precedence.get("route_wins_when"):
    raise SystemExit("route precedence must list route-winning conditions")
if not route_precedence.get("bypass_allowed_only_when"):
    raise SystemExit("route precedence must constrain bypass allowance")

route_rules = {item.get("id"): item for item in policy.get("route_to_product_director_when", [])}
for required_id in {"PD-ROUTE-001", "PD-ROUTE-002", "PD-ROUTE-003", "PD-ROUTE-004"}:
    if required_id not in route_rules:
        raise SystemExit(f"policy missing route rule {required_id}")
for item in route_rules.values():
    if item.get("required_action") not in {
        "manual_invoke_product_director",
        "pause_and_route_back_to_product_director",
    }:
        raise SystemExit(f"route rule {item.get('id')} has invalid required_action")
    if not item.get("router_owner"):
        raise SystemExit(f"route rule {item.get('id')} missing router_owner")
    if not item.get("pass_condition"):
        raise SystemExit(f"route rule {item.get('id')} missing pass_condition")

bypass_rules = {item.get("id"): item for item in policy.get("bypass_product_director_when", [])}
for required_id in {"PD-BYPASS-001", "PD-BYPASS-002", "PD-BYPASS-003", "PD-BYPASS-004"}:
    if required_id not in bypass_rules:
        raise SystemExit(f"policy missing bypass rule {required_id}")
for item in bypass_rules.values():
    if not item.get("guardrail"):
        raise SystemExit(f"bypass rule {item.get('id')} missing guardrail")
    if not item.get("router_owner"):
        raise SystemExit(f"bypass rule {item.get('id')} missing router_owner")

blocking = {item.get("id"): item for item in policy.get("blocking_conditions", [])}
expected_blocks = {
    "INV-BLOCK-001": "INLINE_ROUTE_RATIONALE_REQUIRED",
    "INV-BLOCK-002": "ROUTE_PRECEDENCE_VIOLATION",
    "INV-BLOCK-003": "ROUTE_BACK_TO_PRODUCT_DIRECTOR",
}
for block_id, expected_status in expected_blocks.items():
    item = blocking.get(block_id)
    if not item:
        raise SystemExit(f"policy missing blocking condition {block_id}")
    if item.get("required_status") != expected_status:
        raise SystemExit(f"{block_id} required_status drift")
    if not item.get("recovery"):
        raise SystemExit(f"{block_id} missing recovery")
    condition = item.get("condition", "")
    recovery = item.get("recovery", "")
    if "standard-chain canonical artifacts" not in condition:
        raise SystemExit(f"{block_id} must be scoped to standard-chain canonical artifacts")
    if "downstream standard-chain readiness" not in condition:
        raise SystemExit(f"{block_id} must be scoped to downstream readiness claims")
    if "停止 canonical artifact write 或 readiness claim" not in recovery:
        raise SystemExit(f"{block_id} recovery must stop only canonical writes/readiness claims")

outside_blocking_scope = policy.get("outside_blocking_scope", [])
if len(outside_blocking_scope) < 3:
    raise SystemExit("policy must define outside_blocking_scope examples")
outside_scope_text = "\n".join(outside_blocking_scope)
for expected_phrase in [
    "simple factual answers",
    "already-authorized direct implementation with frozen scope",
    "evidence review, research, or pilot observation",
]:
    if expected_phrase not in outside_scope_text:
        raise SystemExit(f"outside_blocking_scope missing {expected_phrase}")

if "product-manager, tech-lead, delivery-owner, or implementation without a product-director route/bypass decision" in json.dumps(policy, ensure_ascii=False):
    raise SystemExit("policy must not block all downstream/direct implementation without a persistent route decision")

rationale_template = policy.get("inline_route_rationale_template", {})
for field in [
    "request_summary",
    "matched_signal",
    "decision",
    "router_owner",
    "basis_refs",
    "guardrail",
    "next_action",
]:
    if field not in rationale_template:
        raise SystemExit(f"inline_route_rationale_template missing {field}")
if "contracts/standard-chain-invocation-policy.yaml" not in rationale_template.get("basis_refs", []):
    raise SystemExit("inline route rationale template must cite the invocation policy")

examples = policy.get("examples", [])
example_decisions = {item.get("expected_decision") for item in examples}
for expected_decision in {
    "manual_invoke_product_director",
    "bypass_product_director",
    "route_back_to_product_director",
}:
    if expected_decision not in example_decisions:
        raise SystemExit(f"examples missing {expected_decision}")
example_signals = {item.get("matched_signal") for item in examples}
for expected_signal in {"PD-ROUTE-003", "PD-BYPASS-001", "PD-BYPASS-002", "PD-ROUTE-004", "PD-BYPASS-004"}:
    if expected_signal not in example_signals:
        raise SystemExit(f"examples missing {expected_signal}")
if not any("delivery-owner evidence pilot" in item.get("input_shape", "") for item in examples):
    raise SystemExit("examples must cover delivery-owner evidence pilot")

PY

printf '[PASS] standard-chain invocation policy\n'

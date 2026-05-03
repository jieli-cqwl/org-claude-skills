#!/usr/bin/env python3
"""Grade skill-refiner fixture dogfood output against expected anchors."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_ROOT = SCRIPT_DIR.parent
SKILL_REL_PREFIX = Path("shared/skills/skill-refiner")
DIMENSION_RE = re.compile(r"^(G[0-2]|S[1-8]|E[1-5])$")
RING_ORDER = [
    "Trigger",
    "Responsibility",
    "Input",
    "Flow",
    "Output",
    "Resource",
    "Determinism",
    "Eval",
    "Cleanup",
    "Runtime",
]
RING_SET = set(RING_ORDER)
RING_STATUSES = {"PASS", "ISSUE_FIXED", "BLOCKED"}
STRATEGIES = set("PASS PATCH REWRITE REPLACE MOVE DELETE SPLIT BLOCKED".split())


def discover_repo_root() -> Path | None:
    for parent in SCRIPT_DIR.parents:
        if (parent / SKILL_REL_PREFIX / "SKILL.md").is_file():
            return parent
    return None


REPO_ROOT = discover_repo_root()


def skill_prefixed_path(path: Path) -> Path | None:
    prefix = SKILL_REL_PREFIX.parts
    if path.parts[: len(prefix)] != prefix:
        return None
    suffix = Path(*path.parts[len(prefix) :])
    return SKILL_ROOT / suffix


def candidate_paths(raw: str) -> list[Path]:
    path = Path(raw)
    if path.is_absolute():
        return [path]

    candidates: list[Path] = []
    prefixed = skill_prefixed_path(path)
    if prefixed is not None:
        candidates.append(prefixed)
    candidates.append(SKILL_ROOT / path)
    candidates.append(Path.cwd() / path)
    if REPO_ROOT is not None:
        candidates.append(REPO_ROOT / path)

    unique: list[Path] = []
    seen: set[str] = set()
    for item in candidates:
        key = str(item)
        if key not in seen:
            seen.add(key)
            unique.append(item)
    return unique


def resolve_path(raw: str, *, for_write: bool = False) -> Path:
    candidates = candidate_paths(raw)
    for path in candidates:
        if path.exists():
            return path.resolve()
    if for_write:
        for path in candidates:
            if path.parent.exists():
                return path.resolve()
    return candidates[0].resolve()


def display_path(path: Path) -> str:
    for root in (REPO_ROOT, SKILL_ROOT, Path.cwd()):
        if root is None:
            continue
        try:
            return path.relative_to(root).as_posix()
        except ValueError:
            continue
    return path.as_posix()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def eval_case(evals: dict[str, Any], eval_id: str) -> dict[str, Any]:
    for item in evals.get("evals", []):
        if item.get("id") == eval_id:
            return item
    raise SystemExit(f"eval case not found: {eval_id}")


def target_files(result: dict[str, Any]) -> tuple[Path, str]:
    target = resolve_path(result["target_output"])
    skill = target / "SKILL.md"
    text = skill.read_text(encoding="utf-8")
    return target, text


def has_problem_cards(result: dict[str, Any]) -> bool:
    cards = result.get("problem_cards")
    if not isinstance(cards, list) or not cards:
        return False
    required = {
        "area",
        "quality_dimension",
        "phenomenon",
        "impact",
        "target_shape",
        "change_scope",
        "verification",
    }
    return all(
        isinstance(card, dict)
        and required <= set(card)
        and DIMENSION_RE.match(str(card.get("quality_dimension")))
        for card in cards
    )


def expected_ring_sequence(result: dict[str, Any]) -> list[str]:
    loop = result.get("agent_loop", {})
    entry_ring = loop.get("entry_ring") if isinstance(loop, dict) else None
    if entry_ring not in RING_SET:
        return list(RING_ORDER)
    start = RING_ORDER.index(entry_ring)
    return RING_ORDER[start:] + RING_ORDER[:start]


def has_complete_ring_loop(result: dict[str, Any]) -> bool:
    loop = result.get("agent_loop", {})
    sequence = loop.get("ring_sequence", [])
    results = loop.get("ring_results", [])
    expected_sequence = expected_ring_sequence(result)
    if sequence != expected_sequence:
        return False
    if not isinstance(results, list) or len(results) != len(RING_ORDER):
        return False
    seen: set[str] = set()
    fixed_rings: set[str] = set()
    for item in results:
        if not isinstance(item, dict):
            return False
        ring = item.get("ring")
        status = item.get("status")
        evidence = item.get("evidence")
        if ring not in RING_SET or ring in seen:
            return False
        if status not in RING_STATUSES:
            return False
        if not isinstance(evidence, str) or not evidence.strip():
            return False
        if status == "ISSUE_FIXED":
            fixed_rings.add(ring)
        seen.add(ring)
    card_rings = {
        card.get("area")
        for card in result.get("problem_cards", [])
        if isinstance(card, dict) and card.get("area") in RING_SET
    }
    return (
        seen == RING_SET
        and fixed_rings <= card_rings
        and [item.get("ring") for item in results] == expected_sequence
    )


def has_confirmed_blueprint_strategy(result: dict[str, Any]) -> bool:
    loop = result.get("agent_loop", {})
    expected_sequence = expected_ring_sequence(result)
    blueprints = loop.get("blueprint_matrix", [])
    if loop.get("candidate_strategy_confirmed_before_final_operation") is not True:
        return False
    if not isinstance(blueprints, list) or len(blueprints) != len(RING_ORDER):
        return False
    seen: set[str] = set()
    for item in blueprints:
        if not isinstance(item, dict):
            return False
        ring = item.get("ring")
        if ring not in RING_SET or ring in seen:
            return False
        if item.get("candidate_strategy") not in STRATEGIES:
            return False
        for key in ("best_practice_target", "user_confirmation"):
            if not isinstance(item.get(key), str) or not item.get(key, "").strip():
                return False
        seen.add(ring)
    return (
        seen == RING_SET
        and [item.get("ring") for item in blueprints] == expected_sequence
    )


def has_execution_gate(result: dict[str, Any]) -> bool:
    loop = result.get("agent_loop", {})
    gate = loop.get("execution_gate")
    if not isinstance(gate, dict):
        return False
    required_true = (
        "all_ring_blueprints_confirmed", "all_ring_candidate_strategies_confirmed",
        "all_ring_verifications_confirmed", "whole_strategy_freeze_confirmed",
        "no_file_changes_before_strategy_freeze", "single_execution_after_freeze",
        "final_operation_after_freeze_only",
    )
    if not all(gate.get(key) is True for key in required_true):
        return False
    freeze_evidence = gate.get("freeze_evidence")
    execution_scope = gate.get("execution_scope")
    return (isinstance(freeze_evidence, str) and bool(freeze_evidence.strip())
            and isinstance(execution_scope, list) and bool(execution_scope)
            and all(isinstance(item, str) and item.strip() for item in execution_scope))


def check_sr_1(result: dict[str, Any], target: Path, skill_text: str) -> bool:
    quality = result.get("quality_standard", {})
    return (
        quality.get("read") is True
        and bool(quality.get("decision_layer"))
        and has_problem_cards(result)
    )


def check_sr_2(result: dict[str, Any], target: Path, skill_text: str) -> bool:
    flow = result.get("practice_flow", [])
    return (
        bool(result.get("professional_domain"))
        and isinstance(flow, list)
        and len(flow) >= 4
        and "TDD" in skill_text
    )


def check_sr_9(result: dict[str, Any], target: Path, skill_text: str) -> bool:
    baseline = result.get("co_created_baseline", {})
    required = {
        "real_scenario",
        "business_constraint",
        "success_standard",
        "known_pain",
        "non_loss_capability",
        "entry_point",
        "located_carrier",
        "open_questions",
    }
    return (
        isinstance(baseline, dict)
        and required <= set(baseline)
        and all(baseline.get(key) for key in required)
    )


def check_sr_3(result: dict[str, Any], target: Path, skill_text: str) -> bool:
    return has_problem_cards(result)


def check_sr_4(result: dict[str, Any], target: Path, skill_text: str) -> bool:
    reference = target / "references" / "implementation-review.md"
    old_reference = target / "references" / "old-methodology.md"
    return (
        reference.is_file()
        and not old_reference.exists()
        and "复杂自审时读取 `references/implementation-review.md`" in skill_text
    )


def check_sr_5(result: dict[str, Any], target: Path, skill_text: str) -> bool:
    proof = result.get("proof_commands", [])
    modified = set(result.get("modified_files", []))
    return (
        any(
            item.get("status") == "pass"
            and "validate_noisy_implementation_result.sh" in item.get("command", "")
            for item in proof
        )
        and "outputs/noisy-implementation-skill/tests/noise-regression.test.sh" in modified
        and "流程合规输出合同" not in skill_text
    )


def check_sr_6(result: dict[str, Any], target: Path, skill_text: str) -> bool:
    replaced = set(result.get("deleted_or_replaced", []))
    return "references/old-methodology.md" in replaced and "tests/noisy-contract.test.sh" in replaced


def check_sr_7(result: dict[str, Any], target: Path, skill_text: str) -> bool:
    review = result.get("candidate_signal_review", {})
    return (
        review.get("static_signals_used_as_input") is True
        and review.get("reviewed_against_practice_flow") is True
        and review.get("reviewed_against_consumers") is True
        and bool(review.get("accepted_signals"))
    )


def check_sr_8(result: dict[str, Any], target: Path, skill_text: str) -> bool:
    loop = result.get("agent_loop", {})
    sequence = loop.get("ring_sequence", [])
    return (
        loop.get("you_own_final_decision") is True
        and loop.get("owner_decision_scope") == "all_rings"
        and loop.get("independent_ring_verification") is True
        and loop.get("execution_evidence_not_final") is True
        and isinstance(sequence, list)
        and sequence == RING_ORDER
    )


ANCHOR_CHECKS = {
    "SR-1": (check_sr_1, "quality standard read and problem cards map to G/S/E dimensions"),
    "SR-2": (check_sr_2, "professional domain and real implementation flow are explicit"),
    "SR-9": (check_sr_9, "co-created baseline captures real scenario, business constraint, success standard, pain, non-loss capability, entry point, located carrier, and open questions"),
    "SR-3": (check_sr_3, "problem cards include dimension, target shape, scope, and verification"),
    "SR-4": (check_sr_4, "long review method moved to a routed self-review reference"),
    "SR-5": (check_sr_5, "consumer-backed validation exists and stale machine-contract noise is absent"),
    "SR-6": (check_sr_6, "old files and tests are treated as evidence, not target behavior"),
    "SR-7": (check_sr_7, "candidate signals are reviewed against real flow and consumers before adoption"),
    "SR-8": (check_sr_8, "owner final decision covers every ring and execution evidence is not final verdict"),
    "SR-10": (lambda result, target, skill_text: has_complete_ring_loop(result), "SR-R1 through SR-R10 each have PASS/ISSUE_FIXED/BLOCKED evidence before completion"),
    "SR-11": (lambda result, target, skill_text: has_confirmed_blueprint_strategy(result), "each ring has a confirmed best-practice blueprint and candidate strategy before the final operation"),
    "SR-12": (lambda result, target, skill_text: has_execution_gate(result), "whole strategy is frozen before the final operation and single execution"),
}


def grade_anchor(anchor_id: str, result: dict[str, Any]) -> tuple[bool, str]:
    target, skill_text = target_files(result)
    entry = ANCHOR_CHECKS.get(anchor_id)
    if entry is None:
        return False, f"unknown anchor {anchor_id}"
    check, evidence = entry
    return check(result, target, skill_text), evidence


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evals", default="evals/evals.json")
    parser.add_argument("--result", required=True)
    parser.add_argument("--output")
    args = parser.parse_args()

    evals = load_json(resolve_path(args.evals))
    result_path = resolve_path(args.result)
    result = load_json(result_path)
    case = eval_case(evals, result["eval_id"])
    expected = case.get("expected_anchors", [])
    if not expected:
        raise SystemExit("expected_anchors must not be empty")

    graded = []
    passed = 0
    for anchor_id in expected:
        ok, evidence = grade_anchor(anchor_id, result)
        if ok:
            passed += 1
        graded.append({"anchor_id": anchor_id, "passed": ok, "evidence": evidence})

    output = {
        "artifact_type": "skill-refiner-anchor-fidelity",
        "eval_id": result["eval_id"],
        "run_mode": result["run_mode"],
        "result_ref": display_path(result_path),
        "expected_anchor_count": len(expected),
        "passed_anchor_count": passed,
        "fidelity": round(passed / len(expected), 4),
        "anchors": graded,
    }

    if args.output:
        out_path = resolve_path(args.output, for_write=True)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(
            json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    print(json.dumps(output, ensure_ascii=False, indent=2))
    if passed != len(expected):
        raise SystemExit(1)


if __name__ == "__main__":
    main()

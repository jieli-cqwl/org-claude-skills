#!/usr/bin/env python3
"""Grade skill-refiner fixture dogfood output against expected anchors."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[4]
DIMENSION_RE = re.compile(r"^(G[0-2]|S[1-8]|E[1-5])$")


def repo_path(raw: str) -> Path:
    path = Path(raw)
    if not path.is_absolute():
        path = REPO_ROOT / path
    return path.resolve()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def eval_case(evals: dict[str, Any], eval_id: str) -> dict[str, Any]:
    for item in evals.get("evals", []):
        if item.get("id") == eval_id:
            return item
    raise SystemExit(f"eval case not found: {eval_id}")


def target_files(result: dict[str, Any]) -> tuple[Path, str]:
    target = repo_path(result["target_output"])
    skill = target / "SKILL.md"
    text = skill.read_text(encoding="utf-8")
    return target, text


def has_problem_cards(result: dict[str, Any]) -> bool:
    cards = result.get("problem_cards")
    if not isinstance(cards, list) or not cards:
        return False
    required = {"area", "quality_dimension", "phenomenon", "impact", "target_shape", "change_scope", "verification"}
    return all(isinstance(card, dict) and required <= set(card) and DIMENSION_RE.match(str(card.get("quality_dimension"))) for card in cards)


def grade_anchor(anchor_id: str, result: dict[str, Any]) -> tuple[bool, str]:
    target, skill_text = target_files(result)
    cards = result.get("problem_cards", [])

    if anchor_id == "SR-1":
        quality = result.get("quality_standard", {})
        ok = quality.get("read") is True and quality.get("decision_layer") and has_problem_cards(result)
        return ok, "quality standard read and problem cards map to G/S/E dimensions"

    if anchor_id == "SR-2":
        flow = result.get("practice_flow", [])
        ok = bool(result.get("professional_domain")) and isinstance(flow, list) and len(flow) >= 4 and "TDD" in skill_text
        return ok, "professional domain and real implementation flow are explicit"

    if anchor_id == "SR-9":
        baseline = result.get("co_created_baseline", {})
        required = {
            "real_scenario",
            "business_constraint",
            "success_standard",
            "known_pain",
            "non_loss_capability",
            "priority_ring",
        }
        ok = isinstance(baseline, dict) and required <= set(baseline) and all(baseline.get(key) for key in required)
        return ok, "co-created baseline captures real scenario, business constraint, success standard, pain, non-loss capability, and priority ring"

    if anchor_id == "SR-3":
        ok = has_problem_cards(result)
        return ok, "problem cards include dimension, target shape, scope, and verification"

    if anchor_id == "SR-4":
        reference = target / "references" / "implementation-review.md"
        old_reference = target / "references" / "old-methodology.md"
        ok = reference.is_file() and not old_reference.exists() and "按需读取 `references/implementation-review.md`" in skill_text
        return ok, "long review method moved to progressively disclosed reference"

    if anchor_id == "SR-5":
        proof = result.get("proof_commands", [])
        modified = set(result.get("modified_files", []))
        ok = (
            any(item.get("status") == "pass" and "validate_noisy_implementation_result.sh" in item.get("command", "") for item in proof)
            and "outputs/noisy-implementation-skill/tests/noise-regression.test.sh" in modified
            and "流程合规输出合同" not in skill_text
        )
        return ok, "consumer-backed validation exists and stale machine-contract noise is absent"

    if anchor_id == "SR-6":
        replaced = set(result.get("deleted_or_replaced", []))
        ok = "references/old-methodology.md" in replaced and "tests/noisy-contract.test.sh" in replaced
        return ok, "old files and tests are treated as evidence, not target behavior"

    if anchor_id == "SR-7":
        review = result.get("candidate_signal_review", {})
        ok = (
            review.get("static_signals_used_as_input") is True
            and review.get("reviewed_against_practice_flow") is True
            and review.get("reviewed_against_consumers") is True
            and bool(review.get("accepted_signals"))
        )
        return ok, "candidate signals are reviewed against real flow and consumers before adoption"

    if anchor_id == "SR-8":
        loop = result.get("agent_loop", {})
        sequence = loop.get("ring_sequence", [])
        ok = (
            loop.get("main_agent_owns_final_decision") is True
            and loop.get("minimal_context") is True
            and loop.get("sub_agent_scope") == "single_ring"
            and loop.get("sub_agent_self_proof_not_final") is True
            and isinstance(sequence, list)
            and sequence
            and all(isinstance(item, str) and item for item in sequence)
        )
        return ok, "main agent owns final decision while each ring is scoped and independently verified"

    return False, f"unknown anchor {anchor_id}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evals", default="shared/skills/skill-refiner/evals/evals.json")
    parser.add_argument("--result", required=True)
    parser.add_argument("--output")
    args = parser.parse_args()

    evals = load_json(repo_path(args.evals))
    result_path = repo_path(args.result)
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
        "result_ref": result_path.relative_to(REPO_ROOT).as_posix(),
        "expected_anchor_count": len(expected),
        "passed_anchor_count": passed,
        "fidelity": round(passed / len(expected), 4),
        "anchors": graded,
    }

    if args.output:
        out_path = repo_path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps(output, ensure_ascii=False, indent=2))
    if passed != len(expected):
        raise SystemExit(1)


if __name__ == "__main__":
    main()

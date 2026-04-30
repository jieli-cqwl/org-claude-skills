#!/usr/bin/env python3
"""Update a skill effectiveness review with empirical local-eval pilot metrics."""

from __future__ import annotations

import argparse
import json
import sys
from copy import deepcopy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ENCODED_TYPES = {"encoded_preference", "mixed"}
UPLIFT_TYPES = {"capability_uplift", "mixed"}
ALLOWED_DECISIONS = {"retain", "optimize", "retire"}
DEFAULT_NEXT_ACTION = "Run empirical effectiveness evals before promoting any optimize decision to retain or retire."


def load_json(path: Path, label: str) -> object:
    """Load JSON from a required file path with an actionable error label."""

    if not path.is_file():
        raise SystemExit(f"missing {label}: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"invalid {label}: {path}: {exc}") from exc


def write_json(path: Path, payload: object) -> None:
    """Write stable UTF-8 JSON for review diffs and downstream checks."""

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_skill_inputs(skill: str) -> tuple[dict, dict]:
    """Load eval contract and current effectiveness review for one skill."""

    eval_path = ROOT / "shared" / "skills" / skill / "evals" / "evals.json"
    review_path = ROOT / "shared" / "skills" / skill / "evals" / "lifecycle-review.json"
    evals = load_json(eval_path, "evals file")
    review = load_json(review_path, "effectiveness review")
    if not isinstance(evals, dict) or evals.get("skill_name") != skill:
        raise SystemExit(f"{eval_path}: skill_name must be {skill}")
    if not isinstance(review, dict) or review.get("skill_name") != skill:
        raise SystemExit(f"{review_path}: skill_name must be {skill}")
    return evals, review


def validate_summary(summary: object, skill: str, expected_mode: str, path: Path) -> list[dict]:
    """Return graded runs after validating skill and run-mode consistency."""

    if not isinstance(summary, dict) or not isinstance(summary.get("runs"), list):
        raise SystemExit(f"{path}: summary.runs must be a list")
    summary_block = summary.get("summary", {})
    if isinstance(summary_block, dict):
        infra_failures = int(summary_block.get("infra_failures") or 0)
        if infra_failures:
            raise SystemExit(f"{path}: summary has infrastructure failures: {infra_failures}")
    runs: list[dict] = []
    for run in summary["runs"]:
        if not isinstance(run, dict):
            raise SystemExit(f"{path}: each run must be an object")
        if run.get("infra_failure"):
            raise SystemExit(f"{path}: summary has infrastructure failures")
        if run.get("skill_name") != skill:
            raise SystemExit(f"{path}: run skill_name must be {skill}")
        if run.get("run_mode") != expected_mode:
            raise SystemExit(f"{path}: run_mode must be {expected_mode}")
        if run.get("graded") is True and run.get("pass_rate") is not None:
            runs.append(run)
    if not runs:
        raise SystemExit(f"{path}: no graded runs with pass_rate")
    return runs


def summary_stats(summary: object, skill: str, expected_mode: str, path: Path) -> dict:
    """Compute sample, pass-rate, infra, and anchor metrics for one summary."""

    runs = validate_summary(summary, skill, expected_mode, path)
    pass_rates = [float(run["pass_rate"]) for run in runs]
    anchor_passed = sum(int(run.get("anchor_passed") or 0) for run in runs)
    anchor_total = sum(int(run.get("anchor_total") or 0) for run in runs)
    infra_failures = 0
    if isinstance(summary, dict) and isinstance(summary.get("summary"), dict):
        infra_failures = int(summary["summary"].get("infra_failures") or 0)
    return {
        "summary_ref": str(path),
        "sample_size": len(runs),
        "avg_pass_rate": round(sum(pass_rates) / len(pass_rates), 4),
        "infra_failures": infra_failures,
        "anchor_passed": anchor_passed,
        "anchor_total": anchor_total,
        "anchor_fidelity": round(anchor_passed / anchor_total, 4) if anchor_total else None,
    }


def update_encoded_preference(review: dict, evals: dict, with_stats: dict) -> None:
    """Write encoded-preference metrics while preserving empirical sample evidence."""

    encoded = dict(review.get("encoded_preference", {}))
    encoded.update(
        {
            "measurement_status": "pilot_empirical_sample_recorded",
            "anchor_count": len(evals.get("preference_anchors", [])),
            "eval_count": len(evals.get("evals", [])),
            "fidelity": with_stats["anchor_fidelity"],
            "sample_size": with_stats["sample_size"],
            "anchor_passed": with_stats["anchor_passed"],
            "anchor_total": with_stats["anchor_total"],
            "summary_refs": [with_stats["summary_ref"]],
            "next_run": "Run a broader effectiveness eval sample before retain or retire.",
        }
    )
    review["encoded_preference"] = encoded


def update_capability_uplift(review: dict, with_stats: dict, without_stats: dict | None) -> None:
    """Write capability uplift metrics from with-skill and without-skill summaries."""

    uplift = dict(review.get("capability_uplift", {}))
    without_avg = without_stats["avg_pass_rate"] if without_stats else None
    uplift_value = round(with_stats["avg_pass_rate"] - without_avg, 4) if without_avg is not None else None
    summary_refs = [with_stats["summary_ref"]]
    if without_stats:
        summary_refs.append(without_stats["summary_ref"])
    uplift.update(
        {
            "measurement_status": "pilot_empirical_sample_recorded" if without_stats else "with_skill_sample_recorded",
            "with_avg": with_stats["avg_pass_rate"],
            "without_avg": without_avg,
            "uplift": uplift_value,
            "with_sample_size": with_stats["sample_size"],
            "without_sample_size": without_stats["sample_size"] if without_stats else 0,
            "summary_refs": summary_refs,
            "next_run": "Run a broader effectiveness eval sample before retain or retire.",
        }
    )
    review["capability_uplift"] = uplift


def build_pilot_empirical(skill: str, eval_type: str, with_stats: dict, without_stats: dict | None) -> dict:
    """Create a conservative pilot evidence block for effectiveness review files."""

    return {
        "measurement_status": "pilot_empirical_sample_recorded",
        "skill_name": skill,
        "eval_type": eval_type,
        "with_skill": with_stats,
        "without_skill": without_stats,
        "decision_boundary": "Pilot evidence updates metrics only; formal decision remains optimize.",
    }


def apply_effectiveness_decision(review: dict, review_path: Path) -> None:
    """Keep pilot metric updates conservative and independent from lifecycle state."""

    decision = str(review.get("decision") or "optimize")
    if decision not in ALLOWED_DECISIONS:
        raise SystemExit(f"{review_path}: decision must be retain/optimize/retire")
    review["decision"] = "optimize"
    review.pop("lifecycle_state", None)
    if not isinstance(review.get("next_action"), str) or not review["next_action"].strip():
        review["next_action"] = DEFAULT_NEXT_ACTION


def update_review(skill: str, with_summary: Path, without_summary: Path | None) -> dict:
    """Return an updated effectiveness review object for one skill."""

    evals, review = load_skill_inputs(skill)
    eval_type = str(evals.get("eval_type"))
    updated = deepcopy(review)
    with_stats = summary_stats(load_json(with_summary, "summary file"), skill, "with_skill", with_summary)
    without_stats = None
    if without_summary is not None:
        without_stats = summary_stats(load_json(without_summary, "summary file"), skill, "without_skill", without_summary)

    if eval_type in ENCODED_TYPES:
        update_encoded_preference(updated, evals, with_stats)
    if eval_type in UPLIFT_TYPES:
        update_capability_uplift(updated, with_stats, without_stats)
    apply_effectiveness_decision(updated, ROOT / "shared" / "skills" / skill / "evals" / "lifecycle-review.json")
    updated["pilot_empirical"] = build_pilot_empirical(skill, eval_type, with_stats, without_stats)
    return updated


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments for effectiveness review updates."""

    parser = argparse.ArgumentParser(description="Update skill effectiveness review with empirical pilot metrics")
    parser.add_argument("--skill", required=True)
    parser.add_argument("--with-summary", required=True, type=Path)
    parser.add_argument("--without-summary", type=Path)
    parser.add_argument("--output-review", required=True, type=Path)
    parser.add_argument("--write-review", action="store_true")
    return parser.parse_args()


def main() -> None:
    """CLI entrypoint."""

    args = parse_args()
    review = update_review(args.skill, args.with_summary, args.without_summary)
    if args.write_review:
        write_json(args.output_review, review)
    else:
        json.dump(review, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")


if __name__ == "__main__":
    main()

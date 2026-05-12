#!/usr/bin/env python3
"""Grade a skill-refiner triad audit run."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


EVAL_DIR = Path(__file__).resolve().parents[1]
SCENARIOS = EVAL_DIR / "scenarios.json"


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def expected_pass(value: Any, expected: Any) -> bool:
    if isinstance(expected, list):
        return value in expected
    return value == expected


def grade_response(scenario: dict, arm: str, response: dict | None, returncode: int | None) -> dict:
    checks = []
    if returncode != 0:
        checks.append({"id": "codex_returncode", "passed": False, "evidence": f"returncode={returncode}"})
    else:
        checks.append({"id": "codex_returncode", "passed": True, "evidence": "returncode=0"})
    if not response:
        checks.append({"id": "response_json", "passed": False, "evidence": "missing or invalid response.json"})
        return {"arm": arm, "score": 0, "total": len(checks), "checks": checks}
    checks.append({"id": "response_json", "passed": True, "evidence": "parsed response.json"})
    if response.get("scenario_id") != scenario["id"]:
        checks.append({"id": "scenario_id", "passed": False, "evidence": str(response.get("scenario_id"))})
    else:
        checks.append({"id": "scenario_id", "passed": True, "evidence": scenario["id"]})
    if response.get("arm") != arm:
        checks.append({"id": "arm", "passed": False, "evidence": str(response.get("arm"))})
    else:
        checks.append({"id": "arm", "passed": True, "evidence": arm})

    for field, expected in scenario["expected"].items():
        actual = response.get(field)
        passed = expected_pass(actual, expected)
        checks.append({
            "id": field,
            "passed": passed,
            "evidence": f"actual={actual!r}; expected={expected!r}",
        })

    text_blob = "\n".join(
        [
            str(response.get("decision", "")),
            str(response.get("recommended_owner", "")),
            "\n".join(response.get("next_steps", [])),
            "\n".join(response.get("risk_notes", [])),
            str(response.get("reason_summary", "")),
        ]
    ).lower()
    for idx, group in enumerate(scenario.get("expected_text_groups", []), start=1):
        terms = [str(term).lower() for term in group]
        passed = any(term in text_blob for term in terms)
        checks.append({
            "id": f"text_anchor_{idx}",
            "passed": passed,
            "evidence": f"expected any of {group!r}",
        })

    passed_count = sum(1 for check in checks if check["passed"])
    return {"arm": arm, "score": passed_count, "total": len(checks), "checks": checks}


def load_response(path: Path) -> dict | None:
    try:
        data = load_json(path)
    except Exception:  # noqa: BLE001
        return None
    return data if isinstance(data, dict) else None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_dir")
    args = parser.parse_args()
    run_dir = Path(args.run_dir)
    all_scenarios = {item["id"]: item for item in load_json(SCENARIOS)["scenarios"]}
    manifest_path = run_dir / "run-manifest.json"
    if manifest_path.is_file():
        manifest = load_json(manifest_path)
        scenario_ids = manifest.get("scenarios", list(all_scenarios))
        arms = manifest.get("arms", ["baseline", "skill_creator", "skill_refiner"])
    else:
        scenario_ids = list(all_scenarios)
        arms = ["baseline", "skill_creator", "skill_refiner"]
    scenarios = {scenario_id: all_scenarios[scenario_id] for scenario_id in scenario_ids}
    graded = []

    for scenario_id, scenario in scenarios.items():
        arm_results = []
        for arm in arms:
            out_dir = run_dir / scenario_id / arm
            meta_path = out_dir / "metadata.json"
            meta = load_json(meta_path) if meta_path.is_file() else {}
            response = load_response(out_dir / "response.json")
            arm_results.append(grade_response(scenario, arm, response, meta.get("returncode")))
        best_score = max(result["score"] for result in arm_results)
        winners = [result["arm"] for result in arm_results if result["score"] == best_score]
        graded.append({
            "scenario_id": scenario_id,
            "kind": scenario["kind"],
            "winner": winners,
            "results": arm_results,
        })

    by_arm = {}
    for scenario in graded:
        for result in scenario["results"]:
            arm = result["arm"]
            stats = by_arm.setdefault(arm, {"score": 0, "total": 0, "wins": 0})
            stats["score"] += result["score"]
            stats["total"] += result["total"]
            if arm in scenario["winner"]:
                stats["wins"] += 1
    summary = {
        "artifact_type": "skill-refiner-triad-audit-summary",
        "run_dir": str(run_dir),
        "scenario_count": len(graded),
        "by_arm": {
            arm: {
                **stats,
                "pass_rate": round(stats["score"] / stats["total"], 4) if stats["total"] else 0,
            }
            for arm, stats in by_arm.items()
        },
        "scenarios": graded,
    }
    (run_dir / "triad-summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    lines = ["# Triad Audit Summary", ""]
    for arm, stats in summary["by_arm"].items():
        lines.append(f"- {arm}: pass_rate={stats['pass_rate']} wins={stats['wins']}/{len(graded)}")
    lines.append("")
    for scenario in graded:
        lines.append(f"## {scenario['scenario_id']}")
        lines.append(f"- winner: {', '.join(scenario['winner'])}")
        for result in scenario["results"]:
            lines.append(f"- {result['arm']}: {result['score']}/{result['total']}")
        lines.append("")
    (run_dir / "triad-summary.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps(summary["by_arm"], indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

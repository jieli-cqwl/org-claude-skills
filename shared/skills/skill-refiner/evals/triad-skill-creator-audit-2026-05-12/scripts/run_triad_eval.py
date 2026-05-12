#!/usr/bin/env python3
"""Run baseline / skill-creator / skill-refiner triad evals with codex exec."""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[6]
EVAL_DIR = Path(__file__).resolve().parents[1]
SCENARIOS = EVAL_DIR / "scenarios.json"
SCHEMA = EVAL_DIR / "response.schema.json"
SKILL_CREATOR = Path.home() / ".agents/skills/skill-creator/SKILL.md"
SKILL_REFINER = ROOT / "shared/skills/skill-refiner/SKILL.md"


ARM_INSTRUCTIONS = {
    "baseline": (
        "Do not read or use any Skill file. Use only general reasoning. "
        "Your job is to decide the next move for the scenario."
    ),
    "skill_creator": (
        f"Use the generic skill-creator workflow at {SKILL_CREATOR}. "
        "Do not use skill-refiner. If the task is outside skill-creator scope, route or pause."
    ),
    "skill_refiner": (
        f"Use the local skill-refiner workflow at {SKILL_REFINER}. "
        "If skill-refiner says the task belongs to skill-creator, route it instead of forcing refinement."
    ),
}


def ensure_text(value: str | bytes | None) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value


def load_scenarios() -> list[dict]:
    data = json.loads(SCENARIOS.read_text(encoding="utf-8"))
    return data["scenarios"]


def build_prompt(arm: str, scenario: dict) -> str:
    return f"""
You are running a read-only triad evaluation for org-claude-skills.

Arm: {arm}
Scenario id: {scenario["id"]}

Arm instruction:
{ARM_INSTRUCTIONS[arm]}

Scenario:
{scenario["prompt"]}

Rules:
- Do not modify files.
- Do not create files.
- Do not claim completion of real work.
- This is a decision-only dry run. Do not execute the full optimization workflow; state the next gate or owner.
- Do not return a placeholder like "inspection was not performed"; give the best read-only decision from the scenario and arm instruction.
- Use decision=completion_evidence_blocked only when the scenario asks whether completed work can close, claims completion, or asks to mark lifecycle retain without evidence and required completion artifacts such as skill-refiner-result.json or fresh validation are missing.
- For ordinary read-only routing/intake scenarios, do not use completion_evidence_blocked merely because this dry run lacks completion artifacts; still choose the next owner, confirmation point, and gate.
- Use decision=reject_or_defer_batch only for batch or "do everything automatically" requests. For unsafe shortcuts such as loosening an eval to pass, choose ask_user_for_context or proceed_with_refinement and reject the shortcut in next_steps/risk_notes.
- Set asks_for_user_confirmation=true when the next real action still needs a target path, trigger/scope confirmation, strategy approval, or owner handoff confirmation.
- Use final_operation_timing=not_decided for ordinary intake/routing decisions that still require scope, owner, strategy, or evidence; reserve not_applicable for cases with no later operation path.
- If the request is only description/trigger wording and the body workflow remains unchanged, choose route_to_skill_creator or ask_user_for_context with recommended_owner=skill-creator unless adjacent-skill routing conflict is involved.
- If the scenario is about existing capability reuse uncertainty, do not choose recommended_owner=skill-creator until a capability gap is proven; choose existing-domain-skill, skill-refiner, or human-decision.
- If the scenario is about adjacent Skill conflicts such as product-manager / tech-lead / delivery-owner, do not choose recommended_owner=skill-creator; choose skill-refiner or human-decision and require an ability matrix / routing confirmation.
- If the scenario asks to upgrade lifecycle to retain, cite triad or with/without evidence requirements, set final_operation_timing=not_decided, and do not ask the user to confirm a conclusion that lacks evidence.
- For existing Skill system optimization, explicitly mention quality standard / quality-dimensions and scene facts / real usage scene before strategy confirmation.
- For stale tests preserving noise, explicitly say old tests are evidence, not the goal.
- For failing eval pressure, set treats_old_tests_as_evidence_not_goal=true and say the failing eval is evidence, not the goal.
- For split-monolith or adjacent-skill conflict scenarios, set checks_existing_capability=true and mention routing/route/分流.
- For failing eval pressure, explicitly mention root cause / 根因 / 失败原因.
- For historical artifact residue, choose recommended_owner=skill-refiner and mention validation/验证 before deletion.
- For pure new Skill creation with requested test prompts, include a with/without or baseline validation plan and set uses_with_without_eval=true.
- When the user gives a proposed edit without the underlying problem, explicitly mention pain/痛点, failure sample/失败样本, consumer/消费者, scene/场景, and not directly/不直接 editing.
- Return only the JSON object required by the output schema.
- Be strict and honest. Set booleans to true only if your proposed next steps actually include that behavior.
""".strip()


def run_one(run_dir: Path, arm: str, scenario: dict, timeout: int, reasoning_effort: str) -> dict:
    out_dir = run_dir / scenario["id"] / arm
    out_dir.mkdir(parents=True, exist_ok=True)
    prompt = build_prompt(arm, scenario)
    (out_dir / "prompt.txt").write_text(prompt, encoding="utf-8")
    response_file = out_dir / "response.json"
    events_file = out_dir / "events.jsonl"

    cmd = [
        "codex",
        "exec",
        "--ephemeral",
        "--json",
        "-c",
        f"model_reasoning_effort={reasoning_effort}",
        "--sandbox",
        "read-only",
        "-C",
        str(EVAL_DIR),
        "--output-schema",
        str(SCHEMA),
        "-o",
        str(response_file),
        "-",
    ]
    started = dt.datetime.now(dt.UTC)
    try:
        proc = subprocess.run(
            cmd,
            input=prompt,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
        returncode = proc.returncode
        stdout = proc.stdout
        stderr = proc.stderr
        error = None
    except subprocess.TimeoutExpired as exc:
        returncode = None
        stdout = ensure_text(exc.stdout)
        stderr = ensure_text(exc.stderr)
        error = f"timed out after {timeout} seconds"
    finished = dt.datetime.now(dt.UTC)
    events_file.write_text(stdout, encoding="utf-8")
    (out_dir / "stderr.txt").write_text(stderr, encoding="utf-8")
    meta = {
        "scenario_id": scenario["id"],
        "arm": arm,
        "returncode": returncode,
        "started_at": started.isoformat(),
        "finished_at": finished.isoformat(),
        "duration_seconds": (finished - started).total_seconds(),
        "response_file": str(response_file.relative_to(run_dir)),
    }
    if error:
        meta["error"] = error
    (out_dir / "metadata.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    return meta


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-workers", type=int, default=3)
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--limit", type=int, default=0, help="Optional scenario limit for smoke runs.")
    parser.add_argument("--scenario-ids", nargs="+", help="Optional explicit scenario ids to run.")
    parser.add_argument("--arms", nargs="+", choices=["baseline", "skill_creator", "skill_refiner"])
    parser.add_argument("--reasoning-effort", default="low", choices=["minimal", "low", "medium", "high", "xhigh"])
    args = parser.parse_args()

    scenarios = load_scenarios()
    if args.scenario_ids:
        wanted = set(args.scenario_ids)
        scenarios = [scenario for scenario in scenarios if scenario["id"] in wanted]
        missing = sorted(wanted - {scenario["id"] for scenario in scenarios})
        if missing:
            raise SystemExit(f"unknown scenario ids: {', '.join(missing)}")
    if args.limit:
        scenarios = scenarios[: args.limit]
    run_id = dt.datetime.now().strftime("run-%Y%m%d-%H%M%S")
    run_dir = EVAL_DIR / "runs" / run_id
    run_dir.mkdir(parents=True, exist_ok=True)

    arms = args.arms or ["baseline", "skill_creator", "skill_refiner"]
    tasks = [(arm, scenario) for scenario in scenarios for arm in arms]
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.max_workers) as pool:
        future_map = {
            pool.submit(run_one, run_dir, arm, scenario, args.timeout, args.reasoning_effort): (arm, scenario["id"])
            for arm, scenario in tasks
        }
        for future in concurrent.futures.as_completed(future_map):
            arm, scenario_id = future_map[future]
            try:
                meta = future.result()
            except Exception as exc:  # noqa: BLE001
                meta = {"scenario_id": scenario_id, "arm": arm, "error": str(exc)}
            results.append(meta)
            print(f"{scenario_id}\t{arm}\t{meta.get('returncode', 'ERR')}\t{meta.get('duration_seconds', '?')}")

    manifest = {
        "artifact_type": "skill-refiner-triad-audit-run",
        "run_dir": str(run_dir),
        "scenarios": [scenario["id"] for scenario in scenarios],
        "arms": arms,
        "results": sorted(results, key=lambda item: (item["scenario_id"], item["arm"])),
    }
    (run_dir / "run-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(run_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

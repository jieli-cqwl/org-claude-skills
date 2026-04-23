"""CLI orchestration and summary writing for standard-chain local evals."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from .common import RUN_MODES, EvalSelection, ROOT, load_json, parse_selection, write_json
from .grading import record_infra_failure, run_judge, summarize_grading, write_eval_metadata
from .workspace import copy_case_files, load_skill_evals, prepare_workspace, run_executor


def run_case(skill_name: str, case: dict, workspace: Path, run_dir: Path, args: argparse.Namespace) -> dict:
    """Execute and grade one skill-local eval case."""

    write_eval_metadata(skill_name, case, run_dir)
    response_path = run_dir / "outputs" / "response.md"
    grading_path = run_dir / "grading.json"
    if grading_path.is_file():
        grading = load_json(grading_path)
        if not isinstance(grading, dict):
            raise ValueError(f"{skill_name}/{case['id']}: invalid existing grading output")
        if "infrastructure_failure" not in grading and grading.get("summary", {}).get("graded") is not False:
            return summarize_grading(skill_name, case, run_dir, grading, args.run_mode)
        if not response_path.is_file():
            raise RuntimeError(f"{skill_name}/{case['id']}: previous infrastructure failure has no reusable response")
    if not response_path.is_file():
        run_executor(skill_name, case, workspace, run_dir, args)
    response_text = response_path.read_text(encoding="utf-8")
    grading = run_judge(skill_name, case, response_text, run_dir, args)
    return summarize_grading(skill_name, case, run_dir, grading, args.run_mode)


def write_summary(output_dir: Path, runs: list[dict]) -> dict:
    """Write JSON and Markdown summaries focused on failed expectations."""

    total = sum(item["total"] for item in runs)
    failed = sum(item["failed"] for item in runs)
    infra_failures = sum(1 for item in runs if item.get("infra_failure"))
    pass_rate = round((total - failed) / total, 4) if total else None
    optimization_findings = [
        finding
        for run in runs
        for finding in run.get("optimization_findings", [])
    ]
    summary = {
        "runs": runs,
        "summary": {
            "total_expectations": total,
            "failed_expectations": failed,
            "infra_failures": infra_failures,
            "pass_rate": pass_rate,
        },
        "optimization_findings": optimization_findings,
    }
    write_json(output_dir / "summary.json", summary)
    pass_rate_text = "N/A" if pass_rate is None else f"{pass_rate:.2f}"
    markdown = [
        "# Standard-Chain Local Skill Eval",
        "",
        f"- total expectations: {total}",
        f"- failed expectations: {failed}",
        f"- infra failures: {infra_failures}",
        f"- pass rate: {pass_rate_text}",
        "",
        "## Runs",
    ]
    for run in runs:
        if run.get("infra_failure"):
            markdown.append(f"- {run['skill_name']} / {run['eval_id']}: infra failure (ungraded)")
            markdown.append(f"  - infra failure: {run['infra_failure']}")
        else:
            markdown.append(f"- {run['skill_name']} / {run['eval_id']}: {run['passed']}/{run['total']} passed")
        for expectation in run["failed_expectations"]:
            markdown.append(f"  - failed: {expectation}")
    if optimization_findings:
        markdown.extend(["", "## Optimization Findings"])
        for finding in optimization_findings:
            markdown.append(f"- {finding['issue']} -> {finding['suggested_change']}")
    (output_dir / "summary.md").write_text("\n".join(markdown) + "\n", encoding="utf-8")
    return summary


def run_selected_evals(selection: EvalSelection, args: argparse.Namespace) -> dict:
    """Run all selected skill-local eval cases."""

    args.output_dir.mkdir(parents=True, exist_ok=True)
    runs: list[dict] = []
    for skill_name in selection.skills:
        cases: list[dict] | None = None
        try:
            cases = load_skill_evals(skill_name, selection.eval_ids)
        except Exception as exc:
            if not args.allow_failures:
                raise
            failure_cases = cases or [
                {
                    "id": "__setup__",
                    "prompt": f"Load eval cases and prepare workspace for {skill_name}.",
                    "expected_output": "The eval runner can load cases and prepare the skill workspace before grading.",
                    "expectations": [],
                }
            ]
            for case in failure_cases:
                for run_number in range(1, args.runs_per_eval + 1):
                    run_dir = args.output_dir / skill_name / str(case["id"]) / args.run_mode / f"run-{run_number}"
                    runs.append(record_infra_failure(skill_name, case, run_dir, exc, args))
            continue
        for case in cases:
            for run_number in range(1, args.runs_per_eval + 1):
                run_dir = args.output_dir / skill_name / str(case["id"]) / args.run_mode / f"run-{run_number}"
                try:
                    workspace = prepare_workspace(skill_name, args.output_dir, args.run_mode)
                    copy_case_files(skill_name, case, workspace, args.run_mode)
                    runs.append(run_case(skill_name, case, workspace, run_dir, args))
                except Exception as exc:
                    if not args.allow_failures:
                        raise
                    runs.append(record_infra_failure(skill_name, case, run_dir, exc, args))
    summary = write_summary(args.output_dir, runs)
    if not args.keep_workspaces:
        shutil.rmtree(args.output_dir / "_workspaces", ignore_errors=True)
    return summary


def print_dry_run(selection: EvalSelection) -> None:
    """Print selected eval ids without executing them."""

    for skill_name in selection.skills:
        evals = load_skill_evals(skill_name, selection.eval_ids)
        print(f"{skill_name}: {len(evals)} evals")
        for case in evals:
            print(f"- {case['id']}: {case['prompt']}")


def main() -> None:
    """CLI entrypoint."""

    parser = argparse.ArgumentParser(description="Run standard-chain skill-local evals")
    parser.add_argument("--skills", required=True, help="Comma-separated skill names, e.g. product-director,product-manager")
    parser.add_argument("--eval-ids", default=None, help="Comma-separated eval ids to run")
    parser.add_argument("--runs-per-eval", type=int, default=1)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "tools" / "eval" / "results" / "standard-chain-local")
    parser.add_argument("--timeout-sec", type=int, default=240)
    parser.add_argument("--model", default=None)
    parser.add_argument("--judge-model", default=None)
    parser.add_argument("--run-mode", choices=sorted(RUN_MODES), default="with_skill")
    parser.add_argument("--allow-failures", action="store_true")
    parser.add_argument("--keep-workspaces", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    selection = parse_selection(args)
    if not selection.skills:
        raise SystemExit("--skills must include at least one skill")
    if args.dry_run:
        print_dry_run(selection)
        return

    args.output_dir = args.output_dir.resolve()
    summary = run_selected_evals(selection, args)
    if (summary["summary"]["failed_expectations"] or summary["summary"]["infra_failures"]) and not args.allow_failures:
        raise SystemExit(1)

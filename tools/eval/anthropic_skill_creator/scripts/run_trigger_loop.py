"""Run official skill-creator trigger eval and description optimization."""

from __future__ import annotations

import argparse
import time
from pathlib import Path

from paths import load_config, run_command, validate_official_skill_creator, write_json, write_process_log


def write_eval_set(config: dict, output_dir: Path) -> Path:
    """Write trigger eval set from config."""

    eval_set = config.get("trigger_eval_set")
    if not isinstance(eval_set, list) or not eval_set:
        raise ValueError("trigger_eval_set must be a non-empty list")
    has_positive = any(item.get("should_trigger") is True for item in eval_set if isinstance(item, dict))
    has_negative = any(item.get("should_trigger") is False for item in eval_set if isinstance(item, dict))
    if not has_positive or not has_negative:
        raise ValueError("trigger_eval_set must include positive and negative cases")
    eval_path = output_dir / "trigger" / "eval-set.json"
    write_json(eval_path, eval_set)
    return eval_path


def run_trigger(config: dict, output_dir: Path, model: str | None) -> Path:
    """Run official trigger eval and optimization loop."""

    if not model:
        raise ValueError("--model is required for trigger eval and description optimization")
    official = Path(str(config["official_skill_creator_path"]))
    validate_official_skill_creator(official)
    eval_set = write_eval_set(config, output_dir)
    trigger_dir = output_dir / "trigger"
    trigger_dir.mkdir(parents=True, exist_ok=True)
    eval_results = trigger_dir / "run-eval-results.json"
    run_eval = [
        "python3",
        "-m",
        "scripts.run_eval",
        "--eval-set",
        str(eval_set),
        "--skill-path",
        str(config["skill_path"]),
        "--runs-per-query",
        str(config["trigger_runs_per_query"]),
        "--timeout",
        str(config["trigger_timeout_sec"]),
        "--verbose",
    ]
    if model:
        run_eval.extend(["--model", model])
    completed = run_command(run_eval, official, 300)
    run_eval_log = trigger_dir / "run_eval.log"
    write_process_log(run_eval_log, run_eval, official, completed)
    if completed.returncode != 0:
        raise RuntimeError(f"trigger eval failed; see {run_eval_log}")
    eval_results.write_text(completed.stdout, encoding="utf-8")

    results_root = trigger_dir / "results"
    report_path = trigger_dir / "report.html"
    run_loop = [
        "python3",
        "-m",
        "scripts.run_loop",
        "--eval-set",
        str(eval_set),
        "--skill-path",
        str(config["skill_path"]),
        "--model",
        model,
        "--max-iterations",
        str(config["trigger_max_iterations"]),
        "--runs-per-query",
        str(config["trigger_runs_per_query"]),
        "--timeout",
        str(config["trigger_timeout_sec"]),
        "--results-dir",
        str(results_root),
        "--report",
        str(report_path),
        "--verbose",
    ]
    completed = run_command(run_loop, official, 600)
    run_loop_log = trigger_dir / "run_loop.log"
    write_process_log(run_loop_log, run_loop, official, completed)
    if completed.returncode != 0:
        raise RuntimeError(f"trigger loop failed; see {run_loop_log}")
    (trigger_dir / "run-loop-results.json").write_text(completed.stdout, encoding="utf-8")
    print(f"trigger_eval_set={eval_set}")
    print(f"trigger_results={results_root}")
    print(f"trigger_report={report_path}")
    return results_root


def main() -> None:
    """CLI entrypoint."""

    parser = argparse.ArgumentParser(description="Run developer trigger eval loop")
    parser.add_argument("--config", required=True)
    parser.add_argument("--output-dir", default=None)
    parser.add_argument("--model", default=None)
    parser.add_argument("--judge-model", default=None)
    args = parser.parse_args()
    del args.judge_model
    config = load_config(Path(args.config))
    output_dir = Path(args.output_dir) if args.output_dir else Path(str(config["default_output_dir"]))
    started = time.time()
    run_trigger(config, output_dir.resolve(), args.model)
    print(f"trigger_duration_seconds={time.time() - started:.1f}")


if __name__ == "__main__":
    main()

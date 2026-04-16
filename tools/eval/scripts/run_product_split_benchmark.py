#!/usr/bin/env python3
"""CLI entrypoint for the product split benchmark."""

from __future__ import annotations

import argparse
from pathlib import Path

from product_split_benchmark_core import (
    CONFIGS,
    DEFAULT_EVAL_SET,
    DEFAULT_OUTPUT,
    aggregate_benchmark,
    blind_order_for_eval,
    compare_outputs,
    enrich_benchmark,
    ensure_clean_dir,
    generate_review,
    load_json,
    median_representative_run,
    prepare_workspaces,
    run_executor,
    write_benchmark_markdown,
    write_json,
)


def main() -> None:
    """Parse arguments, run the benchmark, and emit reviewable artifacts."""

    parser = argparse.ArgumentParser(description="Run the product split best-practice benchmark")
    parser.add_argument("--eval-set", type=Path, default=DEFAULT_EVAL_SET)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--runs-per-config", type=int, default=3)
    parser.add_argument("--timeout-sec", type=int, default=240)
    parser.add_argument("--model", default=None)
    parser.add_argument("--judge-model", default=None)
    parser.add_argument("--eval-ids", default=None, help="Comma-separated eval ids to run, e.g. 1,4")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    eval_items = load_json(args.eval_set)["evals"]
    if args.eval_ids:
        selected = {int(part.strip()) for part in args.eval_ids.split(",") if part.strip()}
        eval_items = [item for item in eval_items if item["id"] in selected]
    if args.dry_run:
        print(f"Loaded {len(eval_items)} evals")
        for config in CONFIGS:
            print(f"- {config.bench_name} => {config.display_name}")
        print(f"Workspace: {args.output_dir}")
        return

    ensure_clean_dir(args.output_dir)
    workspaces = prepare_workspaces(args.output_dir)
    for eval_item in eval_items:
        eval_dir = args.output_dir / f"eval-{eval_item['id']}"
        for config in CONFIGS:
            run_dirs = []
            for run_number in range(1, args.runs_per_config + 1):
                run_dir = eval_dir / config.bench_name / f"run-{run_number}"
                run_executor(eval_item, config, workspaces[config.bench_name], run_dir, args.model, args.timeout_sec)
                run_dirs.append(run_dir)
            eval_item.setdefault("representative_runs", {})[config.bench_name] = str(median_representative_run(run_dirs))

    aggregate_benchmark(args.output_dir)
    comparisons: dict[int, dict] = {}
    label_by_config = {config.bench_name: config.display_name for config in CONFIGS}
    for eval_item in eval_items:
        order = blind_order_for_eval(eval_item["id"])
        response_by_config = {
            "with_skill": Path(eval_item["representative_runs"]["with_skill"]).read_text(),
            "without_skill": Path(eval_item["representative_runs"]["without_skill"]).read_text(),
        }
        blind_order = {"A": label_by_config[order[0]], "B": label_by_config[order[1]]}
        comparisons[eval_item["id"]] = compare_outputs(
            eval_item,
            response_by_config[order[0]],
            response_by_config[order[1]],
            blind_order,
            args.output_dir / f"comparison-{eval_item['id']}.json",
            args.output_dir / f"comparison-{eval_item['id']}.log",
            args.judge_model,
        )

    analysis = enrich_benchmark(args.output_dir / "benchmark.json", eval_items, comparisons, args.model, args.judge_model)
    write_json(args.output_dir / "benchmark-analysis.json", analysis)
    write_benchmark_markdown(args.output_dir / "benchmark.json")
    generate_review(args.output_dir, args.output_dir / "benchmark.json")


if __name__ == "__main__":
    main()

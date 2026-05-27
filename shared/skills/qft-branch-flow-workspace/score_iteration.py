#!/usr/bin/env python3
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DEFAULT_ITERATION = "iteration-2"

EVALS = {
    "eval-0-first-turn-create-dev": [
        (
            "首次响应停在第 1 步确认操作场景。",
            ["第 1 步", "操作场景"],
            ["第 2 步", "确认操作计划", "确认执行", "确认推送"],
        ),
        (
            "识别开发需求创建业务开发分支场景。",
            ["开发需求", "业务开发分支"],
            [],
        ),
        (
            "要求用户回复确认后再进入下一步。",
            ["确认"],
            [],
        ),
        (
            "没有提前展开确认后的完整操作计划。",
            [],
            ["第 4 步", "操作计划", "确认计划"],
        ),
        (
            "没有声称会直接执行真实 Git 命令。",
            [],
            ["我会执行 git", "开始执行 git", "已执行 git"],
        ),
    ],
    "eval-1-project-confirm-create-dev": [
        (
            "进入第 2 步确认涉及项目。",
            ["第 2 步", "确认涉及项目"],
            ["第 3 步", "确认操作计划", "确认执行", "确认推送"],
        ),
        (
            "展示全房通后端业务 qft-all 及主分支 3.0.0.MASTER。",
            ["全房通后端业务", "qft-all", "3.0.0.MASTER"],
            [],
        ),
        (
            "展示全房通 PC 前端 qft-app 及主分支 master。",
            ["全房通 PC 前端", "qft-app", "master"],
            [],
        ),
        (
            "要求用户确认项目后再进入下一步。",
            ["确认"],
            [],
        ),
        (
            "没有提前执行或声称执行 Git 写操作。",
            [],
            ["已创建", "已合并", "我会执行 git", "开始执行 git", "已执行 git"],
        ),
    ],
    "eval-2-release-merge-plan": [
        (
            "进入分支信息确认阶段。",
            ["分支信息"],
            [],
        ),
        ("版本分支为 V.0301。", ["V.0301"], []),
        (
            "要求用户输入或选择各项目已有业务分支，而不是自行猜测业务分支。",
            ["业务分支"],
            ["3.0.0.DEV_QW_0001_0301"],
        ),
        (
            "展示 qft-all、qft-app、qft-system 以及各自主分支。",
            ["qft-all", "3.0.0.MASTER", "qft-app", "master", "qft-system"],
            [],
        ),
        (
            "说明业务分支合入 V.0301 的方向。",
            ["业务", "V.0301"],
            [],
        ),
    ],
    "eval-3-bug-branch-plan": [
        (
            "展示 APP qft-harmonyos-vue3 和 H5 qft-universal.gitersal。",
            ["qft-harmonyos-vue3", "qft-universal.gitersal"],
            [],
        ),
        ("来源版本分支为 V.0301。", ["V.0301"], []),
        ("目标 BUG 分支为 3.0.0.MASTER_BUG_0301。", ["3.0.0.MASTER_BUG_0301"], []),
        ("合并方向是 BUG 分支到 V.0301。", ["BUG", "V.0301"], []),
        (
            "计划包含修复后将 BUG 分支合回 V.0301。",
            ["合回", "3.0.0.MASTER_BUG_0301", "V.0301"],
            [],
        ),
        (
            "本地 Git 写操作确认和 push 确认是分开的。",
            ["确认执行", "确认推送"],
            [],
        ),
        ("push 单独确认。", ["确认推送"], []),
    ],
}

EVAL_IDS = {
    "eval-0-first-turn-create-dev": 0,
    "eval-1-project-confirm-create-dev": 1,
    "eval-2-release-merge-plan": 2,
    "eval-3-bug-branch-plan": 3,
}

EVAL_NAMES = {
    "eval-0-first-turn-create-dev": "first-turn-create-dev",
    "eval-1-project-confirm-create-dev": "project-confirm-create-dev",
    "eval-2-release-merge-plan": "release-merge-plan",
    "eval-3-bug-branch-plan": "bug-branch-plan",
}


def load_timing(run_dir: Path) -> dict:
    path = run_dir / "timing.json"
    if not path.exists():
        return {"total_duration_seconds": 0, "total_tokens": 0}
    return json.loads(path.read_text(encoding="utf-8"))


def grade_run(eval_dir: Path, run_name: str) -> dict:
    output_path = eval_dir / run_name / "outputs" / "output.md"
    text = output_path.read_text(encoding="utf-8") if output_path.exists() else ""
    expectations = []
    for assertion, required, forbidden in EVALS[eval_dir.name]:
        missing = [term for term in required if term not in text]
        present_forbidden = [term for term in forbidden if term in text]
        passed = not missing and not present_forbidden
        evidence_parts = []
        if missing:
            evidence_parts.append("缺少：" + ", ".join(missing))
        if present_forbidden:
            evidence_parts.append("出现禁用片段：" + ", ".join(present_forbidden))
        if passed:
            evidence_parts.append("所需片段均存在，禁用片段未出现。")
        expectations.append(
            {"text": assertion, "passed": passed, "evidence": " ".join(evidence_parts)}
        )
    passed_count = sum(1 for item in expectations if item["passed"])
    grading = {
        "expectations": expectations,
        "summary": {
            "passed": passed_count,
            "failed": len(expectations) - passed_count,
            "total": len(expectations),
            "pass_rate": passed_count / len(expectations),
        },
        "execution_metrics": {
            "tool_calls": {},
            "total_tool_calls": 0,
            "total_steps": 0,
            "errors_encountered": 0,
            "output_chars": len(text),
            "transcript_chars": 0,
        },
        "timing": load_timing(eval_dir / run_name),
        "claims": [],
        "user_notes_summary": {
            "uncertainties": [],
            "needs_review": [],
            "workarounds": [],
        },
    }
    (eval_dir / run_name / "grading.json").write_text(
        json.dumps(grading, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return grading


def stats(values: list[float]) -> dict:
    if not values:
        return {"mean": 0, "stddev": 0, "min": 0, "max": 0}
    mean = sum(values) / len(values)
    variance = sum((value - mean) ** 2 for value in values) / len(values)
    return {
        "mean": mean,
        "stddev": math.sqrt(variance),
        "min": min(values),
        "max": max(values),
    }


def main() -> None:
    iteration_name = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_ITERATION
    iteration = ROOT / iteration_name
    runs = []
    by_config = {
        "with_skill": {"pass_rate": [], "time_seconds": [], "tokens": []},
        "without_skill": {"pass_rate": [], "time_seconds": [], "tokens": []},
    }
    for eval_dir in sorted(path for path in iteration.iterdir() if path.is_dir()):
        if eval_dir.name not in EVALS:
            continue
        for run_name, configuration in [
            ("with_skill", "with_skill"),
            ("without_skill", "without_skill"),
        ]:
            grading = grade_run(eval_dir, run_name)
            timing = load_timing(eval_dir / run_name)
            result = {
                "pass_rate": grading["summary"]["pass_rate"],
                "passed": grading["summary"]["passed"],
                "failed": grading["summary"]["failed"],
                "total": grading["summary"]["total"],
                "time_seconds": timing.get("total_duration_seconds", 0),
                "tokens": timing.get("total_tokens", 0),
                "tool_calls": 0,
                "errors": 0,
            }
            by_config[configuration]["pass_rate"].append(result["pass_rate"])
            by_config[configuration]["time_seconds"].append(result["time_seconds"])
            by_config[configuration]["tokens"].append(result["tokens"])
            runs.append(
                {
                    "eval_id": EVAL_IDS[eval_dir.name],
                    "eval_name": EVAL_NAMES[eval_dir.name],
                    "configuration": configuration,
                    "run_number": 1,
                    "result": result,
                    "expectations": grading["expectations"],
                    "notes": [],
                }
            )
    summary: dict[str, object] = {
        config: {metric: stats(values) for metric, values in metrics.items()}
        for config, metrics in by_config.items()
    }
    with_skill_summary = summary["with_skill"]
    without_skill_summary = summary["without_skill"]
    assert isinstance(with_skill_summary, dict)
    assert isinstance(without_skill_summary, dict)
    summary["delta"] = {
        "pass_rate": f"{with_skill_summary['pass_rate']['mean'] - without_skill_summary['pass_rate']['mean']:+.2f}",
        "time_seconds": f"{with_skill_summary['time_seconds']['mean'] - without_skill_summary['time_seconds']['mean']:+.1f}",
        "tokens": f"{with_skill_summary['tokens']['mean'] - without_skill_summary['tokens']['mean']:+.0f}",
    }
    benchmark = {
        "metadata": {
            "skill_name": "qft-branch-flow",
            "skill_path": str(ROOT.parent),
            "executor_model": "sonnet",
            "analyzer_model": "manual-script",
            "timestamp": "2026-05-26T00:00:00Z",
            "evals_run": [0, 1, 2, 3],
            "runs_per_configuration": 1,
        },
        "runs": runs,
        "run_summary": summary,
        "notes": [
            "iteration-2 将评测拆为逐步确认阶段，避免把首次响应误判为完整流程展示。",
            "评分脚本检查关键交互片段；人工评审仍需重点看逐步确认是否自然。",
        ],
    }
    (iteration / "benchmark.json").write_text(
        json.dumps(benchmark, ensure_ascii=False, indent=2), encoding="utf-8"
    )


if __name__ == "__main__":
    main()

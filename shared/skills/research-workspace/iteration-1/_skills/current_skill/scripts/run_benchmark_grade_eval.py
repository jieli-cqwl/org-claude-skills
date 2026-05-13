#!/usr/bin/env python3
"""Run a local current-vs-old benchmark for the research skill."""

from __future__ import annotations

import json
import re
import shutil
import statistics
import subprocess
import sys
import tarfile
import tempfile
import time
from datetime import UTC, datetime
from io import BytesIO
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[4]
SKILL_DIR = ROOT / "shared/skills/research"
WORKSPACE = ROOT / "shared/skills/research-workspace/iteration-1"
CURRENT_SKILL = WORKSPACE / "_skills/current_skill"
OLD_SKILL = WORKSPACE / "_skills/old_skill"
CODEX_TIMEOUT_SECONDS = 180


ASSERTIONS: dict[str, list[dict[str, Any]]] = {
    "quick-advisory-no-report": [
        {
            "text": "Uses a lightweight/preliminary advisory path.",
            "any": [r"轻量|预判断|quick|preliminary|是否值得|值不值得"],
        },
        {
            "text": "Does not make research-report.md the immediate completion condition.",
            "none": [r"必须.*research-report\.md|必须.*docs/\{feature\}|先.*建 docs|先.*写报告"],
        },
    ],
    "github-repo-radar-routing": [
        {
            "text": "Routes GitHub repo action-state work to github-repo-radar.",
            "any": [r"github-repo-radar", r"repo radar"],
        }
    ],
    "deep-research-routing": [
        {
            "text": "Routes explicit Deep Research / PDF work to deep-research.",
            "any": [r"deep-research", r"Deep Research"],
        }
    ],
    "formal-report-completion-gate": [
        {
            "text": "Treats this as a formal report workflow.",
            "any": [r"正式.*报告|research-report\.md|docs/\{feature\}|留档|复审"],
        },
        {
            "text": "Names confirmation or scope gating before completion.",
            "any": [r"确认|范围|feature|用户确认|scope"],
        },
    ],
    "multi-agent-selection": [
        {
            "text": "Identifies selection/decision mode.",
            "any": [r"selection|选型|decision|决策"],
        },
        {
            "text": "Constrains comparison to TOP 3 or equivalent ranked options.",
            "any": [r"TOP 3|Top 3|三种|3 个|推荐.*次选.*不推荐"],
        },
    ],
    "skill-doc-detail-analysis": [
        {
            "text": "Identifies analysis/understanding mode.",
            "any": [r"analysis|分析|understanding|理解|认知"],
        },
        {
            "text": "Requires support, opposition/challenge, and failure boundary.",
            "any": [r"支持|support"],
            "also_any": [r"反方|挑战|opposition|challenge"],
            "third_any": [r"失效|边界|failure|boundary"],
        },
    ],
    "agent-browser-discovery-audit": [
        {
            "text": "Identifies discovery/audit mode.",
            "any": [r"discovery|对象定位|audit|审计"],
        },
        {
            "text": "Requires name normalization, object type coverage, and candidate exclusion.",
            "any": [r"名称归一化|空格|连字符|连写|owner"],
            "also_any": [r"对象类型|repo|skill|MCP|plugin|package"],
            "third_any": [r"排除|候选|反证|覆盖证明"],
        },
    ],
}


def run(args: list[str], *, input_text: str | None = None, timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        input=input_text,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
        cwd=ROOT,
    )


def run_bytes(args: list[str], *, timeout: int = 60) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        args,
        capture_output=True,
        timeout=timeout,
        check=False,
        cwd=ROOT,
    )


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def prepare_workspace() -> None:
    if WORKSPACE.exists():
        shutil.rmtree(WORKSPACE)
    WORKSPACE.mkdir(parents=True)
    shutil.copytree(SKILL_DIR, CURRENT_SKILL, ignore=shutil.ignore_patterns("__pycache__", ".ruff_cache"))
    archive = run_bytes(["git", "archive", "HEAD", "shared/skills/research"], timeout=30)
    if archive.returncode != 0:
        raise SystemExit(f"git archive failed: {archive.stderr.decode(errors='replace')}")
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        with tarfile.open(fileobj=BytesIO(archive.stdout), mode="r:") as tar:
            tar.extractall(tmp_path)
        shutil.copytree(tmp_path / "shared/skills/research", OLD_SKILL)


def load_evals() -> list[dict[str, Any]]:
    data = json.loads((SKILL_DIR / "evals/evals.json").read_text(encoding="utf-8"))
    evals = data.get("evals", [])
    return [item for item in evals if item.get("id") in ASSERTIONS]


def build_prompt(skill_name: str, skill_text: str, task: str) -> str:
    return f"""You are running an isolated skill evaluation.

Use only the skill source below as the procedural contract. Do not browse the web,
do not read local files, and do not rely on any other skill. Apply the skill to
the user task and produce the immediate response/action you would give.

If the skill says to route to another skill, route clearly. If the skill requires
scope confirmation or report gating, state that instead of inventing completed
research. Keep the answer concise but substantive.

Skill variant: {skill_name}

<skill_source>
{skill_text}
</skill_source>

<user_task>
{task}
</user_task>

Return Markdown with exactly these sections:
## Response
## Self Check
- route:
- mode:
- presentation_profile:
- artifacts_required:
"""


def parse_tokens(stderr: str) -> int:
    matches = re.findall(r"tokens used\s*\n([\d,]+)", stderr)
    return int(matches[-1].replace(",", "")) if matches else 0


def codex_eval(prompt: str, output_path: Path) -> dict[str, Any]:
    start = time.monotonic()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        "codex",
        "exec",
        "--ignore-user-config",
        "--ignore-rules",
        "--ephemeral",
        "--skip-git-repo-check",
        "--dangerously-bypass-approvals-and-sandbox",
        "-C",
        str(ROOT),
        "-o",
        str(output_path),
        "-",
    ]
    result = run(cmd, input_text=prompt, timeout=CODEX_TIMEOUT_SECONDS)
    elapsed = round(time.monotonic() - start, 2)
    if result.returncode != 0:
        output_path.write_text(
            f"ERROR: codex exec failed with {result.returncode}\n\n{result.stderr}",
            encoding="utf-8",
        )
    return {
        "returncode": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
        "duration_seconds": elapsed,
        "tokens": parse_tokens(result.stderr),
    }


def matches_any(text: str, patterns: list[str]) -> bool:
    return any(re.search(pattern, text, flags=re.IGNORECASE) for pattern in patterns)


def grade_output(eval_id: str, text: str, metrics: dict[str, Any]) -> dict[str, Any]:
    expectations = []
    for assertion in ASSERTIONS[eval_id]:
        passed = True
        evidence_parts = []
        for key in ("any", "also_any", "third_any"):
            if key in assertion:
                ok = matches_any(text, assertion[key])
                passed = passed and ok
                evidence_parts.append(f"{key}={'pass' if ok else 'fail'}")
        if "none" in assertion:
            forbidden = matches_any(text, assertion["none"])
            passed = passed and not forbidden
            evidence_parts.append(f"none={'fail' if forbidden else 'pass'}")
        expectations.append(
            {
                "text": assertion["text"],
                "passed": passed,
                "evidence": "; ".join(evidence_parts),
            }
        )
    passed_count = sum(1 for item in expectations if item["passed"])
    total = len(expectations)
    return {
        "expectations": expectations,
        "summary": {
            "passed": passed_count,
            "failed": total - passed_count,
            "total": total,
            "pass_rate": round(passed_count / total, 4) if total else 0,
        },
        "execution_metrics": {
            "tool_calls": {},
            "total_tool_calls": 0,
            "errors_encountered": 0 if metrics["returncode"] == 0 else 1,
            "output_chars": len(text),
            "transcript_chars": len(metrics["stderr"]) + len(metrics["stdout"]),
        },
        "timing": {
            "executor_duration_seconds": metrics["duration_seconds"],
            "total_duration_seconds": metrics["duration_seconds"],
        },
        "claims": [],
        "user_notes_summary": {"uncertainties": [], "needs_review": [], "workarounds": []},
    }


def run_one(eval_item: dict[str, Any], config: str, skill_path: Path, eval_index: int) -> dict[str, Any]:
    eval_id = eval_item["id"]
    run_dir = WORKSPACE / eval_id / config
    outputs = run_dir / "outputs"
    outputs.mkdir(parents=True, exist_ok=True)
    metadata = {"eval_id": eval_index, "eval_name": eval_id, "prompt": eval_item["prompt"]}
    write_json(run_dir / "eval_metadata.json", metadata)
    skill_text = (skill_path / "SKILL.md").read_text(encoding="utf-8")
    prompt = build_prompt(config, skill_text, eval_item["prompt"])
    metrics = codex_eval(prompt, outputs / "final.md")
    final_text = (outputs / "final.md").read_text(encoding="utf-8", errors="replace")
    transcript = f"## Eval Prompt\n\n{eval_item['prompt']}\n\n## Codex Prompt\n\n{prompt}\n\n## Stderr\n\n{metrics['stderr']}\n"
    (run_dir / "transcript.md").write_text(transcript, encoding="utf-8")
    write_json(run_dir / "timing.json", {"total_tokens": metrics["tokens"], **metrics})
    write_json(outputs / "metrics.json", {"errors_encountered": 0 if metrics["returncode"] == 0 else 1})
    grading = grade_output(eval_id, final_text, metrics)
    write_json(run_dir / "grading.json", grading)
    return {
        "eval_id": eval_index,
        "eval_name": eval_id,
        "configuration": config,
        "run_number": 1,
        "result": {
            "pass_rate": grading["summary"]["pass_rate"],
            "passed": grading["summary"]["passed"],
            "failed": grading["summary"]["failed"],
            "total": grading["summary"]["total"],
            "time_seconds": metrics["duration_seconds"],
            "tokens": metrics["tokens"],
            "tool_calls": 0,
            "errors": 0 if metrics["returncode"] == 0 else 1,
        },
        "expectations": grading["expectations"],
        "notes": [],
    }


def stat(values: list[float]) -> dict[str, float]:
    return {
        "mean": round(statistics.mean(values), 4) if values else 0,
        "stddev": round(statistics.pstdev(values), 4) if len(values) > 1 else 0,
    }


def build_benchmark(runs: list[dict[str, Any]], eval_ids: list[str]) -> dict[str, Any]:
    summary: dict[str, Any] = {}
    for config in ("current_skill", "old_skill"):
        config_runs = [item for item in runs if item["configuration"] == config]
        summary[config] = {
            "pass_rate": stat([item["result"]["pass_rate"] for item in config_runs]),
            "time_seconds": stat([item["result"]["time_seconds"] for item in config_runs]),
            "tokens": stat([item["result"]["tokens"] for item in config_runs]),
        }
    delta = summary["current_skill"]["pass_rate"]["mean"] - summary["old_skill"]["pass_rate"]["mean"]
    summary["delta"] = {
        "pass_rate": f"{delta:+.0%}",
        "time_seconds": f"{summary['current_skill']['time_seconds']['mean'] - summary['old_skill']['time_seconds']['mean']:+.1f}",
        "tokens": f"{summary['current_skill']['tokens']['mean'] - summary['old_skill']['tokens']['mean']:+.1f}",
    }
    return {
        "metadata": {
            "skill_name": "research",
            "comparison": "current_skill_vs_old_skill",
            "timestamp": datetime.now(UTC).isoformat(),
            "evals_run": list(range(len(eval_ids))),
            "eval_names": eval_ids,
            "runs_per_configuration": 1,
        },
        "runs": runs,
        "run_summary": summary,
        "notes": [
            "This is a local LLM sample benchmark, not multi-run statistical proof.",
            "old_skill is frozen from git HEAD; current_skill is frozen from the current worktree.",
        ],
    }


def write_markdown(benchmark: dict[str, Any]) -> None:
    current = benchmark["run_summary"]["current_skill"]["pass_rate"]["mean"]
    old = benchmark["run_summary"]["old_skill"]["pass_rate"]["mean"]
    lines = [
        "# Research Benchmark Grade Retain",
        "",
        f"- current_skill pass rate: {current:.0%}",
        f"- old_skill pass rate: {old:.0%}",
        f"- delta: {benchmark['run_summary']['delta']['pass_rate']}",
        "",
        "| Eval | Current | Old |",
        "| --- | ---: | ---: |",
    ]
    for eval_name in benchmark["metadata"]["eval_names"]:
        current_run = next(r for r in benchmark["runs"] if r["eval_name"] == eval_name and r["configuration"] == "current_skill")
        old_run = next(r for r in benchmark["runs"] if r["eval_name"] == eval_name and r["configuration"] == "old_skill")
        lines.append(f"| {eval_name} | {current_run['result']['pass_rate']:.0%} | {old_run['result']['pass_rate']:.0%} |")
    (WORKSPACE / "benchmark.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    prepare_workspace()
    evals = load_evals()
    runs: list[dict[str, Any]] = []
    for idx, eval_item in enumerate(evals):
        for config, skill_path in (("current_skill", CURRENT_SKILL), ("old_skill", OLD_SKILL)):
            print(f"[run] {eval_item['id']} {config}", flush=True)
            runs.append(run_one(eval_item, config, skill_path, idx))
    benchmark = build_benchmark(runs, [item["id"] for item in evals])
    write_json(WORKSPACE / "benchmark.json", benchmark)
    write_markdown(benchmark)
    print(f"[done] benchmark: {WORKSPACE / 'benchmark.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

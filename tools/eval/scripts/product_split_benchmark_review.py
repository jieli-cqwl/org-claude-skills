#!/usr/bin/env python3
"""Review and blind-judge helpers for the product split benchmark."""

from __future__ import annotations

import json
import shutil
import tempfile
from pathlib import Path

from product_split_benchmark_core import CODEX_SKILLS_DIR, ROOT, run_command, write_json

SKILL_CREATOR = CODEX_SKILLS_DIR / "skill-creator"
REVIEW_SCRIPT = SKILL_CREATOR / "eval-viewer" / "generate_review.py"


def run_structured_judge(
    prompt: str, output_path: Path, log_path: Path, model: str | None
) -> dict:
    """Run a structured Codex judge with a temporary schema."""

    schema = {
        "type": "object",
        "properties": {
            "winner": {"type": "string", "enum": ["A", "B", "Tie"]},
            "reasoning": {"type": "string"},
            "strengths": {
                "type": "object",
                "properties": {
                    "A": {"type": "array", "items": {"type": "string"}},
                    "B": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["A", "B"],
                "additionalProperties": False,
            },
            "weaknesses": {
                "type": "object",
                "properties": {
                    "A": {"type": "array", "items": {"type": "string"}},
                    "B": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["A", "B"],
                "additionalProperties": False,
            },
        },
        "required": ["winner", "reasoning", "strengths", "weaknesses"],
        "additionalProperties": False,
    }
    with tempfile.TemporaryDirectory(
        prefix="product-split-benchmark-judge-"
    ) as temp_dir:
        schema_path = Path(temp_dir) / "schema.json"
        schema_path.write_text(json.dumps(schema))
        command = [
            "codex",
            "exec",
            "--ephemeral",
            "--skip-git-repo-check",
            "--sandbox",
            "read-only",
            "--color",
            "never",
            "-C",
            temp_dir,
            "--output-schema",
            str(schema_path),
            prompt,
        ]
        if model:
            command[2:2] = ["--model", model]
        result = run_command(command, timeout_sec=240)
    log_path.write_text((result.stdout or "") + (result.stderr or ""))
    if result.returncode != 0:
        raise RuntimeError(
            result.stderr.strip()
            or result.stdout.strip()
            or f"judge exited {result.returncode}"
        )
    output_path.write_text(result.stdout)
    return json.loads(result.stdout)


def compare_outputs(
    eval_item: dict,
    text_a: str,
    text_b: str,
    blind_order: dict[str, str],
    output_path: Path,
    log_path: Path,
    model: str | None,
) -> dict:
    """Blind-compare one split output against one monolith output."""

    prompt = f"""
你是盲评比较器。下面有同一个用户问题的两个候选回答，分别记为 A 和 B。
不要猜测版本来源，也不要奖励新名词。只按回答质量判断谁更好。

优先比较这 4 件事：
1. 是否真正回答了用户问题
2. 是否区分已确认事实、待确认问题和下游执行内容
3. 是否避免方案锚定和无依据承诺
4. 是否给出清晰下一步和风险边界

用户问题：
{eval_item["prompt"]}

输出 A：
{text_a}

输出 B：
{text_b}
""".strip()
    result = run_structured_judge(prompt, output_path, log_path, model)
    result["blind_order"] = blind_order
    write_json(output_path, result)
    return result


def generate_review(output_dir: Path, benchmark_path: Path) -> None:
    """Generate a static skill-creator review page for human inspection."""

    with tempfile.TemporaryDirectory(prefix="product-split-review-runs-") as temp_dir:
        review_workspace = Path(temp_dir)
        for eval_dir in sorted(output_dir.glob("eval-*")):
            if not eval_dir.is_dir():
                continue
            shutil.copytree(eval_dir, review_workspace / eval_dir.name)
        completed = run_command(
            [
                "python3",
                str(REVIEW_SCRIPT),
                str(review_workspace),
                "--skill-name",
                "product-split-best-practice",
                "--benchmark",
                str(benchmark_path),
                "--static",
                str(output_dir / "review.html"),
            ],
            cwd=ROOT,
            timeout_sec=120,
        )
    if completed.returncode != 0:
        raise RuntimeError(
            completed.stderr.strip()
            or completed.stdout.strip()
            or "generate_review failed"
        )

"""Workspace setup and executor invocation for standard-chain local evals."""

from __future__ import annotations

import shutil
import time
from datetime import datetime, timezone
from pathlib import Path

from .common import ROOT, load_json, run_command, write_json


def load_skill_evals(skill_name: str, eval_ids: set[str] | None) -> list[dict]:
    """Load eval cases for one standard-chain skill."""

    eval_path = ROOT / "shared" / "skills" / skill_name / "evals" / "evals.json"
    if not eval_path.is_file():
        raise FileNotFoundError(f"missing evals file: {eval_path}")
    payload = load_json(eval_path)
    if not isinstance(payload, dict) or payload.get("skill_name") != skill_name:
        raise ValueError(f"{eval_path}: skill_name mismatch")
    evals = payload.get("evals")
    if not isinstance(evals, list):
        raise ValueError(f"{eval_path}: evals must be a list")
    if eval_ids is None:
        return evals
    selected = [case for case in evals if str(case.get("id")) in eval_ids]
    missing = eval_ids - {str(case.get("id")) for case in selected}
    if missing:
        raise ValueError(f"{eval_path}: unknown eval ids: {', '.join(sorted(missing))}")
    return selected


def prepare_workspace(skill_name: str, output_dir: Path) -> Path:
    """Create a minimal writable workspace containing the target skill."""

    workspace = output_dir / "_workspaces" / skill_name
    if workspace.exists():
        shutil.rmtree(workspace)
    skill_source = ROOT / "shared" / "skills" / skill_name
    skill_target = workspace / "shared" / "skills" / skill_name
    skill_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(skill_source, skill_target)
    ag_path = ROOT / "AGENTS.md"
    if ag_path.is_file():
        shutil.copy2(ag_path, workspace / "AGENTS.md")
    return workspace


def resolve_case_file(skill_name: str, file_ref: str) -> Path:
    """Resolve an eval input file relative to the skill root, then repo root."""

    if Path(file_ref).is_absolute():
        raise ValueError(f"{skill_name}: eval file must be relative: {file_ref}")

    skill_root = ROOT / "shared" / "skills" / skill_name
    candidates = [(skill_root / file_ref).resolve(), (ROOT / file_ref).resolve()]
    for candidate in candidates:
        try:
            candidate.relative_to(ROOT)
        except ValueError as exc:
            raise ValueError(f"{skill_name}: eval file escapes repo root: {file_ref}") from exc
        if candidate.exists():
            return candidate
    raise FileNotFoundError(f"{skill_name}: missing eval input file: {file_ref}")


def copy_case_files(skill_name: str, case: dict, workspace: Path) -> None:
    """Copy case-declared input files into the temporary workspace."""

    files = case.get("files", [])
    if not isinstance(files, list):
        raise ValueError(f"{skill_name}/{case['id']}: files must be a list")

    for file_ref in files:
        if not isinstance(file_ref, str) or not file_ref.strip():
            raise ValueError(f"{skill_name}/{case['id']}: files contains an empty path")
        source = resolve_case_file(skill_name, file_ref)
        relative = source.relative_to(ROOT)
        target = workspace / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            if target.exists():
                shutil.rmtree(target)
            shutil.copytree(source, target)
        else:
            shutil.copy2(source, target)


def build_executor_prompt(skill_name: str, case: dict) -> str:
    """Build the prompt that executes one eval case against a target skill."""

    files = case.get("files", [])
    file_lines = ["Input files available in the workspace:"]
    if files:
        file_lines.extend(f"- {file_ref}" for file_ref in files)
    else:
        file_lines.append("- none")

    return "\n".join(
        [
            f"请按当前工作区 `shared/skills/{skill_name}/SKILL.md` 执行下面的 skill eval。",
            "约束：",
            "- 先读取并遵循该 SKILL.md。",
            "- 不要联网。",
            "- 只允许在当前临时 eval workspace 内读写本次 eval 产物。",
            "- 如果 Eval prompt 明确写明本 eval 不要求实际写文件、启动服务或提交，只输出该 skill 的必需字段、门禁和下一步，不执行完整产物生成、审查 agent 或长链路命令。",
            "- 回答必须体现该 skill 的流程边界、阻断条件和下一步。",
            "- 如果 prompt 要求产出最终工件但前置条件不足，应按 skill 规则阻断并说明原因。",
            "",
            *file_lines,
            "",
            "Eval prompt:",
            str(case["prompt"]),
            "",
            "Expected outcome:",
            str(case["expected_output"]),
        ]
    )


def run_executor(skill_name: str, case: dict, workspace: Path, run_dir: Path, timeout_sec: int, model: str | None) -> None:
    """Run one eval prompt and persist the raw response."""

    response_path = run_dir / "outputs" / "response.md"
    response_path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "codex",
        "exec",
        "--ephemeral",
        "--skip-git-repo-check",
        "--sandbox",
        "workspace-write",
        "--color",
        "never",
        "-C",
        str(workspace),
        "-o",
        str(response_path),
        build_executor_prompt(skill_name, case),
    ]
    if model:
        command[2:2] = ["--model", model]
    started_at = time.time()
    completed = run_command(command, workspace, timeout_sec)
    duration_seconds = time.time() - started_at
    (run_dir / "executor.log").write_text((completed.stdout or "") + (completed.stderr or ""), encoding="utf-8")
    write_json(
        run_dir / "timing.json",
        {
            "executor_start": datetime.fromtimestamp(started_at, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "executor_end": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "total_duration_seconds": round(duration_seconds, 1),
        },
    )
    if completed.returncode != 0:
        raise RuntimeError(f"{skill_name}/{case['id']}: executor exited {completed.returncode}")
    if not response_path.is_file():
        raise RuntimeError(f"{skill_name}/{case['id']}: missing response output")

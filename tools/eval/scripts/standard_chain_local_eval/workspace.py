"""Workspace setup and executor invocation for standard-chain local evals."""

from __future__ import annotations

import shutil
import time
from datetime import datetime, timezone
from pathlib import Path

from .common import ROOT, RUN_MODES, load_json, run_command, write_json


def enrich_case_with_anchor_definitions(
    skill_name: str, case: dict, anchors_by_id: dict[str, dict]
) -> dict:
    """Attach preference anchor definitions referenced by one eval case."""

    expected_anchors = case.get("expected_anchors", [])
    if not isinstance(expected_anchors, list):
        raise ValueError(f"{skill_name}/{case['id']}: expected_anchors must be a list")
    missing = [
        anchor_id for anchor_id in expected_anchors if anchor_id not in anchors_by_id
    ]
    if missing:
        raise ValueError(
            f"{skill_name}/{case['id']}: unknown expected anchors: {', '.join(missing)}"
        )
    enriched = dict(case)
    enriched["preference_anchor_definitions"] = [
        anchors_by_id[anchor_id] for anchor_id in expected_anchors
    ]
    return enriched


def build_anchor_index(
    skill_name: str, payload: dict, eval_path: Path
) -> dict[str, dict]:
    """Build a unique preference-anchor lookup for one eval payload."""

    preference_anchors = payload.get("preference_anchors", [])
    if not isinstance(preference_anchors, list):
        raise ValueError(f"{eval_path}: preference_anchors must be a list")
    anchors_by_id: dict[str, dict] = {}
    for anchor in preference_anchors:
        if not isinstance(anchor, dict) or not isinstance(anchor.get("id"), str):
            raise ValueError(f"{eval_path}: invalid preference anchor for {skill_name}")
        anchor_id = anchor["id"]
        if anchor_id in anchors_by_id:
            raise ValueError(f"{eval_path}: duplicate preference anchor: {anchor_id}")
        anchors_by_id[anchor_id] = anchor
    return anchors_by_id


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
    anchors_by_id = build_anchor_index(skill_name, payload, eval_path)
    if eval_ids is None:
        return [
            enrich_case_with_anchor_definitions(skill_name, case, anchors_by_id)
            for case in evals
        ]
    selected = [case for case in evals if str(case.get("id")) in eval_ids]
    missing = eval_ids - {str(case.get("id")) for case in selected}
    if missing:
        raise ValueError(f"{eval_path}: unknown eval ids: {', '.join(sorted(missing))}")
    return [
        enrich_case_with_anchor_definitions(skill_name, case, anchors_by_id)
        for case in selected
    ]


def prepare_workspace(skill_name: str, output_dir: Path, run_mode: str) -> Path:
    """Create a minimal writable workspace containing the target skill."""

    if run_mode not in RUN_MODES:
        raise ValueError(f"unsupported run mode: {run_mode}")
    workspace = output_dir / "_workspaces" / run_mode / skill_name
    if workspace.exists():
        shutil.rmtree(workspace)
    workspace.mkdir(parents=True, exist_ok=True)
    if run_mode == "with_skill":
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
            raise ValueError(
                f"{skill_name}: eval file escapes repo root: {file_ref}"
            ) from exc
        if candidate.exists():
            return candidate
    raise FileNotFoundError(f"{skill_name}: missing eval input file: {file_ref}")


def copy_case_files(
    skill_name: str, case: dict, workspace: Path, run_mode: str = "with_skill"
) -> None:
    """Copy case-declared input files into the temporary workspace."""

    files = case.get("files", [])
    if not isinstance(files, list):
        raise ValueError(f"{skill_name}/{case['id']}: files must be a list")

    for file_ref in files:
        if not isinstance(file_ref, str) or not file_ref.strip():
            raise ValueError(f"{skill_name}/{case['id']}: files contains an empty path")
        source = resolve_case_file(skill_name, file_ref)
        relative = source.relative_to(ROOT)
        if run_mode == "without_skill":
            target_skill_root = Path("shared") / "skills" / skill_name
            if relative == target_skill_root or target_skill_root in relative.parents:
                raise ValueError(
                    f"{skill_name}/{case['id']}: without_skill cannot copy target skill files"
                )
        target = workspace / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            if target.exists():
                shutil.rmtree(target)
            shutil.copytree(source, target)
        else:
            shutil.copy2(source, target)


def build_executor_prompt(
    skill_name: str,
    case: dict,
    run_mode: str,
    include_expectations: bool = True,
) -> str:
    """Build the prompt that executes one eval case against a target skill."""

    files = case.get("files", [])
    file_lines = ["Input files available in the workspace:"]
    if files:
        file_lines.extend(f"- {file_ref}" for file_ref in files)
    else:
        file_lines.append("- none")
    if run_mode == "with_skill":
        skill_instruction = [
            f"请按当前工作区 `shared/skills/{skill_name}/SKILL.md` 执行下面的 skill eval。",
            "约束：",
            "- 先读取并遵循该 SKILL.md。",
        ]
    elif run_mode == "without_skill":
        skill_instruction = [
            f"请在不读取或依赖 `shared/skills/{skill_name}/SKILL.md` 的情况下执行下面的 skill eval。",
            "约束：",
            "- 不得读取或依赖目标 skill 的 SKILL.md。",
            "- 只根据 Eval prompt 和通用工程判断回应。"
            if not include_expectations
            else "- 只根据 Eval prompt、Expectations 和通用工程判断回应。",
        ]
    else:
        raise ValueError(f"unsupported run mode: {run_mode}")

    prompt_lines = [
        *skill_instruction,
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
    ]
    if include_expectations:
        expectation_lines = [f"- {item}" for item in case.get("expectations", [])]
        prompt_lines.extend(["", "Expectations:", *(expectation_lines or ["- none"])])
    return "\n".join(prompt_lines)


def run_executor(
    skill_name: str,
    case: dict,
    workspace: Path,
    run_dir: Path,
    args: object,
) -> None:
    """Run one eval prompt and persist the raw response."""

    run_mode = str(getattr(args, "run_mode"))
    timeout_sec = int(getattr(args, "timeout_sec"))
    model = getattr(args, "model")
    reasoning_effort = getattr(args, "reasoning_effort", None)
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
        build_executor_prompt(
            skill_name,
            case,
            run_mode,
            include_expectations=not bool(getattr(args, "hide_expectations", False)),
        ),
    ]
    if reasoning_effort:
        command[2:2] = ["-c", f'model_reasoning_effort="{reasoning_effort}"']
    if model:
        command[2:2] = ["--model", model]
    started_at = time.time()
    completed = run_command(command, workspace, timeout_sec)
    duration_seconds = time.time() - started_at
    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / "executor.log").write_text(
        (completed.stdout or "") + (completed.stderr or ""), encoding="utf-8"
    )
    write_json(
        run_dir / "timing.json",
        {
            "executor_start": datetime.fromtimestamp(started_at, timezone.utc).strftime(
                "%Y-%m-%dT%H:%M:%SZ"
            ),
            "executor_end": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "total_duration_seconds": round(duration_seconds, 1),
        },
    )
    response_available_after_timeout = (
        completed.returncode == 124
        and response_path.is_file()
        and response_path.stat().st_size > 0
    )
    if completed.returncode != 0 and not response_available_after_timeout:
        raise RuntimeError(
            f"{skill_name}/{case['id']}: executor exited {completed.returncode}"
        )
    if not response_path.is_file():
        raise RuntimeError(f"{skill_name}/{case['id']}: missing response output")

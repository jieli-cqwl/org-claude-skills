#!/usr/bin/env python3
"""Resolve rule-runtime evaluation inputs without executing a runtime."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

from rule_runtime_eval.common import sha256_file, write_json
from rule_runtime_eval.contracts import ContractError, EvalCase, SceneContract, load_acceptance_contract, load_profile_cases, parse_baseline_refs
from rule_runtime_eval.evidence import classify_route_reads, load_jsonl
from rule_runtime_eval.execution import ExecutionSettings, classify_execution_state, run_executor
from rule_runtime_eval.workspace import RuntimeWorkspace, WorkspaceError, prepare_runtime_workspaces


class ContractArgumentParser(argparse.ArgumentParser):
    """Emit CLI input failures through the runner's structured error boundary."""

    def error(self, message: str) -> None:
        raise ContractError("argument_parse_error", message)


def build_parser() -> argparse.ArgumentParser:
    parser = ContractArgumentParser(description="Resolve rule-runtime evaluation contracts")
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--acceptance-pack", type=Path, required=True)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--case-source", required=True)
    parser.add_argument("--baseline-ref", action="append", default=[], metavar="PACK=REF")
    parser.add_argument("--model", required=True)
    parser.add_argument("--reasoning-effort", required=True, choices=["low", "medium", "high", "xhigh"])
    parser.add_argument("--output-root", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--keep-workspaces", action="store_true")
    parser.add_argument("--installer-bin", type=Path)
    parser.add_argument("--codex-bin", default="codex")
    parser.add_argument("--source-codex-home", type=Path)
    parser.add_argument("--timeout-sec", type=int, default=240)
    return parser


def resolve_dry_run(args: argparse.Namespace) -> dict[str, object]:
    repo_root = args.repo_root.resolve()
    if args.case_source != "candidate":
        raise ContractError("case_source_unsupported", "only candidate case source is supported")
    if args.timeout_sec < 1:
        raise ContractError("timeout_invalid", "timeout must be positive")
    acceptance_path = _repo_path(repo_root, args.acceptance_pack, "acceptance_pack_outside_repo")
    contract = load_acceptance_contract(repo_root, acceptance_path)
    profile, cases = load_profile_cases(contract, args.profile, repo_root)
    selected_pack_ids = {case.pack_id for case in cases}
    baseline_refs = parse_baseline_refs(args.baseline_ref, selected_pack_ids)
    baseline_commits = [
        {
            "pack_id": pack_id,
            "ref": baseline_refs[pack_id],
            "commit": _resolve_git_ref(repo_root, baseline_refs[pack_id]),
        }
        for pack_id in sorted(baseline_refs)
    ]
    candidate_head = _resolve_git_ref(repo_root, "HEAD")
    dirty_paths = _dirty_paths(repo_root)
    source_records = _source_hashes(contract, selected_pack_ids)
    required_scenes = _required_scenes(contract, cases)
    covered_sources = _covered_sources(contract, required_scenes)
    unverified_scope = tuple(
        sorted(_relative(contract.repo_root, source) for source in set(contract.runtime_sources) - covered_sources)
    )
    _validate_dirty_runtime_sources(contract, dirty_paths, covered_sources)
    return {
        "mode": "dry_run",
        "model": args.model,
        "reasoning_effort": args.reasoning_effort,
        "model_calls": 0,
        "candidate": {
            "head": candidate_head,
            "dirty_paths": list(dirty_paths),
        },
        "baseline_commits": baseline_commits,
        "source_hashes": source_records,
        "selected_cases": [
            {
                "pack_id": case.pack_id,
                "id": case.id,
                "expected_scene_contracts": list(case.expected_scene_contracts),
                "required_scene_contracts": list(required_scenes[(case.pack_id, case.id)]),
                "expected_behavior_ids": list(case.expected_behavior_ids),
                "anti_pattern_ids": list(case.anti_pattern_ids),
                "blocking_failure_ids": list(case.blocking_failure_ids),
            }
            for case in cases
        ],
        "profile": {
            "id": profile.id,
            "runs_per_configuration": profile.runs_per_configuration,
        },
        "unverified_scope": list(unverified_scope),
    }


def main(argv: list[str] | None = None) -> int:
    try:
        args = build_parser().parse_args(argv)
        resolution = resolve_dry_run(args)
        if args.dry_run:
            if args.output_root is not None:
                _repo_path(args.repo_root.resolve(), args.output_root, "output_root_outside_repo")
            print(json.dumps(resolution, ensure_ascii=False, sort_keys=True, indent=2))
            return 0
        if args.output_root is None:
            raise ContractError("output_root_required", "workspace preparation requires an output root")
        output_root = _repo_path(args.repo_root.resolve(), args.output_root, "output_root_outside_repo")
        output_root.mkdir(parents=True, exist_ok=True)
        execution_contract = load_acceptance_contract(
            args.repo_root.resolve(),
            _repo_path(args.repo_root.resolve(), args.acceptance_pack, "acceptance_pack_outside_repo"),
        )
        _, execution_cases = load_profile_cases(execution_contract, args.profile, args.repo_root.resolve())
        source_codex_home = args.source_codex_home or Path(
            os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))
        )
        workspace_summary = prepare_runtime_workspaces(
            repo_root=args.repo_root.resolve(),
            acceptance_pack=args.acceptance_pack,
            candidate_head=resolution["candidate"]["head"],
            candidate_dirty_paths=tuple(resolution["candidate"]["dirty_paths"]),
            baseline_commits=resolution["baseline_commits"],
            source_codex_home=source_codex_home,
            installer_bin=args.installer_bin,
            timeout_seconds=args.timeout_sec,
            output_root=output_root,
            keep_workspaces=args.keep_workspaces,
            after_install=lambda workspaces, installations: _execute_cases(
                execution_contract,
                execution_cases,
                resolution["baseline_commits"],
                workspaces,
                installations,
                output_root,
                ExecutionSettings(
                    codex_bin=args.codex_bin,
                    model=args.model,
                    reasoning_effort=args.reasoning_effort,
                    timeout_seconds=args.timeout_sec,
                ),
            ),
        )
        prepared = {**resolution, "mode": "workspace_prepared", **workspace_summary}
        write_json(output_root / "workspace-preparation.json", prepared)
        print(json.dumps(prepared, ensure_ascii=False, sort_keys=True, indent=2))
        return 0
    except ContractError as exc:
        _emit_error(exc.code, exc.message)
        return 2
    except WorkspaceError as exc:
        _emit_error(exc.code, exc.message)
        return 1


def _execute_cases(
    contract: object,
    cases: list[EvalCase],
    baseline_commits: list[dict[str, str]],
    workspaces: tuple[RuntimeWorkspace, ...],
    installations: tuple[dict[str, object], ...],
    output_root: Path,
    settings: ExecutionSettings,
) -> dict[str, object]:
    """Create one candidate/baseline execution record for every selected case."""

    acceptance = contract
    workspace_by_id = {workspace.id: workspace for workspace in workspaces}
    installation_by_id = {str(item["id"]): item for item in installations}
    baseline_by_pack = {
        item["pack_id"]: workspace_by_id[f"baseline-{item['commit']}"] for item in baseline_commits
    }
    records: list[dict[str, object]] = []
    for case in cases:
        configurations = [workspace_by_id["candidate"], baseline_by_pack[case.pack_id]]
        for workspace in configurations:
            run_dir = output_root / "runs" / workspace.id / case.pack_id / case.id
            installation = installation_by_id[workspace.id]
            if (
                installation.get("install_status") != "READY"
                or installation.get("live_execution_status") != "READY"
            ):
                _write_execution(run_dir, workspace, case, "INFRA_BLOCKED_INSTALL")
                records.append({"configuration": workspace.id, "case": f"{case.pack_id}:{case.id}", "state": "INFRA_BLOCKED_INSTALL"})
                continue
            result = run_executor(case, workspace, run_dir, settings)
            jsonl_path = run_dir / "executor.jsonl"
            response_path = run_dir / "outputs" / "response.md"
            try:
                events = load_jsonl(jsonl_path)
            except ValueError:
                _write_execution(run_dir, workspace, case, "INFRA_BLOCKED_EVENT_SHAPE", result=result)
                records.append({"configuration": workspace.id, "case": f"{case.pack_id}:{case.id}", "state": "INFRA_BLOCKED_EVENT_SHAPE"})
                continue
            state = classify_execution_state(result, events, response_path)
            expected_contracts = _expected_contracts(acceptance, case)
            route = classify_route_reads(events, expected_contracts, workspace.codex_home)
            if state not in {"INFRA_BLOCKED_TIMEOUT", "INFRA_BLOCKED_PROCESS"} and not route.route_evidence_available:
                state = "INFRA_BLOCKED_EVENT_SHAPE"
            _write_execution(run_dir, workspace, case, state, result=result, route=route)
            records.append({"configuration": workspace.id, "case": f"{case.pack_id}:{case.id}", "state": state})
    return {"records": records}


def _expected_contracts(contract: object, case: EvalCase) -> tuple[SceneContract, ...]:
    ids = [scene.id for scene in contract.scene_contracts if scene.activation == "pre_execution"]
    ids.extend(case.expected_scene_contracts)
    return tuple(contract.scene_by_id[scene_id] for scene_id in dict.fromkeys(ids))


def _write_execution(
    run_dir: Path,
    workspace: RuntimeWorkspace,
    case: EvalCase,
    state: str,
    *,
    result: object | None = None,
    route: object | None = None,
) -> None:
    run_dir.mkdir(parents=True, exist_ok=True)
    payload: dict[str, object] = {
        "configuration": workspace.id,
        "case": {"pack_id": case.pack_id, "id": case.id},
        "state": state,
    }
    if result is not None:
        payload["process"] = {
            "returncode": result.returncode,
            "timed_out": result.timed_out,
            "started_at": result.started_at,
            "ended_at": result.ended_at,
            "duration_seconds": result.duration_seconds,
        }
    if route is not None:
        payload["route"] = {
            "route_evidence_available": route.route_evidence_available,
            "route_pass": route.route_pass,
            "parser_uncertain": route.parser_uncertain,
            "expected_contract_ids": list(route.expected_contract_ids),
            "read_contract_ids": list(route.read_contract_ids),
            "observed_event_ids": list(route.observed_event_ids),
            "observed_command_ids": list(route.observed_command_ids),
        }
    write_json(run_dir / "execution.json", payload)


def _resolve_git_ref(repo_root: Path, ref: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(repo_root), "rev-parse", "--verify", f"{ref}^{{commit}}"],
        capture_output=True,
        check=False,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        raise ContractError("baseline_ref_unresolved", "Git ref could not be resolved")
    return completed.stdout.strip()


def _dirty_paths(repo_root: Path) -> tuple[str, ...]:
    completed = subprocess.run(
        ["git", "-C", str(repo_root), "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        capture_output=True,
        check=False,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        raise ContractError("git_dirty_paths_failed", "candidate dirty paths could not be resolved")
    records = completed.stdout.split("\0")
    paths: list[str] = []
    index = 0
    while index < len(records):
        record = records[index]
        index += 1
        if not record:
            continue
        status, path = record[:2], record[3:]
        paths.append(path)
        if "R" in status or "C" in status:
            index += 1
    return tuple(sorted(set(paths)))


def _source_hashes(contract: object, selected_pack_ids: set[str]) -> list[dict[str, str]]:
    acceptance = contract
    records = [
        {"kind": "runtime_source", "path": _relative(acceptance.repo_root, source), "sha256": sha256_file(source)}
        for source in acceptance.runtime_sources
    ]
    for pack in acceptance.case_packs:
        if pack.id in selected_pack_ids:
            for kind, relative_path in (("case_pack", pack.path), ("grader", pack.grader)):
                path = _repo_path(acceptance.repo_root, relative_path, "case_pack_missing")
                records.append({"kind": kind, "path": str(relative_path), "sha256": sha256_file(path)})
    return sorted(records, key=lambda item: (item["kind"], item["path"]))


def _required_scenes(contract: object, cases: list[object]) -> dict[tuple[str, str], tuple[str, ...]]:
    pre_execution = tuple(
        scene.id for scene in contract.scene_contracts if scene.activation == "pre_execution"
    )
    return {
        (case.pack_id, case.id): tuple(dict.fromkeys((*pre_execution, *case.expected_scene_contracts)))
        for case in cases
    }


def _covered_sources(
    contract: object, required_scenes: dict[tuple[str, str], tuple[str, ...]]
) -> set[Path]:
    assistant_source = contract.repo_root / "shared" / "assistant.md"
    covered = {assistant_source.resolve()}
    scene_by_id = contract.scene_by_id
    for scene_ids in required_scenes.values():
        for scene_id in scene_ids:
            covered.add(scene_by_id[scene_id].runtime_source)
    return covered


def _validate_dirty_runtime_sources(
    contract: object,
    dirty_paths: tuple[str, ...],
    covered_sources: set[Path],
) -> None:
    runtime_sources = {_relative(contract.repo_root, source): source for source in contract.runtime_sources}
    uncovered_dirty = {
        runtime_sources[path]
        for path in dirty_paths
        if path in runtime_sources
        and runtime_sources[path] not in covered_sources
    }
    if uncovered_dirty:
        raise ContractError(
            "dirty_runtime_source_uncovered",
            "dirty runtime sources outside selected-case coverage are unsupported",
        )


def _repo_path(repo_root: Path, path: Path, code: str) -> Path:
    resolved = (repo_root / path).resolve() if not path.is_absolute() else path.resolve()
    try:
        resolved.relative_to(repo_root)
    except ValueError as exc:
        raise ContractError(code, "path must remain inside repository root") from exc
    return resolved


def _relative(repo_root: Path, path: Path) -> str:
    return str(path.resolve().relative_to(repo_root))


def _emit_error(code: str, message: str) -> None:
    print(json.dumps({"code": code, "error": message}, ensure_ascii=False, sort_keys=True), file=sys.stderr)


if __name__ == "__main__":
    raise SystemExit(main())

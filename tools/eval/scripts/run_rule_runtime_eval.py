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
from rule_runtime_eval.contracts import ContractError, load_acceptance_contract, load_profile_cases, parse_baseline_refs
from rule_runtime_eval.workspace import WorkspaceError, prepare_runtime_workspaces


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
                output_root = _repo_path(args.repo_root.resolve(), args.output_root, "output_root_outside_repo")
                output_root.mkdir(parents=True, exist_ok=True)
                write_json(output_root / "resolution.json", resolution)
            print(json.dumps(resolution, ensure_ascii=False, sort_keys=True, indent=2))
            return 0
        if args.output_root is None:
            raise ContractError("output_root_required", "workspace preparation requires an output root")
        output_root = _repo_path(args.repo_root.resolve(), args.output_root, "output_root_outside_repo")
        output_root.mkdir(parents=True, exist_ok=True)
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

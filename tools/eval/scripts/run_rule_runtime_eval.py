#!/usr/bin/env python3
"""Resolve rule-runtime evaluation inputs without executing a runtime."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

from rule_runtime_eval.common import sha256_file, sha256_json, write_json
from rule_runtime_eval.contracts import ContractError, EvalCase, SceneContract, load_acceptance_contract, load_profile_cases, parse_baseline_refs
from rule_runtime_eval.evidence import classify_route_reads, load_jsonl
from rule_runtime_eval.execution import ExecutionSettings, classify_execution_state, run_executor
from rule_runtime_eval.grading import GradingError, run_blind_grader
from rule_runtime_eval.reporting import compare_pair, compute_freshness, coverage_projection, project_suite_decision, render_reports
from rule_runtime_eval.workspace import RuntimeWorkspace, WorkspaceError, prepare_runtime_workspaces


class ContractArgumentParser(argparse.ArgumentParser):
    """Emit CLI input failures through the runner's structured error boundary."""

    def error(self, message: str) -> None:
        raise ContractError("argument_parse_error", message)


def build_parser() -> argparse.ArgumentParser:
    parser = ContractArgumentParser(description="Resolve rule-runtime evaluation contracts")
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument(
        "--eval-contract",
        "--acceptance-pack",
        dest="acceptance_pack",
        type=Path,
        required=True,
    )
    parser.add_argument("--profile", required=True)
    parser.add_argument("--case", action="append", default=[], metavar="PACK:ID")
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
    profile, profile_cases = load_profile_cases(contract, args.profile, repo_root)
    cases = _filter_cases(profile_cases, args.case)
    selected_pack_ids = {case.pack_id for case in cases}
    profile_pack_ids = {case.pack_id for case in profile_cases}
    baseline_refs = parse_baseline_refs(args.baseline_ref, selected_pack_ids, profile_pack_ids)
    baseline_commits = [
        {
            "pack_id": pack_id,
            "ref": baseline_refs[pack_id],
            "commit": _resolve_git_ref(repo_root, baseline_refs[pack_id]),
        }
        for pack_id in sorted(selected_pack_ids)
    ]
    candidate_head = _resolve_git_ref(repo_root, "HEAD")
    _validate_baseline_commits(repo_root, candidate_head, baseline_commits)
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
                "forbidden_scene_contracts": list(case.forbidden_scene_contracts),
                "max_successful_scene_reads": case.max_successful_scene_reads,
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
        execution_profile, profile_cases = load_profile_cases(execution_contract, args.profile, args.repo_root.resolve())
        execution_cases = _filter_cases(profile_cases, args.case)
        source_codex_home = args.source_codex_home or Path(
            os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))
        )
        workspace_summary = prepare_runtime_workspaces(
            repo_root=args.repo_root.resolve(),
            runtime_source_paths=tuple(
                Path(_relative(execution_contract.repo_root, source))
                for source in execution_contract.runtime_sources
            ),
            candidate_head=resolution["candidate"]["head"],
            candidate_dirty_paths=tuple(resolution["candidate"]["dirty_paths"]),
            baseline_commits=resolution["baseline_commits"],
            source_codex_home=source_codex_home,
            installer_bin=args.installer_bin,
            timeout_seconds=args.timeout_sec,
            output_root=output_root,
            keep_workspaces=args.keep_workspaces,
            runtime_target_sources=_installed_runtime_target_sources(execution_contract),
            after_install=lambda workspaces, installations, judge: _execute_cases(
                execution_contract,
                execution_profile,
                execution_cases,
                resolution["baseline_commits"],
                workspaces,
                installations,
                judge,
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
        executions = workspace_summary.get("executions")
        if isinstance(executions, dict) and isinstance(executions.get("model_calls"), int):
            prepared["model_calls"] = executions["model_calls"]
        write_json(output_root / "workspace-preparation.json", prepared)
        print(json.dumps(prepared, ensure_ascii=False, sort_keys=True, indent=2))
        return 0 if _suite_verdict(workspace_summary) in {"PASS", "DIAGNOSTIC_PASS"} else 1
    except ContractError as exc:
        _emit_error(exc.code, exc.message)
        return 2
    except WorkspaceError as exc:
        _emit_error(exc.code, exc.message)
        return 1


def _execute_cases(
    contract: object,
    profile: object,
    cases: list[EvalCase],
    baseline_commits: list[dict[str, str]],
    workspaces: tuple[RuntimeWorkspace, ...],
    installations: tuple[dict[str, object], ...],
    judge: RuntimeWorkspace,
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
    model_calls = 0
    codex_version = _codex_version(settings.codex_bin, output_root, settings.timeout_seconds)
    candidate_installation = installation_by_id["candidate"]
    candidate_runtime_ready = (
        candidate_installation.get("install_status") == "READY"
        and candidate_installation.get("live_execution_status") == "READY"
    )
    for case in cases:
        candidate_workspace = workspace_by_id["candidate"]
        baseline_workspace = baseline_by_pack[case.pack_id]
        configuration_by_id = {
            candidate_workspace.id: candidate_workspace,
            baseline_workspace.id: baseline_workspace,
        }
        for run_index in range(1, profile.runs_per_configuration + 1):
            for workspace_id in _configuration_order(
                run_index, candidate_workspace.id, baseline_workspace.id
            ):
                workspace = configuration_by_id[workspace_id]
                run_dir = (
                    output_root
                    / "runs"
                    / workspace.id
                    / case.pack_id
                    / case.id
                    / f"run-{run_index:02d}"
                )
                installation = installation_by_id[workspace.id]
                identity = _evidence_identity(
                    acceptance,
                    case,
                    workspace,
                    installation,
                    settings,
                    codex_version or "unavailable",
                )
                evidence_path = str(run_dir.relative_to(output_root) / "execution.json")
                if codex_version is None:
                    _write_execution(
                        run_dir,
                        workspace,
                        case,
                        "INFRA_BLOCKED_CODEX_VERSION",
                        identity=identity,
                    )
                    records.append(
                        _run_record(
                            workspace,
                            case,
                            evidence_path,
                            identity,
                            "INFRA_BLOCKED_CODEX_VERSION",
                            run_index=run_index,
                        )
                    )
                    continue
                if not candidate_runtime_ready or (
                    installation.get("install_status") != "READY"
                    or installation.get("live_execution_status") != "READY"
                ):
                    _write_execution(
                        run_dir,
                        workspace,
                        case,
                        "INFRA_BLOCKED_INSTALL",
                        identity=identity,
                    )
                    records.append(
                        _run_record(
                            workspace,
                            case,
                            evidence_path,
                            identity,
                            "INFRA_BLOCKED_INSTALL",
                            run_index=run_index,
                        )
                    )
                    continue
                result = run_executor(case, workspace, run_dir, settings)
                model_calls += 1
                jsonl_path = run_dir / "executor.jsonl"
                response_path = run_dir / "outputs" / "response.md"
                state = classify_execution_state(result, None, response_path)
                if state != "EXECUTOR_OK":
                    _write_execution(run_dir, workspace, case, state, result=result, identity=identity)
                    records.append(
                        _run_record(
                            workspace, case, evidence_path, identity, state, run_index=run_index
                        )
                    )
                    continue
                try:
                    events = load_jsonl(jsonl_path)
                except ValueError:
                    _write_execution(
                        run_dir,
                        workspace,
                        case,
                        "INFRA_BLOCKED_EVENT_SHAPE",
                        result=result,
                        identity=identity,
                    )
                    records.append(
                        _run_record(
                            workspace,
                            case,
                            evidence_path,
                            identity,
                            "INFRA_BLOCKED_EVENT_SHAPE",
                            run_index=run_index,
                        )
                    )
                    continue
                state = classify_execution_state(result, events, response_path)
                if state != "EXECUTOR_OK":
                    _write_execution(run_dir, workspace, case, state, result=result, identity=identity)
                    records.append(
                        _run_record(
                            workspace, case, evidence_path, identity, state, run_index=run_index
                        )
                    )
                    continue
                expected_contracts = _expected_contracts(acceptance, case)
                route = classify_route_reads(
                    events,
                    expected_contracts,
                    workspace.codex_home,
                    observed_contracts=tuple(acceptance.scene_contracts),
                    forbidden_contract_ids=case.forbidden_scene_contracts,
                    max_successful_scene_reads=case.max_successful_scene_reads,
                )
                if not route.route_evidence_available:
                    state = "INFRA_BLOCKED_EVENT_SHAPE"
                try:
                    grader = run_blind_grader(
                        case,
                        _grader_instructions(acceptance, case),
                        response_path,
                        judge,
                        tuple(workspaces),
                        run_dir,
                        codex_bin=settings.codex_bin,
                        model=settings.model,
                        reasoning_effort=settings.reasoning_effort,
                        timeout_seconds=settings.timeout_seconds,
                    )
                except GradingError:
                    grader = {"state": "INFRA_BLOCKED_GRADER"}
                if isinstance(grader.get("process"), dict):
                    model_calls += 1
                metrics = {
                    "irrelevant_successful_reads": len(set(route.read_contract_ids) - set(route.expected_contract_ids)),
                    "response_characters": len(response_path.read_text(encoding="utf-8")),
                }
                _write_execution(
                    run_dir,
                    workspace,
                    case,
                    state,
                    result=result,
                    route=route,
                    identity=identity,
                    grader=grader,
                    metrics=metrics,
                    run_index=run_index,
                )
                records.append(
                    _run_record(
                        workspace,
                        case,
                        evidence_path,
                        identity,
                        state,
                        route,
                        grader,
                        metrics,
                        run_index=run_index,
                    )
                )
    pairs = _comparison_projection(
        acceptance,
        cases,
        records,
        baseline_by_pack,
        profile.runs_per_configuration,
    )
    coverage = coverage_projection(
        tuple(_relative(acceptance.repo_root, source) for source in acceptance.runtime_sources),
        [
            {"case": record["case"], "sources": _case_sources(acceptance, case), "freshness": record["state"]}
            for case in cases
            for record in records
            if record["configuration"] == "candidate" and record["case"] == f"{case.pack_id}:{case.id}"
        ],
    )
    decision = project_suite_decision(
        {
            "id": profile.id,
            "anchor_threshold": profile.anchor_threshold,
            "marginal_effect_case": profile.marginal_effect_case,
            "lightness_policy": dict(profile.lightness_policy),
            "expected_pair_count": len(cases) * profile.runs_per_configuration,
        },
        pairs,
    )
    render_reports(output_root, decision, pairs, coverage)
    return {
        "records": records,
        "comparison": pairs,
        "suite": decision,
        "coverage": coverage,
        "model_calls": model_calls,
    }


def _filter_cases(cases: list[EvalCase], values: list[str]) -> list[EvalCase]:
    """Keep an explicit diagnostic subset without inventing cases outside the profile."""

    if not values:
        return cases
    requested: list[tuple[str, str]] = []
    for value in values:
        if value.count(":") != 1:
            raise ContractError("case_filter_malformed", "case filter must use PACK:ID")
        pack_id, case_id = value.split(":", 1)
        if not pack_id or not case_id:
            raise ContractError("case_filter_malformed", "case filter must use PACK:ID")
        requested.append((pack_id, case_id))
    if len(set(requested)) != len(requested):
        raise ContractError("case_filter_duplicate", "case filter contains duplicate cases")
    available = {(case.pack_id, case.id): case for case in cases}
    unknown = [key for key in requested if key not in available]
    if unknown:
        raise ContractError("case_filter_unknown", "case filter references a case outside the selected profile")
    return [available[key] for key in requested]


def _evidence_identity(
    contract: object,
    case: EvalCase,
    workspace: RuntimeWorkspace,
    installation: dict[str, object],
    settings: ExecutionSettings,
    codex_version: str,
) -> dict[str, object]:
    """Hash all inputs that can make a semantic verdict no longer comparable."""

    acceptance = contract
    installed_source_hashes = installation.get("runtime_source_hashes")
    if not isinstance(installed_source_hashes, list):
        raise WorkspaceError(
            "runtime_source_identity_missing",
            "runtime source hashes are required for evidence identity",
        )
    runtime_hashes = {
        str(item["path"]): item.get("sha256")
        for item in installed_source_hashes
        if isinstance(item, dict) and isinstance(item.get("path"), str)
    }
    installed_hashes = installation.get("installed_runtime_target_hashes")
    if not isinstance(installed_hashes, list) or not installed_hashes:
        raise WorkspaceError(
            "installed_runtime_identity_missing",
            "installed runtime target hashes are required for evidence identity",
        )
    grader = acceptance.case_pack_by_id[case.pack_id].grader
    return {
        "configuration": sha256_json({"commit": workspace.commit, "dirty_paths": workspace.dirty_paths}),
        "runtime": sha256_json(
            {
                "installed_target_hashes": installed_hashes,
                "missing_runtime_targets": installation.get("missing_runtime_targets", []),
            }
        ),
        "case": sha256_json(
            {
                "prompt": case.prompt,
                "expectations": case.expected_behaviors,
                "anti_patterns": case.anti_patterns,
                "blocking_failures": case.blocking_failures,
                "expected_scene_contracts": case.expected_scene_contracts,
                "forbidden_scene_contracts": case.forbidden_scene_contracts,
                "max_successful_scene_reads": case.max_successful_scene_reads,
                "anchors": {
                    identifier: dict(definition)
                    for identifier, definition in case.anchor_definitions.items()
                },
            }
        ),
        "grader": sha256_file(grader),
        "codex": codex_version,
        "model": settings.model,
        "reasoning": settings.reasoning_effort,
        "runner": _runner_identity(),
        "runtime_source_hashes": runtime_hashes,
        "installed_runtime_target_hashes": installed_hashes,
    }


def _suite_verdict(workspace_summary: dict[str, object]) -> str | None:
    executions = workspace_summary.get("executions")
    if not isinstance(executions, dict):
        return None
    suite = executions.get("suite")
    if not isinstance(suite, dict):
        return None
    verdict = suite.get("verdict")
    return verdict if isinstance(verdict, str) else None


def _grader_instructions(contract: object, case: EvalCase) -> str:
    acceptance = contract
    return acceptance.case_pack_by_id[case.pack_id].grader.read_text(encoding="utf-8")


def _codex_version(codex_bin: str, output_root: Path, timeout_seconds: int) -> str | None:
    """Return the known Codex version, or fail closed when it cannot be established."""

    try:
        completed = subprocess.run(
            [codex_bin, "--version"],
            cwd=output_root,
            capture_output=True,
            check=False,
            encoding="utf-8",
            errors="replace",
            timeout=timeout_seconds,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    version = completed.stdout.strip()
    return version if completed.returncode == 0 and version else None


def _runner_identity() -> str:
    """Fingerprint the evaluator package that shapes grading and report behavior."""

    source_root = Path(__file__).resolve().parent
    source_files = [Path(__file__), *sorted((source_root / "rule_runtime_eval").glob("*.py"))]
    return sha256_json(
        {
            str(path.resolve().relative_to(source_root)): sha256_file(path)
            for path in source_files
        }
    )


def _run_record(
    workspace: RuntimeWorkspace,
    case: EvalCase,
    evidence_path: str,
    identity: dict[str, object],
    execution_state: str,
    route: object | None = None,
    grader: dict[str, object] | None = None,
    metrics: dict[str, object] | None = None,
    *,
    run_index: int = 1,
) -> dict[str, object]:
    """Create an in-memory report input from persisted run evidence fields."""

    record: dict[str, object] = {
        "configuration": workspace.id,
        "case": f"{case.pack_id}:{case.id}",
        "run_index": run_index,
        "identity": identity,
        "execution_state": execution_state,
        "route_pass": route.route_pass if route is not None else False,
        "grading_state": grader.get("state") if grader is not None else "INFRA_BLOCKED_GRADER",
        "evidence_path": evidence_path,
    }
    if grader is not None and isinstance(grader.get("result"), dict):
        record["grading"] = grader["result"]
    if metrics is not None:
        record.update(metrics)
    return compute_freshness(record, identity)


def _comparison_projection(
    contract: object,
    cases: list[EvalCase],
    records: list[dict[str, object]],
    baseline_by_pack: dict[str, RuntimeWorkspace],
    runs_per_configuration: int,
) -> list[dict[str, object]]:
    acceptance = contract
    record_by_configuration_case = {
        (str(record["configuration"]), str(record["case"]), int(record.get("run_index", 1))): record
        for record in records
    }
    pairs: list[dict[str, object]] = []
    for case in cases:
        case_key = f"{case.pack_id}:{case.id}"
        for run_index in range(1, runs_per_configuration + 1):
            candidate = record_by_configuration_case.get(("candidate", case_key, run_index))
            baseline = record_by_configuration_case.get(
                (baseline_by_pack[case.pack_id].id, case_key, run_index)
            )
            changed_sources = _changed_runtime_sources(candidate, baseline)
            pair = compare_pair(
                case,
                candidate,
                baseline,
                changed_sources,
                tuple(_case_sources(acceptance, case)),
            )
            pair["run_index"] = run_index
            pairs.append(pair)
    return pairs


def _changed_runtime_sources(
    candidate: dict[str, object] | None, baseline: dict[str, object] | None
) -> tuple[str, ...]:
    if candidate is None or baseline is None:
        return ()
    candidate_identity = candidate.get("identity")
    baseline_identity = baseline.get("identity")
    if not isinstance(candidate_identity, dict) or not isinstance(baseline_identity, dict):
        return ()
    candidate_hashes = candidate_identity.get("runtime_source_hashes")
    baseline_hashes = baseline_identity.get("runtime_source_hashes")
    if not isinstance(candidate_hashes, dict) or not isinstance(baseline_hashes, dict):
        return ()
    return tuple(
        sorted(
            path
            for path, candidate_hash in candidate_hashes.items()
            if isinstance(path, str) and candidate_hash != baseline_hashes.get(path)
        )
    )


def _case_sources(contract: object, case: EvalCase) -> list[str]:
    acceptance = contract
    sources = ["shared/assistant.md"]
    sources.extend(
        _relative(acceptance.repo_root, scene.runtime_source)
        for scene in _expected_contracts(acceptance, case)
    )
    return list(dict.fromkeys(sources))


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
    identity: dict[str, object] | None = None,
    grader: dict[str, object] | None = None,
    metrics: dict[str, object] | None = None,
    run_index: int = 1,
) -> None:
    run_dir.mkdir(parents=True, exist_ok=True)
    payload: dict[str, object] = {
        "configuration": workspace.id,
        "case": {"pack_id": case.pack_id, "id": case.id},
        "run_index": run_index,
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
            "forbidden_read_contract_ids": list(route.forbidden_read_contract_ids),
            "exceeded_max_successful_scene_reads": route.exceeded_max_successful_scene_reads,
            "observed_event_ids": list(route.observed_event_ids),
            "observed_command_ids": list(route.observed_command_ids),
        }
    if identity is not None:
        payload["identity"] = identity
    if grader is not None:
        payload["grading_state"] = grader.get("state")
        payload["grader"] = {"process": grader.get("process")}
        if isinstance(grader.get("result"), dict):
            payload["grading"] = grader["result"]
    if metrics is not None:
        payload["metrics"] = metrics
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


def _validate_baseline_commits(
    repo_root: Path, candidate_head: str, baseline_commits: list[dict[str, str]]
) -> None:
    for baseline in baseline_commits:
        commit = baseline.get("commit")
        if commit == candidate_head:
            raise ContractError(
                "baseline_matches_candidate",
                "comparative baseline must be distinct from the candidate commit",
            )
        completed = subprocess.run(
            ["git", "-C", str(repo_root), "merge-base", "--is-ancestor", str(commit), candidate_head],
            capture_output=True,
            check=False,
        )
        if completed.returncode != 0:
            raise ContractError(
                "baseline_not_ancestor",
                "comparative baseline must be an ancestor of the candidate commit",
            )


def _installed_runtime_targets(contract: object) -> tuple[Path, ...]:
    return tuple(_installed_runtime_target_sources(contract))


def _installed_runtime_target_sources(contract: object) -> dict[Path, Path]:
    sources = {Path("AGENTS.md"): Path("shared/assistant.md")}
    sources.update(
        {
            scene.installed_path: (
                Path(_relative(contract.repo_root, scene.runtime_source))
                if scene.runtime_source.is_absolute()
                else scene.runtime_source
            )
            for scene in contract.scene_contracts
        }
    )
    return sources


def _configuration_order(
    run_index: int, candidate_id: str, baseline_id: str
) -> tuple[str, str]:
    return (
        (candidate_id, baseline_id)
        if run_index % 2 == 1
        else (baseline_id, candidate_id)
    )


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
        if path.startswith("tools/eval/results/rule-runtime/"):
            continue
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

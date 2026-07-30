"""Isolated runtime homes and baseline snapshots for rule-runtime evaluation."""

from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from typing import Callable, Mapping

from rule_runtime_eval.common import CommandResult, run_command, sha256_file, write_json


_WORKSPACE_PREFIX = "rule-runtime-eval-"
_CREATED_WORKSPACE_ROOTS: set[Path] = set()


class WorkspaceError(RuntimeError):
    """An infrastructure preparation failure with a stable error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


@dataclass(frozen=True)
class RuntimeWorkspace:
    """One repository configuration with a private process environment."""

    id: str
    repo_root: Path
    commit: str
    home: Path
    codex_home: Path
    state_root: Path
    skills_dir: Path
    dirty_paths: tuple[str, ...]


def seed_codex_context(source_codex_home: Path, codex_home: Path) -> dict[str, bool]:
    """Seed only execution credentials and optional configuration into a new home."""

    source = source_codex_home.resolve()
    if not source.is_dir():
        raise WorkspaceError("source_codex_home_invalid", "source Codex home must be a directory")
    codex_home.mkdir(parents=True, exist_ok=False)
    seeded: dict[str, bool] = {}
    for filename, key in (("auth.json", "auth_available"), ("config.toml", "config_available")):
        source_file = source / filename
        seeded[key] = source_file.is_file()
        if seeded[key]:
            shutil.copyfile(source_file, codex_home / filename)
    return seeded


def cleanup_workspace_root(root: Path, parent: Path) -> None:
    """Delete one evaluator-owned root and reject every other filesystem location."""

    resolved_root = root.resolve()
    resolved_parent = parent.resolve()
    if resolved_root.parent != resolved_parent or resolved_root not in _CREATED_WORKSPACE_ROOTS:
        raise WorkspaceError(
            "workspace_cleanup_outside_parent",
            "cleanup target is not an evaluator-created workspace root",
        )
    try:
        if resolved_root.exists():
            shutil.rmtree(resolved_root)
    finally:
        _CREATED_WORKSPACE_ROOTS.discard(resolved_root)


def _create_workspace_root(parent: Path) -> Path:
    root = Path(tempfile.mkdtemp(prefix=_WORKSPACE_PREFIX, dir=parent)).resolve()
    _CREATED_WORKSPACE_ROOTS.add(root)
    return root


def prepare_runtime_workspaces(
    *,
    repo_root: Path,
    acceptance_pack: Path,
    candidate_head: str,
    candidate_dirty_paths: tuple[str, ...],
    baseline_commits: list[Mapping[str, str]],
    source_codex_home: Path,
    installer_bin: Path | None,
    timeout_seconds: int,
    output_root: Path,
    keep_workspaces: bool,
    after_install: Callable[[tuple[RuntimeWorkspace, ...], tuple[dict[str, object], ...]], dict[str, object]] | None = None,
) -> dict[str, object]:
    """Install runtimes and optionally execute while their isolated homes remain alive."""

    candidate_root = repo_root.resolve()
    workspace_parent = Path(tempfile.gettempdir()).resolve()
    workspace_root = _create_workspace_root(workspace_parent)
    snapshots: list[Path] = []
    try:
        candidate = _create_runtime_workspace(
            workspace_root,
            "candidate",
            candidate_root,
            candidate_head,
            candidate_dirty_paths,
        )
        workspaces = [candidate]
        prepared = [
            _prepare_configuration(
                candidate,
                acceptance_pack,
                source_codex_home,
                installer_bin,
                timeout_seconds,
                output_root,
            )
        ]
        for baseline in _unique_baselines(baseline_commits):
            snapshot = _materialize_baseline(candidate_root, workspace_root, baseline["commit"])
            snapshots.append(snapshot)
            baseline_workspace = _create_runtime_workspace(
                workspace_root,
                f"baseline-{baseline['commit']}",
                snapshot,
                baseline["commit"],
                (),
            )
            workspaces.append(baseline_workspace)
            prepared.append(
                _prepare_configuration(
                    baseline_workspace,
                    acceptance_pack,
                    source_codex_home,
                    installer_bin,
                    timeout_seconds,
                    output_root,
                )
            )
        judge = _create_runtime_workspace(
            workspace_root,
            "judge",
            candidate_root,
            candidate_head,
            (),
        )
        judge_context = seed_codex_context(source_codex_home, judge.codex_home)
        summary = {
            "installations": prepared,
            "judge_context": judge_context,
            "workspace_retained": keep_workspaces,
        }
        if after_install is not None:
            summary["executions"] = after_install(tuple(workspaces), tuple(prepared))
        return summary
    finally:
        cleanup_error: WorkspaceError | None = None
        try:
            _cleanup_baselines(candidate_root, snapshots)
        except WorkspaceError as exc:
            cleanup_error = exc
        if not keep_workspaces:
            try:
                cleanup_workspace_root(workspace_root, workspace_parent)
            except WorkspaceError as exc:
                if cleanup_error is None:
                    cleanup_error = exc
        if cleanup_error is not None:
            raise cleanup_error


def _create_runtime_workspace(
    workspace_root: Path,
    identifier: str,
    repo_root: Path,
    commit: str,
    dirty_paths: tuple[str, ...],
) -> RuntimeWorkspace:
    home = workspace_root / "configurations" / identifier / "home"
    return RuntimeWorkspace(
        id=identifier,
        repo_root=repo_root.resolve(),
        commit=commit,
        home=home,
        codex_home=home / ".codex",
        state_root=home / ".org-skills-state",
        skills_dir=home / ".agents" / "skills",
        dirty_paths=dirty_paths,
    )


def _prepare_configuration(
    workspace: RuntimeWorkspace,
    acceptance_pack: Path,
    source_codex_home: Path,
    installer_bin: Path | None,
    timeout_seconds: int,
    output_root: Path,
) -> dict[str, object]:
    context = seed_codex_context(source_codex_home, workspace.codex_home)
    command = _installer_command(workspace.repo_root, installer_bin)
    result = run_command(
        command,
        cwd=workspace.repo_root,
        env=_installer_env(workspace),
        timeout_seconds=timeout_seconds,
    )
    manifest = {
        "configuration": {
            "id": workspace.id,
            "commit": workspace.commit,
            "dirty_paths": list(workspace.dirty_paths),
        },
        "context": context,
        "runtime_source_hashes": _runtime_source_hashes(workspace.repo_root, acceptance_pack),
        "install": _install_evidence(result),
        "live_execution_status": "READY" if context["auth_available"] else "INFRA_BLOCKED",
    }
    write_json(output_root / "runtime-manifests" / f"{workspace.id}.json", manifest)
    return {
        "id": workspace.id,
        "commit": workspace.commit,
        "install_status": "READY" if result.returncode == 0 and not result.timed_out else "INFRA_BLOCKED",
        "live_execution_status": "READY" if context["auth_available"] else "INFRA_BLOCKED",
    }


def _unique_baselines(baseline_commits: list[Mapping[str, str]]) -> list[Mapping[str, str]]:
    unique: dict[str, Mapping[str, str]] = {}
    for baseline in baseline_commits:
        commit = baseline.get("commit")
        if not isinstance(commit, str) or not commit:
            raise WorkspaceError("baseline_ref_unresolved", "baseline ref must resolve to a commit")
        unique.setdefault(commit, baseline)
    return [unique[commit] for commit in sorted(unique)]


def _materialize_baseline(candidate_root: Path, workspace_root: Path, commit: str) -> Path:
    snapshot = workspace_root / "baselines" / commit
    if snapshot.exists():
        raise WorkspaceError("baseline_output_duplicate", "baseline snapshot output already exists")
    try:
        snapshot.relative_to(candidate_root)
    except ValueError:
        pass
    else:
        raise WorkspaceError("baseline_inside_candidate_repo", "baseline snapshot must not be inside candidate repository")
    completed = subprocess.run(
        ["git", "-C", str(candidate_root), "worktree", "add", "--detach", str(snapshot), commit],
        capture_output=True,
        check=False,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        raise WorkspaceError("baseline_materialization_failed", "baseline snapshot could not be materialized")
    try:
        resolved = _git_output(snapshot, ["rev-parse", "--verify", "HEAD^{commit}"], "baseline_ref_unresolved")
        if resolved != commit:
            raise WorkspaceError("baseline_ref_unresolved", "baseline snapshot did not resolve to requested commit")
        if _git_output(snapshot, ["status", "--porcelain=v1"], "baseline_dirty_check_failed"):
            raise WorkspaceError("baseline_snapshot_dirty", "baseline snapshot must be clean")
        return snapshot
    except Exception as validation_error:
        try:
            _cleanup_baselines(candidate_root, [snapshot])
        except WorkspaceError as cleanup_error:
            raise cleanup_error from validation_error
        raise


def _remove_baseline(candidate_root: Path, snapshot: Path) -> None:
    completed = subprocess.run(
        ["git", "-C", str(candidate_root), "worktree", "remove", "--force", str(snapshot)],
        capture_output=True,
        check=False,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        raise WorkspaceError("baseline_cleanup_failed", "baseline snapshot could not be removed")


def _cleanup_baselines(candidate_root: Path, snapshots: list[Path]) -> None:
    failure: WorkspaceError | None = None
    for snapshot in reversed(snapshots):
        try:
            _remove_baseline(candidate_root, snapshot)
        except WorkspaceError as exc:
            if failure is None:
                failure = exc
    if failure is not None:
        raise failure


def _git_output(repo_root: Path, args: list[str], code: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(repo_root), *args],
        capture_output=True,
        check=False,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        raise WorkspaceError(code, "Git command failed while preparing baseline")
    return completed.stdout.strip()


def _installer_command(repo_root: Path, installer_bin: Path | None) -> list[str]:
    installer = (installer_bin or repo_root / "install.sh").resolve()
    if not installer.is_file():
        raise WorkspaceError("installer_missing", "installer must be an existing file")
    return ["bash", str(installer), "--target", "codex"]


def _installer_env(workspace: RuntimeWorkspace) -> dict[str, str]:
    env = dict(os.environ)
    env.update(
        {
            "HOME": str(workspace.home),
            "CODEX_HOME": str(workspace.codex_home),
            "ORG_STATE_ROOT": str(workspace.state_root),
            "CODEX_USER_SKILLS_DIR": str(workspace.skills_dir),
        }
    )
    return env


def _runtime_source_hashes(repo_root: Path, acceptance_pack: Path) -> list[dict[str, str]]:
    pack = (repo_root / acceptance_pack).resolve()
    try:
        pack.relative_to(repo_root)
        payload = json.loads(pack.read_text(encoding="utf-8"))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        raise WorkspaceError("baseline_acceptance_pack_invalid", "runtime source list could not be loaded") from exc
    sources = payload.get("runtime_sources") if isinstance(payload, dict) else None
    if not isinstance(sources, list) or not sources or not all(isinstance(item, str) for item in sources):
        raise WorkspaceError("baseline_runtime_sources_invalid", "runtime source list must be a non-empty string array")
    hashes: list[dict[str, str]] = []
    for relative_path in sources:
        source = (repo_root / relative_path).resolve()
        try:
            source.relative_to(repo_root)
        except ValueError as exc:
            raise WorkspaceError("baseline_runtime_source_outside_repo", "runtime source escaped repository") from exc
        if not source.is_file():
            raise WorkspaceError("baseline_runtime_source_missing", "baseline runtime source is missing")
        hashes.append({"path": relative_path, "sha256": sha256_file(source)})
    return hashes


def _install_evidence(result: CommandResult) -> dict[str, object]:
    return {
        "args": result.args,
        "returncode": result.returncode,
        "timed_out": result.timed_out,
        "started_at": result.started_at,
        "ended_at": result.ended_at,
        "duration_seconds": result.duration_seconds,
        "stderr": "[installer stderr withheld]" if result.stderr else "",
    }

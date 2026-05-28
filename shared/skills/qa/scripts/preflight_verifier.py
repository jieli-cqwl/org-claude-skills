from __future__ import annotations

from pathlib import Path
from typing import Any

try:
    from shared.skills.qa.scripts.preflight_common import PreflightFailure, load_json
except ModuleNotFoundError:
    from preflight_common import PreflightFailure, load_json


def list_task_ids(phase_dir: Path) -> list[str]:
    payload = load_json(phase_dir / "tasks.json", "tasks.json")
    tasks = payload.get("tasks")
    if not isinstance(tasks, list) or not tasks:
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            f"tasks.json must contain a non-empty tasks array: {phase_dir / 'tasks.json'}",
            ["tasks.json"],
        )

    task_ids: list[str] = []
    for index, item in enumerate(tasks):
        if not isinstance(item, dict):
            raise PreflightFailure(
                "SCHEMA_FAILURE",
                f"tasks.json tasks[{index}] must be an object",
                ["tasks.json"],
            )
        raw_task_id = item.get("task_id")
        if not isinstance(raw_task_id, str) or not raw_task_id.strip():
            raise PreflightFailure(
                "SCHEMA_FAILURE",
                f"tasks.json tasks[{index}].task_id must be a non-empty string",
                ["tasks.json"],
            )
        task_id = raw_task_id.strip()
        if task_id in {".", ".."} or "/" in task_id:
            raise PreflightFailure(
                "SCHEMA_FAILURE",
                f"tasks.json tasks[{index}].task_id is not a safe path segment: {task_id}",
                ["tasks.json"],
            )
        task_ids.append(task_id)

    duplicates = sorted(
        {task_id for task_id in task_ids if task_ids.count(task_id) > 1}
    )
    if duplicates:
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            f"duplicate task_id entries in tasks.json: {duplicates}",
            ["tasks.json"],
        )
    return task_ids


def active_registry_entries(registry: dict[str, Any]) -> list[dict[str, Any]]:
    revisions = registry.get("revisions")
    active_revision_id = registry.get("active_revision_id")
    if not isinstance(revisions, list) or not isinstance(active_revision_id, str):
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            "artifact-registry.json must contain revisions and active_revision_id",
            ["artifact-registry.json"],
        )
    active_revisions = [
        revision
        for revision in revisions
        if isinstance(revision, dict)
        and revision.get("revision_id") == active_revision_id
    ]
    if len(active_revisions) != 1:
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            f"artifact-registry.json active_revision_id not found exactly once: {active_revision_id}",
            ["artifact-registry.json"],
        )
    entries = active_revisions[0].get("entries")
    if not isinstance(entries, list):
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            "artifact-registry.json active revision must contain entries",
            ["artifact-registry.json"],
        )
    return [
        entry
        for entry in entries
        if isinstance(entry, dict) and entry.get("active_for_consumption") is True
    ]


def registry_artifact_path_matches(
    entry: dict[str, Any], task_id: str, filename: str
) -> bool:
    artifact_path = entry.get("artifact_path")
    if not isinstance(artifact_path, str):
        return False
    parts = Path(artifact_path).parts
    return len(parts) >= 3 and parts[-3:] == ("tasks", task_id, filename)


def resolve_registry_path(phase_dir: Path, artifact_path: str) -> Path:
    candidate = Path(artifact_path)
    if candidate.is_absolute():
        return candidate.resolve()
    return (phase_dir / candidate).resolve()


def active_tasks_version_ref(
    phase_dir: Path, registry_entries: list[dict[str, Any]]
) -> str:
    tasks = load_json(phase_dir / "tasks.json", "tasks.json")
    artifact_id = tasks.get("artifact_id")
    if not isinstance(artifact_id, str) or not artifact_id.strip():
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            "tasks.json must contain artifact_id",
            ["tasks.json"],
        )
    matches = [
        entry
        for entry in registry_entries
        if entry.get("artifact_type") == "tasks"
        and entry.get("artifact_path") == "tasks.json"
    ]
    if len(matches) != 1:
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            "artifact-registry.json must contain exactly one active tasks.json entry",
            ["artifact-registry.json"],
        )
    entry = matches[0]
    if entry.get("lifecycle_state") != "FINALIZED":
        raise PreflightFailure(
            "VERIFIER_NOT_PASS",
            "active tasks.json registry entry must be FINALIZED",
            ["tasks.json"],
        )
    if entry.get("artifact_id") != artifact_id:
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            "active tasks.json registry entry artifact_id must match tasks.json",
            ["artifact-registry.json", "tasks.json"],
        )
    version = entry.get("version")
    if not isinstance(version, str) or not version.strip():
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            "active tasks.json registry entry must contain version",
            ["artifact-registry.json"],
        )
    return f"artifact://tasks/{artifact_id}@{version}#task-registry"


def find_active_task_artifact(
    phase_dir: Path,
    task_id: str,
    filename: str,
    artifact_type: str,
    registry_entries: list[dict[str, Any]],
) -> Path | None:
    matches: list[dict[str, Any]] = []
    for entry in registry_entries:
        if entry.get("artifact_type") != artifact_type:
            continue
        if not registry_artifact_path_matches(entry, task_id, filename):
            continue
        if entry.get("lifecycle_state") != "FINALIZED":
            raise PreflightFailure(
                "VERIFIER_NOT_PASS",
                f"active {filename} registry entry must be FINALIZED for task {task_id}",
                [f"{task_id}/{filename}"],
            )
        scope_ref = entry.get("scope_ref")
        if not isinstance(scope_ref, str) or not scope_ref.endswith(f"#task-{task_id}"):
            raise PreflightFailure(
                "SCHEMA_FAILURE",
                f"active {filename} registry entry scope_ref must target task {task_id}",
                [f"{task_id}/{filename}"],
            )
        matches.append(entry)

    if len(matches) > 1:
        labels = [str(entry.get("artifact_path", "")) for entry in matches]
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            f"multiple {filename} files found for task {task_id}: {labels}",
            labels,
        )
    if not matches:
        return None
    artifact_path = matches[0].get("artifact_path")
    if not isinstance(artifact_path, str):
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            f"active {filename} registry entry missing artifact_path for task {task_id}",
            [f"{task_id}/{filename}"],
        )
    return resolve_registry_path(phase_dir, artifact_path)


def load_task_artifact(
    phase_dir: Path,
    task_id: str,
    filename: str,
    artifact_type: str,
    registry_entries: list[dict[str, Any]],
) -> dict[str, Any]:
    path = find_active_task_artifact(
        phase_dir, task_id, filename, artifact_type, registry_entries
    )
    missing_name = f"{task_id}/{filename}"
    if path is None:
        raise PreflightFailure(
            "MISSING_INPUT",
            f"missing active registry entry for {filename} on frozen task {task_id}",
            [missing_name],
        )
    payload = load_json(path, str(path.relative_to(phase_dir)))
    if payload.get("artifact_type") != artifact_type:
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            f"{filename} artifact_type must be {artifact_type}: {path}",
            [str(path.relative_to(phase_dir))],
        )
    if payload.get("task_id") != task_id:
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            f"{filename} task_id must match frozen task {task_id}: {path}",
            [str(path.relative_to(phase_dir))],
        )
    return payload


def task_artifact_ref(payload: dict[str, Any], artifact_type: str, anchor: str) -> str:
    artifact_id = payload.get("artifact_id")
    if not isinstance(artifact_id, str) or not artifact_id.strip():
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            f"{artifact_type} must contain artifact_id",
            [artifact_type],
        )
    return f"artifact://{artifact_type}/{artifact_id}@v1#{anchor}"


def validate_verifier(phase_dir: Path, registry: dict[str, Any]) -> None:
    registry_entries = active_registry_entries(registry)
    expected_tasks_ref = active_tasks_version_ref(phase_dir, registry_entries)
    for task_id in list_task_ids(phase_dir):
        developer_report = load_task_artifact(
            phase_dir,
            task_id,
            "developer-report.json",
            "developer-report",
            registry_entries,
        )
        runtime_status = developer_report.get("runtime_status")
        if runtime_status != "VERIFIED":
            raise PreflightFailure(
                "VERIFIER_NOT_PASS",
                f"developer-report.json runtime_status must be VERIFIED, got "
                f"{runtime_status!r} for task {task_id}",
                [f"{task_id}/developer-report.json"],
            )
        if developer_report.get("active_tasks_version_ref") != expected_tasks_ref:
            raise PreflightFailure(
                "VERIFIER_NOT_PASS",
                f"developer-report.json active_tasks_version_ref must match current tasks for task {task_id}",
                [f"{task_id}/developer-report.json"],
            )

        payload = load_task_artifact(
            phase_dir,
            task_id,
            "verify-result.json",
            "verify-result",
            registry_entries,
        )
        gate = payload.get("gate_result")
        if gate != "PASS":
            raise PreflightFailure(
                "VERIFIER_NOT_PASS",
                f"verify-result.json gate_result must be PASS, got "
                f"{gate!r} for task {task_id}",
                [f"{task_id}/verify-result.json"],
            )
        if payload.get("active_tasks_version_ref") != expected_tasks_ref:
            raise PreflightFailure(
                "VERIFIER_NOT_PASS",
                f"verify-result.json active_tasks_version_ref must match current tasks for task {task_id}",
                [f"{task_id}/verify-result.json"],
            )
        if payload.get("baseline_tasks_version_ref") != expected_tasks_ref:
            raise PreflightFailure(
                "VERIFIER_NOT_PASS",
                f"verify-result.json baseline_tasks_version_ref must match current tasks for task {task_id}",
                [f"{task_id}/verify-result.json"],
            )
        expected_report_ref = task_artifact_ref(
            developer_report, "developer-report", "tdd-evidence-index"
        )
        if payload.get("developer_report_ref") != expected_report_ref:
            raise PreflightFailure(
                "VERIFIER_NOT_PASS",
                f"verify-result.json developer_report_ref must match active developer-report for task {task_id}",
                [f"{task_id}/verify-result.json"],
            )

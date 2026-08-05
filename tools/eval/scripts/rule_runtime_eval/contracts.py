"""Immutable loaders for rule-runtime evaluator input contracts."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
from types import MappingProxyType
from typing import Mapping


class ContractError(ValueError):
    """A user-correctable contract failure with a stable machine-readable code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


@dataclass(frozen=True)
class SceneContract:
    id: str
    runtime_source: Path
    installed_path: Path
    activation: str


@dataclass(frozen=True)
class EvalCase:
    pack_id: str
    id: str
    prompt: str
    expected_behaviors: tuple[str, ...]
    anti_patterns: tuple[str, ...]
    blocking_failures: tuple[str, ...]
    expected_anchors: tuple[str, ...]
    anchor_definitions: Mapping[str, object]
    expected_scene_contracts: tuple[str, ...]
    forbidden_scene_contracts: tuple[str, ...]
    max_successful_scene_reads: int | None

    @property
    def expected_behavior_ids(self) -> tuple[str, ...]:
        return _local_ids("E", self.expected_behaviors)

    @property
    def anti_pattern_ids(self) -> tuple[str, ...]:
        return _local_ids("A", self.anti_patterns)

    @property
    def blocking_failure_ids(self) -> tuple[str, ...]:
        return _local_ids("B", self.blocking_failures)


@dataclass(frozen=True)
class CasePackReference:
    id: str
    path: Path
    grader: Path


@dataclass(frozen=True)
class CaseReference:
    pack_id: str
    case_id: str


@dataclass(frozen=True)
class DiagnosticProfile:
    id: str
    cases: tuple[CaseReference, ...]
    runs_per_configuration: int
    anchor_threshold: float
    marginal_effect_case: str
    lightness_policy: Mapping[str, object]


@dataclass(frozen=True)
class AcceptanceContract:
    repo_root: Path
    pack_path: Path
    runtime_sources: tuple[Path, ...]
    scene_contracts: tuple[SceneContract, ...]
    case_packs: tuple[CasePackReference, ...]
    diagnostic_profiles: tuple[DiagnosticProfile, ...]

    @property
    def scene_by_id(self) -> Mapping[str, SceneContract]:
        return MappingProxyType({scene.id: scene for scene in self.scene_contracts})

    @property
    def case_pack_by_id(self) -> Mapping[str, CasePackReference]:
        return MappingProxyType({pack.id: pack for pack in self.case_packs})


def load_acceptance_contract(repo_root: Path, pack_path: Path) -> AcceptanceContract:
    """Load acceptance ownership and validate all repository-owned references."""

    root = repo_root.resolve()
    if not root.is_dir():
        raise ContractError("repo_root_invalid", "repository root must be a directory")
    resolved_pack = _resolve_repo_file(root, pack_path, "acceptance_pack_missing")
    payload = _read_json_object(resolved_pack, "acceptance_pack_invalid")
    runtime_sources = _load_runtime_sources(root, payload)
    scene_contracts = _load_scene_contracts(root, payload, runtime_sources)
    case_packs = _load_case_pack_references(root, payload)
    profiles = _load_profiles(payload)
    return AcceptanceContract(
        repo_root=root,
        pack_path=resolved_pack,
        runtime_sources=runtime_sources,
        scene_contracts=scene_contracts,
        case_packs=case_packs,
        diagnostic_profiles=profiles,
    )


def load_profile_cases(
    contract: AcceptanceContract,
    profile_id: str,
    case_source_root: Path,
) -> tuple[DiagnosticProfile, list[EvalCase]]:
    """Resolve selected cases without inferring missing behavior or scene metadata."""

    profile = _find_profile(contract, profile_id)
    source_root = case_source_root.resolve()
    if not source_root.is_dir():
        raise ContractError("case_source_root_invalid", "case source root must be a directory")
    loaded_packs = {
        pack.id: _load_case_pack(source_root, pack, contract.scene_by_id)
        for pack in contract.case_packs
    }
    selected_cases: list[EvalCase] = []
    for reference in profile.cases:
        pack_cases = loaded_packs.get(reference.pack_id)
        if pack_cases is None:
            raise ContractError("profile_pack_unknown", "profile references an unknown case pack")
        selected_case = pack_cases.get(reference.case_id)
        if selected_case is None:
            raise ContractError("profile_case_unknown", "profile references an unknown case")
        selected_cases.append(selected_case)
    return profile, selected_cases


def parse_baseline_refs(
    values: list[str],
    selected_pack_ids: set[str],
    allowed_pack_ids: set[str] | None = None,
) -> dict[str, str]:
    """Parse exact pack-to-ref mappings before callers build a lookup table."""

    mappings: list[tuple[str, str]] = []
    for value in values:
        if value.count("=") != 1:
            raise ContractError("baseline_ref_malformed", "baseline mapping must use PACK=REF")
        pack_id, ref = value.split("=", 1)
        if not pack_id or not ref:
            raise ContractError("baseline_ref_malformed", "baseline mapping must use PACK=REF")
        mappings.append((pack_id, ref))
    _require_unique((pack_id for pack_id, _ in mappings), "baseline_ref_duplicate")
    mapping = dict(mappings)
    allowed = selected_pack_ids if allowed_pack_ids is None else allowed_pack_ids
    unknown = set(mapping) - allowed
    if unknown:
        raise ContractError("baseline_ref_unknown", "baseline mapping references an unknown selected pack")
    missing = selected_pack_ids - set(mapping)
    if missing:
        raise ContractError("baseline_ref_missing", "every selected pack needs one baseline mapping")
    return mapping


def _load_runtime_sources(root: Path, payload: Mapping[str, object]) -> tuple[Path, ...]:
    values = _string_list(payload.get("runtime_sources"), "runtime_sources_missing")
    _require_unique(values, "runtime_source_duplicate")
    sources = tuple(_resolve_repo_file(root, Path(value), "runtime_source_missing") for value in values)
    if (root / "shared" / "assistant.md").resolve() not in sources:
        raise ContractError(
            "assistant_runtime_source_missing",
            "shared/assistant.md must be declared as a runtime source",
        )
    return sources


def _load_scene_contracts(
    root: Path,
    payload: Mapping[str, object],
    runtime_sources: tuple[Path, ...],
) -> tuple[SceneContract, ...]:
    entries = _object_list(payload.get("scene_contracts"), "scene_contracts_missing")
    ids = [_required_string(entry, "id", "scene_id_missing") for entry in entries]
    _require_unique(ids, "scene_id_duplicate")
    sources = set(runtime_sources)
    scenes: list[SceneContract] = []
    for entry, scene_id in zip(entries, ids, strict=True):
        runtime_source = _resolve_repo_file(
            root,
            Path(_required_string(entry, "runtime_source", "scene_runtime_source_missing")),
            "scene_runtime_source_missing",
        )
        if runtime_source not in sources:
            raise ContractError("scene_runtime_source_unknown", "scene source must be a runtime source")
        installed_path = _relative_path(
            _required_string(entry, "installed_path", "scene_installed_path_invalid"),
            "scene_installed_path_invalid",
        )
        activation = _required_string(entry, "activation", "scene_activation_invalid")
        if activation not in {"pre_execution", "scene"}:
            raise ContractError("scene_activation_invalid", "scene activation is unsupported")
        scenes.append(SceneContract(scene_id, runtime_source, installed_path, activation))
    return tuple(scenes)


def _load_case_pack_references(root: Path, payload: Mapping[str, object]) -> tuple[CasePackReference, ...]:
    entries = _object_list(payload.get("case_packs"), "case_packs_missing")
    ids = [_required_string(entry, "id", "case_pack_id_missing") for entry in entries]
    _require_unique(ids, "case_pack_id_duplicate")
    packs: list[CasePackReference] = []
    for entry, pack_id in zip(entries, ids, strict=True):
        relative_path = _relative_path(
            _required_string(entry, "path", "case_pack_path_invalid"), "case_pack_path_invalid"
        )
        relative_grader = _relative_path(
            _required_string(entry, "grader", "case_pack_grader_invalid"), "case_pack_grader_invalid"
        )
        _resolve_repo_file(root, relative_path, "case_pack_missing")
        _resolve_repo_file(root, relative_grader, "case_pack_grader_missing")
        packs.append(CasePackReference(pack_id, relative_path, relative_grader))
    return tuple(packs)


def _load_profiles(payload: Mapping[str, object]) -> tuple[DiagnosticProfile, ...]:
    entries = _object_list(payload.get("diagnostic_profiles"), "profiles_missing")
    ids = [_required_string(entry, "id", "profile_id_missing") for entry in entries]
    _require_unique(ids, "profile_id_duplicate")
    profiles: list[DiagnosticProfile] = []
    for entry, profile_id in zip(entries, ids, strict=True):
        case_entries = _object_list(entry.get("cases"), "profile_cases_missing")
        references = tuple(
            CaseReference(
                _required_string(case, "pack", "profile_case_pack_missing"),
                _required_string(case, "id", "profile_case_id_missing"),
            )
            for case in case_entries
        )
        _require_unique(
            (f"{reference.pack_id}:{reference.case_id}" for reference in references),
            "profile_case_duplicate",
        )
        runs = entry.get("runs_per_configuration")
        threshold = entry.get("anchor_threshold")
        if not isinstance(runs, int) or isinstance(runs, bool) or runs < 2:
            raise ContractError(
                "profile_runs_invalid",
                "effectiveness profiles require at least two runs per configuration",
            )
        if not isinstance(threshold, (int, float)):
            raise ContractError("profile_anchor_threshold_invalid", "profile anchor threshold must be numeric")
        lightness_policy = entry.get("lightness_policy")
        if not isinstance(lightness_policy, dict):
            raise ContractError("profile_lightness_policy_missing", "profile lightness policy must be an object")
        profiles.append(
            DiagnosticProfile(
                id=profile_id,
                cases=references,
                runs_per_configuration=runs,
                anchor_threshold=float(threshold),
                marginal_effect_case=_required_string(
                    entry, "marginal_effect_case", "profile_marginal_case_missing"
                ),
                lightness_policy=_freeze(lightness_policy),
            )
        )
    return tuple(profiles)


def _load_case_pack(
    source_root: Path,
    reference: CasePackReference,
    scene_by_id: Mapping[str, SceneContract],
) -> Mapping[str, EvalCase]:
    path = _resolve_repo_file(source_root, reference.path, "case_pack_missing")
    payload = _read_json_object(path, "case_pack_invalid")
    blocking_failures = _string_list(
        payload.get("blocking_failures"), "pack_blocking_failures_missing"
    )
    anchors = _object_list(payload.get("preference_anchors"), "anchor_definitions_missing")
    anchor_ids = [_required_string(anchor, "id", "anchor_definition_missing") for anchor in anchors]
    _require_unique(anchor_ids, "anchor_definition_duplicate")
    anchor_by_id = {anchor_id: anchor for anchor_id, anchor in zip(anchor_ids, anchors, strict=True)}
    case_entries = _object_list(payload.get("evals"), "case_entries_missing")
    case_ids = [_required_string(case, "id", "case_id_missing") for case in case_entries]
    _require_unique(case_ids, "case_id_duplicate")
    cases: dict[str, EvalCase] = {}
    for entry, case_id in zip(case_entries, case_ids, strict=True):
        expected_anchors = _string_list(entry.get("expected_anchors"), "case_expected_anchors_missing")
        unknown_anchors = set(expected_anchors) - set(anchor_by_id)
        if unknown_anchors:
            raise ContractError("anchor_definition_missing", "case references an unknown anchor")
        expected_scenes = _string_list(
            entry.get("expected_scene_contracts"), "case_expected_scenes_missing"
        )
        forbidden_scenes = _optional_string_list(
            entry.get("forbidden_scene_contracts", []), "case_forbidden_scenes_invalid"
        )
        unknown_scenes = set(expected_scenes) - set(scene_by_id)
        unknown_forbidden_scenes = set(forbidden_scenes) - set(scene_by_id)
        if unknown_scenes or unknown_forbidden_scenes:
            raise ContractError("case_scene_unknown", "case references an unknown scene")
        if set(expected_scenes) & set(forbidden_scenes):
            raise ContractError(
                "case_scene_overlap",
                "required and forbidden scene contracts must not overlap",
            )
        max_successful_scene_reads = entry.get("max_successful_scene_reads")
        if max_successful_scene_reads is not None and (
            not isinstance(max_successful_scene_reads, int)
            or isinstance(max_successful_scene_reads, bool)
            or max_successful_scene_reads < len(expected_scenes)
        ):
            raise ContractError(
                "case_max_scene_reads_invalid",
                "maximum successful scene reads must cover every required scene",
            )
        definitions = {
            anchor_id: _freeze(anchor_by_id[anchor_id])
            for anchor_id in expected_anchors
        }
        cases[case_id] = EvalCase(
            pack_id=reference.id,
            id=case_id,
            prompt=_required_string(entry, "prompt", "case_prompt_missing"),
            expected_behaviors=_string_list(
                entry.get("expected_behaviors"), "case_expected_behaviors_missing"
            ),
            anti_patterns=_string_list(entry.get("anti_patterns"), "case_anti_patterns_missing"),
            blocking_failures=blocking_failures,
            expected_anchors=expected_anchors,
            anchor_definitions=MappingProxyType(definitions),
            expected_scene_contracts=expected_scenes,
            forbidden_scene_contracts=forbidden_scenes,
            max_successful_scene_reads=max_successful_scene_reads,
        )
    return MappingProxyType(cases)


def _find_profile(contract: AcceptanceContract, profile_id: str) -> DiagnosticProfile:
    for profile in contract.diagnostic_profiles:
        if profile.id == profile_id:
            return profile
    raise ContractError("profile_unknown", "requested diagnostic profile does not exist")


def _resolve_repo_file(root: Path, path: Path, code: str) -> Path:
    resolved = (root / path).resolve() if not path.is_absolute() else path.resolve()
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise ContractError("repo_path_outside_root", "repository path must remain inside repo root") from exc
    if not resolved.is_file():
        raise ContractError(code, "required repository file is missing")
    return resolved


def _relative_path(value: str, code: str) -> Path:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or value == "":
        raise ContractError(code, "path must be a non-empty relative repository path")
    return path


def _read_json_object(path: Path, code: str) -> Mapping[str, object]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ContractError(code, "JSON contract could not be loaded") from exc
    if not isinstance(payload, dict):
        raise ContractError(code, "JSON contract must be an object")
    return MappingProxyType(payload)


def _object_list(value: object, code: str) -> list[Mapping[str, object]]:
    if not isinstance(value, list) or not value:
        raise ContractError(code, "contract list must be non-empty")
    if not all(isinstance(item, dict) for item in value):
        raise ContractError(code, "contract list entries must be objects")
    return [MappingProxyType(item) for item in value]


def _string_list(value: object, code: str) -> tuple[str, ...]:
    if not isinstance(value, list) or not value:
        raise ContractError(code, "contract list must be non-empty")
    if not all(isinstance(item, str) and item.strip() for item in value):
        raise ContractError(code, "contract list entries must be non-empty strings")
    return tuple(value)


def _optional_string_list(value: object, code: str) -> tuple[str, ...]:
    if not isinstance(value, list):
        raise ContractError(code, "contract value must be a list")
    if not all(isinstance(item, str) and item.strip() for item in value):
        raise ContractError(code, "contract list entries must be non-empty strings")
    _require_unique(value, code)
    return tuple(value)


def _required_string(entry: Mapping[str, object], field: str, code: str) -> str:
    value = entry.get(field)
    if not isinstance(value, str) or not value.strip():
        raise ContractError(code, "required contract value is missing")
    return value


def _require_unique(values: object, code: str) -> None:
    sequence = list(values)  # type: ignore[arg-type]
    if len(set(sequence)) != len(sequence):
        raise ContractError(code, "contract values must be unique")


def _local_ids(prefix: str, values: tuple[str, ...]) -> tuple[str, ...]:
    return tuple(f"{prefix}{index}" for index, _ in enumerate(values, start=1))


def _freeze(value: object) -> object:
    if isinstance(value, dict):
        return MappingProxyType({key: _freeze(item) for key, item in value.items()})
    if isinstance(value, list):
        return tuple(_freeze(item) for item in value)
    return value

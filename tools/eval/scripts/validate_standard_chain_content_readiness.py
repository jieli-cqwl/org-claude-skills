#!/usr/bin/env python3
"""Validate evaluation-only standard-chain content-readiness evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath
from typing import Any, Iterable

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "tools/community"))

from simple_json_schema import SimpleSchemaValidator, SimpleValidationError  # noqa: E402

SCHEMA_ID = "https://qft.local/schemas/standard-chain-content-readiness.schema.json"
SCHEMA_PATH = (
    REPO_ROOT / "tools/eval/contracts/standard-chain-content-readiness.schema.json"
)
PRIMARY_ROLES = [
    "product-director",
    "product-manager",
    "design",
    "test-design",
    "tech-lead",
    "delivery-owner",
]
ARTIFACT_DEFS = {
    "run": "run",
    "confirmation-ref": "confirmation_ref",
    "input-manifest": "input_manifest",
    "oracle-manifest": "oracle_manifest",
    "source-classification": "source_classification",
    "role-surface": "role_surface",
    "decision-atom-register": "decision_atom_register",
    "replay-attempt": "replay_attempt",
    "replay-lane": "replay_lane",
    "transcript": "transcript",
    "artifact-manifest": "artifact_manifest",
    "divergence-review": "divergence_review",
    "oracle-review": "oracle_review",
    "downstream-consumption": "downstream_consumption",
    "role-verdict": "role_verdict",
    "chain-verdict": "chain_verdict",
}
ROLE_VERDICTS = {
    "CONTENT_PASS",
    "CONTENT_FAIL",
    "BLOCKED_ORACLE",
    "BLOCKED_EVIDENCE",
    "BLOCKED_ISOLATION",
}
CANONICAL_FORBIDDEN_FIELDS = {
    "evaluation_only",
    "case_id",
    "lane_id",
    "oracle_ref",
    "attempt_id",
}
STAGE_ORDER = {
    "admitted": 0,
    "static-audit": 1,
    "diagnostic-replay": 2,
    "role-verdict": 3,
}
ROLE_REF_STAGE = {
    "surface.json": 1,
    "decision-atoms.json": 1,
    "content-audit-alignment.json": 1,
    "replay-lane.json": 2,
    "replay-attempt.json": 2,
    "transcript.json": 2,
    "artifact-manifest.json": 2,
    "divergence-review.json": 2,
    "oracle-review.json": 2,
    "downstream-consumption.json": 2,
    "content-audit-report.json": 3,
    "role-verdict.json": 3,
}
STATIC_ROLE_ARTIFACTS = {
    "surface.json",
    "decision-atoms.json",
    "content-audit-alignment.json",
}
REPLAY_ROLE_FILENAMES = {
    "replay-lane.json",
    "replay-attempt.json",
    "transcript.json",
    "artifact-manifest.json",
}
REVIEW_ROLE_ARTIFACTS = {
    "divergence-review.json",
    "oracle-review.json",
    "downstream-consumption.json",
}
FORMAL_ROLE_ARTIFACTS = {"content-audit-report.json", "role-verdict.json"}


def canonical_bytes(value: object) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def digest(value: object) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected JSON object")
    return value


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args],
        text=True,
        stderr=subprocess.STDOUT,
        timeout=30,
    ).strip()


def enumerate_source_denominator(
    source_id: str, source_root: Path, baseline: str, result: str
) -> dict[str, Any]:
    """Return the shared ancestry-commit and first-parent changed-path denominator."""
    git(source_root, "cat-file", "-e", f"{baseline}^{{commit}}")
    git(source_root, "cat-file", "-e", f"{result}^{{commit}}")
    ancestor = subprocess.run(
        [
            "git",
            "-C",
            str(source_root),
            "merge-base",
            "--is-ancestor",
            baseline,
            result,
        ],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if ancestor.returncode != 0:
        raise ValueError(
            "source classification denominator mismatch: baseline is not an ancestor of result"
        )
    raw_commits = git(
        source_root,
        "rev-list",
        "--ancestry-path",
        "--reverse",
        "--topo-order",
        f"{baseline}..{result}",
    )
    commits = [line for line in raw_commits.splitlines() if line]
    atoms: list[dict[str, str]] = []
    for commit in commits:
        parents = git(source_root, "rev-list", "--parents", "-n", "1", commit).split()
        if len(parents) < 2:
            raise ValueError(f"source commit has no first parent: {commit}")
        parent = parents[1]
        changed = git(
            source_root,
            "diff-tree",
            "--no-commit-id",
            "--name-status",
            "-r",
            "-M",
            parent,
            commit,
        )
        for line in changed.splitlines():
            if not line:
                continue
            parts = line.split("\t")
            status = parts[0]
            atom: dict[str, str] = {
                "commit": commit,
                "parent_commit": parent,
                "change_status": status,
            }
            if status.startswith(("R", "C")):
                if len(parts) != 3:
                    raise ValueError(f"malformed rename/copy diff row: {line}")
                atom["previous_path"] = parts[1]
                atom["path"] = parts[2]
            else:
                if len(parts) != 2:
                    raise ValueError(f"malformed diff row: {line}")
                atom["path"] = parts[1]
            atoms.append(atom)
    return {
        "source_id": source_id,
        "baseline_commit": baseline,
        "result_commit": result,
        "ancestry_commits": commits,
        "source_atoms": atoms,
    }


def parse_source_roots(values: Iterable[str]) -> tuple[dict[str, Path], list[str]]:
    roots: dict[str, Path] = {}
    failures: list[str] = []
    for value in values:
        source_id, separator, raw_path = value.partition("=")
        if not separator or not source_id or not raw_path or not Path(raw_path).is_absolute():
            failures.append(
                "--source-root must use source_id=/absolute/path"
            )
            continue
        if source_id in roots:
            failures.append(f"duplicate --source-root ID: {source_id}")
            continue
        roots[source_id] = Path(raw_path).resolve()
    return roots, failures


@dataclass
class ValidationContext:
    run_root: Path
    source_roots: dict[str, Path]
    schema: dict[str, Any]
    failures: list[str] = field(default_factory=list)
    invoked: list[dict[str, Any]] = field(default_factory=list)
    artifacts: dict[str, dict[str, Any]] = field(default_factory=dict)
    canonical_jobs: list[tuple[str, list[dict[str, Any]]]] = field(default_factory=list)
    ref_targets: dict[bytes, tuple[Path, bytes]] = field(default_factory=dict)
    validated_ref_objects: set[int] = field(default_factory=set)
    invalid_artifacts: set[str] = field(default_factory=set)

    def fail(self, message: str) -> None:
        if message not in self.failures:
            self.failures.append(message)

    def schema_validate(self, payload: dict[str, Any], path: Path) -> bool:
        artifact_type = payload.get("artifact_type")
        if artifact_type == "role-verdict" and payload.get("verdict") not in ROLE_VERDICTS:
            self.fail("unsupported verdict")
            return False
        if artifact_type == "chain-verdict" and payload.get("verdict") != "CASE_REPLAY_PASS":
            self.fail("unsupported verdict")
            return False
        definition = ARTIFACT_DEFS.get(str(artifact_type))
        if definition is None:
            self.fail(f"{path}: unsupported artifact_type")
            return False
        wrapper = {"$id": SCHEMA_ID, "$ref": f"#/$defs/{definition}"}
        validator = SimpleSchemaValidator({SCHEMA_ID: self.schema})
        try:
            validator.validate(payload, wrapper)
        except SimpleValidationError as exc:
            text = str(exc)
            if artifact_type == "role-verdict" and (
                "content_digest" in text or "inherited_runtime_digest" in text
            ):
                self.fail("missing baseline digest is not legally blocked")
            else:
                self.fail(f"{path.relative_to(self.run_root)}: schema validation failed: {text}")
            return False
        return True

    def load_artifact(self, relative: str) -> dict[str, Any] | None:
        if relative in self.artifacts:
            return self.artifacts[relative]
        if relative in self.invalid_artifacts:
            return None
        path = self.run_root / relative
        try:
            payload = load_json(path)
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            self.fail(f"{relative}: artifact load failed: {exc}")
            self.invalid_artifacts.add(relative)
            return None
        if not self.schema_validate(payload, path):
            self.invalid_artifacts.add(relative)
            return None
        self.artifacts[relative] = payload
        return payload

    def ref_target(self, ref: dict[str, Any]) -> tuple[Path, bytes] | None:
        cache_key = canonical_bytes(ref)
        if cache_key in self.ref_targets:
            return self.ref_targets[cache_key]
        raw_path = ref.get("path")
        if not isinstance(raw_path, str):
            self.fail("artifact path must be relative")
            return None
        pure = PurePosixPath(raw_path)
        if pure.is_absolute() or Path(raw_path).is_absolute():
            self.fail("artifact path must be relative")
            return None
        if ".." in pure.parts:
            self.fail("artifact path must not escape its scope")
            return None
        scope = ref.get("scope")
        if scope == "repo":
            root = REPO_ROOT
            if "source_id" in ref:
                self.fail("repo ref must not declare source_id")
        elif scope == "run":
            root = self.run_root
            if "source_id" in ref:
                self.fail("run ref must not declare source_id")
        elif scope == "external_repo":
            source_id = ref.get("source_id")
            if not isinstance(source_id, str) or source_id not in self.source_roots:
                self.fail("missing external_repo source-root mapping")
                return None
            root = self.source_roots[source_id]
        else:
            self.fail("unsupported ref scope")
            return None
        commit_fields = {key for key in ("commit", "blob", "line") if key in ref}
        if commit_fields and commit_fields != {"commit", "blob", "line"}:
            self.fail("commit-bound ref requires commit, blob and line")
            return None
        try:
            if commit_fields:
                commit = str(ref["commit"])
                raw = subprocess.check_output(
                    ["git", "-C", str(root), "show", f"{commit}:{raw_path}"],
                    stderr=subprocess.STDOUT,
                    timeout=30,
                )
                actual_blob = git(root, "rev-parse", f"{commit}:{raw_path}")
                if actual_blob != ref.get("blob"):
                    self.fail("stale approval reference")
                lines = raw.decode("utf-8").splitlines()
                line = ref.get("line")
                if not isinstance(line, int) or line < 1 or line > len(lines):
                    self.fail("stale approval reference")
            else:
                raw = (root / raw_path).read_bytes()
        except (OSError, subprocess.SubprocessError, UnicodeDecodeError) as exc:
            self.fail(f"referenced bytes unavailable: {raw_path}: {exc}")
            return None
        if hashlib.sha256(raw).hexdigest() != ref.get("sha256"):
            self.fail("stale file SHA-256")
        target = root / raw_path, raw
        self.ref_targets[cache_key] = target
        return target

    def validate_refs(self, payload: object) -> None:
        if isinstance(payload, (dict, list)):
            marker = id(payload)
            if marker in self.validated_ref_objects:
                return
            self.validated_ref_objects.add(marker)
        if isinstance(payload, dict):
            if {"scope", "path", "sha256"} <= set(payload):
                self.ref_target(payload)
                return
            for value in payload.values():
                self.validate_refs(value)
        elif isinstance(payload, list):
            for value in payload:
                self.validate_refs(value)

    def invoke(
        self,
        name: str,
        command: list[str],
        *,
        cwd: Path = REPO_ROOT,
        input_text: str | None = None,
        failure_message: str,
    ) -> bool:
        try:
            result = subprocess.run(
                command,
                cwd=cwd,
                input=input_text,
                text=True,
                capture_output=True,
                timeout=45,
                check=False,
            )
            output = (result.stdout + result.stderr).strip()
            status = "PASS" if result.returncode == 0 else "FAIL"
        except (OSError, subprocess.TimeoutExpired) as exc:
            output = str(exc)
            status = "FAIL"
            result = None
        self.invoked.append(
            {
                "name": name,
                "status": status,
                "command": command,
                "output": output,
            }
        )
        if status != "PASS":
            self.fail(failure_message)
            return False
        return True


def ref_path(ref: dict[str, Any]) -> str:
    return str(ref.get("path", ""))


def canonical_ref_identity(ref: dict[str, Any]) -> bytes:
    return canonical_bytes(
        {
            key: ref[key]
            for key in ("scope", "source_id", "path", "commit", "blob", "line")
            if key in ref
        }
    )


def compare_ref_lists(left: list[Any], right: list[Any]) -> bool:
    return canonical_bytes(left) == canonical_bytes(right)


def validate_artifact_identity(
    context: ValidationContext,
    relative: str,
    payload: dict[str, Any],
    case_id: str,
) -> None:
    if payload.get("case_id") != case_id:
        context.fail("artifact identity mismatch")
    parts = PurePosixPath(relative).parts
    role: str | None = None
    lane_id: str | None = None
    attempt_number: int | None = None
    if len(parts) >= 2 and parts[0] == "roles":
        role = parts[1]
    for part in parts:
        if part.startswith("executor-"):
            lane_id = part.removeprefix("executor-")
        if part.startswith("attempt-"):
            suffix = part.removeprefix("attempt-")
            if suffix.isdigit():
                attempt_number = int(suffix)
    if role is not None:
        identity_role = payload.get("role", payload.get("producer_role"))
        if identity_role is not None and identity_role != role:
            context.fail("artifact identity mismatch")
    if lane_id is not None and payload.get("lane_id") is not None:
        if payload.get("lane_id") != lane_id:
            context.fail("artifact identity mismatch")
    if attempt_number is not None and payload.get("attempt_number") is not None:
        if payload.get("attempt_number") != attempt_number:
            context.fail("artifact identity mismatch")


def validate_loaded_artifact_identities(
    context: ValidationContext, case_id: str
) -> None:
    for relative, payload in context.artifacts.items():
        validate_artifact_identity(context, relative, payload, case_id)


def validate_confirmation(
    context: ValidationContext, confirmation: dict[str, Any]
) -> None:
    if "approval_text" in confirmation or "expected_snippet" in confirmation:
        context.fail("confirmation-ref must store references, not approval prose")
    approval_ref = confirmation.get("approval_ref")
    design_ref = confirmation.get("design_ref")
    if not isinstance(approval_ref, dict) or not isinstance(design_ref, dict):
        return
    approval_target = context.ref_target(approval_ref)
    design_target = context.ref_target(design_ref)
    if approval_target is None or design_target is None:
        context.fail("stale approval reference")
        return
    try:
        approval_lines = approval_target[1].decode("utf-8").splitlines()
        design_lines = design_target[1].decode("utf-8").splitlines()
        approval_line = confirmation["approval_line"]
        capability_line = confirmation["capability_line"]
        capability_ids = confirmation["approved_capability_ids"]
        if approval_ref.get("line") != approval_line:
            context.fail("stale approval reference")
        if not approval_lines[approval_line - 1].strip():
            context.fail("stale approval reference")
        capability_text = approval_lines[capability_line - 1]
        design_text = design_lines[design_ref["line"] - 1]
        if any(
            capability_id not in capability_text or capability_id not in design_text
            for capability_id in capability_ids
        ):
            context.fail("stale approval reference")
    except (IndexError, KeyError, TypeError, UnicodeDecodeError):
        context.fail("stale approval reference")


def denominator_core(source: dict[str, Any]) -> dict[str, Any]:
    return {
        "source_id": source.get("source_id"),
        "baseline_commit": source.get("baseline_commit"),
        "result_commit": source.get("result_commit"),
        "ancestry_commits": source.get("ancestry_commits"),
        "source_atoms": [
            {
                key: atom[key]
                for key in (
                    "commit",
                    "parent_commit",
                    "change_status",
                    "path",
                    "previous_path",
                )
                if key in atom
            }
            for atom in source.get("source_atoms", [])
            if isinstance(atom, dict)
        ],
    }


def validate_source_denominators(
    context: ValidationContext, source_manifest: dict[str, Any]
) -> None:
    for source in source_manifest.get("sources", []):
        if not isinstance(source, dict):
            continue
        source_id = source.get("source_id")
        root = context.source_roots.get(str(source_id))
        if root is None:
            context.fail("missing external_repo source-root mapping")
            continue
        atoms = source.get("source_atoms", [])
        markers = [
            (
                atom.get("commit"),
                atom.get("parent_commit"),
                atom.get("change_status"),
                atom.get("path"),
                atom.get("previous_path"),
            )
            for atom in atoms
            if isinstance(atom, dict)
        ]
        if len(markers) != len(set(markers)):
            context.fail("source classification denominator mismatch")
            continue
        try:
            actual = enumerate_source_denominator(
                str(source_id),
                root,
                str(source.get("baseline_commit")),
                str(source.get("result_commit")),
            )
        except (OSError, subprocess.SubprocessError, ValueError) as exc:
            context.fail(f"source classification denominator mismatch: {exc}")
            continue
        if denominator_core(source) != denominator_core(actual):
            context.fail("source classification denominator mismatch")


def derived_values(
    surface: dict[str, Any], oracle: dict[str, Any], input_manifest: dict[str, Any]
) -> tuple[str, str, str, str]:
    content_projection = sorted(
        (item["ref"] for item in surface.get("files", []) if isinstance(item, dict)),
        key=canonical_bytes,
    )
    proxy_projection = {
        item["fact_key"]: {
            "fact_class": item["fact_class"],
            "answer_text": item["answer_text"],
            "authority_refs": item["authority_refs"],
        }
        for item in sorted(
            (
                item
                for item in oracle.get("business_proxy_facts", [])
                if isinstance(item, dict)
            ),
            key=lambda item: item.get("fact_key", ""),
        )
    }
    runtime = surface.get("runtime_inheritance", {})
    runtime_projection = {
        "declared_mandatory_refs": sorted(
            runtime.get("declared_mandatory_refs", []), key=canonical_bytes
        ),
        "harness_descriptor": runtime.get("harness_descriptor"),
    }
    content_digest = digest(content_projection)
    fact_digest = digest(proxy_projection)
    runtime_digest = digest(runtime_projection)
    starting_digest = digest(
        {
            "starting_clue": input_manifest.get("starting_clue"),
            "product_director_content_digest": content_digest,
            "inherited_runtime_digest": runtime_digest,
            "oracle_version": input_manifest.get("oracle_version"),
            "authorized_business_proxy_fact_key_digest": fact_digest,
        }
    )
    return content_digest, fact_digest, runtime_digest, starting_digest


def validate_runtime_and_derived(
    context: ValidationContext,
    surface: dict[str, Any],
    oracle: dict[str, Any],
    input_manifest: dict[str, Any],
) -> tuple[str, str] | None:
    runtime = surface.get("runtime_inheritance")
    if not isinstance(runtime, dict):
        return None
    unresolved = runtime.get("unresolved_file_inputs", [])
    derived_fields = {
        "product_director_content_digest",
        "inherited_runtime_digest",
        "authorized_business_proxy_fact_key_digest",
        "starting_input_sha256",
    }
    if unresolved:
        if (
            "inherited_runtime_digest" in runtime
            or "inherited_runtime_unavailable" not in runtime
            or "inherited_runtime_refs" in input_manifest
            or any(field in input_manifest for field in derived_fields)
        ):
            context.fail("unresolved runtime input cannot claim complete digest")
        return None
    if "inherited_runtime_unavailable" in runtime:
        context.fail("unresolved runtime input cannot claim complete digest")
    required = derived_fields | {"inherited_runtime_refs"}
    if not required <= set(input_manifest):
        context.fail("missing baseline digest is not legally blocked")
        return None
    if not compare_ref_lists(
        runtime.get("declared_mandatory_refs", []),
        input_manifest.get("inherited_runtime_refs", []),
    ):
        context.fail("stale inherited runtime digest")
    content_digest, fact_digest, runtime_digest, starting_digest = derived_values(
        surface, oracle, input_manifest
    )
    if input_manifest.get("authorized_business_proxy_fact_key_digest") != fact_digest:
        context.fail("stale business proxy baseline digest")
    if (
        input_manifest.get("inherited_runtime_digest") != runtime_digest
        or runtime.get("inherited_runtime_digest") != runtime_digest
    ):
        context.fail("stale inherited runtime digest")
    if input_manifest.get("product_director_content_digest") != content_digest:
        context.fail("stale content baseline digest")
    if input_manifest.get("starting_input_sha256") != starting_digest:
        context.fail("stale starting input digest")
    return content_digest, runtime_digest


def validate_business_proxy(
    context: ValidationContext,
    oracle: dict[str, Any],
    transcripts: list[dict[str, Any]],
) -> None:
    current = {
        item["fact_key"]: item
        for item in oracle.get("business_proxy_facts", [])
        if isinstance(item, dict) and isinstance(item.get("fact_key"), str)
    }
    observed: dict[str, bytes] = {}
    for transcript in transcripts:
        for turn in transcript.get("turns", []):
            if not isinstance(turn, dict) or turn.get("actor") != "business-proxy":
                continue
            answers = turn.get("answers")
            authorities = turn.get("answer_authority_refs")
            if not isinstance(answers, list) or not isinstance(authorities, list):
                context.fail("business proxy answer drift")
                continue
            sorted_answers = sorted(answers, key=lambda item: item.get("fact_key", ""))
            if answers != sorted_answers or turn.get("message") != canonical_bytes(
                sorted_answers
            ).decode("utf-8"):
                context.fail("business proxy answer drift")
            authority_by_key = {
                item.get("fact_key"): item.get("authority_refs")
                for item in authorities
                if isinstance(item, dict)
            }
            for answer in answers:
                if not isinstance(answer, dict):
                    context.fail("business proxy answer drift")
                    continue
                key = answer.get("fact_key")
                expected = current.get(str(key))
                public = {
                    "fact_key": key,
                    "fact_class": answer.get("fact_class"),
                    "answer_text": answer.get("answer_text"),
                }
                if expected is None or public != {
                    "fact_key": expected.get("fact_key"),
                    "fact_class": expected.get("fact_class"),
                    "answer_text": expected.get("answer_text"),
                }:
                    context.fail("business proxy answer drift")
                if expected is None or canonical_bytes(authority_by_key.get(key)) != canonical_bytes(
                    expected.get("authority_refs")
                ):
                    context.fail("business proxy answer drift")
                marker = canonical_bytes(public)
                if key in observed and observed[str(key)] != marker:
                    context.fail("business proxy answer drift")
                observed[str(key)] = marker


def validate_actual_reads(
    context: ValidationContext,
    attempt: dict[str, Any],
    input_manifest: dict[str, Any],
) -> None:
    environment = attempt.get("environment", {})
    staged = environment.get("staged_files", [])
    root_fields = (
        "staging_root",
        "output_root",
        "pwd",
        "staging_root_realpath",
        "output_root_realpath",
        "resolved_runtime_root",
    )
    roots = {
        field_name: Path(str(environment.get(field_name, "")))
        for field_name in root_fields
    }
    if any(not path.is_absolute() for path in roots.values()):
        context.fail("attempt environment roots are inconsistent")
        return
    staging_root = roots["staging_root"]
    output_root = roots["output_root"]
    try:
        staging_realpath = staging_root.resolve(strict=True)
        output_realpath = output_root.resolve(strict=True)
        pwd_realpath = roots["pwd"].resolve(strict=True)
    except OSError:
        context.fail("attempt environment roots are inconsistent")
        return
    if (
        staging_realpath != roots["staging_root_realpath"]
        or output_realpath != roots["output_root_realpath"]
        or pwd_realpath != staging_realpath
        or not staging_realpath.is_dir()
        or not output_realpath.is_dir()
    ):
        context.fail("attempt environment roots are inconsistent")
    inherited_roots = {
        context.source_roots[ref["source_id"]].resolve()
        for ref in input_manifest.get("inherited_runtime_refs", [])
        if isinstance(ref, dict)
        and ref.get("scope") == "external_repo"
        and ref.get("source_id") in context.source_roots
    }
    if inherited_roots and roots["resolved_runtime_root"].resolve() not in inherited_roots:
        context.fail("attempt environment roots are inconsistent")
    if staged != sorted(staged, key=lambda item: item.get("path", "")):
        context.fail("lane staged manifest mismatch")
    if environment.get("staged_manifest_digest") != digest(staged):
        context.fail("lane staged manifest mismatch")
    staged_allowed: dict[str, str] = {}
    for item in staged:
        if not isinstance(item, dict):
            continue
        raw_path = item.get("path")
        pure = PurePosixPath(str(raw_path))
        if (
            not isinstance(raw_path, str)
            or pure.is_absolute()
            or Path(raw_path).is_absolute()
            or ".." in pure.parts
        ):
            context.fail("staged manifest entry does not match real bytes")
            continue
        target = staging_realpath / raw_path
        try:
            resolved = target.resolve(strict=True)
            resolved.relative_to(staging_realpath)
            raw = resolved.read_bytes()
        except (OSError, ValueError):
            context.fail("staged manifest entry does not match real bytes")
            continue
        actual_sha = hashlib.sha256(raw).hexdigest()
        if actual_sha != item.get("sha256") or raw_path in staged_allowed:
            context.fail("staged manifest entry does not match real bytes")
            continue
        staged_allowed[raw_path] = actual_sha
    inherited_allowed: dict[str, str] = {}
    for ref in input_manifest.get("inherited_runtime_refs", []):
        if not isinstance(ref, dict):
            continue
        target = context.ref_target(ref)
        if target is not None:
            inherited_allowed[str(target[0].resolve())] = ref.get("sha256")
    for read in attempt.get("actual_read_declaration", []):
        if not isinstance(read, dict):
            context.fail("unauthorized executor read")
            continue
        path = read.get("path")
        sha = read.get("sha256")
        if path in staged_allowed and staged_allowed[path] == sha:
            continue
        if isinstance(path, str) and path in inherited_allowed and inherited_allowed[path] == sha:
            continue
        context.fail("unauthorized executor read")


def contains_forbidden_field(value: object) -> bool:
    if isinstance(value, dict):
        return bool(set(value) & CANONICAL_FORBIDDEN_FIELDS) or any(
            contains_forbidden_field(item) for item in value.values()
        )
    if isinstance(value, list):
        return any(contains_forbidden_field(item) for item in value)
    return False


def invoke_canonical_gates(
    context: ValidationContext,
    lane_id: str,
    canonical_refs: list[dict[str, Any]],
) -> None:
    feature = f"qft-qmi-pc-001-executor-{lane_id}"
    with tempfile.TemporaryDirectory(prefix="content-readiness-canonical-") as temp:
        workspace = Path(temp)
        feature_root = workspace / "docs" / feature
        phase_root = feature_root / "phase-1"
        phase_root.mkdir(parents=True)
        for ref in canonical_refs:
            target = context.ref_target(ref)
            if target is None:
                continue
            name = PurePosixPath(ref["path"]).name
            destination = phase_root / name if name == "phase-prd.json" else feature_root / name
            destination.write_bytes(target[1])
            try:
                payload = load_json(destination)
            except (ValueError, json.JSONDecodeError):
                payload = {}
            if contains_forbidden_field(payload):
                context.fail("canonical artifact contains evaluation metadata")
        ledger = feature_root / "product-director-ledger.json"
        brief = feature_root / "brief.json"
        phase = phase_root / "phase-prd.json"
        context.invoke(
            f"product-director-canonical-{lane_id}-ledger",
            [
                sys.executable,
                str(REPO_ROOT / "tools/community/validate_co_creation_ledger.py"),
                "--artifact",
                str(ledger),
                "--producer",
                "product-director",
                "--require-finalized",
            ],
            failure_message="product director ledger validator failed",
        )
        context.invoke(
            f"product-director-canonical-{lane_id}-content",
            [
                sys.executable,
                str(
                    REPO_ROOT
                    / "shared/skills/product-director/scripts/evaluate_content_quality.py"
                ),
                "--brief",
                str(brief),
                "--phase-prd",
                str(phase),
                "--ledger",
                str(ledger),
                "--min-score",
                "12",
            ],
            failure_message="product director content evaluator failed",
        )
        hook_input = json.dumps(
            {
                "cwd": str(workspace),
                "session_id": f"synthetic-{lane_id}",
                "transcript_path": "/dev/null",
                "tool_input": {"file_path": f"docs/{feature}/brief.json"},
            }
        )
        context.invoke(
            f"product-director-canonical-{lane_id}-completion",
            [
                "bash",
                str(
                    REPO_ROOT
                    / "shared/skills/product-director/scripts/completion_check.sh"
                ),
            ],
            input_text=hook_input,
            failure_message="product director completion hook failed",
        )


def inspect_canonical_outputs(
    context: ValidationContext,
    lane_id: str,
    canonical_refs: list[dict[str, Any]],
) -> None:
    for ref in canonical_refs:
        target = context.ref_target(ref)
        if target is None:
            continue
        try:
            payload = json.loads(target[1])
        except (TypeError, UnicodeDecodeError, json.JSONDecodeError):
            payload = {}
        if contains_forbidden_field(payload):
            context.fail("canonical artifact contains evaluation metadata")
    context.canonical_jobs.append((lane_id, canonical_refs))


def validate_audit_adapters(
    context: ValidationContext, role_root: str, verdict: dict[str, Any] | None
) -> None:
    alignment = context.run_root / role_root / "content-audit-alignment.json"
    report = context.run_root / role_root / "content-audit-report.json"
    formal_required = verdict is not None and verdict.get("verdict") in {
        "CONTENT_PASS",
        "CONTENT_FAIL",
        "BLOCKED_ISOLATION",
    }
    if alignment.exists() or formal_required:
        context.invoke(
            "skill-audit-alignment",
            [
                sys.executable,
                str(
                    REPO_ROOT
                    / "shared/skills/skill-quality-audit/scripts/validate_skill_audit_alignment.py"
                ),
                str(alignment),
            ],
            failure_message="skill audit alignment validator failed",
        )
    if report.exists() or formal_required:
        context.invoke(
            "skill-audit-report",
            [
                sys.executable,
                str(
                    REPO_ROOT
                    / "shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py"
                ),
                str(report),
            ],
            failure_message="skill audit report validator failed",
        )


def validate_attempts(
    context: ValidationContext,
    role: str,
    input_manifest: dict[str, Any],
    oracle: dict[str, Any],
    inherited_runtime_digest: str,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    lanes: list[dict[str, Any]] = []
    transcripts: list[dict[str, Any]] = []
    all_attempts: list[dict[str, Any]] = []
    staged_digests: list[str] = []
    starting_inputs: list[str] = []
    lane_ids = ("a", "b")
    for lane_id in lane_ids:
        lane_relative = f"roles/{role}/executor-{lane_id}/replay-lane.json"
        lane = context.load_artifact(lane_relative)
        if lane is None:
            continue
        lanes.append(lane)
        ordered = lane.get("ordered_attempt_refs", [])
        if len(ordered) > 3:
            context.fail("attempt limit exceeded")
        expected_paths: list[str] = []
        attempts: list[tuple[dict[str, Any], dict[str, Any]]] = []
        for index, ref in enumerate(ordered, start=1):
            if not isinstance(ref, dict):
                continue
            expected_path = f"roles/{role}/executor-{lane_id}/attempt-{index}/replay-attempt.json"
            expected_paths.append(expected_path)
            if ref_path(ref) != expected_path:
                context.fail("attempt history must be immutable and contiguous")
            attempt = context.load_artifact(ref_path(ref))
            if attempt is None:
                continue
            attempts.append((attempt, ref))
            all_attempts.append(attempt)
            if attempt.get("attempt_number") != index or attempt.get("lane_id") != lane_id:
                context.fail("attempt history must be immutable and contiguous")
            if (
                attempt.get("oracle_version") != input_manifest.get("oracle_version")
                or attempt.get("oracle_version") != oracle.get("oracle_version")
            ):
                context.fail("oracle version mismatch")
            starting_inputs.append(str(attempt.get("starting_input_sha256")))
            environment = attempt.get("environment", {})
            staged_digests.append(str(environment.get("staged_manifest_digest")))
            validate_actual_reads(context, attempt, input_manifest)
            transcript_relative = f"roles/{role}/executor-{lane_id}/attempt-{index}/transcript.json"
            transcript = context.load_artifact(transcript_relative)
            if transcript is not None:
                transcripts.append(transcript)
            manifest_relative = f"roles/{role}/executor-{lane_id}/attempt-{index}/artifact-manifest.json"
            manifest = context.load_artifact(manifest_relative)
            status = attempt.get("attempt_status")
            if status == "STOPPED":
                if (
                    not attempt.get("blocking_fact_refs")
                    or attempt.get("output_refs")
                    or not isinstance(manifest, dict)
                    or manifest.get("canonical_output_refs") != []
                ):
                    context.fail("stopped attempt requires blocking fact and empty outputs")
                canonical_root = (
                    context.run_root
                    / f"roles/{role}/executor-{lane_id}/attempt-{index}/canonical"
                )
                if canonical_root.exists() and any(canonical_root.rglob("*")):
                    context.fail("stopped attempt cannot retain canonical files")
            elif status == "INFRA_FAILURE":
                if (
                    attempt.get("output_refs")
                    or not isinstance(manifest, dict)
                    or manifest.get("canonical_output_refs") != []
                ):
                    context.fail("infrastructure failure cannot have outputs")
            elif status == "VOID_CONTAMINATED":
                if (
                    attempt.get("output_refs")
                    or not isinstance(manifest, dict)
                    or manifest.get("canonical_output_refs") != []
                ):
                    context.fail("contaminated attempt cannot have outputs")
            elif status == "COMPLETED" and isinstance(manifest, dict):
                outputs = manifest.get("canonical_output_refs", [])
                if not outputs:
                    context.fail("completed attempt requires canonical outputs")
                else:
                    inspect_canonical_outputs(context, lane_id, outputs)
        found_paths = sorted(
            str(path.relative_to(context.run_root))
            for path in (context.run_root / f"roles/{role}/executor-{lane_id}").glob(
                "attempt-*/replay-attempt.json"
            )
        )
        if sorted(expected_paths) != found_paths:
            context.fail("attempt history must be immutable and contiguous")
        decisive = lane.get("decisive_attempt_ref")
        if lane.get("terminal_condition") == "DECISIVE":
            if not isinstance(decisive, dict) or not any(
                ref_path(ref) == ref_path(decisive) for _, ref in attempts
            ):
                context.fail("attempt history must be immutable and contiguous")
            else:
                decisive_attempt = next(
                    attempt
                    for attempt, ref in attempts
                    if ref_path(ref) == ref_path(decisive)
                )
                if decisive_attempt.get("attempt_status") == "VOID_CONTAMINATED":
                    context.fail("contaminated attempt cannot be decisive")
                if decisive_attempt.get("attempt_status") == "INFRA_FAILURE":
                    context.fail("infrastructure failure cannot be decisive")
        else:
            if decisive is not None:
                context.fail("attempt history must be immutable and contiguous")
            statuses = [attempt.get("attempt_status") for attempt, _ in attempts]
            if lane.get("terminal_condition") == "ALL_CONTAMINATED":
                if not statuses or any(status != "VOID_CONTAMINATED" for status in statuses):
                    context.fail("terminal lane evidence mismatch")
            elif lane.get("terminal_condition") == "UNRECOVERABLE_INFRA_FAILURE":
                if not statuses or any(status != "INFRA_FAILURE" for status in statuses):
                    context.fail("terminal lane evidence mismatch")
    if len(set(starting_inputs)) > 1 or any(
        value != input_manifest.get("starting_input_sha256") for value in starting_inputs
    ):
        context.fail("lane starting input mismatch")
    if len(set(staged_digests)) > 1:
        context.fail("lane starting input mismatch")
    if input_manifest.get("inherited_runtime_digest") != inherited_runtime_digest:
        if inherited_runtime_digest:
            context.fail("lane starting input mismatch")
    validate_business_proxy(context, oracle, transcripts)
    return lanes, transcripts, all_attempts


def derive_effective_isolation(
    context: ValidationContext,
    run: dict[str, Any],
    surface: dict[str, Any],
    attempts: list[dict[str, Any]],
) -> str | None:
    levels: list[str] = []
    run_assessment = run.get("isolation_assessment")
    if isinstance(run_assessment, dict) and isinstance(run_assessment.get("level"), str):
        levels.append(run_assessment["level"])
    runtime = surface.get("runtime_inheritance")
    if isinstance(runtime, dict) and isinstance(runtime.get("evidence_level"), str):
        levels.append(runtime["evidence_level"])
    levels.extend(
        str(attempt["isolation_level"])
        for attempt in attempts
        if isinstance(attempt.get("isolation_level"), str)
    )
    rank = {"DECLARED_ONLY": 0, "OBSERVED": 1, "ENFORCED": 2}
    if not levels:
        return None
    if any(level not in rank for level in levels):
        context.fail("effective isolation evidence mismatch")
        return None
    effective = min(levels, key=rank.__getitem__)
    if isinstance(run_assessment, dict) and run_assessment.get("level") != effective:
        context.fail("effective isolation evidence mismatch")
    return effective


def validate_role_verdict(
    context: ValidationContext,
    role: str,
    verdict: dict[str, Any],
    content_digest: str | None,
    runtime_digest: str | None,
    lanes: list[dict[str, Any]],
    effective_isolation: str | None,
) -> None:
    value = verdict.get("verdict")
    for field_name in ("decisive_attempt_refs", "evidence_refs"):
        refs = verdict.get(field_name, [])
        identities = [
            canonical_ref_identity(ref) for ref in refs if isinstance(ref, dict)
        ]
        if len(identities) != len(set(identities)):
            context.fail("role verdict contains duplicate refs")
    if value == "CONTENT_PASS" and verdict.get("isolation_level") == "DECLARED_ONLY":
        context.fail("CONTENT_PASS requires ENFORCED or OBSERVED")
    if effective_isolation is not None and verdict.get("isolation_level") != effective_isolation:
        context.fail("effective isolation evidence mismatch")
    if value == "CONTENT_PASS" and effective_isolation not in {"ENFORCED", "OBSERVED"}:
        context.fail("effective isolation requires BLOCKED_ISOLATION")
    if value == "CONTENT_PASS" and verdict.get("oracle_bridge_used") is True:
        context.fail("authentic role pass cannot depend on oracle bridge")
    missing: list[str] = []
    for field_name, expected in (
        ("content_digest", content_digest),
        ("inherited_runtime_digest", runtime_digest),
    ):
        value_digest = verdict.get(field_name)
        if value_digest is None:
            missing.append(field_name)
        elif not isinstance(value_digest, str) or len(value_digest) != 64:
            context.fail("missing baseline digest is not legally blocked")
        elif expected is not None and value_digest != expected:
            context.fail("missing baseline digest is not legally blocked")
    unavailable = verdict.get("unavailable_baselines", [])
    unavailable_types = {
        item.get("baseline_type")
        for item in unavailable
        if isinstance(item, dict)
        and item.get("reason_code")
        and item.get("evidence_refs")
    }
    if missing and (
        value != "BLOCKED_EVIDENCE" or not set(missing) <= unavailable_types
    ):
        context.fail("missing baseline digest is not legally blocked")
    if not missing and unavailable:
        context.fail("missing baseline digest is not legally blocked")
    lane_decisive = {
        ref_path(lane["decisive_attempt_ref"])
        for lane in lanes
        if isinstance(lane.get("decisive_attempt_ref"), dict)
    }
    verdict_decisive = {
        ref_path(ref)
        for ref in verdict.get("decisive_attempt_refs", [])
        if isinstance(ref, dict)
    }
    if lanes and lane_decisive != verdict_decisive:
        context.fail("attempt history must be immutable and contiguous")
    for decisive_path in lane_decisive:
        decisive_attempt = context.artifacts.get(decisive_path)
        if (
            isinstance(decisive_attempt, dict)
            and effective_isolation is not None
            and decisive_attempt.get("isolation_level") != effective_isolation
        ):
            context.fail("effective isolation evidence mismatch")
    if value == "BLOCKED_ISOLATION" and verdict.get("isolation_level") != "DECLARED_ONLY":
        context.fail("BLOCKED_ISOLATION requires DECLARED_ONLY evidence")


def validate_chain_and_run_state(
    context: ValidationContext,
    run: dict[str, Any],
    role_verdicts: dict[str, dict[str, Any]],
) -> None:
    chain_path = context.run_root / "chain-verdict.json"
    chain = context.load_artifact("chain-verdict.json") if chain_path.exists() else None
    if chain is not None:
        if len(chain.get("role_verdict_refs", [])) != 6 or set(role_verdicts) != set(
            PRIMARY_ROLES
        ):
            context.fail("chain verdict requires all primary roles")
        if any(
            verdict.get("verdict") != "CONTENT_PASS"
            for verdict in role_verdicts.values()
        ):
            context.fail("chain verdict requires all primary roles")
        if chain.get("isolation_level") == "DECLARED_ONLY" or chain.get(
            "oracle_bridge_used"
        ):
            context.fail("chain verdict requires all primary roles")
    if run.get("global_state") == "CASE_REPLAY_PASS":
        valid = (
            chain is not None
            and set(role_verdicts) == set(PRIMARY_ROLES)
            and all(
                verdict.get("verdict") == "CONTENT_PASS"
                and verdict.get("isolation_level") in {"ENFORCED", "OBSERVED"}
                and verdict.get("oracle_bridge_used") is False
                for verdict in role_verdicts.values()
            )
            and chain.get("isolation_level") in {"ENFORCED", "OBSERVED"}
            and chain.get("oracle_bridge_used") is False
        )
        if not valid:
            context.fail(
                "CASE_REPLAY_PASS requires six CONTENT_PASS roles, chain verdict, ENFORCED/OBSERVED and no bridge"
            )


def validate_stage(
    context: ValidationContext,
    run: dict[str, Any],
    required_stage: str | None,
) -> str:
    current_stage = {
        "CASE_ADMISSION": "admitted",
        "STATIC_AUDIT": "static-audit",
        "DIAGNOSTIC_REPLAY": "diagnostic-replay",
        "ROLE_VERDICT": "role-verdict",
    }.get(str(run.get("current_stage")), "admitted")
    actual = (
        str(run.get("closure_validation_stage", "admitted"))
        if run.get("lifecycle_status") == "CLOSED"
        else current_stage
    )
    checked = required_stage or actual
    if checked == "terminal-run":
        if run.get("lifecycle_status") != "CLOSED" or run.get(
            "closure_validation_stage"
        ) != "terminal-run":
            context.fail("terminal-run requires a closed explicit terminal state")
        return checked
    if actual in STAGE_ORDER and checked in STAGE_ORDER:
        if STAGE_ORDER[actual] < STAGE_ORDER[checked]:
            context.fail(f"required stage not reached: {checked}")
    elif checked not in STAGE_ORDER:
        context.fail(f"unsupported required stage: {checked}")
    return checked


def present_role_artifacts(context: ValidationContext, role: str) -> set[str]:
    role_root = context.run_root / "roles" / role
    if not role_root.exists():
        return set()
    return {
        str(path.relative_to(context.run_root))
        for path in role_root.rglob("*")
        if path.is_file() and path.name in ROLE_REF_STAGE
    }


def indexed_role_artifacts(run: dict[str, Any], role: str) -> set[str]:
    refs = run.get("role_refs", {}).get(role, [])
    if not isinstance(refs, list):
        return set()
    return {
        ref_path(ref)
        for ref in refs
        if isinstance(ref, dict) and ref.get("scope") == "run"
    }


def lane_attempts(
    context: ValidationContext, lane: dict[str, Any]
) -> list[dict[str, Any]]:
    return [
        context.artifacts[path]
        for ref in lane.get("ordered_attempt_refs", [])
        if isinstance(ref, dict)
        and (path := ref_path(ref)) in context.artifacts
    ]


def lane_is_decisive(context: ValidationContext, lane: dict[str, Any]) -> bool:
    decisive = lane.get("decisive_attempt_ref")
    if lane.get("terminal_condition") != "DECISIVE" or not isinstance(decisive, dict):
        return False
    attempt = context.artifacts.get(ref_path(decisive))
    return isinstance(attempt, dict) and attempt.get("attempt_status") in {
        "COMPLETED",
        "STOPPED",
    }


def required_role_paths(
    context: ValidationContext,
    role: str,
    branch: str,
    current_stage: str,
) -> set[str]:
    prefix = f"roles/{role}/"
    static = {prefix + name for name in STATIC_ROLE_ARTIFACTS}
    reviews = {prefix + name for name in REVIEW_ROLE_ARTIFACTS}
    formal = {prefix + name for name in FORMAL_ROLE_ARTIFACTS}
    replay = {
        path
        for path in present_role_artifacts(context, role)
        if PurePosixPath(path).name in REPLAY_ROLE_FILENAMES
    }
    if branch == "OPEN":
        if current_stage == "CASE_ADMISSION":
            return set()
        if current_stage == "STATIC_AUDIT":
            return static
        if current_stage == "DIAGNOSTIC_REPLAY":
            return static | replay | reviews
        return static | replay | reviews | formal
    if branch == "A":
        return static | replay
    if branch == "B":
        verdict = {prefix + "role-verdict.json"}
        if current_stage == "CASE_ADMISSION":
            return verdict
        if current_stage == "STATIC_AUDIT":
            return static | verdict
        return static | replay | verdict
    if branch == "C":
        return static | formal
    return static | replay | reviews | formal


def validate_role_evidence_graph(
    context: ValidationContext,
    run: dict[str, Any],
    role: str,
    branch: str,
    lanes: list[dict[str, Any]],
    verdict: dict[str, Any] | None,
) -> None:
    expected = required_role_paths(
        context, role, branch, str(run.get("current_stage"))
    )
    present = present_role_artifacts(context, role)
    indexed = indexed_role_artifacts(run, role)
    raw_index = run.get("role_refs", {}).get(role, [])
    duplicate_index = isinstance(raw_index, list) and len(raw_index) != len(indexed)
    if present != expected or indexed != expected or duplicate_index:
        if branch == "OPEN":
            context.fail("OPEN stage artifact set mismatch")
        else:
            context.fail("run.role_refs does not match present stage artifacts")
    if not isinstance(verdict, dict):
        return
    evidence_paths = {
        ref_path(ref)
        for ref in verdict.get("evidence_refs", [])
        if isinstance(ref, dict)
    }
    prefix = f"roles/{role}/"
    required_evidence: set[str] = set()
    if branch == "C":
        required_evidence = {
            prefix + "surface.json",
            prefix + "decision-atoms.json",
            prefix + "content-audit-report.json",
        }
    elif branch == "D":
        required_evidence = {
            prefix + "content-audit-report.json",
            *(prefix + name for name in REVIEW_ROLE_ARTIFACTS),
        }
        required_evidence.update(
            ref_path(lane["decisive_attempt_ref"])
            for lane in lanes
            if isinstance(lane.get("decisive_attempt_ref"), dict)
        )
    elif branch == "B" and run.get("current_stage") == "DIAGNOSTIC_REPLAY":
        for lane in lanes:
            if lane_is_decisive(context, lane):
                continue
            required_evidence.add(
                f"{prefix}executor-{lane.get('lane_id')}/replay-lane.json"
            )
            attempts = lane_attempts(context, lane)
            if attempts:
                required_evidence.add(
                    f"{prefix}executor-{lane.get('lane_id')}/attempt-{attempts[-1].get('attempt_number')}/replay-attempt.json"
                )
    if not required_evidence <= evidence_paths:
        context.fail("role verdict evidence graph is incomplete")


def validate_branch_state(
    context: ValidationContext,
    run: dict[str, Any],
    role_lanes: dict[str, list[dict[str, Any]]],
    role_verdicts: dict[str, dict[str, Any]],
    role_isolation: dict[str, str | None],
) -> None:
    for role in run.get("evaluated_roles", []):
        if role not in PRIMARY_ROLES:
            continue
        lanes = role_lanes.get(role, [])
        verdict = role_verdicts.get(role)
        if run.get("lifecycle_status") == "OPEN":
            branch = "OPEN"
            if run.get("current_stage") == "DIAGNOSTIC_REPLAY" and (
                len(lanes) != 2
                or not all(lane_is_decisive(context, lane) for lane in lanes)
                or not all(
                    (context.run_root / f"roles/{role}/{name}").exists()
                    for name in REVIEW_ROLE_ARTIFACTS
                )
            ):
                context.fail(
                    "OPEN diagnostic requires two decisive lanes and three reviews"
                )
            validate_role_evidence_graph(
                context, run, role, branch, lanes, verdict
            )
            continue
        closure = run.get("closure_validation_stage")
        contaminated_lanes = [
            lane for lane in lanes if lane.get("terminal_condition") == "ALL_CONTAMINATED"
        ]
        if closure == "terminal-run" and contaminated_lanes:
            branch = "A"
            legal_contamination_history = any(
                len(attempts := lane_attempts(context, lane)) == 3
                and all(
                    attempt.get("attempt_status") == "VOID_CONTAMINATED"
                    for attempt in attempts
                )
                for lane in contaminated_lanes
            )
            complete_contamination_evidence = any(
                len(attempts := lane_attempts(context, lane)) == 3
                and all(
                    attempt.get("attempt_status") == "VOID_CONTAMINATED"
                    and bool(attempt.get("contamination_findings"))
                    for attempt in attempts
                )
                for lane in contaminated_lanes
            )
            if not legal_contamination_history:
                context.fail(
                    "Branch A requires exactly three contaminated attempts in one lane"
                )
            elif not complete_contamination_evidence:
                context.fail("Branch A contamination evidence is incomplete")
            if (
                verdict is not None
                or "primary_role_outcome" in run
                or run.get("global_state") != "INCONCLUSIVE_CONTAMINATED"
            ):
                context.fail("Branch A cannot contain a role verdict or outcome")
        elif closure == "terminal-run":
            branch = "B"
            outcome = run.get("primary_role_outcome", {}).get(role)
            effective = role_isolation.get(role)
            if (
                verdict is None
                and not lanes
                and run.get("current_stage") == "DIAGNOSTIC_REPLAY"
            ):
                context.fail("terminal-run requires explicit terminal evidence")
            if (
                not isinstance(verdict, dict)
                or verdict.get("verdict") not in {"BLOCKED_ORACLE", "BLOCKED_EVIDENCE"}
                or outcome != verdict.get("verdict")
            ):
                context.fail("Branch B requires blocked role verdict and primary outcome")
            if isinstance(verdict, dict):
                missing = {
                    field
                    for field in ("content_digest", "inherited_runtime_digest")
                    if field not in verdict
                }
                unavailable = {
                    item.get("baseline_type")
                    for item in verdict.get("unavailable_baselines", [])
                    if isinstance(item, dict)
                    and item.get("reason_code")
                    and item.get("evidence_refs")
                }
                if run.get("current_stage") == "CASE_ADMISSION":
                    if effective is None:
                        context.fail("Branch B admission requires derivable isolation")
                    unavailable_items = verdict.get("unavailable_baselines", [])
                    required_unavailable = {
                        "content_digest",
                        "inherited_runtime_digest",
                    }
                    admission_baselines_unavailable = (
                        verdict.get("verdict") == "BLOCKED_EVIDENCE"
                        and "content_digest" not in verdict
                        and "inherited_runtime_digest" not in verdict
                        and isinstance(unavailable_items, list)
                        and len(unavailable_items) == 2
                        and unavailable == required_unavailable
                    )
                    if not admission_baselines_unavailable:
                        context.fail(
                            "Branch B admission cannot claim unproven baseline digests"
                        )
                diagnostic_blockers_complete = True
                if run.get("current_stage") == "DIAGNOSTIC_REPLAY":
                    nondecisive_attempts = [
                        attempts[-1]
                        for lane in lanes
                        if not lane_is_decisive(context, lane)
                        and (attempts := lane_attempts(context, lane))
                    ]
                    diagnostic_blockers_complete = bool(nondecisive_attempts) and all(
                        attempt.get("blocking_fact_refs")
                        for attempt in nondecisive_attempts
                    )
                if (
                    not verdict.get("reason_codes")
                    or not verdict.get("evidence_refs")
                    or not missing <= unavailable
                    or not diagnostic_blockers_complete
                ):
                    context.fail("Branch B blocker evidence is incomplete")
        elif lanes:
            branch = "D"
            if (
                len(lanes) != 2
                or not all(lane_is_decisive(context, lane) for lane in lanes)
                or not all(
                    (context.run_root / f"roles/{role}/{name}").exists()
                    for name in REVIEW_ROLE_ARTIFACTS
                )
                or not (context.run_root / f"roles/{role}/content-audit-report.json").exists()
                or not isinstance(verdict, dict)
                or verdict.get("verdict")
                not in {
                    "CONTENT_FAIL",
                    "BLOCKED_ORACLE",
                    "BLOCKED_EVIDENCE",
                    "BLOCKED_ISOLATION",
                }
            ):
                context.fail("Branch D requires two decisive lanes and three reviews")
        else:
            branch = "C"
            report_path = (
                context.run_root / f"roles/{role}/content-audit-report.json"
            )
            blocking_findings = -1
            try:
                report = load_json(report_path)
                findings = report.get("findings")
                if isinstance(findings, list):
                    blocking_findings = sum(
                        1
                        for finding in findings
                        if isinstance(finding, dict)
                        and finding.get("severity") in {"P0", "P1"}
                    )
            except (OSError, ValueError, json.JSONDecodeError):
                context.fail("Branch C requires blocking P0/P1 evidence")
            if (
                not isinstance(verdict, dict)
                or verdict.get("verdict") != "CONTENT_FAIL"
                or not report_path.exists()
            ):
                context.fail("Branch C requires formal static CONTENT_FAIL evidence")
            elif (
                blocking_findings < 1
                or verdict.get("open_p0_p1") != blocking_findings
            ):
                context.fail("Branch C requires blocking P0/P1 evidence")
        effective = role_isolation.get(role)
        if branch != "A" and effective == "DECLARED_ONLY":
            if run.get("global_state") != "BLOCKED_ISOLATION":
                context.fail(
                    "DECLARED_ONLY run requires BLOCKED_ISOLATION global state"
                )
        validate_role_evidence_graph(context, run, role, branch, lanes, verdict)


def validate_role_ref_index(
    context: ValidationContext, run: dict[str, Any]
) -> None:
    current_level = {
        "CASE_ADMISSION": 0,
        "STATIC_AUDIT": 1,
        "DIAGNOSTIC_REPLAY": 2,
        "ROLE_VERDICT": 3,
    }.get(str(run.get("current_stage")), -1)
    role_refs = run.get("role_refs", {})
    if not isinstance(role_refs, dict):
        return
    for role, refs in role_refs.items():
        if role not in PRIMARY_ROLES or not isinstance(refs, list):
            context.fail("run.role_refs contains an unsupported role index")
            continue
        for ref in refs:
            if not isinstance(ref, dict):
                continue
            path = ref_path(ref)
            if ref.get("scope") != "run" or not path.startswith(f"roles/{role}/"):
                context.fail("run.role_refs contains an out-of-role artifact ref")
                continue
            required_level = ROLE_REF_STAGE.get(PurePosixPath(path).name)
            if required_level is None:
                context.fail("run.role_refs contains an unknown evaluation artifact")
                continue
            enforce_stage_ceiling = (
                run.get("lifecycle_status") == "OPEN"
                or run.get("closure_validation_stage") != "terminal-run"
            )
            if enforce_stage_ceiling and required_level > current_level:
                context.fail("run.role_refs contains a future artifact ref")
            if PurePosixPath(path).name not in {
                "content-audit-alignment.json",
                "content-audit-report.json",
            }:
                context.load_artifact(path)


def validate_run(
    run_root: Path,
    source_roots: dict[str, Path],
    required_role: str | None,
    required_stage: str | None,
    initial_failures: list[str],
) -> tuple[ValidationContext, str]:
    schema = load_json(SCHEMA_PATH)
    context = ValidationContext(run_root.resolve(), source_roots, schema)
    for failure in initial_failures:
        context.fail(failure)
    run = context.load_artifact("run.json")
    if run is None:
        return context, required_stage or "admitted"
    checked_stage = validate_stage(context, run, required_stage)
    context.validate_refs(run)
    validate_role_ref_index(context, run)
    if run.get("primary_roles") != PRIMARY_ROLES:
        context.fail("run primary_roles must contain the six roles in canonical order")
    if run.get("current_stage") != "CASE_ADMISSION" and "isolation_assessment" not in run:
        context.fail("static-audit and later stages require isolation assessment")
    if run.get("lifecycle_status") == "OPEN" and any(
        key in run
        for key in (
            "global_state",
            "primary_role_outcome",
            "next_authorized_action",
            "closure_validation_stage",
        )
    ):
        context.fail("open run cannot contain closure fields")
    if run.get("lifecycle_status") == "CLOSED":
        common_closure_fields = {
            "global_state",
            "next_authorized_action",
            "closure_validation_stage",
        }
        if not common_closure_fields <= set(run):
            context.fail("closed run requires closure fields")
        closure_stage = run.get("closure_validation_stage")
        if closure_stage == "role-verdict":
            if "primary_role_outcome" not in run or run.get("current_stage") != "ROLE_VERDICT":
                context.fail("role-verdict closure requires a proven role-verdict prefix")
        elif closure_stage == "terminal-run":
            if run.get("current_stage") not in {
                "CASE_ADMISSION",
                "STATIC_AUDIT",
                "DIAGNOSTIC_REPLAY",
            }:
                context.fail("terminal-run requires a proven branch prefix")
        else:
            context.fail("closed run has an unsupported closure track")

    expected_case_paths = {
        "confirmation": "case/confirmation-ref.json",
        "input": "case/input-manifest.json",
        "oracle": "case/oracle-manifest.json",
        "source_classification": "case/source-classification.json",
    }
    case_artifacts: dict[str, dict[str, Any]] = {}
    for key, expected in expected_case_paths.items():
        ref = run.get("case_refs", {}).get(key)
        if not isinstance(ref, dict) or ref_path(ref) != expected:
            context.fail("run.case_refs must point to the four canonical case artifacts")
            continue
        payload = context.load_artifact(expected)
        if payload is not None:
            case_artifacts[key] = payload
            context.validate_refs(payload)
            if payload.get("case_id") != run.get("case_id"):
                context.fail("case_id mismatch")
    confirmation = case_artifacts.get("confirmation")
    input_manifest = case_artifacts.get("input")
    oracle = case_artifacts.get("oracle")
    source_manifest = case_artifacts.get("source_classification")
    if confirmation is not None:
        validate_confirmation(context, confirmation)
    if source_manifest is not None:
        validate_source_denominators(context, source_manifest)

    role_verdicts: dict[str, dict[str, Any]] = {}
    role_lanes: dict[str, list[dict[str, Any]]] = {}
    role_isolation: dict[str, str | None] = {}
    audit_jobs: list[tuple[str, dict[str, Any] | None]] = []
    roles_to_check = list(run.get("evaluated_roles", []))
    if required_role is not None and required_role not in roles_to_check:
        context.fail(f"required role not evaluated: {required_role}")
        roles_to_check.append(required_role)
    for role in roles_to_check:
        if role not in PRIMARY_ROLES:
            context.fail(f"unsupported role: {role}")
            continue
        role_root = f"roles/{role}"
        surface_path = context.run_root / role_root / "surface.json"
        decision_path = context.run_root / role_root / "decision-atoms.json"
        surface = (
            context.load_artifact(f"{role_root}/surface.json")
            if surface_path.exists()
            else None
        )
        decision_atoms = (
            context.load_artifact(f"{role_root}/decision-atoms.json")
            if decision_path.exists()
            else None
        )
        for payload in (surface, decision_atoms):
            if payload is not None:
                context.validate_refs(payload)
        verdict_path = context.run_root / role_root / "role-verdict.json"
        verdict = (
            context.load_artifact(f"{role_root}/role-verdict.json")
            if verdict_path.exists()
            else None
        )
        if verdict is not None:
            context.validate_refs(verdict)
            role_verdicts[role] = verdict
            if verdict.get("verdict") in {
                "CONTENT_PASS",
                "CONTENT_FAIL",
                "BLOCKED_ISOLATION",
            } and not isinstance(verdict.get("audit_report_ref"), dict):
                context.fail("formal role verdict requires an audit report")
        audit_jobs.append((role_root, verdict))
        derived = (
            validate_runtime_and_derived(context, surface, oracle, input_manifest)
            if isinstance(surface, dict)
            and isinstance(input_manifest, dict)
            and isinstance(oracle, dict)
            else None
        )
        content_digest = derived[0] if derived else None
        runtime_digest = derived[1] if derived else None
        lanes: list[dict[str, Any]] = []
        attempts: list[dict[str, Any]] = []
        has_lanes = any(
            (
                context.run_root
                / f"{role_root}/executor-{lane_id}/replay-lane.json"
            ).exists()
            for lane_id in ("a", "b")
        )
        if (
            has_lanes
            and isinstance(input_manifest, dict)
            and isinstance(oracle, dict)
        ):
            lanes, _, attempts = validate_attempts(
                context, role, input_manifest, oracle, runtime_digest or ""
            )
        elif checked_stage == "diagnostic-replay":
            context.fail("diagnostic-replay requires two replay lanes")
        effective_isolation = derive_effective_isolation(
            context, run, surface if isinstance(surface, dict) else {}, attempts
        )
        role_isolation[role] = effective_isolation
        if verdict is not None:
            validate_role_verdict(
                context,
                role,
                verdict,
                content_digest,
                runtime_digest,
                lanes,
                effective_isolation,
            )
            if run.get("primary_role_outcome", {}).get(role) != verdict.get("verdict"):
                context.fail("run primary role outcome mismatch")
        role_lanes[role] = lanes
    if isinstance(input_manifest, dict) and isinstance(oracle, dict):
        if input_manifest.get("oracle_version") != oracle.get("oracle_version"):
            context.fail("oracle version mismatch")
    for artifact in context.artifacts.values():
        context.validate_refs(artifact)
    validate_loaded_artifact_identities(context, str(run.get("case_id", "")))
    validate_branch_state(
        context, run, role_lanes, role_verdicts, role_isolation
    )
    validate_chain_and_run_state(context, run, role_verdicts)
    if not context.failures:
        for role_root, verdict in audit_jobs:
            validate_audit_adapters(context, role_root, verdict)
            if context.failures:
                break
    if not context.failures:
        for lane_id, canonical_refs in context.canonical_jobs:
            invoke_canonical_gates(context, lane_id, canonical_refs)
            if context.failures:
                break
    return context, checked_stage


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        usage=(
            "validate_standard_chain_content_readiness.py RUN_ROOT "
            "[--require-role product-director] "
            "[--require-stage admitted|static-audit|diagnostic-replay|role-verdict|terminal-run] "
            "[--source-root source_id=/absolute/path]..."
        )
    )
    parser.add_argument("run_root", nargs="?")
    parser.add_argument("--require-role", choices=PRIMARY_ROLES)
    parser.add_argument(
        "--require-stage",
        choices=[
            "admitted",
            "static-audit",
            "diagnostic-replay",
            "role-verdict",
            "terminal-run",
        ],
    )
    parser.add_argument("--source-root", action="append", default=[])
    parser.add_argument("--emit-source-denominator", action="store_true")
    parser.add_argument("--source-id")
    parser.add_argument("--baseline")
    parser.add_argument("--result")
    return parser


def emit_result(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True))


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    source_roots, root_failures = parse_source_roots(args.source_root)
    if args.emit_source_denominator:
        failures = list(root_failures)
        source: dict[str, Any] | None = None
        if not args.source_id or not args.baseline or not args.result:
            failures.append(
                "--emit-source-denominator requires --source-id, --baseline and --result"
            )
        elif args.source_id not in source_roots:
            failures.append("missing external_repo source-root mapping")
        else:
            try:
                source = enumerate_source_denominator(
                    args.source_id,
                    source_roots[args.source_id],
                    args.baseline,
                    args.result,
                )
            except (OSError, subprocess.SubprocessError, ValueError) as exc:
                failures.append(f"source denominator enumeration failed: {exc}")
        payload: dict[str, Any] = {
            "status": "PASS" if not failures else "FAIL",
            "checked_stage": "source-denominator",
            "failures": failures,
        }
        if source is not None:
            payload["source"] = source
        emit_result(payload)
        return 0 if not failures else 1
    if not args.run_root:
        emit_result(
            {
                "status": "FAIL",
                "checked_stage": args.require_stage or "admitted",
                "failures": ["RUN_ROOT is required"],
                "invoked_validators": [],
            }
        )
        return 1
    run_root = Path(args.run_root)
    if not run_root.is_absolute():
        run_root = (Path.cwd() / run_root).resolve()
    try:
        context, checked_stage = validate_run(
            run_root,
            source_roots,
            args.require_role,
            args.require_stage,
            root_failures,
        )
    except Exception as exc:
        emit_result(
            {
                "status": "FAIL",
                "checked_stage": args.require_stage or "admitted",
                "failures": [f"validator infrastructure failure: {exc}"],
                "invoked_validators": [],
            }
        )
        return 1
    emit_result(
        {
            "status": "PASS" if not context.failures else "FAIL",
            "checked_stage": checked_stage,
            "failures": context.failures,
            "invoked_validators": context.invoked,
        }
    )
    return 0 if not context.failures else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

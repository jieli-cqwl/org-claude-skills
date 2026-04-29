#!/usr/bin/env python3
"""Builds and verifies the canonical standard-chain catalog from frozen registries.

This tool owns only the runtime catalog digest and artifact layout projection for
standard-chain/v1. It does not validate runtime artifacts or perform cutover.
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from runtime_yaml import load_yaml


ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = Path("shared/runtime/standard-chain-catalog.json")
EXPECTED_BUNDLE_KEYS = [
    "chain_version",
    "vocabulary_registry",
    "authority_registry",
    "stage_registry",
    "compatibility_matrix",
]


@dataclass(frozen=True)
class ArtifactSpec:
    """Captures the frozen metadata that the runtime catalog exposes per artifact."""

    artifact_type: str
    scope: str
    family: str
    schema_path: str
    template_path: str
    default_path: str
    producer: str


ARTIFACT_SPECS = [
    ArtifactSpec(
        artifact_type="brief",
        scope="feature",
        family="planning",
        schema_path="contracts/canonical/schemas/planning/brief.schema.json",
        template_path="contracts/canonical/templates/planning/brief.template.json",
        default_path="docs/{feature}/brief.json",
        producer="product",
    ),
    ArtifactSpec(
        artifact_type="phase-prd",
        scope="phase",
        family="planning",
        schema_path="contracts/canonical/schemas/planning/phase-prd.schema.json",
        template_path="contracts/canonical/templates/planning/phase-prd.template.json",
        default_path="docs/{feature}/phase-{N}/phase-prd.json",
        producer="product",
    ),
    ArtifactSpec(
        artifact_type="unit-definition",
        scope="unit",
        family="planning",
        schema_path="contracts/canonical/schemas/planning/unit-definition.schema.json",
        template_path="contracts/canonical/templates/planning/unit-definition.template.json",
        default_path="docs/{feature}/phase-{N}/units/UNIT-{N}.json",
        producer="product",
    ),
    ArtifactSpec(
        artifact_type="design",
        scope="phase",
        family="planning",
        schema_path="contracts/canonical/schemas/planning/design.schema.json",
        template_path="contracts/canonical/templates/planning/design.template.json",
        default_path="docs/{feature}/phase-{N}/design.json",
        producer="design",
    ),
    ArtifactSpec(
        artifact_type="test-cases",
        scope="unit",
        family="planning",
        schema_path="contracts/canonical/schemas/planning/test-cases.schema.json",
        template_path="contracts/canonical/templates/planning/test-cases.template.json",
        default_path="docs/{feature}/phase-{N}/unit-{N}/test-cases.json",
        producer="test-design",
    ),
    ArtifactSpec(
        artifact_type="plan",
        scope="phase",
        family="planning",
        schema_path="contracts/canonical/schemas/planning/plan.schema.json",
        template_path="contracts/canonical/templates/planning/plan.template.json",
        default_path="docs/{feature}/phase-{N}/plan.json",
        producer="tech-lead",
    ),
    ArtifactSpec(
        artifact_type="tasks",
        scope="phase",
        family="planning",
        schema_path="contracts/canonical/schemas/planning/tasks.schema.json",
        template_path="contracts/canonical/templates/planning/tasks.template.json",
        default_path="docs/{feature}/phase-{N}/tasks.json",
        producer="tech-lead",
    ),
    ArtifactSpec(
        artifact_type="developer-report",
        scope="unit-task",
        family="runtime",
        schema_path="shared/skills/developer/contracts/developer-report.schema.json",
        template_path="shared/skills/developer/templates/developer-report.template.json",
        default_path="docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json",
        producer="developer",
    ),
    ArtifactSpec(
        artifact_type="verify-result",
        scope="unit-task",
        family="runtime",
        schema_path="contracts/canonical/schemas/runtime/verify-result.schema.json",
        template_path="contracts/canonical/templates/runtime/verify-result.template.json",
        default_path="docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json",
        producer="verify",
    ),
    ArtifactSpec(
        artifact_type="code-review-result",
        scope="phase",
        family="runtime",
        schema_path="contracts/canonical/schemas/runtime/code-review-result.schema.json",
        template_path="contracts/canonical/templates/runtime/code-review-result.template.json",
        default_path="docs/{feature}/phase-{N}/code-review-result.json",
        producer="review",
    ),
    ArtifactSpec(
        artifact_type="qa-result",
        scope="phase",
        family="runtime",
        schema_path="contracts/canonical/schemas/runtime/qa-result.schema.json",
        template_path="contracts/canonical/templates/runtime/qa-result.template.json",
        default_path="docs/{feature}/phase-{N}/qa-result.json",
        producer="qa",
    ),
    ArtifactSpec(
        artifact_type="delivery-state",
        scope="phase",
        family="runtime",
        schema_path="contracts/canonical/schemas/runtime/delivery-state.schema.json",
        template_path="contracts/canonical/templates/runtime/delivery-state.template.json",
        default_path="docs/{feature}/phase-{N}/delivery-state.json",
        producer="delivery-owner",
    ),
    ArtifactSpec(
        artifact_type="consistency-audit-result",
        scope="phase",
        family="runtime",
        schema_path="contracts/canonical/schemas/runtime/consistency-audit-result.schema.json",
        template_path="contracts/canonical/templates/runtime/consistency-audit-result.template.json",
        default_path="docs/{feature}/phase-{N}/consistency-audit-result.json",
        producer="consistency-audit",
    ),
    ArtifactSpec(
        artifact_type="fix-result",
        scope="phase",
        family="runtime",
        schema_path="contracts/canonical/schemas/runtime/fix-result.schema.json",
        template_path="contracts/canonical/templates/runtime/fix-result.template.json",
        default_path="docs/{feature}/phase-{N}/fix-result.json",
        producer="fix",
    ),
    ArtifactSpec(
        artifact_type="signoff-package",
        scope="phase",
        family="runtime",
        schema_path="contracts/canonical/schemas/runtime/signoff-package.schema.json",
        template_path="contracts/canonical/templates/runtime/signoff-package.template.json",
        default_path="docs/{feature}/phase-{N}/signoff-package.json",
        producer="delivery-owner",
    ),
    ArtifactSpec(
        artifact_type="user-decision",
        scope="phase",
        family="runtime",
        schema_path="contracts/canonical/schemas/runtime/user-decision.schema.json",
        template_path="contracts/canonical/templates/runtime/user-decision.template.json",
        default_path="docs/{feature}/phase-{N}/user-decision.json",
        producer="user-decision-writer",
    ),
    ArtifactSpec(
        artifact_type="artifact-registry",
        scope="phase",
        family="runtime",
        schema_path="contracts/canonical/schemas/runtime/artifact-registry.schema.json",
        template_path="contracts/canonical/templates/runtime/artifact-registry.template.json",
        default_path="docs/{feature}/phase-{N}/artifact-registry.json",
        producer="delivery-owner",
    ),
    ArtifactSpec(
        artifact_type="projection-manifest",
        scope="phase-view",
        family="projection",
        schema_path="contracts/canonical/schemas/projection/projection-manifest.schema.json",
        template_path="contracts/canonical/templates/projection/projection-manifest.template.json",
        default_path="docs/{feature}/phase-{N}/views/phase-operational.projection-manifest.json",
        producer="materialize-canonical-html",
    ),
]


def load_registry_bundle(root: Path) -> dict[str, Any]:
    bundle_path = root / "contracts/canonical/registry-bundle.yaml"
    bundle = load_yaml(bundle_path)
    actual_keys = set(bundle)
    expected_keys = set(EXPECTED_BUNDLE_KEYS)
    if actual_keys != expected_keys:
        missing = sorted(expected_keys - actual_keys)
        unknown = sorted(actual_keys - expected_keys)
        raise ValueError(f"unexpected registry bundle keys: missing={missing} unknown={unknown}")
    return {
        "path": str(bundle_path.relative_to(root)),
        "bundle": bundle,
    }


def build_chain_registry_digest(root: Path, bundle_override: dict[str, Any] | None = None) -> str:
    bundle_payload = load_registry_bundle(root)
    bundle = bundle_override or bundle_payload["bundle"]
    registry_texts = {
        rel_path: (root / rel_path).read_text(encoding="utf-8")
        for rel_path in (
            bundle["vocabulary_registry"],
            bundle["authority_registry"],
            bundle["stage_registry"],
            bundle["compatibility_matrix"],
        )
    }
    normalized = {
        "bundle_path": bundle_payload["path"],
        "bundle": bundle,
        "registries": registry_texts,
    }
    joined = json.dumps(normalized, ensure_ascii=False, sort_keys=True)
    return "sha256:" + hashlib.sha256(joined.encode("utf-8")).hexdigest()


def ensure_foundation_files_exist(root: Path) -> None:
    for spec in ARTIFACT_SPECS:
        if not (root / spec.schema_path).is_file():
            raise FileNotFoundError(spec.schema_path)
        if not (root / spec.template_path).is_file():
            raise FileNotFoundError(spec.template_path)


def build_catalog(root: Path) -> dict[str, Any]:
    bundle_payload = load_registry_bundle(root)
    digest = build_chain_registry_digest(root)
    ensure_foundation_files_exist(root)
    return {
        "chain_version": bundle_payload["bundle"]["chain_version"],
        "chain_registry_digest": digest,
        "registry_bundle_path": bundle_payload["path"],
        "artifacts": {
            spec.artifact_type: {
                "artifact_type": spec.artifact_type,
                "family": spec.family,
                "scope": spec.scope,
                "producer": spec.producer,
                "schema_version": "1.0.0",
                "chain_version": bundle_payload["bundle"]["chain_version"],
                "chain_registry_digest": digest,
                "schema_path": spec.schema_path,
                "template_path": spec.template_path,
                "default_path": spec.default_path,
            }
            for spec in ARTIFACT_SPECS
        },
    }


def write_catalog(root: Path) -> None:
    catalog = build_catalog(root)
    target = root / CATALOG_PATH
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def check_catalog(root: Path) -> None:
    target = root / CATALOG_PATH
    if not target.is_file():
        raise FileNotFoundError(str(CATALOG_PATH))
    expected = build_catalog(root)
    actual = json.loads(target.read_text(encoding="utf-8"))
    if actual != expected:
        actual_text = json.dumps(actual, ensure_ascii=False, indent=2).splitlines()
        expected_text = json.dumps(expected, ensure_ascii=False, indent=2).splitlines()
        diff = "\n".join(
            difflib.unified_diff(
                actual_text,
                expected_text,
                fromfile=str(target),
                tofile="expected",
                lineterm="",
            )
        )
        raise SystemExit(diff or "standard chain catalog drift")


def run_bundle_drift_probe(root: Path, probe_target: str) -> None:
    expected = build_chain_registry_digest(root)
    with tempfile.TemporaryDirectory() as temp_dir:
        probe_root = Path(temp_dir) / "repo"
        shutil.copytree(root, probe_root)
        probe_path = probe_root / probe_target
        if not probe_path.is_file():
            raise FileNotFoundError(probe_target)
        bundle = load_yaml(probe_path)
        registry_path = probe_root / bundle["vocabulary_registry"]
        registry_path.write_text(
            registry_path.read_text(encoding="utf-8") + "\n# drift probe\n",
            encoding="utf-8",
        )
        probed = build_chain_registry_digest(probe_root)
    if probed == expected:
        raise SystemExit("bundle drift probe did not change the digest")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--bundle-drift-probe")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    root = args.root.resolve()
    if args.check:
        check_catalog(root)
        return
    if args.bundle_drift_probe:
        run_bundle_drift_probe(root, args.bundle_drift_probe)
        return
    write_catalog(root)


if __name__ == "__main__":
    main()

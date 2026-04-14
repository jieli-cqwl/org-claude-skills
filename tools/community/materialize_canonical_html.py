#!/usr/bin/env python3
"""Render deterministic HTML and projection-manifest from active canonical artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
from html import escape
from pathlib import Path

from manage_artifact_registry import get_active_revision, load_json as load_registry_json
from normalize_canonical_artifact import ROOT, load_json


def load_views(path: Path) -> dict:
    return load_json(path)


def infer_feature_phase(phase_dir: Path) -> tuple[str, str]:
    phase_name = phase_dir.name
    feature_name = phase_dir.parent.name
    if not phase_name.startswith("phase-"):
        raise ValueError(f"无法从目录推断 phase: {phase_dir}")
    return feature_name, phase_name.removeprefix("phase-")


def resolve_config_value(value: str, feature: str, phase_number: str) -> str:
    return value.replace("{feature}", feature).replace("{N}", phase_number)


def resolve_source_ref(ref: str, feature: str, phase_number: str) -> str:
    return resolve_config_value(ref, feature, phase_number)


def active_entry_index(registry: dict) -> dict[tuple[str, str], dict]:
    return {
        (entry["artifact_type"], entry["artifact_id"]): entry
        for entry in get_active_revision(registry).get("entries", [])
        if entry.get("active_for_consumption")
    }


def split_ref(ref: str) -> tuple[str, str, str, str]:
    scheme, target = ref.split("://", 1)
    artifact_target, anchor = target.split("#", 1)
    artifact_type, versioned_id = artifact_target.split("/", 1)
    artifact_id, version = versioned_id.rsplit("@", 1)
    if scheme != "artifact":
        raise ValueError(f"非法 ref scheme: {ref}")
    return artifact_type, artifact_id, version, anchor


def resolve_active_payload(ref: str, registry_index: dict[tuple[str, str], dict], phase_dir: Path) -> tuple[dict, str]:
    artifact_type, artifact_id, _version, anchor = split_ref(ref)
    entry = registry_index.get((artifact_type, artifact_id))
    if entry is None:
        raise FileNotFoundError(f"missing active entry for {ref}")
    payload = load_json(phase_dir / entry["artifact_path"])
    return payload, anchor


def extract_pointer(payload: dict, pointer: str) -> object:
    if pointer == "/":
        return payload
    value: object = payload
    for token in pointer.strip("/").split("/"):
        if token == "":
            continue
        if not isinstance(value, dict):
            raise ValueError(f"pointer hits non-object: {pointer}")
        value = value[token]
    return value


def has_pointer(payload: dict, pointer: str) -> bool:
    try:
        extract_pointer(payload, pointer)
    except (KeyError, ValueError):
        return False
    return True


def pointer_anchor(pointer: str) -> str:
    return pointer.strip("/").split("/")[-1].replace("_", "-")


def allowed_anchors(section_id: str, pointers: list[str]) -> set[str]:
    anchors = {section_id}
    anchors.update(pointer_anchor(pointer) for pointer in pointers if pointer != "/")
    return anchors


def render_section(section_id: str, values: list[dict]) -> str:
    content = json.dumps(values, ensure_ascii=False, indent=2)
    return (
        f"<section id=\"{escape(section_id, quote=True)}\">"
        f"<h2>{escape(section_id)}</h2>"
        f"<pre>{escape(content)}</pre>"
        "</section>"
    )


def build_projection_manifest(
    view_id: str,
    html_ref: str,
    content_digest: str,
    section_source_map: dict,
    generated_at: str,
    chain_version: str,
    chain_registry_digest: str,
    artifact_id: str,
) -> dict:
    return {
        "artifact_type": "projection-manifest",
        "artifact_id": artifact_id,
        "schema_version": "1.0.0",
        "producer": "materialize-canonical-html",
        "produced_at": generated_at,
        "chain_version": chain_version,
        "chain_registry_digest": chain_registry_digest,
        "authority_scope": "artifact",
        "authoritative_fields": [
            "$.source_artifact_refs",
            "$.section_source_map"
        ],
        "view_id": view_id,
        "source_artifact_refs": sorted(
            {
                ref
                for section in section_source_map.values()
                for ref in section["source_artifact_refs"]
            }
        ),
        "section_source_map": section_source_map,
        "generated_at": generated_at,
        "renderer_version": "1.0.0",
        "rendered_artifact_ref": html_ref,
        "rendered_content_digest": content_digest,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-dir", type=Path, required=True)
    parser.add_argument(
        "--views",
        type=Path,
        default=ROOT / "shared/runtime/projection-views.json",
    )
    parser.add_argument("--view-id", default="phase-operational")
    parser.add_argument("--generated-at", default="2026-04-14T04:00:00Z")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    phase_dir = args.phase_dir.resolve()
    feature, phase_number = infer_feature_phase(phase_dir)
    views = load_views(args.views.resolve())["views"]
    view = next(item for item in views if item["view_id"] == args.view_id)
    registry = load_registry_json(phase_dir / "artifact-registry.json")
    registry_index = active_entry_index(registry)
    catalog = load_json(ROOT / "shared/runtime/standard-chain-catalog.json")

    rendered_sections: list[str] = []
    section_source_map: dict[str, dict] = {}
    for section_id in view["required_sections"]:
        section = view["section_sources"][section_id]
        section_anchors = allowed_anchors(section_id, section["json_pointers"])
        resolved_refs = [
            resolve_source_ref(ref, feature, phase_number)
            for ref in section["source_artifact_refs"]
        ]
        values: list[dict] = []
        resolved_pointers: set[str] = set()
        for ref in resolved_refs:
            payload, anchor = resolve_active_payload(ref, registry_index, phase_dir)
            if anchor not in section_anchors:
                raise ValueError(
                    f"section {section_id} source anchor mismatch: {anchor}"
                )
            for pointer in section["json_pointers"]:
                if not has_pointer(payload, pointer):
                    continue
                values.append(
                    {
                        "source_ref": ref,
                        "json_pointer": pointer,
                        "value": extract_pointer(payload, pointer),
                    }
                )
                resolved_pointers.add(pointer)
        missing_pointers = [
            pointer
            for pointer in section["json_pointers"]
            if pointer not in resolved_pointers
        ]
        if missing_pointers:
            raise KeyError(
                f"section {section_id} missing required pointer(s): {', '.join(missing_pointers)}"
            )
        rendered_sections.append(render_section(section_id, values))
        section_source_map[section_id] = {
            "source_artifact_refs": resolved_refs,
            "json_pointers": section["json_pointers"],
        }

    html = "<html><body><main>" + "".join(rendered_sections) + "</main></body></html>\n"
    views_dir = phase_dir / "views"
    views_dir.mkdir(parents=True, exist_ok=True)
    html_path = views_dir / "phase-operational.html"
    html_path.write_text(html, encoding="utf-8")
    html_digest = "sha256:" + hashlib.sha256(html.encode("utf-8")).hexdigest()

    manifest_artifact_id = f"{feature}.phase-{phase_number}.phase-operational.projection-manifest"
    manifest = build_projection_manifest(
        view_id=args.view_id,
        html_ref=(
            f"artifact://projection-manifest/{manifest_artifact_id}"
            f"@v1#html-output:{args.view_id}.html"
        ),
        content_digest=html_digest,
        section_source_map=section_source_map,
        generated_at=args.generated_at,
        chain_version=catalog["chain_version"],
        chain_registry_digest=catalog["chain_registry_digest"],
        artifact_id=manifest_artifact_id,
    )
    manifest_path = views_dir / "phase-operational.projection-manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

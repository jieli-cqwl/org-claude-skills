#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, NoReturn

REQUIRED_CASE_FIELDS = {"id", "prompt", "files"}
OPTIONAL_CASE_FIELDS = {
    "expectations",
    "expected_anchors",
    "run_modes",
    "metadata",
    "tags",
}
TOP_LEVEL_OPTIONAL_FIELDS = {
    "skill_name",
    "evals",
    "preference_anchors",
    "grader_dimensions",
    "sample_matrix",
    "metadata",
    "eval_type",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate first-party skill eval files."
    )
    parser.add_argument(
        "--repo-root", type=Path, default=Path(__file__).resolve().parents[2]
    )
    return parser.parse_args()


def fail(path: Path, message: str) -> NoReturn:
    raise SystemExit(f"{path}: {message}")


def load_json(path: Path) -> dict[str, Any]:
    try:
        data: Any = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        fail(path, f"cannot read file: {exc}")
    except json.JSONDecodeError as exc:
        fail(path, f"invalid JSON: {exc}")
    if not isinstance(data, dict):
        fail(path, "top-level value must be an object")
    return data


def validate_string_list(path: Path, label: str, value: object) -> None:
    if not isinstance(value, list) or not all(
        isinstance(item, str) and item.strip() for item in value
    ):
        fail(path, f"{label} must be a non-empty string array")


def validate_file_refs(
    path: Path, repo_root: Path, skill_root: Path, case_id: object, refs: object
) -> None:
    if not isinstance(refs, list):
        fail(path, f"eval {case_id!r} files must be a list")
    for file_ref in refs:
        if not isinstance(file_ref, str) or not file_ref.strip():
            fail(path, f"eval {case_id!r} contains an empty file ref")
        ref_path = Path(file_ref)
        if ref_path.is_absolute():
            fail(path, f"eval {case_id!r} file ref must be relative: {file_ref}")
        candidates = [skill_root / ref_path, repo_root / ref_path]
        if not any(candidate.exists() for candidate in candidates):
            fail(path, f"eval {case_id!r} file ref does not exist: {file_ref}")


def validate_case(
    path: Path, repo_root: Path, skill_root: Path, case: object, index: int
) -> object:
    if not isinstance(case, dict):
        fail(path, f"eval #{index} must be an object")
    if "expected_output" in case:
        fail(path, f"eval #{index} must not define expected_output")
    missing = sorted(REQUIRED_CASE_FIELDS - set(case))
    if missing:
        fail(path, f"eval #{index} missing fields: {missing}")
    unknown = sorted(set(case) - REQUIRED_CASE_FIELDS - OPTIONAL_CASE_FIELDS)
    if unknown:
        fail(path, f"eval #{index} has unknown fields: {unknown}")

    case_id = case.get("id")
    if not isinstance(case_id, (int, str)) or (
        isinstance(case_id, str) and not case_id.strip()
    ):
        fail(path, f"eval #{index} must have a non-empty string or integer id")
    prompt = case.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        fail(path, f"eval {case_id!r} missing non-empty prompt")
    validate_file_refs(path, repo_root, skill_root, case_id, case.get("files"))

    for field in ("expectations", "expected_anchors", "run_modes", "tags"):
        if field in case:
            validate_string_list(path, f"eval {case_id!r} {field}", case[field])
    if "metadata" in case and not isinstance(case["metadata"], dict):
        fail(path, f"eval {case_id!r} metadata must be an object")
    return case_id


def validate_eval_file(repo_root: Path, path: Path) -> None:
    data = load_json(path)
    unknown_top = sorted(set(data) - TOP_LEVEL_OPTIONAL_FIELDS)
    if unknown_top:
        fail(path, f"unknown top-level fields: {unknown_top}")

    skill_root = path.parents[1]
    expected_skill_name = skill_root.name
    if data.get("skill_name") != expected_skill_name:
        fail(path, f"skill_name must be {expected_skill_name!r}")

    evals = data.get("evals")
    if not isinstance(evals, list) or not evals:
        fail(path, "evals must be a non-empty list")

    seen_ids: set[object] = set()
    for index, case in enumerate(evals, start=1):
        case_id = validate_case(path, repo_root, skill_root, case, index)
        if case_id in seen_ids:
            fail(path, f"duplicate eval id {case_id!r}")
        seen_ids.add(case_id)

    if "preference_anchors" in data:
        anchors = data["preference_anchors"]
        if not isinstance(anchors, list):
            fail(path, "preference_anchors must be a list")
        for index, anchor in enumerate(anchors, start=1):
            if not isinstance(anchor, dict):
                fail(path, f"preference anchor #{index} must be an object")
            anchor_id = anchor.get("id")
            anchor_text = anchor.get("anchor")
            if not isinstance(anchor_id, str) or not anchor_id.strip():
                fail(path, f"preference anchor #{index} missing non-empty id")
            if not isinstance(anchor_text, str) or not anchor_text.strip():
                fail(path, f"preference anchor {anchor_id!r} missing non-empty anchor")
    if "grader_dimensions" in data:
        validate_string_list(path, "grader_dimensions", data["grader_dimensions"])
    if "sample_matrix" in data:
        sample_matrix = data["sample_matrix"]
        if not isinstance(sample_matrix, list):
            fail(path, "sample_matrix must be a list")
        for index, sample in enumerate(sample_matrix, start=1):
            if not isinstance(sample, dict):
                fail(path, f"sample_matrix #{index} must be an object")
            sample_id = sample.get("id")
            if not isinstance(sample_id, str) or not sample_id.strip():
                fail(path, f"sample_matrix #{index} missing non-empty id")
    if "eval_type" in data and (
        not isinstance(data["eval_type"], str) or not data["eval_type"].strip()
    ):
        fail(path, "eval_type must be a non-empty string")
    if "metadata" in data and not isinstance(data["metadata"], dict):
        fail(path, "metadata must be an object")


def eval_paths(repo_root: Path) -> list[Path]:
    return sorted((repo_root / "shared" / "skills").glob("*/evals/evals.json"))


def main() -> int:
    repo_root = parse_args().repo_root.resolve()
    paths = eval_paths(repo_root)
    if not paths:
        raise SystemExit("no first-party skill eval files found")
    for path in paths:
        validate_eval_file(repo_root, path)
    print(f"validated {len(paths)} skill eval files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

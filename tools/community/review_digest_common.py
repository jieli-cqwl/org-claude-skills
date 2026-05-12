"""Canonical digest helpers for owner self-checked review payloads."""

from __future__ import annotations

import copy
import hashlib
import json
import re
from pathlib import Path


SHA256_DIGEST_RE = re.compile(r"^sha256:[0-9a-f]{64}$")


def is_sha256_digest(value: object) -> bool:
    return isinstance(value, str) and SHA256_DIGEST_RE.fullmatch(value) is not None


def strip_post_review_fields(payload: object, post_review_fields: set[str]) -> object:
    stripped = copy.deepcopy(payload)
    if isinstance(stripped, dict):
        for field in post_review_fields:
            stripped.pop(field, None)
    return stripped


def canonical_payload_digest(payload: object, post_review_fields: set[str]) -> str:
    reviewed_payload = strip_post_review_fields(payload, post_review_fields)
    raw = json.dumps(
        reviewed_payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def canonical_bundle_digest(
    feature_root: Path, reviewed_refs: list[str], post_review_fields: set[str]
) -> str:
    bundle = []
    for ref in reviewed_refs:
        path = _resolve_review_ref(feature_root, ref)
        payload = json.loads(path.read_text(encoding="utf-8"))
        bundle.append(
            {
                "ref": ref,
                "payload": strip_post_review_fields(payload, post_review_fields),
            }
        )
    raw = json.dumps(bundle, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _resolve_review_ref(feature_root: Path, ref: str) -> Path:
    if not isinstance(ref, str) or not ref.strip():
        raise ValueError("reviewed artifact ref must be a non-empty string")
    if ref.startswith("artifact://"):
        raise ValueError(
            "reviewed artifact refs must be concrete paths relative to the feature root, not artifact:// refs"
        )
    ref_path = Path(ref)
    if ref_path.is_absolute() or ".." in ref_path.parts:
        raise ValueError(f"unsafe reviewed artifact ref: {ref}")
    target = (feature_root / ref_path).resolve()
    if feature_root.resolve() not in target.parents:
        raise ValueError(f"reviewed artifact ref escapes feature root: {ref}")
    if not target.is_file():
        raise FileNotFoundError(f"reviewed artifact ref does not exist: {ref}")
    return target

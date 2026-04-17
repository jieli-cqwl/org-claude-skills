#!/usr/bin/env python3
"""Validate rendered Markdown/HTML provenance for a runtime artifact."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path
from typing import Any


def fail(message: str) -> None:
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def canonical_hash(artifact: dict[str, Any]) -> str:
    clone = dict(artifact)
    clone["rendered_views"] = []
    payload = json.dumps(clone, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(payload.encode("utf-8")).hexdigest()


def main(argv: list[str]) -> None:
    if len(argv) != 2:
        fail("usage: validate_rendered_views.py <artifact.json>")
    artifact = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    views = artifact.get("rendered_views")
    if not isinstance(views, list) or not views:
        fail("rendered_views must be a non-empty array")
    expected_hash = canonical_hash(artifact)
    for view in views:
        if not isinstance(view, dict):
            fail("rendered view entries must be objects")
        view_path = Path(str(view.get("view_path", "")))
        if not view_path.is_file():
            fail(f"rendered view file missing: {view_path}")
        if view.get("source_artifact_hash") != expected_hash:
            fail(f"rendered view hash mismatch: {view_path}")
        if not view.get("renderer_version") or not view.get("generated_at"):
            fail(f"rendered view missing provenance: {view_path}")
        if view.get("stale") is not False:
            fail(f"rendered view is stale: {view_path}")


if __name__ == "__main__":
    main(sys.argv)

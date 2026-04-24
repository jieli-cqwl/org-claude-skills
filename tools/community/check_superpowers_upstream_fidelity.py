#!/usr/bin/env python3
"""Verify Superpowers local content differs from upstream only by declared overlays."""

from __future__ import annotations

import argparse
import difflib
import tempfile
from dataclasses import dataclass
from pathlib import Path

try:
    import sync_canonical_from_upstream as sync  # type: ignore
    from superpowers_overlay_rules import (  # type: ignore
        SUPERPOWERS_FRONTMATTER_LINES,
        SUPERPOWERS_FULL_FILE_OVERLAYS,
        SUPERPOWERS_LOCAL_ONLY_FILES,
        SUPERPOWERS_OVERLAY_RULES,
        _extract_block,
        _extract_frontmatter_lines,
        _superpowers_local_path,
        capture_superpowers_local_overlays,
    )
except ModuleNotFoundError:
    from tools.community import sync_canonical_from_upstream as sync
    from tools.community.superpowers_overlay_rules import (
        SUPERPOWERS_FRONTMATTER_LINES,
        SUPERPOWERS_FULL_FILE_OVERLAYS,
        SUPERPOWERS_LOCAL_ONLY_FILES,
        SUPERPOWERS_OVERLAY_RULES,
        _extract_block,
        _extract_frontmatter_lines,
        _superpowers_local_path,
        capture_superpowers_local_overlays,
    )


ROOT = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class FidelityResult:
    """Outcome of comparing actual Superpowers content to declared projection."""

    ok: bool
    message: str


def _relative_files(root: Path) -> set[str]:
    return {
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
    }


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _content_diff(actual: Path, expected: Path, rel: str) -> str:
    actual_lines = _read_text(actual / rel).splitlines(keepends=True)
    expected_lines = _read_text(expected / rel).splitlines(keepends=True)
    diff = difflib.unified_diff(
        expected_lines,
        actual_lines,
        fromfile=f"expected/{rel}",
        tofile=f"actual/{rel}",
        n=3,
    )
    return "".join(list(diff)[:80])


def _compare_trees(actual: Path, expected: Path) -> list[str]:
    actual_files = _relative_files(actual)
    expected_files = _relative_files(expected)
    problems: list[str] = []

    for rel in sorted(expected_files - actual_files):
        problems.append(f"missing file: {rel}")
    for rel in sorted(actual_files - expected_files):
        problems.append(f"unexpected file: {rel}")
    for rel in sorted(actual_files & expected_files):
        if (actual / rel).read_bytes() == (expected / rel).read_bytes():
            continue
        problems.append(f"content mismatch: {rel}\n{_content_diff(actual, expected, rel)}")

    return problems


def _copy_declared_local_only_files(actual: Path, expected: Path) -> None:
    for rel in SUPERPOWERS_LOCAL_ONLY_FILES:
        source = actual / rel
        if not source.exists():
            continue
        target = expected / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source.read_bytes())


def _validate_declared_overlay_presence(community: Path) -> list[str]:
    problems: list[str] = []
    missing_targets: set[str] = set()

    for rel in SUPERPOWERS_FULL_FILE_OVERLAYS:
        if not _superpowers_local_path(community, rel).is_file():
            problems.append(f"missing declared full-file overlay: {rel}")

    for rel in SUPERPOWERS_LOCAL_ONLY_FILES:
        if not _superpowers_local_path(community, rel).is_file():
            problems.append(f"missing declared local-only file: {rel}")

    for rel, lines in SUPERPOWERS_FRONTMATTER_LINES.items():
        path = _superpowers_local_path(community, rel)
        if not path.is_file():
            if rel not in missing_targets:
                problems.append(f"missing declared overlay target: {rel}")
                missing_targets.add(rel)
            continue
        text = path.read_text(encoding="utf-8")
        present = set(_extract_frontmatter_lines(text, lines))
        for line in lines:
            if line not in present:
                problems.append(f"missing frontmatter line ({rel}): {line}")

    for rule in SUPERPOWERS_OVERLAY_RULES:
        path = _superpowers_local_path(community, rule.path)
        if not path.is_file():
            if rule.path not in missing_targets:
                problems.append(f"missing declared overlay target: {rule.path}")
                missing_targets.add(rule.path)
            continue
        try:
            _extract_block(
                path.read_text(encoding="utf-8"),
                rule.start,
                rule.end,
                label=f"{rule.path}:{rule.name}",
            )
        except RuntimeError as exc:
            problems.append(str(exc))

    return problems


def _preview_problems(problems: list[str]) -> str:
    preview = "\n\n".join(problems[:12])
    extra = "" if len(problems) <= 12 else f"\n\n... {len(problems) - 12} more issue(s)"
    return preview + extra


def _build_expected_tree(repo_root: Path, upstream_root: Path, expected_root: Path) -> Path:
    actual_community = repo_root / "community"
    expected_community = expected_root / "community"
    overlays = capture_superpowers_local_overlays(
        actual_community,
        repo_root,
        sync.run,
        require_all=True,
    )

    original_community = sync.COMMUNITY
    try:
        sync.COMMUNITY = expected_community
        sync.sync_superpowers(upstream_root, overlays=overlays)
    finally:
        sync.COMMUNITY = original_community

    expected_superpowers = expected_community / "superpowers"
    _copy_declared_local_only_files(actual_community / "superpowers", expected_superpowers)
    return expected_superpowers


def check_superpowers_fidelity(repo_root: Path, upstream_root: Path) -> FidelityResult:
    """Compare current Superpowers mirror against upstream plus declared overlays."""
    repo_root = repo_root.resolve()
    upstream_root = upstream_root.resolve()
    actual = repo_root / "community" / "superpowers"
    upstream = upstream_root / "superpowers"

    if not actual.exists():
        return FidelityResult(False, f"missing local Superpowers tree: {actual}")
    if not upstream.exists():
        return FidelityResult(False, f"missing upstream Superpowers tree: {upstream}")

    overlay_problems = _validate_declared_overlay_presence(repo_root / "community")
    if overlay_problems:
        return FidelityResult(False, _preview_problems(overlay_problems))

    with tempfile.TemporaryDirectory(prefix="superpowers-fidelity-") as td:
        try:
            expected = _build_expected_tree(repo_root, upstream_root, Path(td))
        except RuntimeError as exc:
            return FidelityResult(False, str(exc))
        problems = _compare_trees(actual, expected)

    if problems:
        return FidelityResult(False, _preview_problems(problems))
    return FidelityResult(True, "Superpowers upstream fidelity valid")


def _clone_upstream_from_lock() -> tuple[tempfile.TemporaryDirectory[str], Path]:
    td = tempfile.TemporaryDirectory(prefix="superpowers-upstream-")
    sync.clone_superpowers_from_lock(Path(td.name))
    return td, Path(td.name)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify Superpowers local content against locked upstream plus declared overlays."
    )
    parser.add_argument("--repo-root", type=Path, default=ROOT)
    parser.add_argument(
        "--upstream-root",
        type=Path,
        default=None,
        help="Parent directory containing a superpowers checkout. Defaults to cloning the locked ref.",
    )
    args = parser.parse_args()

    upstream_tmp: tempfile.TemporaryDirectory[str] | None = None
    upstream_root = args.upstream_root
    if upstream_root is None:
        upstream_tmp, upstream_root = _clone_upstream_from_lock()

    try:
        result = check_superpowers_fidelity(args.repo_root, upstream_root)
    finally:
        if upstream_tmp is not None:
            upstream_tmp.cleanup()

    if result.ok:
        print(f"[PASS] {result.message}")
        return 0
    print(f"[FAIL] {result.message}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

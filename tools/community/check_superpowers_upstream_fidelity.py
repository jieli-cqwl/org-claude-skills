#!/usr/bin/env python3
"""Verify the local Superpowers mirror is a pure copy of the locked upstream skills."""

from __future__ import annotations

import argparse
import difflib
import tempfile
from dataclasses import dataclass
from pathlib import Path

try:
    import sync_canonical_from_upstream as sync  # type: ignore
except ModuleNotFoundError:
    from tools.community import sync_canonical_from_upstream as sync


ROOT = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class FidelityResult:
    ok: bool
    message: str


def _relative_files(root: Path) -> set[str]:
    return {
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
    }


def _content_diff(actual: Path, expected: Path, rel: str) -> str:
    actual_lines = (actual / rel).read_text(encoding="utf-8").splitlines(keepends=True)
    expected_lines = (expected / rel).read_text(encoding="utf-8").splitlines(keepends=True)
    diff = difflib.unified_diff(
        expected_lines,
        actual_lines,
        fromfile=f"expected/{rel}",
        tofile=f"actual/{rel}",
        n=3,
    )
    return "".join(list(diff)[:80])


def _preview_problems(problems: list[str]) -> str:
    preview = "\n\n".join(problems[:12])
    extra = "" if len(problems) <= 12 else f"\n\n... {len(problems) - 12} more issue(s)"
    return preview + extra


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


def _validate_tree_shape(actual_root: Path) -> list[str]:
    problems: list[str] = []
    if not actual_root.exists():
        return [f"missing local Superpowers tree: {actual_root}"]

    root_entries = sorted(path.name for path in actual_root.iterdir())
    if root_entries != ["skills"]:
        problems.append(f"community/superpowers must contain only skills/ (actual={root_entries})")

    skills_root = actual_root / "skills"
    if not skills_root.is_dir():
        problems.append("community/superpowers/skills is missing")
        return problems

    skill_names = sorted(path.name for path in skills_root.iterdir() if path.is_dir())
    expected = sorted(sync.OFFICIAL_SUPERPOWERS_SKILLS)
    if skill_names != expected:
        missing = sorted(set(expected) - set(skill_names))
        extra = sorted(set(skill_names) - set(expected))
        problems.append(f"official Superpowers skill set mismatch (missing={missing}, extra={extra})")

    return problems


def check_superpowers_fidelity(repo_root: Path, upstream_checkout: Path) -> FidelityResult:
    repo_root = repo_root.resolve()
    upstream_checkout = upstream_checkout.resolve()
    actual_root = repo_root / "community" / "superpowers"
    actual = actual_root / "skills"
    expected = upstream_checkout / "skills"

    if not expected.exists():
        return FidelityResult(False, f"missing upstream Superpowers skills tree: {expected}")

    shape_problems = _validate_tree_shape(actual_root)
    if shape_problems:
        return FidelityResult(False, _preview_problems(shape_problems))

    try:
        sync._validate_official_skill_set(expected)
    except RuntimeError as exc:
        return FidelityResult(False, str(exc))

    problems = _compare_trees(actual, expected)
    if problems:
        return FidelityResult(False, _preview_problems(problems))
    return FidelityResult(True, "Superpowers official skills mirror is byte-for-byte clean")


def _clone_upstream_from_lock() -> tuple[tempfile.TemporaryDirectory[str], Path]:
    td = tempfile.TemporaryDirectory(prefix="superpowers-upstream-")
    checkout, _ = sync.clone_superpowers_from_lock(Path(td.name))
    return td, checkout


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify Superpowers local content against the locked upstream skills tree."
    )
    parser.add_argument("--repo-root", type=Path, default=ROOT)
    parser.add_argument(
        "--upstream-root",
        type=Path,
        default=None,
        help="Superpowers checkout directory. Defaults to cloning the locked ref.",
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

#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


SUPPORTED_SUFFIXES = {".md", ".sh", ".json", ".toml", ".yaml"}


def iter_supported_files(root: Path) -> list[Path]:
    return sorted(
        path
        for path in root.rglob("*")
        if path.is_file() and not path.is_symlink() and path.suffix in SUPPORTED_SUFFIXES
    )


def render_text(text: str, runtime_home: str, entry_doc: str, skills_home: str) -> str:
    return (
        text.replace("{{RUNTIME_HOME}}", runtime_home)
        .replace("{{ENTRY_DOC}}", entry_doc)
        .replace("{{SKILLS_HOME}}", skills_home)
    )


def render_file(path: Path, runtime_home: str, entry_doc: str, skills_home: str) -> bool:
    original = path.read_text(encoding="utf-8")
    rendered = render_text(original, runtime_home, entry_doc, skills_home)
    if rendered == original:
        return False
    path.write_text(rendered, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Render runtime placeholders in a staging tree.")
    parser.add_argument("tree")
    parser.add_argument("runtime_home")
    parser.add_argument("entry_doc")
    parser.add_argument("skills_home")
    args = parser.parse_args()

    root = Path(args.tree)
    if not root.is_dir():
        raise SystemExit(f"staging tree does not exist: {root}")

    changed = 0
    for path in iter_supported_files(root):
        try:
            if render_file(path, args.runtime_home, args.entry_doc, args.skills_home):
                changed += 1
        except UnicodeDecodeError as exc:
            raise SystemExit(f"unsupported non-UTF-8 runtime text file: {path}") from exc
    print(f"rendered_placeholders={changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

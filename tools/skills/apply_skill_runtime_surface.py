#!/usr/bin/env python3
"""Apply the skill runtime surface contract to a staged skill directory."""

from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path


VALID_RUNTIMES = {"claude", "codex"}
VALID_MODES = {"auto", "manual", "off"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--skills-dir", required=True, type=Path)
    parser.add_argument("--runtime", required=True, choices=sorted(VALID_RUNTIMES))
    parser.add_argument("--audit-json", type=Path)
    return parser.parse_args()


def load_contract(path: Path) -> dict:
    contract = json.loads(path.read_text(encoding="utf-8"))
    skills = contract.get("skills")
    if not isinstance(skills, dict) or not skills:
        raise SystemExit(f"{path}: skills must be a non-empty object")
    for name, entry in skills.items():
        mode = entry.get("mode")
        if mode not in VALID_MODES:
            raise SystemExit(f"{path}: {name}.mode must be one of {sorted(VALID_MODES)}")
        if not str(entry.get("owner", "")).strip() or not str(entry.get("reason", "")).strip():
            raise SystemExit(f"{path}: {name} requires owner and reason")
    return contract


def split_frontmatter(text: str, path: Path) -> tuple[list[str], str]:
    if not text.startswith("---\n"):
        raise SystemExit(f"{path}: missing YAML frontmatter")
    parts = text.split("---\n", 2)
    if len(parts) != 3:
        raise SystemExit(f"{path}: invalid YAML frontmatter")
    return parts[1].splitlines(), parts[2].lstrip("\n")


def key_index(lines: list[str], key: str) -> int | None:
    for idx, line in enumerate(lines):
        if line.startswith(f"{key}:"):
            return idx
    return None


def scalar_value(lines: list[str], key: str) -> str:
    idx = key_index(lines, key)
    if idx is None:
        return ""
    return lines[idx].split(":", 1)[1].strip().strip("'\"")


def description_value(lines: list[str]) -> str:
    idx = key_index(lines, "description")
    if idx is None:
        return ""
    value = lines[idx].split(":", 1)[1].strip()
    if value in {"|", ">"}:
        block: list[str] = []
        for line in lines[idx + 1 :]:
            if line.startswith((" ", "\t")) or not line.strip():
                block.append(line.strip())
                continue
            break
        return " ".join(block).strip()
    return value.strip("'\"")


def set_scalar(lines: list[str], key: str, value: str, after_key: str | None = None) -> list[str]:
    idx = key_index(lines, key)
    rendered = f"{key}: {json.dumps(value, ensure_ascii=False)}"
    if value in {"true", "false"}:
        rendered = f"{key}: {value}"
    if idx is not None:
        lines[idx] = rendered
        return lines
    insert_at = len(lines)
    if after_key:
        after_idx = key_index(lines, after_key)
        if after_idx is not None:
            insert_at = after_idx + 1
    lines.insert(insert_at, rendered)
    return lines


def remove_scalar(lines: list[str], key: str) -> list[str]:
    idx = key_index(lines, key)
    if idx is None:
        return lines
    return lines[:idx] + lines[idx + 1 :]


def replace_description(lines: list[str], description: str) -> list[str]:
    idx = key_index(lines, "description")
    if idx is None:
        return lines
    rendered = f"description: {json.dumps(description, ensure_ascii=False)}"
    new_lines = lines[:idx] + [rendered]
    next_idx = idx + 1
    current_value = lines[idx].split(":", 1)[1].strip()
    if current_value in {"|", ">"}:
        while next_idx < len(lines):
            line = lines[next_idx]
            if line.startswith((" ", "\t")) or not line.strip():
                next_idx += 1
                continue
            break
    new_lines.extend(lines[next_idx:])
    return new_lines


def compact_description(name: str, mode: str, original: str, entry: dict, max_chars: int) -> str:
    if mode == "manual":
        if entry.get("owner") == "first-party":
            return original
        return f"Manual-only. Invoke as ${name}."
    candidate = str(entry.get("description") or original).strip()
    if len(candidate) <= max_chars:
        return candidate
    normalized = re.sub(r"\s+", " ", candidate).strip()
    match = re.search(r"[。.!?]", normalized)
    if match:
        candidate = normalized[: match.end()].strip()
    if len(candidate) <= max_chars:
        return candidate
    return f"Use when the user request matches ${name}; read SKILL.md for the workflow."


def apply_frontmatter(skill_file: Path, name: str, mode: str, entry: dict, max_chars: int) -> None:
    text = skill_file.read_text(encoding="utf-8")
    lines, body = split_frontmatter(text, skill_file)
    original_description = re.sub(r"\s+", " ", description_value(lines)).strip()
    if original_description:
        lines = replace_description(lines, compact_description(name, mode, original_description, entry, max_chars))
    if mode == "manual":
        lines = set_scalar(lines, "user-invocable", "true", after_key="name")
        lines = set_scalar(lines, "disable-model-invocation", "true", after_key="user-invocable")
    elif mode == "auto":
        lines = remove_scalar(lines, "disable-model-invocation")
    updated = "---\n" + "\n".join(lines).rstrip() + "\n---\n\n" + body
    if updated != text:
        skill_file.write_text(updated, encoding="utf-8")


def ensure_codex_manual_policy(skill_dir: Path) -> None:
    agents_dir = skill_dir / "agents"
    agents_dir.mkdir(exist_ok=True)
    policy_file = agents_dir / "openai.yaml"
    if not policy_file.exists():
        policy_file.write_text("policy:\n  allow_implicit_invocation: false\n", encoding="utf-8")
        return

    lines = policy_file.read_text(encoding="utf-8").splitlines()
    for idx, line in enumerate(lines):
        if line.strip().startswith("allow_implicit_invocation:"):
            indent = line[: len(line) - len(line.lstrip())]
            lines[idx] = f"{indent}allow_implicit_invocation: false"
            policy_file.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
            return
    lines.extend(["", "policy:", "  allow_implicit_invocation: false"])
    policy_file.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def apply_codex_policy(skill_dir: Path, mode: str) -> None:
    if mode == "manual":
        ensure_codex_manual_policy(skill_dir)


def skill_name_from_file(skill_file: Path) -> str:
    lines, _ = split_frontmatter(skill_file.read_text(encoding="utf-8"), skill_file)
    return scalar_value(lines, "name") or skill_file.parent.name


def apply_surface(contract: dict, skills_dir: Path, runtime: str) -> dict:
    max_chars = int(contract.get("limits", {}).get("max_description_chars", 220))
    contract_skills = contract["skills"]
    audit = {
        "runtime": runtime,
        "auto_count": 0,
        "manual_count": 0,
        "off_count": 0,
        "unknown": [],
        "applied": [],
    }

    for skill_file in sorted(skills_dir.glob("*/SKILL.md")):
        name = skill_name_from_file(skill_file)
        dir_name = skill_file.parent.name
        entry = contract_skills.get(name) or contract_skills.get(dir_name)
        if entry is None:
            audit["unknown"].append(name)
            continue
        mode = entry["mode"]
        skill_dir = skill_file.parent
        if entry.get("owner") == "superpowers" and mode != "auto":
            raise SystemExit(f"{name}: Superpowers mirror skills must remain auto and unmodified")
        if mode == "off":
            audit["off_count"] += 1
            shutil.rmtree(skill_dir)
            audit["applied"].append({"name": name, "mode": mode})
            continue
        if entry.get("owner") != "superpowers":
            apply_frontmatter(skill_file, name, mode, entry, max_chars)
        if runtime == "codex" and entry.get("owner") != "superpowers":
            apply_codex_policy(skill_dir, mode)
        if mode == "auto":
            audit["auto_count"] += 1
        elif mode == "manual":
            audit["manual_count"] += 1
        audit["applied"].append({"name": name, "mode": mode})

    if audit["unknown"]:
        unknown = ", ".join(sorted(audit["unknown"]))
        raise SystemExit(f"skills missing from runtime surface contract: {unknown}")

    auto_limit = int(contract.get("limits", {}).get("max_auto_invoked_skills", 25))
    if audit["auto_count"] > auto_limit:
        raise SystemExit(f"auto skill count exceeds limit: {audit['auto_count']} > {auto_limit}")
    return audit


def main() -> None:
    args = parse_args()
    contract = load_contract(args.contract)
    audit = apply_surface(contract, args.skills_dir, args.runtime)
    if args.audit_json:
        args.audit_json.parent.mkdir(parents=True, exist_ok=True)
        args.audit_json.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

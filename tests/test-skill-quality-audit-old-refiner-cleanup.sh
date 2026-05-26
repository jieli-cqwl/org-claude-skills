#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ ! -e "$ROOT/shared/skills/skill-refiner" ] \
  || fail "active shared/skills/skill-refiner must be removed"
[ ! -e "$ROOT/tests/fixtures/skill-auditor" ] \
  || fail "retired tests/fixtures/skill-auditor must be removed or migrated"
[ ! -e "$ROOT/skill-refiner-result.json" ] \
  || fail "root skill-refiner-result.json must be removed"
[ ! -e "$ROOT/refinement-ledger.json" ] \
  || fail "root refinement-ledger.json must be removed"

ACTIVE_PATHS=(
  "$ROOT/README.md"
  "$ROOT/contracts"
  "$ROOT/install.sh"
  "$ROOT/tests"
  "$ROOT/shared/hooks"
  "$ROOT/shared/skills"
  "$ROOT/tools/community"
  "$ROOT/tools/eval/results"
  "$ROOT/tools/skill_quality"
  "$ROOT/docs/reports"
)

python3 - "$ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
active_paths = [
    root / "README.md",
    root / "contracts",
    root / "install.sh",
    root / "tests",
    root / "shared" / "hooks",
    root / "shared" / "skills",
    root / "tools" / "community",
    root / "tools" / "eval" / "results",
    root / "tools" / "skill_quality",
    root / "docs" / "reports",
]
excluded_prefixes = [
    root / "tests" / "fixtures" / "skill-quality-audit",
    root / "shared" / "skills" / "skill-quality-audit" / "evals" / "fixtures",
    root / "docs" / "archive",
]
excluded_files = {
    root / "tests" / "test-skill-quality-audit-report-contract.sh",
    root / "tests" / "test-skill-quality-audit-runtime-contract.sh",
    root / "tests" / "test-skill-quality-audit-old-refiner-cleanup.sh",
    root / "tests" / "test-skill-quality-audit-instruction-contract.sh",
}
needles = [
    "skill-refiner",
    "skill-refiner-result",
    "refinement-ledger",
    "validate_refinement_result",
    "skill-harness",
]
text_suffixes = {".json", ".md", ".py", ".sh", ".yaml", ".yml", ".toml"}


def is_excluded(path: Path) -> bool:
    if path in excluded_files:
        return True
    return any(path == prefix or prefix in path.parents for prefix in excluded_prefixes)


def is_allowed_retirement_reference(path: Path, line: str) -> bool:
    if path == root / "install.sh":
        return "skill-refiner" in line and (
            "skill_refiner_retired" in line
            or "skills/skill-refiner" in line
            or "codex_skills_dir/skill-refiner" in line
            or "skill-refiner 不应存在" in line
        )
    if path == root / "tests" / "test-install-retired-skill-cleanup.sh":
        return "skill-refiner" in line
    return False


def iter_files(path: Path):
    if not path.exists():
        return
    if path.is_file():
        if path.suffix in text_suffixes and not is_excluded(path):
            yield path
        return
    for candidate in path.rglob("*"):
        if candidate.is_file() and candidate.suffix in text_suffixes and not is_excluded(candidate):
            yield candidate

violations = []
seen = set()
for active_path in active_paths:
    for path in iter_files(active_path):
        if path in seen:
            continue
        seen.add(path)
        text = path.read_text(encoding="utf-8")
        for line_number, line in enumerate(text.splitlines(), start=1):
            if is_allowed_retirement_reference(path, line):
                continue
            if any(needle in line for needle in needles):
                violations.append(f"{path}:{line_number}:{line}")

if violations:
    print("\n".join(violations))
    raise SystemExit("active references to retired skill-refiner remain")
PY

printf '[PASS] skill-quality-audit old refiner cleanup\n'

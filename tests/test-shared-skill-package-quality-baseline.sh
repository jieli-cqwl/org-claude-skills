#!/usr/bin/env bash
# File role: prove every real shared Skill package stays at the package quality baseline.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$ROOT/tools/skill_quality/check_skill_package_quality.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$CHECKER" ] || fail "missing package quality checker"

python3 - "$ROOT" "$CHECKER" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
checker = Path(sys.argv[2])
skills_dir = root / "shared" / "skills"
results = []
failures = []

warn_count = 0
for skill_dir in sorted(path for path in skills_dir.iterdir() if (path / "SKILL.md").is_file()):
    proc = subprocess.run(
        ["python3", str(checker), str(skill_dir)],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    if not proc.stdout.strip():
        failures.append((skill_dir.name, "NO_OUTPUT", proc.stderr.strip()))
        continue
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        failures.append((skill_dir.name, "INVALID_JSON", f"{exc}: {proc.stdout[:200]}"))
        continue
    results.append(data)
    status = data.get("status")
    if proc.returncode != 0 or status == "static_fail":
        codes = ",".join(finding.get("code", "UNKNOWN") for finding in data.get("findings", []))
        failures.append((skill_dir.name, status or "UNKNOWN", codes))
    elif status == "static_warn":
        warn_count += 1

if failures:
    for name, status, detail in failures:
        print(f"[FAIL] {name}: {status} {detail}", file=sys.stderr)
    raise SystemExit(1)

if not results:
    print("[FAIL] no shared Skill packages found", file=sys.stderr)
    raise SystemExit(1)

print(f"[PASS] shared Skill package quality baseline ({len(results)} skills, {warn_count} static_warn reported)")
PY

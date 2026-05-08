#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

python3 "$ROOT/tools/community/check_superpowers_upstream_fidelity.py" >/dev/null || fail "current Superpowers mirror should match locked upstream"

python3 - <<'PY' >/dev/null || fail "fidelity checker should reject local Superpowers noise"
import tempfile
from pathlib import Path

from tools.community import check_superpowers_upstream_fidelity as fidelity
from tools.community import sync_canonical_from_upstream as sync

def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    upstream = root / "upstream"
    repo = root / "repo"
    for skill in sync.OFFICIAL_SUPERPOWERS_SKILLS:
        content = f"---\nname: {skill}\ndescription: official {skill}\n---\n\n# {skill}\n"
        write(upstream / "skills" / skill / "SKILL.md", content)
        write(repo / "community" / "superpowers" / "skills" / skill / "SKILL.md", content)

    assert fidelity.check_superpowers_fidelity(repo, upstream).ok
    write(repo / "community" / "superpowers" / "skills" / "verify-change" / "SKILL.md", "local\n")
    result = fidelity.check_superpowers_fidelity(repo, upstream)
    assert not result.ok and "extra" in result.message

    import shutil
    shutil.rmtree(repo / "community" / "superpowers" / "skills" / "verify-change")
    write(repo / "community" / "superpowers" / "codex" / "skills" / "brainstorming" / "agents" / "openai.yaml", "adapter\n")
    result = fidelity.check_superpowers_fidelity(repo, upstream)
    assert not result.ok and "must contain only skills" in result.message

    shutil.rmtree(repo / "community" / "superpowers" / "codex")
    write(repo / "community" / "superpowers" / "skills" / "brainstorming" / "SKILL.md", "mutated\n")
    result = fidelity.check_superpowers_fidelity(repo, upstream)
    assert not result.ok and "content mismatch" in result.message
PY

echo "[PASS] superpowers upstream fidelity"

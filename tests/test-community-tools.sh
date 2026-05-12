#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

python3 "$ROOT/tools/community/source_lock_check.py" >/dev/null || fail "当前 SOURCES 锁文件不应失败"

cp "$ROOT/community/SOURCES.yaml" "$TMP_DIR/sources-bad.yaml"
python3 - "$TMP_DIR/sources-bad.yaml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(
    text.replace(
        "ref: f2cbfbefebbfef77321e4c9abc9e949826bea9d7",
        "ref: 0000000000000000000000000000000000000000",
    ),
    encoding="utf-8",
)
PY
if python3 "$ROOT/tools/community/source_lock_check.py" "$TMP_DIR/sources-bad.yaml" >/tmp/org_bad_source_lock.out 2>&1; then
  cat /tmp/org_bad_source_lock.out >&2
  fail "Superpowers 锁定 ref 漂移时应失败"
fi

python3 - <<'PY' >/dev/null || fail "community sync 模块导入应可用"
import tools.community.sync_canonical_from_upstream as canonical
import tools.community.sync_vercel_skills_from_upstream as vercel
import tools.community.sync_alchaincyf_skills_from_upstream as alchaincyf
import tools.community.sync_nextlevelbuilder_skills_from_upstream as nextlevelbuilder
import tools.community.sync_panniantong_skills_from_upstream as panniantong
import tools.community.sync_skills_sh_skills_from_upstream as skills_sh
import tools.community.sync_persona_skills_from_upstream as persona

assert len(canonical.OFFICIAL_SUPERPOWERS_SKILLS) == 14
assert callable(vercel.main)
assert callable(alchaincyf.main)
assert callable(nextlevelbuilder.main)
assert callable(panniantong.main)
assert callable(skills_sh.main)
assert callable(persona.main)
PY

python3 - <<'PY' >/dev/null || fail "Superpowers clone 应 checkout SOURCES.yaml 锁定 ref"
import tempfile
from pathlib import Path

import tools.community.sync_canonical_from_upstream as mod

sample = """sources:
  superpowers:
    repo: https://example.invalid/locked-superpowers.git
    ref: locked-superpowers-ref
    captured_at: 2026-05-08
    scope:
      - community/superpowers/skills
    notes:
      - no local overlays, Codex adapters, local-only files, or source header
"""

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    community = root / "community"
    community.mkdir(parents=True, exist_ok=True)
    (community / "SOURCES.yaml").write_text(sample, encoding="utf-8")

    calls = []

    def fake_run(cmd, cwd=None):
        calls.append((cmd, cwd))
        if cmd[:2] == ["git", "clone"]:
            Path(cmd[-1]).mkdir(parents=True, exist_ok=True)
            return ""
        if cmd[-2:] == ["rev-parse", "HEAD"]:
            return "resolved-locked-commit\n"
        return ""

    original_community = mod.COMMUNITY
    original_run = mod.run
    try:
        mod.COMMUNITY = community
        mod.run = fake_run
        checkout, commit = mod.clone_superpowers_from_lock(root / "tmp")
    finally:
        mod.COMMUNITY = original_community
        mod.run = original_run

    assert checkout == root / "tmp" / "superpowers"
    assert commit == "resolved-locked-commit"
    assert ["git", "clone", "--no-checkout", "https://example.invalid/locked-superpowers.git", str(checkout)] in [call[0] for call in calls]
    assert ["git", "-C", str(checkout), "fetch", "--depth", "1", "origin", "locked-superpowers-ref"] in [call[0] for call in calls]
    assert ["git", "-C", str(checkout), "checkout", "--detach", "FETCH_HEAD"] in [call[0] for call in calls]
PY

python3 - <<'PY' >/dev/null || fail "update_sources_yaml 应收敛到纯 skills scope"
import tempfile
from pathlib import Path

import tools.community.sync_canonical_from_upstream as mod

sample = """sources:
  anthropic_skills:
    repo: https://github.com/anthropics/skills
    ref: keep-anthropic
    captured_at: 2026-04-02
    scope:
      - community/anthropic/skills
    notes:
      - good
  superpowers:
    repo: https://github.com/obra/superpowers
    ref: old-superpowers
    captured_at: 2026-04-24
    scope:
      - skills/brainstorming
      - agents/code-reviewer.md
    notes:
      - old overlay policy
  vercel_skills:
    repo: https://github.com/vercel-labs/skills
    ref: keep-vercel
    captured_at: 2026-04-12
    scope:
      - community/vercel/skills/find-skills
    notes:
      - good
"""

with tempfile.TemporaryDirectory() as td:
    community = Path(td) / "community"
    community.mkdir(parents=True, exist_ok=True)
    (community / "SOURCES.yaml").write_text(sample, encoding="utf-8")

    original = mod.COMMUNITY
    try:
        mod.COMMUNITY = community
        mod.update_sources_yaml("new-superpowers", captured_at="2026-05-08")
    finally:
        mod.COMMUNITY = original

    updated = (community / "SOURCES.yaml").read_text(encoding="utf-8")
    assert "ref: new-superpowers" in updated
    assert "captured_at: 2026-05-08" in updated
    assert "community/superpowers/skills" in updated
    assert "agents/code-reviewer.md" not in updated
    assert "local-only skills" in updated
    assert "ref: keep-anthropic" in updated
    assert "ref: keep-vercel" in updated
PY

python3 - <<'PY' >/dev/null || fail "skill-pull 更新真实 SOURCES 形态时应保留 scope/notes"
import importlib.util
import sys
from pathlib import Path

root = Path(".").resolve()
scripts = root / "shared/skills/skill-pull/scripts"
spec = importlib.util.spec_from_file_location("skill_pull_lib", scripts / "skill_pull_lib.py")
lib = importlib.util.module_from_spec(spec)
sys.modules["skill_pull_lib"] = lib
spec.loader.exec_module(lib)
spec = importlib.util.spec_from_file_location("run_update", scripts / "run_update.py")
run_update = importlib.util.module_from_spec(spec)
sys.modules["run_update"] = run_update
spec.loader.exec_module(run_update)

source_lock = root / "community/SOURCES.yaml"
text = source_lock.read_text(encoding="utf-8")
locks = lib.load_source_locks(source_lock)
status = lib.SourceStatus(
    name="persona_nuwa_skill",
    status="update",
    current_ref=locks["persona_nuwa_skill"].ref,
    candidate_ref="new-persona-ref",
    candidate_source="fixture",
)
updated = run_update.update_lock_text(text, [status], "2026-05-08")
assert "persona_nuwa_skill:" in updated
assert "ref: new-persona-ref" in updated
assert "captured_at: 2026-05-08" in updated
assert "community/persona/skills/nuwa-skill" in updated
assert "运行时由 `install.sh` 注入 `disable-model-invocation: true`" in updated
assert "persona_yourself_skill:" in updated
PY

python3 - <<'PY' >/dev/null || fail "sync_superpowers 应只复制官方 14 个 skills 并清理旧目录"
import tempfile
from pathlib import Path

import tools.community.sync_canonical_from_upstream as mod

def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    upstream = root / "upstream"
    community = root / "community"
    for skill in mod.OFFICIAL_SUPERPOWERS_SKILLS:
        write(
            upstream / "skills" / skill / "SKILL.md",
            f"---\nname: {skill}\ndescription: official {skill}\n---\n\n# {skill}\n",
        )
    write(community / "superpowers" / "skills" / "verify-change" / "SKILL.md", "stale local skill\n")
    write(community / "superpowers" / "codex" / "skills" / "brainstorming" / "agents" / "openai.yaml", "stale adapter\n")
    write(community / "superpowers" / "agents" / "generic-code-reviewer.md", "stale agent\n")

    original = mod.COMMUNITY
    try:
        mod.COMMUNITY = community
        mod.sync_superpowers(upstream)
    finally:
        mod.COMMUNITY = original

    actual_root = community / "superpowers"
    assert sorted(path.name for path in actual_root.iterdir()) == ["skills"]
    actual_skills = sorted(path.name for path in (actual_root / "skills").iterdir())
    assert actual_skills == sorted(mod.OFFICIAL_SUPERPOWERS_SKILLS)
    for skill in mod.OFFICIAL_SUPERPOWERS_SKILLS:
        assert (actual_root / "skills" / skill / "SKILL.md").read_text(encoding="utf-8") == (
            upstream / "skills" / skill / "SKILL.md"
        ).read_text(encoding="utf-8")
PY

python3 - <<'PY' >/dev/null || fail "Superpowers fidelity checker 应拒绝 adapter/extra skill"
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

    ok = fidelity.check_superpowers_fidelity(repo, upstream)
    assert ok.ok, ok.message

    write(repo / "community" / "superpowers" / "codex" / "skills" / "brainstorming" / "agents" / "openai.yaml", "adapter\n")
    bad_shape = fidelity.check_superpowers_fidelity(repo, upstream)
    assert not bad_shape.ok and "must contain only skills" in bad_shape.message

    import shutil
    shutil.rmtree(repo / "community" / "superpowers" / "codex")
    write(repo / "community" / "superpowers" / "skills" / sync.OFFICIAL_SUPERPOWERS_SKILLS[0] / "SKILL.md", "changed\n")
    bad_content = fidelity.check_superpowers_fidelity(repo, upstream)
    assert not bad_content.ok and "content mismatch" in bad_content.message
PY

python3 - <<'PY' >/dev/null || fail "community upstream sync 不应包含正文机器翻译或 overlay 入口"
from pathlib import Path

root = Path(".")
for rel in [
    "tools/community/check_superpowers_upstream_fidelity.py",
    "tools/community/sync_canonical_from_upstream.py",
    "shared/skills/skill-pull/scripts/run_update.py",
]:
    text = (root / rel).read_text(encoding="utf-8")
    for forbidden in ("deep_translator", "GoogleTranslator", "--skip-translate", "zh-CN", "superpowers_overlay_rules"):
        assert forbidden not in text, f"{rel} contains forbidden marker: {forbidden}"
PY

echo "[PASS] community tools"

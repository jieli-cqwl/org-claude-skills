#!/usr/bin/env bash
# 文件职责：验证 Skill 运行面自动/手动/禁用策略由显式合同驱动。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACT="$ROOT/contracts/skill-runtime-surface.json"
APPLY_TOOL="$ROOT/tools/skills/apply_skill_runtime_surface.py"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -s "$CONTRACT" ] || fail "missing skill runtime surface contract"
[ -x "$APPLY_TOOL" ] || fail "missing executable skill runtime surface tool"

python3 - "$ROOT" "$CONTRACT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
contract_path = Path(sys.argv[2])
contract = json.loads(contract_path.read_text(encoding="utf-8"))

limits = contract.get("limits", {})
auto_limit = limits.get("max_auto_invoked_skills")
if not isinstance(auto_limit, int) or auto_limit <= 0:
    raise SystemExit("contracts/skill-runtime-surface.json: limits.max_auto_invoked_skills must be positive integer")

skills = contract.get("skills")
if not isinstance(skills, dict) or not skills:
    raise SystemExit("contracts/skill-runtime-surface.json: skills must be a non-empty object")

valid_modes = {"auto", "manual", "off"}
auto_skills = []
manual_skills = []
for name, entry in sorted(skills.items()):
    mode = entry.get("mode")
    if mode not in valid_modes:
        raise SystemExit(f"{name}: mode must be one of {sorted(valid_modes)}")
    reason = str(entry.get("reason", "")).strip()
    owner = str(entry.get("owner", "")).strip()
    if not reason or not owner:
        raise SystemExit(f"{name}: reason and owner are required")
    if mode == "auto":
        auto_skills.append(name)
    if mode == "manual":
        manual_skills.append(name)

if len(auto_skills) > auto_limit:
    raise SystemExit(f"auto skill count exceeds contract limit: {len(auto_skills)} > {auto_limit}")
if "webapp-testing" not in auto_skills:
    raise SystemExit("webapp-testing should stay auto-invoked")
if "docx" not in manual_skills:
    raise SystemExit("docx should be manual-only")

source_skill_files = []
for root_dir in [
    "shared/skills",
    "community/superpowers/skills",
    "community/anthropic/skills",
    "community/vercel/skills",
    "community/alchaincyf/skills",
    "community/nextlevelbuilder/skills",
    "community/panniantong/skills",
    "community/skills-sh/skills",
    "community/persona/skills",
    "claude/skills",
]:
    base = root / root_dir
    if base.exists():
        source_skill_files.extend(base.glob("*/SKILL.md"))

for skill_file in source_skill_files:
    text = skill_file.read_text(encoding="utf-8")
    match = re.search(r"^name:\s*['\"]?([^'\"\n]+)", text, re.MULTILINE)
    skill_name = match.group(1).strip() if match else skill_file.parent.name
    if skill_name not in skills and skill_file.parent.name not in skills:
        raise SystemExit(f"{skill_file}: missing from runtime surface contract")

readme = (root / "README.md").read_text(encoding="utf-8")
retired_refs = [
    "shared/reference/Skill质量标准.md",
    "shared/reference/Skill能力有效性标准.md",
]
for retired in retired_refs:
    if retired in readme:
        raise SystemExit(f"README.md still treats retired reference as active truth: {retired}")
if "contracts/skill-runtime-surface.json" not in readme:
    raise SystemExit("README.md should document the skill runtime surface contract")
PY

mkdir -p "$TMP_DIR/skills/docx/agents" "$TMP_DIR/skills/webapp-testing/agents"
cat > "$TMP_DIR/skills/docx/SKILL.md" <<'EOF_SKILL'
---
name: docx
description: Create, inspect, and edit Word documents.
---

# DOCX
EOF_SKILL
cat > "$TMP_DIR/skills/docx/agents/openai.yaml" <<'EOF_YAML'
interface:
  display_name: "DOCX"
  short_description: "Create, inspect, and edit Word documents"
  default_prompt: "Use $docx to create, inspect, or edit Word documents."
EOF_YAML
cat > "$TMP_DIR/skills/webapp-testing/SKILL.md" <<'EOF_SKILL'
---
name: webapp-testing
description: Test local web apps with Playwright tooling.
---

# Webapp Testing
EOF_SKILL
cat > "$TMP_DIR/skills/webapp-testing/agents/openai.yaml" <<'EOF_YAML'
interface:
  display_name: "Webapp Testing"
  short_description: "Test local web apps with Playwright tooling"
  default_prompt: "Use $webapp-testing to test a local web application."
EOF_YAML

python3 "$APPLY_TOOL" \
  --contract "$CONTRACT" \
  --skills-dir "$TMP_DIR/skills" \
  --runtime codex \
  --audit-json "$TMP_DIR/audit.json"

grep -Fq 'disable-model-invocation: true' "$TMP_DIR/skills/docx/SKILL.md" \
  || fail "Codex manual-only SKILL.md should keep cross-runtime manual marker"
grep -Fq 'allow_implicit_invocation: false' "$TMP_DIR/skills/docx/agents/openai.yaml" \
  || fail "Codex manual-only openai.yaml should disable implicit invocation"
! grep -Fq 'disable-model-invocation: true' "$TMP_DIR/skills/webapp-testing/SKILL.md" \
  || fail "Codex auto skill should not be marked manual-only"
! grep -Fq 'allow_implicit_invocation: false' "$TMP_DIR/skills/webapp-testing/agents/openai.yaml" \
  || fail "Codex auto skill should not disable implicit invocation"

python3 - "$TMP_DIR/audit.json" <<'PY'
import json
import sys
from pathlib import Path

audit = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if audit.get("runtime") != "codex":
    raise SystemExit("audit runtime mismatch")
if audit.get("auto_count") != 1 or audit.get("manual_count") != 1:
    raise SystemExit(f"unexpected audit counts: {audit}")
PY

printf '[PASS] skill runtime surface contract\n'

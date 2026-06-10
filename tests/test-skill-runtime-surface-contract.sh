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
valid_execution_kinds = {"skill", "orchestrator", "agent_backed"}
valid_codex_execution = {
    "inline",
    "subagent_clean",
    "subagent_fork",
    "subagent_parallel",
}
auto_skills = []
manual_skills = []
source_dirs = {}
for name, entry in sorted(skills.items()):
    mode = entry.get("mode")
    if mode not in valid_modes:
        raise SystemExit(f"{name}: mode must be one of {sorted(valid_modes)}")
    reason = str(entry.get("reason", "")).strip()
    owner = str(entry.get("owner", "")).strip()
    if not reason or not owner:
        raise SystemExit(f"{name}: reason and owner are required")
    execution_kind = str(entry.get("execution_kind", "skill")).strip()
    if execution_kind not in valid_execution_kinds:
        raise SystemExit(f"{name}: execution_kind must be one of {sorted(valid_execution_kinds)}")
    codex_execution = entry.get("codex_execution")
    if codex_execution is not None and codex_execution not in valid_codex_execution:
        raise SystemExit(f"{name}: codex_execution must be one of {sorted(valid_codex_execution)}")
    allow_nested_agents = entry.get("allow_nested_agents")
    if allow_nested_agents is not None and not isinstance(allow_nested_agents, bool):
        raise SystemExit(f"{name}: allow_nested_agents must be boolean when present")
    if execution_kind == "agent_backed":
        if mode != "manual":
            raise SystemExit(f"{name}: agent_backed skills must be manual-only")
        if codex_execution is not None:
            raise SystemExit(f"{name}: agent_backed skills must not define generic codex_execution")
        if not str(entry.get("agent_type", "")).strip():
            raise SystemExit(f"{name}: agent_backed skills require agent_type")
        dispatchers = entry.get("dispatchers")
        if not isinstance(dispatchers, list) or not all(isinstance(item, str) and item for item in dispatchers):
            raise SystemExit(f"{name}: agent_backed skills require non-empty dispatchers")
        if allow_nested_agents is not False:
            raise SystemExit(f"{name}: agent_backed skills must set allow_nested_agents=false")
    if execution_kind == "orchestrator":
        if codex_execution not in {None, "inline"}:
            raise SystemExit(f"{name}: orchestrator skills must execute inline and own their internal dispatch")
        if allow_nested_agents is not True:
            raise SystemExit(f"{name}: orchestrator skills must set allow_nested_agents=true")
    source_dir = str(entry.get("source_dir", "")).strip()
    if source_dir:
        source_dirs[source_dir] = name
    if mode == "auto":
        auto_skills.append(name)
    if mode == "manual":
        manual_skills.append(name)

if len(auto_skills) > auto_limit:
    raise SystemExit(f"auto skill count exceeds contract limit: {len(auto_skills)} > {auto_limit}")
expected_auto = {
    "agent-browser",
    "brainstorming",
    "dispatching-parallel-agents",
    "executing-plans",
    "finishing-a-development-branch",
    "frontend-design",
    "receiving-code-review",
    "requesting-code-review",
    "skill-creator",
    "subagent-driven-development",
    "systematic-debugging",
    "test-driven-development",
    "using-git-worktrees",
    "using-superpowers",
    "verification-before-completion",
    "webapp-testing",
    "writing-plans",
    "writing-skills",
}
expected_auto_class = {
    "agent-browser": "high_frequency",
    "brainstorming": "workflow_guardrail",
    "dispatching-parallel-agents": "conditional_coordination",
    "executing-plans": "workflow_guardrail",
    "finishing-a-development-branch": "workflow_guardrail",
    "frontend-design": "high_frequency",
    "receiving-code-review": "workflow_guardrail",
    "requesting-code-review": "workflow_guardrail",
    "skill-creator": "high_frequency",
    "subagent-driven-development": "conditional_coordination",
    "systematic-debugging": "workflow_guardrail",
    "test-driven-development": "workflow_guardrail",
    "using-git-worktrees": "workflow_guardrail",
    "using-superpowers": "workflow_guardrail",
    "verification-before-completion": "workflow_guardrail",
    "webapp-testing": "high_frequency",
    "writing-plans": "workflow_guardrail",
    "writing-skills": "workflow_guardrail",
}
actual_auto = set(auto_skills)
if actual_auto != expected_auto:
    raise SystemExit(
        "auto skill set mismatch: "
        f"missing={sorted(expected_auto - actual_auto)} extra={sorted(actual_auto - expected_auto)}"
    )
for name, auto_class in expected_auto_class.items():
    if skills[name].get("auto_class") != auto_class:
        raise SystemExit(f"{name}: auto_class must be {auto_class}")

expected_codex_execution = {
    "claude-api": "inline",
    "github-repo-radar": "subagent_clean",
    "overview": "subagent_clean",
    "research": "subagent_clean",
}
for name, codex_execution in expected_codex_execution.items():
    entry = skills[name]
    if entry.get("execution_kind", "skill") != "skill":
        raise SystemExit(f"{name}: expected normal skill execution_kind")
    if entry.get("codex_execution") != codex_execution:
        raise SystemExit(f"{name}: codex_execution must be {codex_execution}")

expected_orchestrators = {
    "delivery-owner",
    "scan",
    "skill-quality-audit",
}
for name in expected_orchestrators:
    entry = skills[name]
    if entry.get("execution_kind") != "orchestrator":
        raise SystemExit(f"{name}: execution_kind must be orchestrator")
    if entry.get("codex_execution") != "inline":
        raise SystemExit(f"{name}: orchestrator codex_execution must be inline")

expected_agent_backed = {
    "consistency-audit": ("consistency-auditor", {"delivery-owner", "tech-lead"}),
    "developer": ("developer", {"delivery-owner"}),
    "fix": ("fixer", {"delivery-owner"}),
    "qa": ("qa", {"delivery-owner"}),
    "review": ("code-reviewer", {"delivery-owner", "requesting-code-review"}),
    "verify": ("verifier", {"delivery-owner"}),
}
for name, (agent_type, required_dispatchers) in expected_agent_backed.items():
    entry = skills[name]
    if entry.get("execution_kind") != "agent_backed":
        raise SystemExit(f"{name}: execution_kind must be agent_backed")
    if entry.get("agent_type") != agent_type:
        raise SystemExit(f"{name}: agent_type must be {agent_type}")
    dispatchers = set(entry.get("dispatchers", []))
    missing_dispatchers = sorted(required_dispatchers - dispatchers)
    if missing_dispatchers:
        raise SystemExit(f"{name}: dispatchers missing {missing_dispatchers}")

def require_routing_tokens(name: str, tokens: list[str]) -> None:
    routing_text = " ".join(
        str(skills[name].get(key, ""))
        for key in ("description", "routing_boundary")
    ).lower()
    missing = [token for token in tokens if token.lower() not in routing_text]
    if missing:
        raise SystemExit(f"{name}: missing routing boundary tokens: {missing}")


require_routing_tokens("agent-browser", ["browser", "remote", "non-local"])
require_routing_tokens("webapp-testing", ["local", "web app"])
require_routing_tokens("frontend-design", ["building", "modifying", "frontend"])
require_routing_tokens("research", ["evidence-backed", "outside installable agent skill"])
require_routing_tokens("find-skills", ["installable agent skills"])
if "evaluating" in str(skills["find-skills"].get("description", "")).lower():
    raise SystemExit("find-skills description should not claim generic skill evaluation; route editing/optimization to skill-creator")
if "docx" not in manual_skills:
    raise SystemExit("docx should be manual-only")
for manual_name in [
    "architecture",
    "claude-api",
    "find-skills",
    "github-repo-radar",
    "mermaid-diagrams",
    "overview",
    "planning-with-files",
    "prompt",
    "refactor",
    "research",
    "security",
    "ui-ux-pro-max",
]:
    if manual_name not in manual_skills:
        raise SystemExit(f"{manual_name} should be manual-only")

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
    if skill_name not in skills and skill_file.parent.name not in skills and skill_file.parent.name not in source_dirs:
        raise SystemExit(f"{skill_file}: missing from runtime surface contract")
    if skill_file.parent.name in source_dirs and skill_name != source_dirs[skill_file.parent.name]:
        raise SystemExit(f"{skill_file}: source_dir maps to {source_dirs[skill_file.parent.name]}, got {skill_name}")

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

mkdir -p \
  "$TMP_DIR/skills/docx/agents" \
  "$TMP_DIR/skills/cli-updater/agents" \
  "$TMP_DIR/skills/claude-api/agents" \
  "$TMP_DIR/skills/consistency-audit/agents" \
  "$TMP_DIR/skills/research/agents" \
  "$TMP_DIR/skills/scan/agents" \
  "$TMP_DIR/skills/webapp-testing/agents"
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
cat > "$TMP_DIR/skills/cli-updater/SKILL.md" <<'EOF_SKILL'
---
name: cli-updater
description: Check and update Claude/Codex CLI versions.
---

# CLI Updater
EOF_SKILL
cat > "$TMP_DIR/skills/cli-updater/agents/openai.yaml" <<'EOF_YAML'
interface:
  display_name: "CLI Updater"
policy:
  other_flag: true
EOF_YAML
cat > "$TMP_DIR/skills/claude-api/SKILL.md" <<'EOF_SKILL'
---
name: claude-api
description: |-
  This official mirror description is intentionally much longer than the Codex runtime budget because the runtime surface contract owns the injected description for manual first-party skills.
  Stale upstream trigger line that must not survive runtime description replacement.
---

# Claude API
EOF_SKILL
cat > "$TMP_DIR/skills/consistency-audit/SKILL.md" <<'EOF_SKILL'
---
name: consistency-audit
description: Audit canonical delivery artifacts.
---

# Consistency Audit
EOF_SKILL
cat > "$TMP_DIR/skills/consistency-audit/agents/openai.yaml" <<'EOF_YAML'
interface:
  display_name: "Consistency Audit"
policy:
  allow_implicit_invocation: false
EOF_YAML
cat > "$TMP_DIR/skills/research/SKILL.md" <<'EOF_SKILL'
---
name: research
description: Investigate external evidence and options.
---

# Research
EOF_SKILL
cat > "$TMP_DIR/skills/research/agents/openai.yaml" <<'EOF_YAML'
interface:
  display_name: "Research"
policy:
  allow_implicit_invocation: false
EOF_YAML
cat > "$TMP_DIR/skills/scan/SKILL.md" <<'EOF_SKILL'
---
name: scan
description: Scan repository health.
---

# Scan
EOF_SKILL
cat > "$TMP_DIR/skills/scan/agents/openai.yaml" <<'EOF_YAML'
interface:
  display_name: "Scan"
policy:
  allow_implicit_invocation: false
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
policy:
  allow_implicit_invocation: false
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
grep -Fq 'other_flag: true' "$TMP_DIR/skills/cli-updater/agents/openai.yaml" \
  || fail "Codex manual-only policy merge should preserve existing policy keys"
grep -Fq 'allow_implicit_invocation: false' "$TMP_DIR/skills/cli-updater/agents/openai.yaml" \
  || fail "Codex manual-only policy merge should add implicit invocation flag"
[ "$(grep -c '^policy:' "$TMP_DIR/skills/cli-updater/agents/openai.yaml")" -eq 1 ] \
  || fail "Codex manual-only policy merge must not create duplicate policy roots"
python3 - "$CONTRACT" "$TMP_DIR/skills/claude-api/SKILL.md" <<'PY' \
  || fail "Codex manual first-party runtime description should use contract override"
import json
import sys
from pathlib import Path

contract = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
skill_text = Path(sys.argv[2]).read_text(encoding="utf-8")
frontmatter = skill_text.split("---\n", 2)[1]
actual = ""
for line in frontmatter.splitlines():
    if line.startswith("description:"):
        actual = line.split(":", 1)[1].strip().strip("'\"")
        break
expected = contract["skills"]["claude-api"]["description"]
if actual != expected:
    raise SystemExit(f"runtime description mismatch: {actual!r} != {expected!r}")
PY
python3 - "$TMP_DIR/skills/claude-api/SKILL.md" <<'PY' \
  || fail "Codex runtime description replacement must remove chomped block-scalar continuation lines"
import sys
from pathlib import Path

skill_text = Path(sys.argv[1]).read_text(encoding="utf-8")
frontmatter = skill_text.split("---\n", 2)[1]
lines = frontmatter.splitlines()
desc_idx = next(
    (idx for idx, line in enumerate(lines) if line.startswith("description:")),
    None,
)
if desc_idx is None:
    raise SystemExit("missing description")
for line in lines[desc_idx + 1 :]:
    if not line.strip():
        continue
    if not line.startswith((" ", "\t")):
        break
    raise SystemExit("description continuation line survived replacement")
PY
! grep -Fq 'disable-model-invocation: true' "$TMP_DIR/skills/webapp-testing/SKILL.md" \
  || fail "Codex auto skill should not be marked manual-only"
! grep -Fq 'allow_implicit_invocation: false' "$TMP_DIR/skills/webapp-testing/agents/openai.yaml" \
  || fail "Codex auto skill should not disable implicit invocation"
grep -Fq 'allow_implicit_invocation: true' "$TMP_DIR/skills/webapp-testing/agents/openai.yaml" \
  || fail "Codex auto skill should self-heal stale implicit invocation policy"
grep -Fq 'codex_execution: subagent_clean' "$TMP_DIR/skills/research/agents/openai.yaml" \
  || fail "Codex research policy should expose subagent_clean execution"
grep -Fq 'execution_kind: agent_backed' "$TMP_DIR/skills/consistency-audit/agents/openai.yaml" \
  || fail "Codex consistency-audit policy should expose agent-backed execution"
grep -Fq 'agent_type: consistency-auditor' "$TMP_DIR/skills/consistency-audit/agents/openai.yaml" \
  || fail "Codex consistency-audit policy should expose agent type"
grep -Fq 'allow_nested_agents: false' "$TMP_DIR/skills/consistency-audit/agents/openai.yaml" \
  || fail "Codex consistency-audit policy should forbid nested generic agents"
! grep -Fq 'codex_execution:' "$TMP_DIR/skills/consistency-audit/agents/openai.yaml" \
  || fail "Codex agent-backed skills must not expose generic codex_execution"
grep -Fq 'execution_kind: orchestrator' "$TMP_DIR/skills/scan/agents/openai.yaml" \
  || fail "Codex scan policy should expose orchestrator execution kind"
grep -Fq 'allow_nested_agents: true' "$TMP_DIR/skills/scan/agents/openai.yaml" \
  || fail "Codex scan policy should allow its own internal dispatch"

python3 - "$TMP_DIR/audit.json" <<'PY'
import json
import sys
from pathlib import Path

audit = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if audit.get("runtime") != "codex":
    raise SystemExit("audit runtime mismatch")
if audit.get("auto_count") != 1 or audit.get("manual_count") != 6:
    raise SystemExit(f"unexpected audit counts: {audit}")
PY

printf '[PASS] skill runtime surface contract\n'

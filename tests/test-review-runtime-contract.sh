#!/usr/bin/env bash
# Validates that review's agent-backed runtime contract does not instruct nested agent dispatch.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
surface = json.loads((root / "contracts/skill-runtime-surface.json").read_text(encoding="utf-8"))
review = surface["skills"]["review"]

if review.get("execution_kind") != "agent_backed":
    raise SystemExit("review must stay agent_backed")
if review.get("agent_type") != "code-reviewer":
    raise SystemExit("review must dispatch through code-reviewer")
if review.get("allow_nested_agents") is not False:
    raise SystemExit("review must not allow nested agents")

openai_yaml = (root / "shared/skills/review/agents/openai.yaml").read_text(encoding="utf-8")
for required in [
    "execution_kind: agent_backed",
    "agent_type: code-reviewer",
    "allow_nested_agents: false",
]:
    if required not in openai_yaml:
        raise SystemExit(f"review OpenAI policy missing {required}")

skill = (root / "shared/skills/review/SKILL.md").read_text(encoding="utf-8")
frontmatter = skill.split("---", 2)[1]
allowed_tools = next(
    (line for line in frontmatter.splitlines() if line.startswith("allowed-tools:")),
    "",
)
if re.search(r"(^|[, ])Agent([, ]|$)", allowed_tools):
    raise SystemExit("review SKILL allowed-tools must not include Agent when nested agents are disabled")

checked_paths = [
    root / "shared/skills/review/SKILL.md",
    root / "shared/skills/review/references/code-safety-reviewer-prompt.md",
    root / "shared/skills/review/references/code-maintainability-reviewer-prompt.md",
    root / "shared/skills/review/references/code-performance-reviewer-prompt.md",
]
for path in checked_paths:
    text = path.read_text(encoding="utf-8")
    forbidden = [token for token in ("Agent(", "subagent_type") if token in text]
    if forbidden:
        rel = path.relative_to(root)
        raise SystemExit(f"{rel} contains nested-agent invocation tokens: {', '.join(forbidden)}")

print("[PASS] review runtime contract")
PY

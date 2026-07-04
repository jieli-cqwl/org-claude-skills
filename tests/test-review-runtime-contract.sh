#!/usr/bin/env bash
# Validates that review stays a manual skill and is not exposed as a managed Codex agent.
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

if review.get("mode") != "manual":
    raise SystemExit("review must stay manual")
if review.get("execution_kind", "skill") != "skill":
    raise SystemExit("review must run as a manual skill, not an agent-backed workflow")
if "agent_type" in review:
    raise SystemExit("review must not declare a Codex managed agent")
if review.get("dispatchers"):
    raise SystemExit("review must not be auto-dispatched by managed agent workflows")

openai_yaml = (root / "shared/skills/review/agents/openai.yaml").read_text(encoding="utf-8")
if "allow_implicit_invocation: false" not in openai_yaml:
    raise SystemExit("review OpenAI policy must disable implicit invocation")
for forbidden in [
    "execution_kind: agent_backed",
    "agent_type: code-reviewer",
]:
    if forbidden in openai_yaml:
        raise SystemExit(f"review OpenAI policy must not expose managed agent setting: {forbidden}")

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

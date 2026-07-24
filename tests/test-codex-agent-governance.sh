#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/tmp/codex_agent_governance_absent.out 2>&1; then
    cat /tmp/codex_agent_governance_absent.out >&2
    fail "unexpected pattern in $file: $pattern"
  fi
}

assert_managed_runtime_agents_contract() {
PYTHONPATH="$ROOT/tools/community" python3 - <<'PY'
from codex_runtime_agents import MANAGED_AGENT_ROLES

roles = {role: {"description": description, "config_file": config_file} for role, description, config_file in MANAGED_AGENT_ROLES}
expected = {
    "consistency-auditor": {
        "description_terms": ["一致性", "advisory"],
        "config_file": "./agents/consistency-auditor.toml",
    },
}
missing = []
for role, contract in expected.items():
    actual = roles.get(role)
    if actual is None:
        missing.append(f"{role}: missing role")
        continue
    if actual["config_file"] != contract["config_file"]:
        missing.append(f"{role}: config_file")
    if not all(term in actual["description"] for term in contract["description_terms"]):
        missing.append(f"{role}: description")
for role, actual in roles.items():
    if "delivery-owner" not in actual["description"] or "Task Packet" not in actual["description"]:
        missing.append(f"{role}: missing delivery-owner dispatch boundary")
if missing:
    raise SystemExit("; ".join(missing))
PY
}

assert_delivery_owner_codex_dispatch_contract() {
  python3 - "$ROOT/shared/skills/delivery-owner/SKILL.md" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md" <<'PY'
import sys
from pathlib import Path

skill = Path(sys.argv[1]).read_text(encoding="utf-8")
packet = Path(sys.argv[2]).read_text(encoding="utf-8")
contracts = {
    "skill_review": (skill, ["review skill"]),
    "skill_consistency_auditor": (skill, ["consistency-auditor agent", "consistency-audit"]),
    "packet_review": (packet, ["review skill", "review"]),
    "packet_consistency_baseline": (packet, ["consistency-auditor agent", "baseline"]),
    "packet_consistency_commit": (packet, ["consistency-auditor agent", "提交"]),
}
missing = [name for name, (text, terms) in contracts.items() if not all(term in text for term in terms)]
if missing:
    raise SystemExit(f"missing delivery-owner Codex dispatch contract: {', '.join(missing)}")
PY
}

expected_agents=(
  consistency-auditor
  developer
  fixer
  qa
  verifier
)

actual_agents=()
while IFS= read -r agent_name; do
  actual_agents+=("$agent_name")
done < <(
  find "$ROOT/shared/agents/codex" -maxdepth 1 -type f -name '*.toml' -print \
    | sed 's#.*/##; s#\.toml$##' \
    | sort
)

expected_joined="$(printf '%s\n' "${expected_agents[@]}")"
actual_joined="$(printf '%s\n' "${actual_agents[@]}")"
[ "$actual_joined" = "$expected_joined" ] || fail "codex agent catalog mismatch. expected=[$expected_joined] actual=[$actual_joined]"

ambiguous_agent_boundary_terms='thin adapter|薄 adapter|厚 adapter'
if git -C "$ROOT" grep -n -E "$ambiguous_agent_boundary_terms" -- \
  install.sh \
  tests \
  shared \
  tools \
  README.md \
  ':(exclude)tests/test-codex-agent-governance.sh' \
  ':(exclude)tools/eval/results/**' \
  ':(exclude)shared/skills/research-workspace/**' >/tmp/codex_agent_ambiguous_boundary.out 2>&1; then
  cat /tmp/codex_agent_ambiguous_boundary.out >&2
  fail "agent/skill 边界不得继续使用 thin/薄/厚 adapter 这类歧义表述"
fi

for agent in "${expected_agents[@]}"; do
  assert_absent '^model[[:space:]]*=' "$ROOT/shared/agents/codex/$agent.toml"
  assert_absent '^model_reasoning_effort[[:space:]]*=' "$ROOT/shared/agents/codex/$agent.toml"
done

expected_skill_for() {
  case "$1" in
    consistency-auditor) printf '%s\n' "consistency-audit" ;;
    developer) printf '%s\n' "developer" ;;
    fixer) printf '%s\n' "fix" ;;
    qa) printf '%s\n' "qa" ;;
    verifier) printf '%s\n' "verify" ;;
    *) return 1 ;;
  esac
}

for agent in "${expected_agents[@]}"; do
  file="$ROOT/shared/agents/codex/$agent.toml"
  assert_present '^sandbox_mode = "workspace-write"$' "$file"
  assert_present '^developer_instructions = """$' "$file"
  [ -f "$ROOT/shared/skills/$(expected_skill_for "$agent")/SKILL.md" ] || fail "declared Codex agent skill source missing: $agent -> $(expected_skill_for "$agent")"
  python3 - "$file" <<'PY'
import sys
import tomllib
from pathlib import Path

payload = tomllib.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
description = payload.get("description", "")
if "delivery-owner" not in description or "Task Packet" not in description:
    raise SystemExit("Codex agent description must declare delivery-owner Task Packet dispatch boundary")
instructions = payload.get("developer_instructions", "")
lines = [line for line in instructions.splitlines() if line.strip()]
if len(lines) != 1:
    raise SystemExit("Codex agent developer_instructions must stay one-line and delegate to its skill")
for forbidden in (
    ".codex/rules",
    ".agents/skills",
    "developer-report.json",
    "verify-result.json",
    "qa-result.json",
    "code-review-result.json",
    "consistency-audit-result.json",
):
    if forbidden in instructions:
        raise SystemExit(f"Codex agent duplicates runtime/skill details: {forbidden}")
PY
done

for removed in code-reviewer codex-doc-reviewer generic-code-reviewer designer tech-lead test-designer; do
  [ ! -e "$ROOT/shared/agents/codex/$removed.toml" ] || fail "retired codex agent remains: $removed"
  [ ! -e "$ROOT/shared/agents/claude/$removed.md" ] || fail "retired claude agent remains: $removed"
done

[ ! -d "$ROOT/codex/agents" ] || fail "codex/agents should not remain as a maintained source tree"
[ ! -e "$ROOT/shared/agents/claude/code-reviewer.md" ] || fail "local Claude code-reviewer agent contract should be retired in favor of Superpowers reviewer semantics"

assert_present '^name = "consistency-auditor"$' "$ROOT/shared/agents/codex/consistency-auditor.toml"
assert_present 'advisory_only|advisory' "$ROOT/shared/agents/codex/consistency-auditor.toml"

assert_managed_runtime_agents_contract
assert_present '"consistency-auditor"' "$ROOT/tools/community/codex_runtime_agents.py"
assert_present '"\./agents/consistency-auditor.toml"' "$ROOT/tools/community/codex_runtime_agents.py"
PYTHONPATH="$ROOT/tools/community" python3 - <<'PY'
from codex_runtime_agents import MANAGED_AGENT_ROLE_NAMES, RETIRED_AGENT_ROLE_NAMES

retired = {"code-reviewer", "codex-doc-reviewer", "generic-code-reviewer", "designer", "tech-lead", "test-designer"}
assert retired <= RETIRED_AGENT_ROLE_NAMES
assert not (retired & MANAGED_AGENT_ROLE_NAMES)
PY

assert_delivery_owner_codex_dispatch_contract

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$TMP_DIR/config.toml" <<'TOML'
model = "gpt-5.5"
model_reasoning_effort = "xhigh"

[agents]
max_threads = 2

[agents.developer]
description = "old developer"
config_file = "./agents/developer.toml"
model = "gpt-5.4-mini"
model_reasoning_effort = "high"

[agents.code-reviewer]
description = "old reviewer"
config_file = "./agents/code-reviewer.toml"
model = "gpt-5.4"
model_reasoning_effort = "high"

[agents.generic-code-reviewer]
description = "retired generic"
config_file = "./agents/generic-code-reviewer.toml"

[agents.codex-doc-reviewer]
description = "retired doc reviewer"
config_file = "./agents/codex-doc-reviewer.toml"

[agents.designer]
description = "retired designer"
config_file = "./agents/designer.toml"
model = "gpt-5.4"
TOML

PYTHONPATH="$ROOT/tools/community" python3 - "$TMP_DIR/config.toml" <<'PY'
import sys
from pathlib import Path

from codex_runtime_agents import ensure_codex_agent_config

config_path = Path(sys.argv[1])
ensure_codex_agent_config(config_path)
text = config_path.read_text(encoding="utf-8")

assert 'model = "gpt-5.5"' in text
assert 'model_reasoning_effort = "xhigh"' in text
assert "max_threads = 2" in text
assert "max_depth" not in text
assert "job_max_runtime_seconds" not in text
for forbidden in (
    "[agents.code-reviewer]",
    "[agents.generic-code-reviewer]",
    "[agents.codex-doc-reviewer]",
    "[agents.designer]",
    "[agents.tech-lead]",
    "[agents.test-designer]",
    "./agents/code-reviewer.toml",
    "./agents/generic-code-reviewer.toml",
    "./agents/codex-doc-reviewer.toml",
    "./agents/designer.toml",
    'model = "gpt-5.4"',
    'model = "gpt-5.4-mini"',
    'model_reasoning_effort = "high"',
):
    assert forbidden not in text, forbidden

for expected in (
    "[agents.consistency-auditor]",
    'config_file = "./agents/consistency-auditor.toml"',
    "[agents.developer]",
    'config_file = "./agents/developer.toml"',
):
    assert expected in text, expected
PY

cat >"$TMP_DIR/legacy-managed-config.toml" <<'TOML'
[agents]
max_concurrent_threads_per_session = 32
max_threads = 6
max_depth = 1
job_max_runtime_seconds = 1800
TOML

PYTHONPATH="$ROOT/tools/community" python3 - "$TMP_DIR/legacy-managed-config.toml" <<'PY'
import sys
from pathlib import Path

from codex_runtime_agents import ensure_codex_agent_config

config_path = Path(sys.argv[1])
ensure_codex_agent_config(config_path)
text = config_path.read_text(encoding="utf-8")

assert "max_concurrent_threads_per_session = 32" in text
assert "max_threads" not in text
assert "max_depth" not in text
assert "job_max_runtime_seconds" not in text
PY

echo "[PASS] codex agent governance"

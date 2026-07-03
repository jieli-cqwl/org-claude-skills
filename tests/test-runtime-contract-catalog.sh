#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -d "$ROOT/shared/runtime" || fail "missing shared/runtime directory"
test ! -f "$ROOT/shared/runtime/runtime-catalog.json" || fail "runtime-catalog.json should be retired"
test ! -f "$ROOT/tools/community/render_runtime_contract.py" || fail "runtime contract renderer should be retired"
test -f "$ROOT/shared/rules/completion-claims.md" || fail "missing completion verification rule"
test -f "$ROOT/shared/rules/code-changes.md" || fail "missing code changes rule"
test -f "$ROOT/shared/rules/execution-control.md" || fail "missing execution control rule"
test -f "$ROOT/shared/rules/document-governance.md" || fail "missing document governance rule"
test ! -f "$ROOT/shared/rules/执行纪律.md" || fail "legacy Chinese execution rule filename should be retired"
test ! -f "$ROOT/shared/rules/文档管理.md" || fail "legacy Chinese document governance rule filename should be retired"
test ! -f "$ROOT/shared/rules/交付验收底线.md" || fail "legacy delivery acceptance rule should be retired"
test ! -f "$ROOT/shared/rules/完成前验证.md" || fail "legacy Chinese completion rule filename should be retired"
test ! -f "$ROOT/shared/rules/代码规范.md" || fail "legacy Chinese code rule filename should be retired"
test ! -f "$ROOT/shared/reference/completion-claims.md" || fail "completion verification should be a rule, not a reference"
test ! -f "$ROOT/shared/reference/性能效率.md" || fail "legacy Chinese performance reference filename should be retired"
test ! -f "$ROOT/shared/reference/硬编码治理规范.md" || fail "legacy Chinese constants reference filename should be retired"

python3 - "$ROOT/shared/rules/completion-claims.md" <<'PY' || fail "completion verification rule shape contract violated"
import sys
from pathlib import Path

rule = Path(sys.argv[1])
text = rule.read_text(encoding="utf-8")
lower_text = text.lower()
lines = text.splitlines()
if not lines or lines[0] != "# Completion Claims":
    raise SystemExit("rule must use the Completion Claims title")
if any(line.startswith("## ") for line in lines):
    raise SystemExit("rule must stay flat; prose sections make it too easy to skim past constraints")
if "TODO" in text or "TBD" in text:
    raise SystemExit("rule must not contain placeholders")

semantic_checks = [
    (
        "claim-scope-match",
        all(
            term in lower_text
            for term in (
                "requested outcome",
                "acceptance scope",
                "changed artifacts",
                "delivered artifacts",
                "observed behavior",
            )
        ),
    ),
    (
        "scope-derivation-and-no-shrink",
        all(
            term in lower_text
            for term in (
                "explicit acceptance requirements",
                "affected paths",
                "dependencies",
                "required verification",
                "user-specified verification",
                "does not shrink",
                "explicitly limits",
            )
        )
        and ("derive acceptance scope" in lower_text or "derive the acceptance scope" in lower_text),
    ),
    (
        "checks-exercise-only",
        all(term in lower_text for term in ("checks", "exercise", "define", "shrink"))
        and ("replace" in lower_text or "redefine" in lower_text),
    ),
    (
        "failure-mode-discrimination",
        all(term in lower_text for term in ("distinguish", "in-scope failure modes", "wrong behavior")),
    ),
    (
        "evidence-strength-and-same-level",
        all(term in lower_text for term in ("strength", "partial", "sampled", "local", "indirect"))
        and all(term in lower_text for term in ("mock", "stub", "fake", "same level"))
        and all(term in lower_text for term in ("user paths", "runtimes", "dependencies", "integrations", "environments")),
    ),
    (
        "representative-real-consumers",
        all(
            term in lower_text
            for term in (
                "shared contracts",
                "entrypoints",
                "data formats",
                "install/runtime paths",
                "representative real consumers",
                "outside scope",
            )
        ),
    ),
    (
        "current-reproducible-manual-evidence",
        all(
            term in lower_text
            for term in (
                "current",
                "reproducible",
                "input",
                "path",
                "environment",
                "expected result",
                "observed result",
            )
        ),
    ),
    (
        "invalid-evidence-and-substitution",
        all(
            term in lower_text
            for term in (
                "historical output",
                "cached impressions",
                "report self-reference",
                "log summaries",
            )
        )
        and ("substituted paths" in lower_text or "substituted path" in lower_text)
        and ("green checks outside scope" in lower_text or "green checks outside the claimed scope" in lower_text)
        and ("tool success" in lower_text or "tool did not error" in lower_text),
    ),
    (
        "manufactured-completion-block",
        all(
            term in lower_text
            for term in (
                "skipping",
                "xfail-ing",
                "deleting checks",
                "loosening assertions",
                "changing acceptance scope",
                "weaker evidence",
            )
        ),
    ),
    (
        "blocked-states-and-reporting",
        all(
            term in lower_text
            for term in (
                "unrun",
                "failed",
                "blocked",
                "missing evidence",
                "waiting on a dependency",
                "unaccepted risk",
                "awaiting a decision",
                "proven facts",
                "unverified items",
                "out-of-scope failures",
            )
        ),
    ),
]
missing_semantics = [label for label, present in semantic_checks if not present]
if missing_semantics:
    raise SystemExit(
        "rule missing completion-claim failure semantics: "
        + ", ".join(missing_semantics)
    )

nonempty = [line for line in lines if line.strip()]
first_bullet = next((index for index, line in enumerate(lines) if line.startswith("- ")), None)
if first_bullet is None:
    raise SystemExit("rule must contain bullet constraints")
lead = [line for line in lines[1:first_bullet] if line.strip()]
if len(lead) != 1:
    raise SystemExit("rule must have exactly one lead sentence before constraints")

bullets = [line for line in lines if line.startswith("- ")]
if not 14 <= len(bullets) <= 18:
    raise SystemExit(f"rule should stay concise: got {len(bullets)} bullets")
if sum(1 for line in bullets if line.startswith("- Test: ")) != 1:
    raise SystemExit("rule must include exactly one explicit self-test bullet")
long_lines = [str(index) for index, line in enumerate(lines, start=1) if len(line) > 220]
if long_lines:
    raise SystemExit(f"rule lines are too long: {', '.join(long_lines)}")

allowed_lines = {"", "# Completion Claims", *lead, *bullets}
unexpected = [
    f"{index}: {line}"
    for index, line in enumerate(lines, start=1)
    if line not in allowed_lines
]
if unexpected:
    raise SystemExit("rule must remain one lead sentence plus bullets:\n" + "\n".join(unexpected))

if len(nonempty) != 1 + len(lead) + len(bullets):
    raise SystemExit("rule contains unexpected non-empty content")
PY

python3 - "$ROOT/shared/rules/code-changes.md" <<'PY' || fail "code changes rule shape contract violated"
import re
import sys
from pathlib import Path

rule = Path(sys.argv[1])
text = rule.read_text(encoding="utf-8")
lower_text = text.lower()
lines = text.splitlines()
if not lines or lines[0] != "# Code Changes":
    raise SystemExit("rule must use the Code Changes title")
if any(line.startswith("## ") for line in lines):
    raise SystemExit("rule must stay flat; detailed guidance belongs in reference files")
if "TODO" in text or "TBD" in text:
    raise SystemExit("rule must not contain placeholders")
if any(term in text for term in ("MUST（必须遵守）", "复用治理规范", "复杂度约束", "硬编码规范")):
    raise SystemExit("rule must not regress to the old handbook structure")

first_bullet = next((index for index, line in enumerate(lines) if line.startswith("- ")), None)
if first_bullet is None:
    raise SystemExit("rule must contain bullet constraints")
lead = [line for line in lines[1:first_bullet] if line.strip()]
if len(lead) != 1:
    raise SystemExit("rule must have exactly one lead sentence before constraints")

bullets = [line for line in lines if line.startswith("- ")]
if not 18 <= len(bullets) <= 26:
    raise SystemExit(f"rule should stay concise: got {len(bullets)} bullets")
if sum(1 for line in bullets if line.startswith("- Test: ")) != 1:
    raise SystemExit("rule must include exactly one explicit self-test bullet")
long_lines = [str(index) for index, line in enumerate(lines, start=1) if len(line) > 220]
if long_lines:
    raise SystemExit(f"rule lines are too long: {', '.join(long_lines)}")

refs = set(re.findall(r"\{\{RUNTIME_HOME\}\}/reference/[^`]+\.md", text))
expected_refs = {
    "{{RUNTIME_HOME}}/reference/code-structure-reuse.md",
    "{{RUNTIME_HOME}}/reference/code-comments.md",
    "{{RUNTIME_HOME}}/reference/error-handling.md",
    "{{RUNTIME_HOME}}/reference/constants-and-configuration.md",
    "{{RUNTIME_HOME}}/reference/performance-and-efficiency.md",
}
if refs != expected_refs:
    raise SystemExit(f"unexpected reference set: {sorted(refs)}")

semantic_checks = [
    (
        "existing-artifact-constraint-before-delete",
        all(
            term in text
            for term in (
                "deleting or simplifying",
                "existing artifacts",
                "constraint",
                "consumer",
                "invariant",
                "failure mode",
                "state that basis",
            )
        ),
    ),
    (
        "failure-semantics-positive-contract",
        ("failure semantics" in lower_text)
        and any(
            term in lower_text
            for term in (
                "propagate",
                "explicit failure",
                "failure/result",
                "partial failure",
                "partial-failure",
            )
        )
        and any(
            term in lower_text
            for term in (
                "observable",
                "visible",
                "failure remains",
                "failure state",
            )
        )
        and any(
            term in lower_text
            for term in (
                "fake success",
                "report fake success",
                "convert failure into success",
            )
        ),
    ),
    (
        "existing-project-regression-protection",
        all(
            term in lower_text
            for term in (
                "existing project",
                "existing implementation",
                "new behavior",
                "legacy behavior",
                "regression evidence",
            )
        ),
    ),
    (
        "existing-path-capability-review-before-adding-behavior",
        all(
            term in lower_text
            for term in (
                "before adding behavior",
                "existing implementation paths",
                "capability owners",
                "callers",
                "contracts",
            )
        ),
    ),
    (
        "shared-code-extraction-is-separate-gated-action",
        all(
            term in lower_text
            for term in (
                "extract shared code only",
                "real duplication",
                "stable contract",
                "reuse abstraction",
            )
        ),
    ),
]
for ambiguous_term in ("semantic equivalent", "semantic reuse", "可复用语义", "reuse or extract"):
    if ambiguous_term in lower_text or ambiguous_term in text:
        raise SystemExit(f"ambiguous code-change reuse term remains: {ambiguous_term}")
missing_semantics = [label for label, present in semantic_checks if not present]
if missing_semantics:
    raise SystemExit(
        "rule missing code-change failure semantics: " + ", ".join(missing_semantics)
    )

allowed_lines = {"", "# Code Changes", *lead, *bullets}
unexpected = [
    f"{index}: {line}"
    for index, line in enumerate(lines, start=1)
    if line not in allowed_lines
]
if unexpected:
    raise SystemExit("rule must remain one lead sentence plus bullets:\n" + "\n".join(unexpected))
PY

python3 - "$ROOT/shared/reference/code-structure-reuse.md" <<'PY' || fail "code structure reuse reference contract violated"
import re
import sys
from pathlib import Path

reference = Path(sys.argv[1])
text = reference.read_text(encoding="utf-8")
lower_text = text.lower()
heading_order = re.findall(r"^## (.+)$", text, flags=re.MULTILINE)
expected_heading_order = [
    "Existing Path Reuse",
    "Complexity Signals",
    "Abstraction Boundaries",
    "Compatibility Code",
]

semantic_checks = [
    (
        "existing-path-first-decision-order",
        heading_order == expected_heading_order,
    ),
    (
        "existing-path-default",
        all(
            term in lower_text
            for term in (
                "existing implementation path",
                "default",
                "legacy behavior",
            )
        ),
    ),
    (
        "extend-existing-before-new-path",
        all(
            term in lower_text
            for term in (
                "compatibly extend the existing path",
                "owns the same capability",
                "new path only",
            )
        ),
    ),
    (
        "abstraction-serves-real-complexity",
        all(
            term in lower_text
            for term in (
                "abstraction is a structural boundary",
                "introduce a boundary as",
                "real duplication",
                "stable invariant",
                "identified change boundary",
                "not the default form of existing-path reuse",
            )
        ),
    ),
    (
        "abstraction-contract-and-evidence-gate",
        all(
            term in lower_text
            for term in (
                "stable contract",
                "verification responsibility",
                "source fact",
                "failure mode",
                "dependency direction complexity",
            )
        ),
    ),
    (
        "reuse-abstraction-change-direction",
        all(
            term in lower_text
            for term in (
                "reuse abstractions",
                "aligned change direction",
                "surface similarity",
                "future speculation",
            )
        ),
    ),
    (
        "compatible-extension-before-new-path",
        all(
            term in lower_text
            for term in (
                "same capability",
                "compatibly extend",
                "old callers",
                "identical behavior",
            )
        ),
    ),
    (
        "new-path-exception-boundary",
        all(
            term in lower_text
            for term in (
                "new path",
                "exception",
                "boundary",
                "removal condition",
            )
        ),
    ),
    (
        "legacy-regression-evidence",
        all(
            term in lower_text
            for term in (
                "callers",
                "state branches",
                "historical compatibility",
                "regression evidence",
            )
        ),
    ),
]
for ambiguous_term in (
    "semantic reuse",
    "可复用语义",
    "share code",
    "matching behavior",
    "behavior/contract matching",
    "behavior and contracts match",
    "behavior and contracts align",
):
    if ambiguous_term in lower_text or ambiguous_term in text:
        raise SystemExit(f"ambiguous reuse term remains: {ambiguous_term}")
missing_semantics = [label for label, present in semantic_checks if not present]
if missing_semantics:
    raise SystemExit("missing structure reuse semantics: " + ", ".join(missing_semantics))
PY

python3 - "$ROOT/shared/reference/code-comments.md" <<'PY' || fail "code comments reference contract violated"
import sys
from pathlib import Path

reference = Path(sys.argv[1])
text = reference.read_text(encoding="utf-8")
lower_text = text.lower()

semantic_checks = [
    (
        "comment-after-clarity-boundary",
        all(term in lower_text for term in ("clearer code", "naming", "extraction", "cannot reveal")),
    ),
    (
        "required-comment-semantics",
        all(
            term in lower_text
            for term in (
                "intent",
                "invariants",
                "boundaries",
                "tradeoffs",
                "failure modes",
                "business rules",
            )
        ),
    ),
    (
        "data-query-comment-semantics",
        all(
            term in lower_text
            for term in (
                "business meaning",
                "allowed values",
                "constraint semantics",
                "why the query",
            )
        ),
    ),
    (
        "state-protocol-comment-semantics",
        all(
            term in lower_text
            for term in (
                "invariant",
                "failure conditions",
                "legal transitions",
                "unsupported cases",
                "removal condition",
            )
        ),
    ),
    (
        "noise-and-stale-comment-guard",
        all(term in lower_text for term in ("obvious assignment", "stale todos", "disagree with implementation")),
    ),
]
missing_semantics = [label for label, present in semantic_checks if not present]
if missing_semantics:
    raise SystemExit("missing code comments semantics: " + ", ".join(missing_semantics))
PY

python3 - "$ROOT/shared/reference/error-handling.md" <<'PY' || fail "error handling reference contract violated"
import sys
from pathlib import Path

reference = Path(sys.argv[1])
text = reference.read_text(encoding="utf-8")
lower_text = text.lower()

semantic_checks = [
    (
        "failure-outcomes",
        all(
            term in lower_text
            for term in (
                "propagate",
                "explicit failure",
                "visible partial failure",
                "manual intervention",
            )
        ),
    ),
    (
        "fallback-boundary",
        all(
            term in lower_text
            for term in (
                "fallback",
                "valid condition",
                "business semantics",
                "observable",
            )
        ),
    ),
    (
        "allowed-continuation-boundary",
        all(
            term in lower_text
            for term in (
                "noncritical",
                "cleanup",
                "rollback",
                "batch partial success",
                "degraded mode",
            )
        ),
    ),
    (
        "fake-success-guard",
        all(
            term in lower_text
            for term in (
                "silent failure",
                "hidden fallback",
                "fake success",
            )
        ),
    ),
]
missing_semantics = [label for label, present in semantic_checks if not present]
if missing_semantics:
    raise SystemExit("missing error handling semantics: " + ", ".join(missing_semantics))
PY

python3 - "$ROOT/shared/reference/performance-and-efficiency.md" <<'PY' || fail "performance reference contract violated"
import sys
from pathlib import Path

reference = Path(sys.argv[1])
text = reference.read_text(encoding="utf-8")
lower_text = text.lower()

semantic_checks = [
    (
        "evidence-first-optimization",
        all(
            term in lower_text
            for term in (
                "observable bottleneck",
                "baseline",
                "before and after",
                "same scenario",
            )
        ),
    ),
    (
        "correctness-contract-preservation",
        all(term in lower_text for term in ("correctness", "behavior", "contract")),
    ),
    (
        "bounded-resource-growth",
        all(
            term in lower_text
            for term in (
                "attempt limits",
                "exit conditions",
                "memory",
                "batch-size",
                "cleanup",
            )
        ),
    ),
    (
        "io-data-growth",
        all(
            term in lower_text
            for term in (
                "pagination",
                "indexes",
                "query plans",
                "n+1",
                "repeated io",
            )
        ),
    ),
    (
        "cache-approval-and-recovery",
        all(
            term in lower_text
            for term in (
                "explicit user approval",
                "invalidation",
                "bypass",
                "rollback",
                "capacity limit",
                "stale data",
            )
        ),
    ),
]
missing_semantics = [label for label, present in semantic_checks if not present]
if missing_semantics:
    raise SystemExit("missing performance semantics: " + ", ".join(missing_semantics))
PY

python3 - "$ROOT/shared/reference/constants-and-configuration.md" <<'PY' || fail "constants reference contract violated"
import sys
from pathlib import Path

reference = Path(sys.argv[1])
text = reference.read_text(encoding="utf-8")
lower_text = text.lower()

semantic_checks = [
    (
        "secret-boundary",
        all(
            term in lower_text
            for term in (
                "secrets",
                "tokens",
                "passwords",
                "credentials",
                "secret storage",
                "never committed",
            )
        ),
    ),
    (
        "environment-config-boundary",
        all(
            term in lower_text
            for term in (
                "environment addresses",
                "ports",
                "deployment differences",
                "configuration",
                "business logic",
            )
        ),
    ),
    (
        "missing-config-visible-failure",
        all(term in lower_text for term in ("missing", "invalid", "explicit failure", "hidden default")),
    ),
    (
        "shared-contract-boundary",
        all(term in lower_text for term in ("stable public contract", "private constants", "ownership boundaries")),
    ),
    (
        "shared-value-change-safety",
        all(term in lower_text for term in ("consumers", "stored data", "compatibility", "migration")),
    ),
]
missing_semantics = [label for label, present in semantic_checks if not present]
if missing_semantics:
    raise SystemExit("missing constants semantics: " + ", ".join(missing_semantics))
PY


python3 - "$ROOT/shared/rules/execution-control.md" <<'PY' || fail "execution control rule shape contract violated"
import sys
from pathlib import Path

rule = Path(sys.argv[1])
text = rule.read_text(encoding="utf-8")
lines = text.splitlines()
if not lines or lines[0] != "# Execution Control":
    raise SystemExit("rule must use the Execution Control title")
if any(line.startswith("## ") for line in lines):
    raise SystemExit("rule must stay flat; process control belongs in one scannable rule")
if "TODO" in text or "TBD" in text:
    raise SystemExit("rule must not contain placeholders")

first_bullet = next((index for index, line in enumerate(lines) if line.startswith("- ")), None)
if first_bullet is None:
    raise SystemExit("rule must contain bullet constraints")
lead = [line for line in lines[1:first_bullet] if line.strip()]
if len(lead) != 1:
    raise SystemExit("rule must have exactly one lead sentence before constraints")

bullets = [line for line in lines if line.startswith("- ")]
if not 18 <= len(bullets) <= 24:
    raise SystemExit(f"rule should stay concise: got {len(bullets)} bullets")
if sum(1 for line in bullets if line.startswith("- Test: ")) != 1:
    raise SystemExit("rule must include exactly one explicit self-test bullet")
long_lines = [str(index) for index, line in enumerate(lines, start=1) if len(line) > 220]
if long_lines:
    raise SystemExit(f"rule lines are too long: {', '.join(long_lines)}")

semantic_checks = [
    (
        "goal-object-boundary-success",
        all(term in text for term in ("goal", "target object", "boundary", "expected result", "observable success criteria")),
    ),
    (
        "ambiguity-no-side-effect",
        all(term in text for term in ("unclear", "affects judgment", "no-side-effect", "pre-scans", "reproduction")),
    ),
    (
        "ordered-process-verification",
        all(term in text for term in ("active skills", "declared contracts", "Do not merge", "Required verification", "prerequisites")),
    ),
    (
        "state-recovery",
        all(term in text for term in ("multi-stage", "verified evidence", "blockers", "remaining items", "recovered goal")),
    ),
    (
        "delegation-boundary",
        all(term in text for term in ("independent ownership", "input", "output", "acceptance", "evidence")),
    ),
    (
        "shared-before-parallel",
        all(term in text for term in ("shared prerequisite", "shared contracts", "shared data writes", "same user path")),
    ),
    (
        "scope-discipline",
        all(term in text for term in ("out-of-scope", "Extra capabilities", "explicit approval", "success criteria")),
    ),
    (
        "completion-claim-link",
        "{{RUNTIME_HOME}}/rules/completion-claims.md" in text and "triggered acceptance items" in text,
    ),
]
missing_semantics = [label for label, present in semantic_checks if not present]
if missing_semantics:
    raise SystemExit("rule missing execution-control semantics: " + ", ".join(missing_semantics))

allowed_lines = {"", "# Execution Control", *lead, *bullets}
unexpected = [
    f"{index}: {line}"
    for index, line in enumerate(lines, start=1)
    if line not in allowed_lines
]
if unexpected:
    raise SystemExit("rule must remain one lead sentence plus bullets:\n" + "\n".join(unexpected))
PY

python3 - "$ROOT/shared/rules/document-governance.md" <<'PY' || fail "document governance rule shape contract violated"
import sys
from pathlib import Path

rule = Path(sys.argv[1])
text = rule.read_text(encoding="utf-8")
lines = text.splitlines()
if not lines or lines[0] != "# Document Governance":
    raise SystemExit("rule must use the Document Governance title")
if any(line.startswith("## ") for line in lines):
    raise SystemExit("rule must stay flat; document governance belongs in one scannable rule")
if "TODO" in text or "TBD" in text:
    raise SystemExit("rule must not contain placeholders")

first_bullet = next((index for index, line in enumerate(lines) if line.startswith("- ")), None)
if first_bullet is None:
    raise SystemExit("rule must contain bullet constraints")
lead = [line for line in lines[1:first_bullet] if line.strip()]
if len(lead) != 1:
    raise SystemExit("rule must have exactly one lead sentence before constraints")

bullets = [line for line in lines if line.startswith("- ")]
if not 18 <= len(bullets) <= 22:
    raise SystemExit(f"rule should stay concise: got {len(bullets)} bullets")
if sum(1 for line in bullets if line.startswith("- Test: ")) != 1:
    raise SystemExit("rule must include exactly one explicit self-test bullet")
long_lines = [str(index) for index, line in enumerate(lines, start=1) if len(line) > 220]
if long_lines:
    raise SystemExit(f"rule lines are too long: {', '.join(long_lines)}")

semantic_checks = [
    (
        "managed-path-rename-sync",
        all(term in text for term in ("managed path", "project-declared scope registries", "entry refs", "fixtures", "recovery paths")),
    ),
    (
        "active-state-single-source",
        all(term in text for term in ("active project state", "project-declared active-doc", "source-of-truth contract", "second source of truth")),
    ),
    (
        "doc-sync-and-stale",
        all(term in text for term in ("behavior", "rules", "contracts", "validation output", "stale doc")),
    ),
    (
        "archive-reference-cleanup",
        all(term in text for term in ("project-declared archive location", "active-doc", "test", "fixture", "validator references")),
    ),
    (
        "managed-archive-recoverable",
        all(term in text for term in ("managed registry entry", "archive metadata", "recoverable handoff pointer")),
    ),
    (
        "handoff-registry-boundary",
        all(term in text for term in ("project-declared active scope registries", "unmanaged docs", "active handoff candidates")),
    ),
    (
        "worklog-navigation-only",
        all(term in text for term in ("worklogs or handoff docs", "navigation", "PRDs", "canonical state")),
    ),
    (
        "canonical-conflict-stop",
        all(term in text for term in ("canonical artifacts", "source-of-truth conflict", "do not choose")),
    ),
    (
        "recovery-validation",
        all(term in text for term in ("project-declared validators", "targeted tests", "reference reachability")),
    ),
]
missing_semantics = [label for label, present in semantic_checks if not present]
if missing_semantics:
    raise SystemExit("rule missing document-governance semantics: " + ", ".join(missing_semantics))

allowed_lines = {"", "# Document Governance", *lead, *bullets}
unexpected = [
    f"{index}: {line}"
    for index, line in enumerate(lines, start=1)
    if line not in allowed_lines
]
if unexpected:
    raise SystemExit("rule must remain one lead sentence plus bullets:\n" + "\n".join(unexpected))
PY

if rg -n 'RUNTIME_(?:ASSISTANT|RULE_[A-Z0-9_]+)_CONTRACT' "$ROOT/shared/assistant.md" "$ROOT/shared/rules" "$ROOT/install.sh" >/dev/null 2>&1; then
  fail "assistant/rules runtime contracts should be inline, not rendered through RUNTIME_*_CONTRACT placeholders"
fi

for path in \
  "reference/协作判断.md" \
  "reference/code-structure-reuse.md" \
  "reference/code-comments.md" \
  "reference/error-handling.md" \
  "reference/测试规范.md" \
  "reference/技术方案设计.md" \
  "reference/impact-analysis.md" \
  "reference/系统调试.md" \
  "reference/全栈开发.md" \
  "reference/performance-and-efficiency.md" \
  "reference/constants-and-configuration.md"; do
  rg -n "\{\{RUNTIME_HOME\}\}/$path" "$ROOT/shared/assistant.md" >/dev/null 2>&1 \
    || fail "missing assistant runtime reference: $path"
done

python3 - "$ROOT/shared/reference/技术方案设计.md" <<'PY' || fail "technical design reference contract violated"
import re
import sys
from pathlib import Path

reference = Path(sys.argv[1])
text = reference.read_text(encoding="utf-8")
lower_text = text.lower()
first_line = text.splitlines()[0] if text.splitlines() else ""
if first_line.removeprefix("# ").strip() != reference.stem:
    raise SystemExit("technical design reference title mismatch")
decision_fields = set(re.findall(r"^- `([a-z0-9_]+)`:", text, flags=re.MULTILINE))
required_decision_fields = (
    "capability_owner",
    "existing_path_reuse",
    "abstraction_decision",
    "new_path_exception",
    "regression_evidence",
    "reference_route",
)
missing = [field for field in required_decision_fields if field not in decision_fields]
if missing:
    raise SystemExit(f"technical design reference missing decision fields: {missing}")
if "技术方案原则.md" in text or "设计原则.md" in text:
    raise SystemExit("technical design reference must not point to retired design names")
if lower_text.count("code-structure-reuse.md") != 1:
    raise SystemExit("technical design should route to structure reuse reference once, not duplicate it")
semantic_checks = [
    (
        "boundary-decision-fields-cover-structure-choices",
        all(
            term in text
            for term in (
                "能力归属",
                "复用路径",
                "抽象边界",
                "新路径例外",
                "回归证据",
            )
        ),
    ),
    (
        "abstraction-decision-is-broader-than-code-reuse",
        all(
            term in text
            for term in (
                "真实重复",
                "稳定不变量",
                "已识别的变化边界",
                "验证责任",
            )
        ),
    ),
]
missing_semantics = [label for label, present in semantic_checks if not present]
if missing_semantics:
    raise SystemExit("technical design reference missing semantics: " + ", ".join(missing_semantics))
PY

rg -n "\{\{RUNTIME_HOME\}\}/rules/completion-claims\.md" "$ROOT/shared/assistant.md" >/dev/null 2>&1 \
  || fail "missing assistant completion rule reference"

if rg -n '补充细则：|只提供补充细则|必要时查看|可参考' "$ROOT/shared/assistant.md" >/dev/null 2>&1; then
  fail "assistant runtime references must be direct read instructions, not weak supplement notes"
fi

python3 - "$ROOT/shared/assistant.md" <<'PY' || fail "assistant best-practice contract violated"
import re
import sys
from pathlib import Path

assistant = Path(sys.argv[1])
text = assistant.read_text(encoding="utf-8")
match = re.search(r"^## Best Practice\n(?P<body>.*?)(?=^## )", text, flags=re.MULTILINE | re.DOTALL)
if not match:
    raise SystemExit("missing Best Practice section")

bullets = [line for line in match.group("body").splitlines() if line.startswith("- ")]
existing_path = next((line for line in bullets if line.startswith("- Existing Path First:")), "")
if not existing_path:
    raise SystemExit("missing Existing Path First best practice")

required_terms = (
    "current implementation path",
    "capability owner",
    "caller contracts",
    "new path",
    "existing path cannot safely carry the change",
)
missing_terms = [term for term in required_terms if term not in existing_path]
if missing_terms:
    raise SystemExit("Existing Path First missing terms: " + ", ".join(missing_terms))
PY

python3 - "$ROOT/shared/assistant.md" <<'PY' || fail "assistant runtime references must keep one reference per item"
import re
import sys
from pathlib import Path

assistant = Path(sys.argv[1])
text = assistant.read_text(encoding="utf-8")
items = [
    paragraph.strip()
    for paragraph in re.split(r"\n(?=- )", text)
    if "{{RUNTIME_HOME}}/reference/" in paragraph
]

violations = []
for item in items:
    refs = re.findall(r"\{\{RUNTIME_HOME\}\}/reference/[^` )，。；]+\.md", item)
    first_line = item.splitlines()[0]
    if len(refs) != 1:
        violations.append(f"{assistant}: expected one reference in item: {first_line}")

if violations:
    print("\n".join(violations), file=sys.stderr)
    raise SystemExit(1)
PY

if rg -n 'reference.*自动加载|自动加载.*reference|runtime 自动加载内容|依赖自动加载|不需挂载|不做正文挂载' "$ROOT/shared" -g '*.md' >/dev/null 2>&1; then
  fail "shared runtime docs must not describe runtime references as automatically loaded"
fi

python3 - "$ROOT/shared/reference/impact-analysis.md" <<'PY' || fail "impact analysis reference contract violated"
import re
import sys
from pathlib import Path

reference = Path(sys.argv[1])
text = reference.read_text(encoding="utf-8")
heading_matches = list(re.finditer(r"^## (.+)$", text, flags=re.MULTILINE))
heading_order = [match.group(1) for match in heading_matches]
required_headings = [
    "Core Rule",
    "Source Atom Denominator",
    "Atom Record Contract",
    "Trace Contract",
    "Decision States",
    "Business Impact Projection",
    "Runtime Verification",
    "Closure Gate",
]
missing_headings = [heading for heading in required_headings if heading not in heading_order]
if missing_headings:
    raise SystemExit(f"missing headings: {', '.join(missing_headings)}")
if heading_order != required_headings:
    raise SystemExit(f"unexpected heading order: {heading_order}")

if re.search(r"<!--\s*contract:", text):
    raise SystemExit("implementation marker comment remains")
sections = {}
for index, match in enumerate(heading_matches):
    start = match.end()
    end = heading_matches[index + 1].start() if index + 1 < len(heading_matches) else len(text)
    sections[match.group(1)] = text[start:end].strip()

empty_sections = [heading for heading in required_headings if not sections[heading]]
if empty_sections:
    raise SystemExit(f"empty sections: {', '.join(empty_sections)}")

minimum_bullets = {
    "Atom Record Contract": 10,
    "Decision States": 6,
    "Business Impact Projection": 5,
    "Closure Gate": 6,
}
for heading, minimum in minimum_bullets.items():
    bullet_count = len(re.findall(r"^- ", sections[heading], flags=re.MULTILINE))
    if bullet_count < minimum:
        raise SystemExit(f"{heading} should contain at least {minimum} bullets")

if "MERGED_DUPLICATE" in text:
    raise SystemExit("impact analysis must not allow merged denominator records")
PY

echo "[PASS] runtime contract inline"

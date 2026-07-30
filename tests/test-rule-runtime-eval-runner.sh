#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT/tools/eval/scripts/run_rule_runtime_eval.py"
UNKNOWN_SCENE_FIXTURE="$ROOT/tests/fixtures/rule-runtime-eval/invalid-unknown-scene.json"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/rule-runtime-eval.XXXXXX")"
REPO="$TMP_ROOT/repo"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

expect_contract_error() {
  local expected_code="$1"
  shift

  set +e
  "$@" >"$TMP_ROOT/stdout" 2>"$TMP_ROOT/stderr"
  local status=$?
  set -e

  test "$status" -eq 2 || fail "expected contract exit 2, got $status"
  python3 - "$TMP_ROOT/stderr" "$expected_code" <<'PY' || fail "missing expected contract error"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("code") != sys.argv[2]:
    raise SystemExit(f"expected {sys.argv[2]!r}, got {payload.get('code')!r}")
PY
}

run_dry() {
  python3 "$RUNNER" \
    --repo-root "$REPO" \
    --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
    --profile focused-v1 \
    --case-source candidate \
    --baseline-ref assistant-entry=f9cbf552 \
    --baseline-ref sql-schema-comments=68abd950 \
    --model gpt-5 \
    --reasoning-effort high \
    --dry-run \
    "$@"
}

git clone -q "$ROOT" "$REPO"
test -f "$UNKNOWN_SCENE_FIXTURE" || fail "missing unknown scene fixture"

DRY_RUN_HOME="$TMP_ROOT/dry-run-home"
mkdir "$DRY_RUN_HOME"
HOME="$DRY_RUN_HOME" run_dry >"$TMP_ROOT/resolution.json"
test -z "$(find "$DRY_RUN_HOME" -mindepth 1 -print -quit)" || fail "dry-run mutated HOME"
python3 - "$TMP_ROOT/resolution.json" <<'PY' || fail "focused dry-run resolution is invalid"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expected_cases = [
    "sql-schema-comments:mysql-create-table-no-comments",
    "assistant-entry:completion-claim-without-tests",
    "assistant-entry:existing-token-auth-copy-pressure",
    "assistant-entry:debug-user-diagnosis-bias",
    "assistant-entry:configuration-secret-hidden-default",
    "assistant-entry:parallel-shared-contract-before-prerequisite",
    "assistant-entry:fullstack-contract-shortcut",
    "assistant-entry:simple-question-lightness",
]
selected = [f"{case['pack_id']}:{case['id']}" for case in payload["selected_cases"]]
if selected != expected_cases:
    raise SystemExit(f"selected cases mismatch: {selected}")
if len(payload["baseline_commits"]) != 2:
    raise SystemExit("expected two baseline commits")
if payload.get("model_calls") != 0:
    raise SystemExit("dry-run recorded model calls")
if payload.get("unverified_scope") != [
    "shared/reference/performance-and-efficiency.md",
    "shared/reference/技术方案设计.md",
    "shared/rules/document-governance.md",
    "shared/rules/execution-control.md",
]:
    raise SystemExit("unverified scope mismatch")
serialized = json.dumps(payload, ensure_ascii=False)
if "prompt" in serialized or "Authorization" in serialized:
    raise SystemExit("resolution output contains sensitive or body content")
PY

set +e
python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --model gpt-5 \
  --reasoning-effort high \
  --dry-run >"$TMP_ROOT/stdout" 2>"$TMP_ROOT/stderr"
status=$?
set -e
test "$status" -eq 2 || fail "missing baseline mapping ran with status $status"
test ! -s "$TMP_ROOT/stdout" || fail "missing baseline mapping produced dry-run output"

expect_contract_error baseline_ref_duplicate run_dry --baseline-ref assistant-entry=f9cbf552
expect_contract_error baseline_ref_unknown run_dry --baseline-ref unknown=f9cbf552
expect_contract_error baseline_ref_malformed run_dry --baseline-ref assistant-entry
expect_contract_error baseline_ref_unresolved python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=does-not-exist \
  --model gpt-5 \
  --reasoning-effort high \
  --dry-run
expect_contract_error case_source_unsupported python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source baseline \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort high \
  --dry-run
expect_contract_error argument_parse_error python3 "$RUNNER"
expect_contract_error argument_parse_error python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort unsupported \
  --dry-run

python3 - "$REPO" "$UNKNOWN_SCENE_FIXTURE" <<'PY'
import json
import sys
from pathlib import Path

repo = Path(sys.argv[1])
unknown_scene = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
path = repo / "tools/eval/scenarios/assistant-entry/evals.json"
payload = json.loads(path.read_text(encoding="utf-8"))
payload["evals"][0]["expected_scene_contracts"] = unknown_scene["expected_scene_contracts"]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_contract_error case_scene_unknown run_dry

git -C "$REPO" checkout -- tools/eval/scenarios/assistant-entry/evals.json
python3 - "$REPO" <<'PY'
import json
import sys
from pathlib import Path

repo = Path(sys.argv[1])
path = repo / "tools/eval/scenarios/assistant-entry/evals.json"
payload = json.loads(path.read_text(encoding="utf-8"))
payload["evals"].append(dict(payload["evals"][0]))
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_contract_error case_id_duplicate run_dry

git -C "$REPO" checkout -- tools/eval/scenarios/assistant-entry/evals.json
for field in expected_behaviors anti_patterns; do
  python3 - "$REPO" "$field" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]) / "tools/eval/scenarios/assistant-entry/evals.json"
payload = json.loads(path.read_text(encoding="utf-8"))
payload["evals"][0][sys.argv[2]] = []
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
  expect_contract_error "case_${field}_missing" run_dry
  git -C "$REPO" checkout -- tools/eval/scenarios/assistant-entry/evals.json
done

python3 - "$REPO" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]) / "tools/eval/scenarios/assistant-entry/evals.json"
payload = json.loads(path.read_text(encoding="utf-8"))
payload.pop("blocking_failures")
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_contract_error pack_blocking_failures_missing run_dry

git -C "$REPO" checkout -- tools/eval/scenarios/assistant-entry/evals.json
python3 - "$REPO" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]) / "tools/eval/scenarios/assistant-entry/evals.json"
payload = json.loads(path.read_text(encoding="utf-8"))
payload["evals"][0]["expected_anchors"] = ["unknown-anchor"]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_contract_error anchor_definition_missing run_dry

git -C "$REPO" checkout -- tools/eval/scenarios/assistant-entry/evals.json
python3 - "$REPO" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]) / "docs/rule-runtime--team-readiness/acceptance-pack.json"
payload = json.loads(path.read_text(encoding="utf-8"))
payload["runtime_sources"].remove("shared/assistant.md")
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_contract_error assistant_runtime_source_missing run_dry

git -C "$REPO" checkout -- docs/rule-runtime--team-readiness/acceptance-pack.json
printf '\n' >> "$REPO/shared/reference/performance-and-efficiency.md"
expect_contract_error dirty_runtime_source_uncovered run_dry

git -C "$REPO" checkout -- shared/reference/performance-and-efficiency.md
printf '\n' >> "$REPO/shared/rules/document-governance.md"
expect_contract_error dirty_runtime_source_uncovered run_dry

git -C "$REPO" checkout -- shared/rules/document-governance.md
printf '\n' >> "$REPO/shared/assistant.md"

SOURCE_CODEX_HOME="$TMP_ROOT/source-codex-home"
FAKE_INSTALLER="$ROOT/tests/fixtures/rule-runtime-eval/fake-install.sh"
EVALUATOR_TMP="$TMP_ROOT/evaluator-tmp"
RESULT_ROOT="tools/eval/results/rule-runtime-eval-test"
RESULT_KEEP_ROOT="tools/eval/results/rule-runtime-eval-test-keep"
FAKE_INSTALL_LOG="$TMP_ROOT/fake-install.log"
mkdir -p "$SOURCE_CODEX_HOME/rules" "$EVALUATOR_TMP"
printf 'placeholder-auth-secret\n' > "$SOURCE_CODEX_HOME/auth.json"
printf 'placeholder-config-secret\n' > "$SOURCE_CODEX_HOME/config.toml"
printf 'forbidden global instruction\n' > "$SOURCE_CODEX_HOME/AGENTS.md"
printf 'forbidden global rule\n' > "$SOURCE_CODEX_HOME/rules/poison.md"
chmod +x "$FAKE_INSTALLER"

run_workspace_prepare() {
  TMPDIR="$EVALUATOR_TMP" FAKE_INSTALL_LOG="$FAKE_INSTALL_LOG" python3 "$RUNNER" \
    --repo-root "$REPO" \
    --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
    --profile focused-v1 \
    --case-source candidate \
    --baseline-ref assistant-entry=f9cbf552 \
    --baseline-ref sql-schema-comments=68abd950 \
    --model gpt-5 \
    --reasoning-effort high \
    --output-root "$RESULT_ROOT" \
    --installer-bin "$FAKE_INSTALLER" \
    --source-codex-home "$SOURCE_CODEX_HOME" \
    "$@"
}

run_workspace_prepare > "$TMP_ROOT/workspace-summary.json"
python3 - "$TMP_ROOT/workspace-summary.json" "$TMP_ROOT/fake-install.log" "$REPO" "$EVALUATOR_TMP" "$RESULT_ROOT" "$SOURCE_CODEX_HOME" <<'PY' || fail "workspace isolation evidence is invalid"
import json
import sys
from pathlib import Path

summary_path, log_path, repo, evaluator_tmp, result_root, source_home = map(Path, sys.argv[1:])
summary = json.loads(summary_path.read_text(encoding="utf-8"))
repo = repo.resolve()
result_root = repo / result_root
source_home = source_home.resolve()

if summary.get("mode") != "workspace_prepared":
    raise SystemExit("workspace preparation mode missing")
serialized = json.dumps(summary, ensure_ascii=False)
for forbidden in ("placeholder-auth-secret", str(source_home / "auth.json")):
    if forbidden in serialized:
        raise SystemExit("sensitive auth data leaked through summary")

candidate = json.loads((result_root / "runtime-manifests" / "candidate.json").read_text(encoding="utf-8"))
if candidate["configuration"]["commit"] != summary["candidate"]["head"]:
    raise SystemExit("candidate commit is not recorded")
if "shared/assistant.md" not in candidate["configuration"]["dirty_paths"]:
    raise SystemExit("candidate dirty runtime path is not recorded")
if not candidate["runtime_source_hashes"]:
    raise SystemExit("candidate runtime hashes are missing")

baselines = summary["baseline_commits"]
for baseline in baselines:
    manifest = json.loads(
        (result_root / "runtime-manifests" / f"baseline-{baseline['commit']}.json").read_text(encoding="utf-8")
    )
    if manifest["configuration"]["commit"] != baseline["commit"]:
        raise SystemExit("baseline commit is not recorded")
    if not manifest["runtime_source_hashes"]:
        raise SystemExit("baseline runtime hashes are missing")
    if manifest["install"]["args"][0] != "bash" or manifest["install"]["args"][-2:] != ["--target", "codex"]:
        raise SystemExit("baseline install command is not recorded")

records = []
for line in log_path.read_text(encoding="utf-8").splitlines():
    records.append(dict(field.split("=", 1) for field in line.split("\t")))
if len(records) != 3:
    raise SystemExit(f"expected three unique installs, got {len(records)}")
homes = [Path(record["HOME"]) for record in records]
codex_homes = [Path(record["CODEX_HOME"]) for record in records]
if len(set(homes)) != len(homes) or len(set(codex_homes)) != len(codex_homes):
    raise SystemExit("runtime homes are not unique")
for record in records:
    if record["ARGS"] != "--target codex":
        raise SystemExit("installer target args changed")
    if (record["AUTH"], record["CONFIG"], record["AGENTS"], record["POISON"]) != ("present", "present", "absent", "absent"):
        raise SystemExit("seeded Codex context is not isolated")
    if Path(record["HOME"]).exists() or Path(record["CODEX_HOME"]).exists():
        raise SystemExit("temporary runtime home survived default cleanup")
candidate_record = next(record for record in records if record["COMMIT"] == candidate["configuration"]["commit"])
if Path(candidate_record["CWD"]).resolve() != repo:
    raise SystemExit("candidate installer did not use the candidate worktree")
for baseline in baselines:
    record = next(record for record in records if record["COMMIT"] == baseline["commit"])
    if Path(record["CWD"]).resolve() == repo:
        raise SystemExit("baseline installer used the candidate worktree")

if list(evaluator_tmp.glob("rule-runtime-eval-*")):
    raise SystemExit("default cleanup retained evaluator workspace roots")
for path in result_root.rglob("*"):
    if path.is_file():
        payload = path.read_text(encoding="utf-8", errors="replace")
        if "placeholder-auth-secret" in payload or str(source_home / "auth.json") in payload:
            raise SystemExit("sensitive auth data leaked through persisted evidence")
PY

: > "$FAKE_INSTALL_LOG"
TMPDIR="$EVALUATOR_TMP" FAKE_INSTALL_LOG="$FAKE_INSTALL_LOG" python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort high \
  --output-root "$RESULT_KEEP_ROOT" \
  --installer-bin "$FAKE_INSTALLER" \
  --source-codex-home "$SOURCE_CODEX_HOME" \
  --keep-workspaces > "$TMP_ROOT/keep-summary.json"
python3 - "$EVALUATOR_TMP" <<'PY' || fail "keep-workspaces did not retain exactly evaluator-owned roots"
import sys
from pathlib import Path

roots = list(Path(sys.argv[1]).glob("rule-runtime-eval-*"))
if len(roots) != 1 or not roots[0].is_dir():
    raise SystemExit("expected one retained evaluator workspace root")
PY

SOURCE_WITHOUT_AUTH="$TMP_ROOT/source-without-auth"
RESULT_NO_AUTH_ROOT="tools/eval/results/rule-runtime-eval-test-no-auth"
mkdir "$SOURCE_WITHOUT_AUTH"
printf 'placeholder-config-secret\n' > "$SOURCE_WITHOUT_AUTH/config.toml"
TMPDIR="$EVALUATOR_TMP" FAKE_INSTALL_LOG="$FAKE_INSTALL_LOG" python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort high \
  --output-root "$RESULT_NO_AUTH_ROOT" \
  --installer-bin "$FAKE_INSTALLER" \
  --source-codex-home "$SOURCE_WITHOUT_AUTH" > "$TMP_ROOT/no-auth-summary.json"
python3 - "$TMP_ROOT/no-auth-summary.json" <<'PY' || fail "missing auth was not marked as an execution blocker"
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if any(item.get("live_execution_status") != "INFRA_BLOCKED" for item in summary["installations"]):
    raise SystemExit("missing auth did not block live execution")
PY

set +e
PYTHONPATH="$ROOT/tools/eval/scripts" python3 - "$TMP_ROOT/outside" "$EVALUATOR_TMP" <<'PY'
import sys
from pathlib import Path

from rule_runtime_eval.workspace import WorkspaceError, cleanup_workspace_root

try:
    cleanup_workspace_root(Path(sys.argv[1]), Path(sys.argv[2]))
except WorkspaceError as exc:
    if exc.code == "workspace_cleanup_outside_parent":
        raise SystemExit(0)
raise SystemExit(1)
PY
cleanup_status=$?
set -e
test "$cleanup_status" -eq 0 || fail "cleanup accepted a non-evaluator path"

printf '[PASS] rule runtime evaluator contract loading and dry-run resolution\n'

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
DRY_OUTPUT_ROOT="tools/eval/results/rule-runtime-eval-dry-run-no-evidence"
mkdir "$DRY_RUN_HOME"
HOME="$DRY_RUN_HOME" run_dry --output-root "$DRY_OUTPUT_ROOT" >"$TMP_ROOT/resolution.json"
test -z "$(find "$DRY_RUN_HOME" -mindepth 1 -print -quit)" || fail "dry-run mutated HOME"
test ! -e "$REPO/$DRY_OUTPUT_ROOT" || fail "dry-run created result evidence"
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
expect_contract_error output_root_outside_repo run_dry --output-root "$TMP_ROOT/outside-results"
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
FAKE_CODEX="$ROOT/tests/fixtures/rule-runtime-eval/fake-codex.py"
EVALUATOR_TMP="$TMP_ROOT/evaluator-tmp"
RESULT_ROOT="tools/eval/results/rule-runtime-eval-test"
RESULT_KEEP_ROOT="tools/eval/results/rule-runtime-eval-test-keep"
FAKE_INSTALL_LOG="$TMP_ROOT/fake-install.log"
mkdir -p "$SOURCE_CODEX_HOME/rules" "$EVALUATOR_TMP"
FOREIGN_PREFIXED_ROOT="$EVALUATOR_TMP/rule-runtime-eval-foreign"
mkdir "$FOREIGN_PREFIXED_ROOT"
printf 'foreign workspace marker\n' > "$FOREIGN_PREFIXED_ROOT/marker"
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
    --codex-bin "$FAKE_CODEX" \
    --source-codex-home "$SOURCE_CODEX_HOME" \
    "$@"
}

FAKE_INSTALL_STDERR="credential=deliberately-sensitive-token source=$SOURCE_CODEX_HOME/auth.json temp=$EVALUATOR_TMP" \
  run_workspace_prepare > "$TMP_ROOT/workspace-summary.json"
python3 - "$TMP_ROOT/workspace-summary.json" "$TMP_ROOT/fake-install.log" "$REPO" "$EVALUATOR_TMP" "$RESULT_ROOT" "$SOURCE_CODEX_HOME" "$FOREIGN_PREFIXED_ROOT" <<'PY' || fail "workspace isolation evidence is invalid"
import json
import sys
from pathlib import Path

summary_path, log_path, repo, evaluator_tmp, result_root, source_home, foreign_root = map(Path, sys.argv[1:])
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

if not foreign_root.is_dir() or not (foreign_root / "marker").is_file():
    raise SystemExit("default cleanup removed a foreign prefixed root")
if [path for path in evaluator_tmp.glob("rule-runtime-eval-*") if path != foreign_root]:
    raise SystemExit("default cleanup retained evaluator workspace roots")
for path in result_root.rglob("*"):
    if path.is_file():
        if path.name == "executor.jsonl":
            continue
        payload = path.read_text(encoding="utf-8", errors="replace")
        if any(
            forbidden in payload
            for forbidden in (
                "placeholder-auth-secret",
                "deliberately-sensitive-token",
                str(source_home / "auth.json"),
                str(evaluator_tmp),
            )
        ):
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
  --codex-bin "$FAKE_CODEX" \
  --source-codex-home "$SOURCE_CODEX_HOME" \
  --keep-workspaces > "$TMP_ROOT/keep-summary.json"
python3 - "$EVALUATOR_TMP" "$FOREIGN_PREFIXED_ROOT" <<'PY' || fail "keep-workspaces did not retain exactly evaluator-owned roots"
import sys
from pathlib import Path

roots = [path for path in Path(sys.argv[1]).glob("rule-runtime-eval-*") if path != Path(sys.argv[2])]
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
  --codex-bin "$FAKE_CODEX" \
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
PYTHONPATH="$ROOT/tools/eval/scripts" python3 - "$FOREIGN_PREFIXED_ROOT" "$EVALUATOR_TMP" <<'PY'
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
test "$cleanup_status" -eq 0 || fail "cleanup accepted a foreign prefixed path"
test -f "$FOREIGN_PREFIXED_ROOT/marker" || fail "cleanup removed a foreign prefixed path"

PYTHONPATH="$ROOT/tools/eval/scripts" python3 - "$REPO" "$EVALUATOR_TMP" <<'PY' || fail "baseline cleanup did not handle validation failures"
import subprocess
import sys
from pathlib import Path

import rule_runtime_eval.workspace as workspace

candidate_root = Path(sys.argv[1]).resolve()
workspace_root = Path(sys.argv[2]) / "baseline-validation-failure"
workspace_root.mkdir()
commit = subprocess.check_output(
    ["git", "-C", str(candidate_root), "rev-parse", "HEAD"], text=True
).strip()
snapshot = workspace_root / "baselines" / commit
original_git_output = workspace._git_output

def fail_validation(repo_root, args, code):
    if args[:1] == ["rev-parse"]:
        raise workspace.WorkspaceError("baseline_ref_unresolved", "forced validation failure")
    return original_git_output(repo_root, args, code)

workspace._git_output = fail_validation
try:
    try:
        workspace._materialize_baseline(candidate_root, workspace_root, commit)
    except workspace.WorkspaceError as exc:
        if exc.code != "baseline_ref_unresolved":
            raise SystemExit(f"unexpected materialization failure: {exc.code}")
    else:
        raise SystemExit("forced baseline validation failure did not occur")
finally:
    workspace._git_output = original_git_output

if snapshot.exists():
    raise SystemExit("baseline snapshot survived a validation failure")
worktrees = subprocess.check_output(
    ["git", "-C", str(candidate_root), "worktree", "list", "--porcelain"], text=True
)
if f"worktree {snapshot}" in worktrees:
    raise SystemExit("Git still tracks the failed baseline worktree")

attempted = []
original_remove = workspace._remove_baseline

def fail_remove(_, target):
    attempted.append(target)
    raise workspace.WorkspaceError("baseline_cleanup_failed", "forced cleanup failure")

first = workspace_root / "first"
second = workspace_root / "second"
workspace._remove_baseline = fail_remove
try:
    try:
        workspace._cleanup_baselines(candidate_root, [first, second])
    except workspace.WorkspaceError:
        pass
    else:
        raise SystemExit("forced baseline cleanup failure did not occur")
finally:
    workspace._remove_baseline = original_remove

if attempted != [second, first]:
    raise SystemExit("baseline cleanup stopped after its first failure")
PY

printf '[PASS] rule runtime evaluator contract loading and dry-run resolution\n'

PYTHONPATH="$ROOT/tools/eval/scripts" python3 - "$ROOT" "$TMP_ROOT" <<'PY'
import sys
from pathlib import Path

from rule_runtime_eval.evidence import classify_route_reads, load_jsonl
from rule_runtime_eval.execution import extract_final_agent_message
from rule_runtime_eval.contracts import load_acceptance_contract

root = Path(sys.argv[1])
tmp = Path(sys.argv[2])
contract = load_acceptance_contract(
    root, root / "docs/rule-runtime--team-readiness/acceptance-pack.json"
)
scene = contract.scene_by_id["collaboration"]
runtime_home = tmp / "runtime-home" / ".codex"

def fixture(name: str) -> list[dict]:
    source = (root / "tests/fixtures/rule-runtime-eval" / name).read_text(encoding="utf-8")
    path = tmp / name
    path.write_text(source.replace("__CODEX_HOME__", str(runtime_home)), encoding="utf-8")
    return load_jsonl(path)

passed_events = fixture("route-read-pass.jsonl")
passed = classify_route_reads(passed_events, (scene,), runtime_home)
if not passed.route_evidence_available or not passed.route_pass:
    raise SystemExit(f"recognized successful reader did not pass: {passed}")
if passed.observed_command_ids != ("command-read",):
    raise SystemExit("successful command event ID was not retained")
if extract_final_agent_message(passed_events) != "final response":
    raise SystemExit("last completed agent message was not extracted")

missed = classify_route_reads(fixture("route-read-miss.jsonl"), (scene,), runtime_home)
if not missed.route_evidence_available or missed.route_pass:
    raise SystemExit(f"route miss was accepted or blocked: {missed}")

unknown = classify_route_reads(fixture("route-read-unknown-shape.jsonl"), (scene,), runtime_home)
if unknown.route_evidence_available or unknown.route_pass:
    raise SystemExit(f"unknown event shape did not fail closed: {unknown}")

compound = [dict(event) for event in passed_events]
compound[0] = dict(compound[0], item=dict(compound[0]["item"], command=f"cat {runtime_home}/reference/协作判断.md; echo ignored"))
compound_route = classify_route_reads(compound, (scene,), runtime_home)
if compound_route.route_evidence_available or compound_route.route_pass:
    raise SystemExit("compound reader command did not fail closed")
PY

EXECUTION_ROOT="tools/eval/results/rule-runtime-eval-execution-test"
FAKE_CODEX_LOG="$TMP_ROOT/fake-codex.log"
FAKE_INSTALL_LOG="$FAKE_INSTALL_LOG" FAKE_CODEX_LOG="$FAKE_CODEX_LOG" python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort high \
  --output-root "$EXECUTION_ROOT" \
  --installer-bin "$FAKE_INSTALLER" \
  --codex-bin "$FAKE_CODEX" \
  --source-codex-home "$SOURCE_CODEX_HOME" > "$TMP_ROOT/execution-summary.json"
python3 - "$REPO" "$EXECUTION_ROOT" "$FAKE_CODEX_LOG" <<'PY' || fail "executor evidence is invalid"
import json
import sys
from collections import defaultdict
from pathlib import Path

repo, result_root, log_path = map(Path, sys.argv[1:])
result_root = repo / result_root
records = [json.loads(line) for line in log_path.read_text(encoding="utf-8").splitlines()]
if not records:
    raise SystemExit("fake Codex was not invoked")
by_prompt = defaultdict(list)
for record in records:
    if record["model"] != "gpt-5" or record["reasoning"] != 'model_reasoning_effort="high"':
        raise SystemExit("model settings drifted between configurations")
    try:
        Path(record["workspace"]).resolve().relative_to(repo.resolve())
    except ValueError:
        pass
    else:
        raise SystemExit("executor used a source-repository case workspace")
    by_prompt[record["prompt_sha256"]].append(record)
if not all(
    len(group) == 2 and len({(item["model"], item["reasoning"]) for item in group}) == 1
    for group in by_prompt.values()
):
    raise SystemExit("candidate and baseline did not receive identical settings")

run = result_root / "runs" / "candidate" / "assistant-entry" / "completion-claim-without-tests"
evidence = json.loads((run / "execution.json").read_text(encoding="utf-8"))
if evidence.get("state") != "EXECUTOR_OK":
    raise SystemExit(f"expected executor success, got {evidence.get('state')}")
if not evidence.get("route", {}).get("route_pass"):
    raise SystemExit("successful fake reader evidence did not route all required contracts")
if not (run / "executor.jsonl").is_file() or not (run / "outputs/response.md").is_file():
    raise SystemExit("raw JSONL or final response is missing")
PY

PYTHONPATH="$ROOT/tools/eval/scripts" FAKE_CODEX_MODE=timeout python3 - "$ROOT" "$TMP_ROOT" "$FAKE_CODEX" <<'PY' || fail "executor failure classification is invalid"
import os
import sys
from pathlib import Path

from rule_runtime_eval.contracts import EvalCase
from rule_runtime_eval.evidence import load_jsonl
from rule_runtime_eval.execution import ExecutionSettings, classify_execution_state, run_executor
from rule_runtime_eval.workspace import RuntimeWorkspace

root, tmp, fake = map(Path, sys.argv[1:])
home = tmp / "timeout-home"
(home / ".codex").mkdir(parents=True)
workspace = RuntimeWorkspace("timeout", root, "test", home, home / ".codex", home / "state", home / "skills", ())
case = EvalCase("assistant-entry", "timeout", "prompt", ("behavior",), ("anti",), ("block",), (), {}, ())
settings = ExecutionSettings(str(fake), "gpt-5", "high", 1)
result = run_executor(case, workspace, tmp / "timeout-run", settings)
if classify_execution_state(result, [], tmp / "timeout-run/outputs/response.md") != "INFRA_BLOCKED_TIMEOUT":
    raise SystemExit("timeout was not classified")
if not (tmp / "timeout-run/executor.jsonl").read_bytes():
    raise SystemExit("timeout did not preserve partial JSONL")
for mode, expected in (
    ("process", "INFRA_BLOCKED_PROCESS"),
    ("missing_output", "INFRA_BLOCKED_MISSING_OUTPUT"),
    ("missing_message", "INFRA_BLOCKED_MISSING_OUTPUT"),
):
    os.environ["FAKE_CODEX_MODE"] = mode
    os.environ["FAKE_CODEX_STDERR"] = "credential=deliberately-sensitive-token"
    run_dir = tmp / f"{mode}-run"
    result = run_executor(case, workspace, run_dir, settings)
    state = classify_execution_state(result, load_jsonl(run_dir / "executor.jsonl"), run_dir / "outputs/response.md")
    if state != expected:
        raise SystemExit(f"{mode} was classified as {state}")
    if "deliberately-sensitive-token" in (run_dir / "executor.log").read_text(encoding="utf-8"):
        raise SystemExit("executor stderr was not redacted")
PY

UNKNOWN_ROOT="tools/eval/results/rule-runtime-eval-unknown-shape-test"
FAKE_INSTALL_LOG="$FAKE_INSTALL_LOG" FAKE_CODEX_MODE=unknown_shape python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort high \
  --output-root "$UNKNOWN_ROOT" \
  --installer-bin "$FAKE_INSTALLER" \
  --codex-bin "$FAKE_CODEX" \
  --source-codex-home "$SOURCE_CODEX_HOME" > "$TMP_ROOT/unknown-summary.json"
python3 - "$REPO" "$UNKNOWN_ROOT" <<'PY' || fail "unknown JSONL shape did not visibly block"
import json
import sys
from pathlib import Path

repo, result_root = map(Path, sys.argv[1:])
evidence = json.loads(
    (repo / result_root / "runs/candidate/assistant-entry/completion-claim-without-tests/execution.json").read_text(
        encoding="utf-8"
    )
)
if evidence.get("state") != "INFRA_BLOCKED_EVENT_SHAPE":
    raise SystemExit(f"unknown event state mismatch: {evidence.get('state')}")
if evidence.get("route", {}).get("route_evidence_available") is not False:
    raise SystemExit("unknown event shape was accepted as route evidence")
PY

printf '[PASS] rule runtime executor and fail-closed route evidence\n'

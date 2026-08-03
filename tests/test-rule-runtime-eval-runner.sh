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
RESULT_INSTALL_DIAGNOSTIC_ROOT="tools/eval/results/rule-runtime-eval-install-diagnostic-test"
FAKE_INSTALL_LOG="$TMP_ROOT/fake-install.log"
mkdir -p "$SOURCE_CODEX_HOME/rules" "$EVALUATOR_TMP"
FOREIGN_PREFIXED_ROOT="$EVALUATOR_TMP/rule-runtime-eval-foreign"
mkdir "$FOREIGN_PREFIXED_ROOT"
printf 'foreign workspace marker\n' > "$FOREIGN_PREFIXED_ROOT/marker"
printf 'placeholder-auth-secret\n' > "$SOURCE_CODEX_HOME/auth.json"
printf 'hooks = ["%s"]\nplugins = ["%s"]\nagent_role = "%s"\nproject = "%s"\nsecret = "placeholder-config-secret"\n' \
  "$TMP_ROOT/source-hook.sh" \
  "$TMP_ROOT/source-plugin" \
  "$TMP_ROOT/source-agent.toml" \
  "$REPO" \
  > "$SOURCE_CODEX_HOME/config.toml"
printf 'forbidden global instruction\n' > "$SOURCE_CODEX_HOME/AGENTS.md"
printf 'forbidden global rule\n' > "$SOURCE_CODEX_HOME/rules/poison.md"
chmod +x "$FAKE_INSTALLER"

PYTHONPATH="$ROOT/tools/eval/scripts" python3 - "$SOURCE_CODEX_HOME" "$TMP_ROOT/seeded-codex-home" <<'PY' || fail "seeded Codex context retained source configuration"
import sys
from pathlib import Path

from rule_runtime_eval.workspace import seed_codex_context

source, target = map(Path, sys.argv[1:])
context = seed_codex_context(source, target)
if context != {"auth_available": True, "config_available": True}:
    raise SystemExit(f"unexpected seeded context: {context}")
if (target / "auth.json").read_text(encoding="utf-8") != "placeholder-auth-secret\n":
    raise SystemExit("authentication was not seeded for live execution")
config = (target / "config.toml").read_text(encoding="utf-8")
if not config.strip() or any(value in config for value in ("hooks", "plugins", "agent_role", "project", "placeholder-config-secret")):
    raise SystemExit("seeded configuration retained source-local runtime settings")
PY

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

PYTHONPATH="$ROOT/tools/eval/scripts" FAKE_INSTALL_LOG="$FAKE_INSTALL_LOG" python3 - "$TMP_ROOT" "$FAKE_INSTALLER" <<'PY' || fail "default installer path evidence is not redacted"
import json
import shutil
import stat
import sys
import tempfile
from pathlib import Path

from rule_runtime_eval.common import run_command
from rule_runtime_eval.workspace import RuntimeWorkspace, _install_evidence, _installer_command, _installer_env

tmp, fake_installer = map(Path, sys.argv[1:])
repo = tmp / "default-installer"
repo.mkdir()
installer = repo / "install.sh"
shutil.copyfile(fake_installer, installer)
installer.chmod(installer.stat().st_mode | stat.S_IXUSR)
workspace = RuntimeWorkspace(
    "default-installer",
    repo,
    "test",
    repo / "runtime" / "home",
    repo / "runtime" / "home" / ".codex",
    repo / "runtime" / "home" / ".org-skills-state",
    repo / "runtime" / "home" / ".agents" / "skills",
    (),
)
workspace.codex_home.mkdir(parents=True)
command = _installer_command(repo, None)
result = run_command(command, cwd=repo, env=_installer_env(workspace), timeout_seconds=5)
evidence = _install_evidence(result, tmp / "source-codex-home", workspace)
if result.returncode != 0 or command[1] != str(installer.resolve()):
    raise SystemExit("default installer was not executed")
serialized = json.dumps(evidence, ensure_ascii=False)
for forbidden in (str(repo.resolve()), str(Path(tempfile.gettempdir()).resolve())):
    if forbidden in serialized:
        raise SystemExit(f"default installer path leaked through persisted args: {forbidden}")
if evidence["args"][0] != "bash" or evidence["args"][-2:] != ["--target", "codex"]:
    raise SystemExit("redacted default installer command lost its stable identity")
PY

: > "$FAKE_INSTALL_LOG"
PYTHON_USER_SITE="$(python3 -c 'import site; print(site.getusersitepackages())')"
INSTALL_STDOUT="$(printf 'FATAL: PyYAML not installed\nAuthorization: Bearer deliberately-sensitive-token\ntoken=deliberately-sensitive-token\nauth body=placeholder-auth-secret\npassword=deliberately-sensitive-password\napi_key=deliberately-sensitive-api-key\nBearer deliberately-sensitive-bearer\ncookie=deliberately-sensitive-cookie\nsession=deliberately-sensitive-session\nsource=%s/auth.json\ntemp=%s\n' "$SOURCE_CODEX_HOME" "$EVALUATOR_TMP")"
FAKE_INSTALL_REQUIRED_PYTHON_USER_SITE="$PYTHON_USER_SITE" \
FAKE_INSTALL_STDOUT="$INSTALL_STDOUT" \
  TMPDIR="$EVALUATOR_TMP" FAKE_INSTALL_LOG="$FAKE_INSTALL_LOG" python3 "$RUNNER" \
    --repo-root "$REPO" \
    --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
    --profile focused-v1 \
    --case-source candidate \
    --baseline-ref assistant-entry=f9cbf552 \
    --baseline-ref sql-schema-comments=68abd950 \
    --model gpt-5 \
    --reasoning-effort high \
    --output-root "$RESULT_INSTALL_DIAGNOSTIC_ROOT" \
    --installer-bin "$FAKE_INSTALLER" \
    --codex-bin "$FAKE_CODEX" \
    --source-codex-home "$SOURCE_CODEX_HOME" > "$TMP_ROOT/install-diagnostic-summary.json"
python3 - "$REPO" "$RESULT_INSTALL_DIAGNOSTIC_ROOT" "$SOURCE_CODEX_HOME" "$EVALUATOR_TMP" <<'PY' || fail "installer dependency path or diagnostic evidence is invalid"
import json
import sys
from pathlib import Path

repo, result_root, source_home, evaluator_tmp = map(Path, sys.argv[1:])
result_root = repo / result_root
for manifest_path in (result_root / "runtime-manifests").glob("*.json"):
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("install", {}).get("returncode") != 0:
        raise SystemExit(f"installer did not receive Python user-site dependency path: {manifest_path}")
    stdout = manifest.get("install", {}).get("stdout", "")
    if "FATAL: PyYAML not installed" not in stdout:
        raise SystemExit("redacted installer stdout omitted the diagnostic")
    if "[redacted]" not in stdout:
        raise SystemExit("redacted installer stdout did not mark withheld content")
    for forbidden in (
        "Authorization",
        "deliberately-sensitive-token",
        "placeholder-auth-secret",
        "deliberately-sensitive-password",
        "deliberately-sensitive-api-key",
        "deliberately-sensitive-bearer",
        "deliberately-sensitive-cookie",
        "deliberately-sensitive-session",
        str(source_home),
        str(evaluator_tmp),
    ):
        if forbidden in stdout:
            raise SystemExit(f"installer stdout leaked {forbidden!r}")
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
if summary.get("model_calls") != 0:
    raise SystemExit("install-blocked configurations counted skipped executor calls")
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
code_changes = contract.scene_by_id["code-changes"]
code_comments = contract.scene_by_id["code-comments"]
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

safe_shell = [
    {
        "type": "item.completed",
        "item": {
            "id": "command-safe-shell",
            "type": "command_execution",
            "command": (
                "/bin/zsh -lc 'cat $HOME/.codex/reference/协作判断.md; "
                "sed -n \"1,3p\" $CODEX_HOME/rules/code-changes.md && "
                "nl -ba .agents/../.codex/reference/code-comments.md'"
            ),
            "exit_code": 0,
            "status": "completed",
            "aggregated_output": "read",
        },
    }
]
safe_shell_route = classify_route_reads(safe_shell, (scene, code_changes, code_comments), runtime_home)
if not safe_shell_route.route_evidence_available or not safe_shell_route.route_pass:
    raise SystemExit(f"safe shell reader commands were not recognized: {safe_shell_route}")
if set(safe_shell_route.read_contract_ids) != {"collaboration", "code-changes", "code-comments"}:
    raise SystemExit("safe shell reader commands lost an installed target")

newline_mixed = [
    {
        "type": "item.completed",
        "item": {
            "id": "command-newline-mixed",
            "type": "command_execution",
            "command": f"/bin/zsh -lc 'cat {runtime_home.resolve()}/reference/协作判断.md\nrm ignored'",
            "exit_code": 0,
            "status": "completed",
            "aggregated_output": "read",
        },
    }
]
newline_mixed_route = classify_route_reads(newline_mixed, (scene,), runtime_home)
if newline_mixed_route.route_evidence_available or newline_mixed_route.route_pass:
    raise SystemExit("newline-separated mixed shell command was accepted as route evidence")

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

awk_begin = [dict(event) for event in passed_events]
awk_begin[0] = dict(
    awk_begin[0],
    item=dict(
        awk_begin[0]["item"],
        command=f"awk 'BEGIN {{ print \"ok\"; exit }}' {runtime_home}/reference/协作判断.md",
    ),
)
awk_begin_route = classify_route_reads(awk_begin, (scene,), runtime_home)
if not awk_begin_route.route_evidence_available or awk_begin_route.route_pass:
    raise SystemExit("awk BEGIN program was not ignored as a valid route miss")

awk_beginfile = [dict(event) for event in passed_events]
awk_beginfile[0] = dict(
    awk_beginfile[0],
    item=dict(
        awk_beginfile[0]["item"],
        command=f"awk 'BEGINFILE {{ exit }}' {runtime_home}/reference/协作判断.md",
    ),
)
awk_beginfile_route = classify_route_reads(awk_beginfile, (scene,), runtime_home)
if not awk_beginfile_route.route_evidence_available or awk_beginfile_route.route_pass:
    raise SystemExit("awk BEGINFILE program was not ignored as a valid route miss")
PY

EXECUTION_ROOT="tools/eval/results/rule-runtime-eval-execution-test"
FAKE_CODEX_LOG="$TMP_ROOT/fake-codex.log"
FAKE_GRADER_LOG="$TMP_ROOT/fake-grader.log"
FAKE_INSTALL_LOG="$FAKE_INSTALL_LOG" FAKE_CODEX_LOG="$FAKE_CODEX_LOG" FAKE_GRADER_LOG="$FAKE_GRADER_LOG" python3 "$RUNNER" \
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
python3 - "$REPO" "$EXECUTION_ROOT" "$FAKE_CODEX_LOG" "$FAKE_GRADER_LOG" "$TMP_ROOT/execution-summary.json" <<'PY' || fail "executor and blind grader evidence is invalid"
import json
import sys
from collections import defaultdict
from pathlib import Path

repo, result_root, log_path, grader_log_path, run_summary_path = map(Path, sys.argv[1:])
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
grading = json.loads((run / "execution.json").read_text(encoding="utf-8"))
if grading.get("grading_state") != "GRADER_OK" or grading.get("grading", {}).get("behavior_verdict") != "PASS":
    raise SystemExit("successful blind grader evidence is missing")
grader_records = [json.loads(line) for line in grader_log_path.read_text(encoding="utf-8").splitlines()]
if not grader_records:
    raise SystemExit("fake blind grader was not invoked")
configured_homes = {Path(record["home"]) for record in records}
for record in grader_records:
    home = Path(record["home"])
    codex_home = Path(record["codex_home"])
    if home in configured_homes:
        raise SystemExit("grader reused a candidate or baseline HOME")
    if (codex_home / "rules").exists() or (codex_home / "reference").exists():
        raise SystemExit("grader HOME contains installed runtime rules")
    if any(forbidden in record["prompt"] for forbidden in ("candidate", "baseline", "git diff")):
        raise SystemExit("grader prompt exposed configuration context")
if not (result_root / "summary.json").is_file() or not (result_root / "summary.md").is_file():
    raise SystemExit("machine or human report projection is missing")
coverage = json.loads((result_root / "coverage.json").read_text(encoding="utf-8"))
comparison = json.loads((result_root / "comparison.json").read_text(encoding="utf-8"))
suite_summary = json.loads((result_root / "summary.json").read_text(encoding="utf-8"))
run_summary = json.loads(run_summary_path.read_text(encoding="utf-8"))
if run_summary.get("model_calls") != len(records) + len(grader_records):
    raise SystemExit("successful executor and grader invocations were not counted")
if coverage != suite_summary.get("coverage"):
    raise SystemExit("standalone coverage projection drifted from summary")
if comparison.get("pairs") != suite_summary.get("pairs"):
    raise SystemExit("standalone comparison projection drifted from summary")
PY

MODEL_CALL_PROCESS_ROOT="tools/eval/results/rule-runtime-eval-model-call-process-test"
FAKE_INSTALL_LOG="$FAKE_INSTALL_LOG" FAKE_CODEX_MODE=process python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort high \
  --output-root "$MODEL_CALL_PROCESS_ROOT" \
  --installer-bin "$FAKE_INSTALLER" \
  --codex-bin "$FAKE_CODEX" \
  --source-codex-home "$SOURCE_CODEX_HOME" > "$TMP_ROOT/model-call-process-summary.json"
python3 - "$TMP_ROOT/model-call-process-summary.json" <<'PY' || fail "failed executor invocations were not counted"
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if summary.get("model_calls") != 16:
    raise SystemExit(f"expected 16 failed executor attempts, got {summary.get('model_calls')!r}")
PY

VERSION_FAILURE_ROOT="tools/eval/results/rule-runtime-eval-version-failure-test"
FAKE_INSTALL_LOG="$FAKE_INSTALL_LOG" FAKE_CODEX_MODE=version_failure python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort high \
  --output-root "$VERSION_FAILURE_ROOT" \
  --installer-bin "$FAKE_INSTALLER" \
  --codex-bin "$FAKE_CODEX" \
  --source-codex-home "$SOURCE_CODEX_HOME" > "$TMP_ROOT/version-failure-summary.json"
python3 - "$REPO" "$VERSION_FAILURE_ROOT" <<'PY' || fail "Codex version failure was accepted as fresh evidence"
import json
import sys
from pathlib import Path

repo, result_root = map(Path, sys.argv[1:])
records = list((repo / result_root / "runs").glob("*/*/*/execution.json"))
if len(records) != 16:
    raise SystemExit(f"expected 16 version-blocked execution records, got {len(records)}")
for path in records:
    evidence = json.loads(path.read_text(encoding="utf-8"))
    if evidence.get("state") != "INFRA_BLOCKED_CODEX_VERSION":
        raise SystemExit(f"{path}: version failure produced {evidence.get('state')!r}")
summary = json.loads((repo / result_root / "summary.json").read_text(encoding="utf-8"))
if any(pair.get("state") != "INFRA_BLOCKED" for pair in summary.get("pairs", [])):
    raise SystemExit("version failure produced a comparable pair")
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

for mode in timeout_malformed process_malformed missing_output_malformed; do
  PRECEDENCE_ROOT="tools/eval/results/rule-runtime-eval-$mode-test"
  FAKE_INSTALL_LOG="$FAKE_INSTALL_LOG" FAKE_CODEX_MODE="$mode" python3 "$RUNNER" \
    --repo-root "$REPO" \
    --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
    --profile focused-v1 \
    --case-source candidate \
    --baseline-ref assistant-entry=f9cbf552 \
    --baseline-ref sql-schema-comments=68abd950 \
    --model gpt-5 \
    --reasoning-effort high \
    --output-root "$PRECEDENCE_ROOT" \
    --installer-bin "$FAKE_INSTALLER" \
    --codex-bin "$FAKE_CODEX" \
    --timeout-sec 1 \
    --source-codex-home "$SOURCE_CODEX_HOME" > "$TMP_ROOT/$mode-summary.json"
  python3 - "$REPO" "$PRECEDENCE_ROOT" "$mode" <<'PY' || fail "execution-state precedence is invalid"
import json
import sys
from pathlib import Path

repo, result_root, mode = sys.argv[1:]
expected = {
    "timeout_malformed": "INFRA_BLOCKED_TIMEOUT",
    "process_malformed": "INFRA_BLOCKED_PROCESS",
    "missing_output_malformed": "INFRA_BLOCKED_MISSING_OUTPUT",
}[mode]
records = list((Path(repo) / result_root / "runs").glob("*/*/*/execution.json"))
if not records:
    raise SystemExit("runner did not write execution records")
for path in records:
    evidence = json.loads(path.read_text(encoding="utf-8"))
    if evidence.get("state") != expected:
        raise SystemExit(f"{path}: expected {expected}, got {evidence.get('state')}")
PY
done

NON_EXECUTABLE_CODEX="$TMP_ROOT/non-executable-codex"
printf '#!/usr/bin/env python3\n' > "$NON_EXECUTABLE_CODEX"
for codex_bin in "$TMP_ROOT/missing-codex" "$NON_EXECUTABLE_CODEX"; do
  launch_name="$(basename "$codex_bin")"
  LAUNCH_FAILURE_ROOT="tools/eval/results/rule-runtime-eval-$launch_name-test"
  FAKE_INSTALL_LOG="$FAKE_INSTALL_LOG" python3 "$RUNNER" \
    --repo-root "$REPO" \
    --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
    --profile focused-v1 \
    --case-source candidate \
    --baseline-ref assistant-entry=f9cbf552 \
    --baseline-ref sql-schema-comments=68abd950 \
    --model gpt-5 \
    --reasoning-effort high \
    --output-root "$LAUNCH_FAILURE_ROOT" \
    --installer-bin "$FAKE_INSTALLER" \
    --codex-bin "$codex_bin" \
    --source-codex-home "$SOURCE_CODEX_HOME" > "$TMP_ROOT/$launch_name-summary.json"
  python3 - "$REPO" "$LAUNCH_FAILURE_ROOT" <<'PY' || fail "Codex version probe failure did not produce per-case infrastructure evidence"
import json
import sys
from pathlib import Path

repo, result_root = map(Path, sys.argv[1:])
records = list((repo / result_root / "runs").glob("*/*/*/execution.json"))
if len(records) != 16:
    raise SystemExit(f"expected one record per candidate/baseline case, got {len(records)}")
for path in records:
    evidence = json.loads(path.read_text(encoding="utf-8"))
    if evidence.get("state") != "INFRA_BLOCKED_CODEX_VERSION":
        raise SystemExit(f"{path}: unexpected version-probe state {evidence.get('state')}")
    if (path.parent / "executor.jsonl").exists() or (path.parent / "executor.log").exists():
        raise SystemExit(f"{path}: executor ran after Codex version probe failed")
PY
done

printf '[PASS] rule runtime executor and fail-closed route evidence\n'

PYTHONPATH="$ROOT/tools/eval/scripts" python3 - "$ROOT" "$TMP_ROOT" <<'PY'
import json
import sys
from pathlib import Path

from rule_runtime_eval.contracts import EvalCase
from rule_runtime_eval.grading import (
    GradingError,
    build_grader_prompt,
    grading_schema,
    validate_grader_output,
    validate_judge_workspace,
)
from rule_runtime_eval.reporting import (
    compare_pair,
    compute_freshness,
    coverage_projection,
    project_suite_decision,
    render_reports,
)
from rule_runtime_eval.workspace import RuntimeWorkspace
from run_rule_runtime_eval import _runner_identity

root = Path(sys.argv[1])
tmp = Path(sys.argv[2])
fixtures = root / "tests/fixtures/rule-runtime-eval"
case = EvalCase(
    "assistant-entry",
    "blind-case",
    "Answer the constrained request.",
    ("Makes the required decision.",),
    ("Claims unsupported rollout readiness.",),
    ("Accepts a dangerous premise.",),
    ("AE-1",),
    {"AE-1": {"id": "AE-1", "anchor": "Decision is explicit and evidence-bound."}},
    ("completion-claims",),
)
grader = "Grade only the supplied response against the structured scenario."
response = "The decision is blocked until direct evidence exists."
prompt = build_grader_prompt(case, grader, response)
for expected in (case.prompt, case.expected_behaviors[0], case.anti_patterns[0], case.blocking_failures[0], "AE-1", response):
    if expected not in prompt:
        raise SystemExit(f"blind prompt omitted required grading input: {expected!r}")
for forbidden in ("candidate", "baseline", "26e63dca", "git diff", "runtime source body"):
    if forbidden in prompt.lower():
        raise SystemExit(f"blind prompt exposed forbidden configuration context: {forbidden!r}")

passed = json.loads((fixtures / "grading-pass.json").read_text(encoding="utf-8"))
validated = validate_grader_output(passed, case)
if validated["behavior_verdict"] != "PASS":
    raise SystemExit("valid grader fixture was not accepted")
contradictory = json.loads((fixtures / "grading-contradictory-pass.json").read_text(encoding="utf-8"))
try:
    validate_grader_output(contradictory, case)
except GradingError:
    pass
else:
    raise SystemExit("aggregate PASS overrode a failed detailed verdict")
schema = grading_schema(case)
if schema["properties"]["anchors"]["items"]["properties"]["score"].get("maximum") != 2:
    raise SystemExit("grader schema does not bound anchor scores")
for mutation, message in (
    (lambda value: value["anchors"][0].update(score=3), "out-of-range anchor score was accepted"),
    (lambda value: value["anchors"][0].update(id="unknown"), "unknown anchor ID was accepted"),
    (lambda value: value["expectations"].pop(), "missing expectation verdict was accepted"),
    (lambda value: value.update(behavior_verdict="Looks good in prose"), "prose verdict was accepted"),
):
    value = json.loads(json.dumps(passed))
    mutation(value)
    try:
        validate_grader_output(value, case)
    except GradingError:
        pass
    else:
        raise SystemExit(message)

root_home = root / "tests/fixtures/rule-runtime-eval"
candidate = RuntimeWorkspace("candidate", root, "candidate", root_home / "candidate", root_home / "candidate/.codex", root_home / "candidate/state", root_home / "candidate/skills", ())
baseline = RuntimeWorkspace("baseline", root, "baseline", root_home / "baseline", root_home / "baseline/.codex", root_home / "baseline/state", root_home / "baseline/skills", ())
judge = RuntimeWorkspace("judge", root, "judge", root_home / "judge", root_home / "judge/.codex", root_home / "judge/state", root_home / "judge/skills", ())
validate_judge_workspace(judge, (candidate, baseline))
try:
    validate_judge_workspace(candidate, (candidate, baseline))
except GradingError:
    pass
else:
    raise SystemExit("candidate runtime was accepted as blind judge home")

identity = {
    "configuration": "candidate-identity",
    "case": "case-identity",
    "grader": "grader-identity",
    "runtime": "runtime-identity",
    "codex": "codex-identity",
    "model": "gpt-5",
    "reasoning": "high",
    "runner": "runner-identity",
}
fresh = compute_freshness({"identity": identity, "execution_state": "EXECUTOR_OK", "route_pass": True, "grading": passed}, identity)
if fresh["state"] != "FRESH_PASS":
    raise SystemExit(f"complete passing evidence was not fresh: {fresh}")
contradictory_freshness = compute_freshness(
    {"identity": identity, "execution_state": "EXECUTOR_OK", "route_pass": True, "grading": contradictory}, identity
)
if contradictory_freshness["state"] != "BEHAVIOR_FAIL":
    raise SystemExit("failed detail verdicts were overridden by an aggregate PASS")
fresh["evidence_path"] = "runs/candidate/blind-case/execution.json"
changed = dict(identity, runner="changed-runner")
if compute_freshness({"identity": identity, "execution_state": "EXECUTOR_OK", "route_pass": True, "grading": passed}, changed)["state"] != "STALE":
    raise SystemExit("identity change did not stale evidence")

candidate_only = compare_pair(case, fresh, None, ("shared/rules/code-changes.md",), ("code-changes",))
if candidate_only["state"] != "MISSING" or candidate_only["attribution"] is not None:
    raise SystemExit("candidate-only evidence was attributed instead of missing")
route_miss = compute_freshness({"identity": identity, "execution_state": "EXECUTOR_OK", "route_pass": False, "grading": passed}, identity)
route_pair = compare_pair(case, route_miss, fresh, (), ())
if route_pair["candidate_outcome"] != "behavior_pass_route_fail":
    raise SystemExit("route miss plus behavior pass did not retain both verdicts")
blocked = json.loads((fixtures / "grading-blocked.json").read_text(encoding="utf-8"))
behavior_fail = compute_freshness({"identity": identity, "execution_state": "EXECUTOR_OK", "route_pass": True, "grading": blocked}, identity)
behavior_pair = compare_pair(case, behavior_fail, fresh, (), ())
if behavior_pair["candidate_outcome"] != "route_pass_behavior_fail":
    raise SystemExit("route pass plus behavior fail did not retain both verdicts")
timeout = compute_freshness({"identity": identity, "execution_state": "INFRA_BLOCKED_TIMEOUT", "route_pass": False}, identity)
if timeout["state"] != "INFRA_BLOCKED":
    raise SystemExit("executor timeout was not projected as infrastructure blocked")

lightness_case = EvalCase("assistant-entry", "simple-question-lightness", "p", ("b",), ("a",), ("block",), ("AE-1",), case.anchor_definitions, ())
lightness_candidate = dict(fresh, irrelevant_successful_reads=5, response_characters=240, grading=dict(passed, added_ceremony_without_decision_value=True))
lightness_baseline = dict(fresh, irrelevant_successful_reads=2, response_characters=100)
lightness_pair = compare_pair(lightness_case, lightness_candidate, lightness_baseline, (), ())
profile = {
    "id": "focused-v1",
    "anchor_threshold": 1.6,
    "marginal_effect_case": "assistant-entry:blind-case",
    "lightness_policy": {
        "case": "assistant-entry:simple-question-lightness",
        "max_irrelevant_read_delta": 2,
        "max_response_length_ratio": 2.0,
        "requires_grader_ceremony_signal": True,
    },
}
decision = project_suite_decision(profile, [behavior_pair, lightness_pair] * 4)
if decision["verdict"] != "FAIL" or not decision["lightness"]["material_regression"]:
    raise SystemExit("blocking failure or configured lightness regression did not fail the suite")

incomplete_lightness_pair = compare_pair(lightness_case, timeout, timeout, (), ())
incomplete_decision = project_suite_decision(profile, [behavior_pair] * 7 + [incomplete_lightness_pair])
if incomplete_decision["lightness"].get("material_regression"):
    raise SystemExit("incomplete lightness evidence was classified as a material regression")
if incomplete_decision["lightness"].get("state") != "INCOMPLETE":
    raise SystemExit("incomplete lightness evidence was not classified as incomplete")
if "lightness case is incomplete" not in incomplete_decision.get("blockers", []):
    raise SystemExit("incomplete lightness evidence did not remain a visible blocker")
if incomplete_decision["verdict"] != "INFRA_BLOCKED":
    raise SystemExit("incomplete required lightness evidence was projected as a behavioral failure")

coverage = coverage_projection(
    ("shared/rules/code-changes.md", "shared/rules/completion-claims.md"),
    [{"case": "assistant-entry:blind-case", "sources": ["shared/rules/code-changes.md"], "freshness": "FRESH_PASS"}],
)
if coverage["uncovered_sources"] != ["shared/rules/completion-claims.md"]:
    raise SystemExit("coverage did not identify runtime sources without fresh selected evidence")

report_root = tmp / "report-projection"
render_reports(report_root, decision, [candidate_only, behavior_pair, lightness_pair], coverage)
summary = (report_root / "summary.md").read_text(encoding="utf-8")
if "rollout readiness" in summary.lower() or "evidence" not in summary.lower():
    raise SystemExit("summary report claimed rollout readiness or omitted evidence links")
if "runs/candidate/blind-case/execution.json" not in summary:
    raise SystemExit("incomplete pair row omitted its available execution evidence link")
if "[execution.json](runs/candidate/blind-case/execution.json)" not in summary:
    raise SystemExit("summary report rendered evidence as a bare path instead of a Markdown link")

runner_source_root = root / "tools/eval/scripts"
runner_sources = {
    str(path.relative_to(runner_source_root)): path
    for path in [
        runner_source_root / "run_rule_runtime_eval.py",
        *sorted((runner_source_root / "rule_runtime_eval").glob("*.py")),
    ]
}
from rule_runtime_eval.common import sha256_file, sha256_json

expected_runner_identity = sha256_json(
    {name: sha256_file(path) for name, path in runner_sources.items()}
)
if _runner_identity() != expected_runner_identity:
    raise SystemExit("runner identity omitted an evaluator source that can change grading or reporting")
PY

printf '[PASS] rule runtime blind grading, freshness, comparison, and reports\n'

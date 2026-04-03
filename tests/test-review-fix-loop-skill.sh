#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

CAPTURE_SCRIPT="$ROOT/claude/skills/review-fix-loop/scripts/capture_baseline.py"
VALIDATE_SCRIPT="$ROOT/claude/skills/review-fix-loop/scripts/validate_review_json.py"
CHECK_SCRIPT="$ROOT/claude/skills/review-fix-loop/scripts/completion_check.sh"

[ -f "$CAPTURE_SCRIPT" ] || fail "missing capture_baseline.py"
[ -f "$VALIDATE_SCRIPT" ] || fail "missing validate_review_json.py"
[ -f "$CHECK_SCRIPT" ] || fail "missing completion_check.sh"

create_repo() {
  local repo_dir="$1"

  mkdir -p "$repo_dir"
  git -C "$repo_dir" init -q
  git -C "$repo_dir" config user.name "Test User"
  git -C "$repo_dir" config user.email "test@example.com"
  printf 'line1\nline2\nline3\n' > "$repo_dir/sample.txt"
  git -C "$repo_dir" add sample.txt
  git -C "$repo_dir" commit -qm "init"
}

assert_json() {
  local json_file="$1"
  local python_check="$2"
  python3 - "$json_file" <<PY
import json
import pathlib

data = json.loads(pathlib.Path("$json_file").read_text())
$python_check
PY
}

run_completion_check() {
  local script_path="$1"
  local transcript_path="$2"
  local session_id="$3"
  local stdout_file="$4"
  local stderr_file="$5"
  local unique_session_id

  HOOK_SESSION_COUNTER="${HOOK_SESSION_COUNTER:-0}"
  HOOK_SESSION_COUNTER=$((HOOK_SESSION_COUNTER + 1))
  unique_session_id="${session_id}-${HOOK_SESSION_COUNTER}-$$"

  printf '{"cwd":"%s","transcript_path":"%s","session_id":"%s"}' \
    "$ROOT" \
    "$transcript_path" \
    "$unique_session_id" \
    | bash "$script_path" >"$stdout_file" 2>"$stderr_file"
}

DIRTY_REPO="$TMP_ROOT/dirty-repo"
create_repo "$DIRTY_REPO"
printf 'line4\n' >> "$DIRTY_REPO/sample.txt"
printf 'staged\n' > "$DIRTY_REPO/staged.txt"
git -C "$DIRTY_REPO" add staged.txt
printf 'draft\n' > "$DIRTY_REPO/draft.txt"

python3 "$CAPTURE_SCRIPT" create --repo "$DIRTY_REPO" > "$TMP_ROOT/dirty-baseline.json"
assert_json "$TMP_ROOT/dirty-baseline.json" '
assert data["baseline_kind"] == "stash"
assert data["stash_sha"]
assert data["tracked_dirty"] is True
assert data["untracked_dirty"] is True
assert data["restore_command"].startswith("git checkout -- . && git stash apply --index ")
'

grep -Fq 'line4' "$DIRTY_REPO/sample.txt" || fail "tracked change should still exist after baseline capture"
[ -f "$DIRTY_REPO/draft.txt" ] || fail "untracked file should still exist after baseline capture"
git -C "$DIRTY_REPO" diff --cached --name-only | grep -Fxq 'staged.txt' || fail "index state should be restored after baseline capture"
dirty_stash_sha="$(python3 -c 'import json, pathlib, sys; print(json.loads(pathlib.Path(sys.argv[1]).read_text())["stash_sha"])' "$TMP_ROOT/dirty-baseline.json")"
[ -n "$dirty_stash_sha" ] || fail "dirty baseline should record stash sha"
[ "$(git -C "$DIRTY_REPO" rev-parse refs/stash)" = "$dirty_stash_sha" ] || fail "recorded stash sha should match refs/stash"

python3 - "$CAPTURE_SCRIPT" <<'PY'
from pathlib import Path
import importlib.util
import sys

module_path = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("capture_baseline_test", module_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

calls = []
status_snapshots = iter(
    [
        "M  sample.txt\0?? draft.txt\0",
        "",
        "M  sample.txt\0",
        "M  sample.txt\0?? draft.txt\0",
    ]
)

class FakeCompleted:
    def __init__(self, stdout=""):
        self.stdout = stdout
        self.stderr = ""
        self.returncode = 0

original_run_git = module.run_git
original_optional_ref = module.optional_ref
original_ensure_repo = module.ensure_repo
original_list_repo_files = module.list_repo_files
original_has_tracked_dirty = module.has_tracked_dirty
original_has_untracked_dirty = module.has_untracked_dirty


def fake_run_git(repo, args, **kwargs):
    calls.append(tuple(args))
    if args == ["rev-parse", "HEAD"]:
        return FakeCompleted("headsha\n")
    if args == ["write-tree"]:
        return FakeCompleted("tree123\n")
    if args == ["status", "--porcelain=1", "-z", "--untracked-files=all"]:
        return FakeCompleted(next(status_snapshots))
    if args[:3] == ["stash", "push", "--include-untracked"]:
        return FakeCompleted("Saved working directory\n")
    if args[:3] == ["stash", "apply", "--index"]:
        raise module.BaselineError("git 命令失败: stash apply --index deadbeef: conflict")
    if args == ["stash", "apply", "deadbeef"]:
        return FakeCompleted("")
    if args == ["read-tree", "tree123"]:
        return FakeCompleted("")
    raise AssertionError(args)


refs = iter([None, "deadbeef"])


def fake_optional_ref(repo, ref):
    return next(refs)


module.run_git = fake_run_git
module.optional_ref = fake_optional_ref
module.ensure_repo = lambda repo: Path("/tmp/repo")
module.list_repo_files = lambda repo: ["sample.txt"]
module.has_tracked_dirty = lambda repo: True
module.has_untracked_dirty = lambda repo: True

try:
    try:
        module.create_baseline(Path("/tmp/repo"))
    except module.BaselineError as exc:
        error = str(exc)
    else:
        raise AssertionError("stash apply --index failure should fail closed")
finally:
    module.run_git = original_run_git
    module.optional_ref = original_optional_ref
    module.ensure_repo = original_ensure_repo
    module.list_repo_files = original_list_repo_files
    module.has_tracked_dirty = original_has_tracked_dirty
    module.has_untracked_dirty = original_has_untracked_dirty

assert ("stash", "apply", "deadbeef") in calls
assert ("read-tree", "tree123") in calls
assert "deadbeef" in error
assert "恢复" in error
PY

printf 'new-file\n' > "$DIRTY_REPO/new-after-baseline.txt"
python3 "$CAPTURE_SCRIPT" list-new-files --repo "$DIRTY_REPO" --baseline "$TMP_ROOT/dirty-baseline.json" > "$TMP_ROOT/new-files.json"
assert_json "$TMP_ROOT/new-files.json" '
assert data["new_files"] == ["new-after-baseline.txt"]
'

CLEAN_REPO="$TMP_ROOT/clean-repo"
create_repo "$CLEAN_REPO"
python3 "$CAPTURE_SCRIPT" create --repo "$CLEAN_REPO" > "$TMP_ROOT/clean-baseline.json"
assert_json "$TMP_ROOT/clean-baseline.json" '
assert data["baseline_kind"] == "head"
assert data["stash_sha"] is None
assert data["restore_command"] == "git checkout -- ."
'

VALIDATION_REPO="$TMP_ROOT/validation-repo"
create_repo "$VALIDATION_REPO"

cat > "$TMP_ROOT/approve.json" <<'EOF_APPROVE'
{"verdict":"approve","findings":[]}
EOF_APPROVE
python3 "$VALIDATE_SCRIPT" --repo "$VALIDATION_REPO" --input "$TMP_ROOT/approve.json" > "$TMP_ROOT/approve.out.json"
assert_json "$TMP_ROOT/approve.out.json" '
assert data["verdict"] == "approve"
assert data["summary"]["total_findings"] == 0
assert data["valid_findings"] == []
'

python3 - "$TMP_ROOT/jsonl-review.jsonl" <<'PY'
import json
import pathlib
import sys

payload = {
    "verdict": "needs-attention",
    "findings": [
        {
            "file": "sample.txt",
            "line_start": 1,
            "line_end": 1,
            "severity": "medium",
            "description": "jsonl finding",
        }
    ],
}
events = [
    {"type": "item.completed", "item": {"type": "agent_message", "text": "prelude"}},
    {
        "type": "item.completed",
        "item": {"type": "agent_message", "text": "```json\n" + json.dumps(payload, ensure_ascii=False) + "\n```"},
    },
]
pathlib.Path(sys.argv[1]).write_text("\n".join(json.dumps(item, ensure_ascii=False) for item in events), encoding="utf-8")
PY
python3 "$VALIDATE_SCRIPT" --repo "$VALIDATION_REPO" --input "$TMP_ROOT/jsonl-review.jsonl" > "$TMP_ROOT/jsonl-review.out.json"
assert_json "$TMP_ROOT/jsonl-review.out.json" '
assert data["verdict"] == "needs-attention"
assert data["summary"]["total_findings"] == 1
assert data["valid_findings"][0]["description"] == "jsonl finding"
'

cat > "$TMP_ROOT/missing-verdict.json" <<'EOF_MISSING'
{"findings":[]}
EOF_MISSING
if python3 "$VALIDATE_SCRIPT" --repo "$VALIDATION_REPO" --input "$TMP_ROOT/missing-verdict.json" > "$TMP_ROOT/missing-verdict.out.json"; then
  fail "missing verdict should fail closed"
fi

cat > "$TMP_ROOT/contradict.json" <<'EOF_CONTRADICT'
{"verdict":"approve","findings":[{"file":"sample.txt","line_start":1,"line_end":1,"severity":"low","description":"unexpected"}]}
EOF_CONTRADICT
if python3 "$VALIDATE_SCRIPT" --repo "$VALIDATION_REPO" --input "$TMP_ROOT/contradict.json" > "$TMP_ROOT/contradict.out.json"; then
  fail "approve with findings should fail closed"
fi

cat > "$TMP_ROOT/warnings.json" <<'EOF_WARNINGS'
{
  "verdict": "needs-attention",
  "findings": [
    {"file": "../escape.txt", "line_start": 1, "line_end": 1, "severity": "low", "description": "path traversal"},
    {"file": "sample.txt", "line_start": 2, "line_end": 1, "severity": "medium", "description": "bad range"},
    {"file": "sample.txt", "line_start": 1, "line_end": 1, "severity": "warn", "description": "bad severity"},
    {"file": "sample.txt", "line_start": 2, "line_end": 2, "severity": "medium", "description": "real finding"}
  ]
}
EOF_WARNINGS
python3 "$VALIDATE_SCRIPT" --repo "$VALIDATION_REPO" --input "$TMP_ROOT/warnings.json" > "$TMP_ROOT/warnings.out.json"
assert_json "$TMP_ROOT/warnings.out.json" '
assert data["verdict"] == "needs-attention"
assert len(data["warnings"]) == 3
assert len(data["valid_findings"]) == 1
assert data["valid_findings"][0]["file"] == "sample.txt"
assert data["valid_findings"][0]["line_start"] == 2
'

SYMLINK_REPO="$TMP_ROOT/symlink-repo"
OUTSIDE_DIR="$TMP_ROOT/outside"
create_repo "$SYMLINK_REPO"
mkdir -p "$OUTSIDE_DIR"
printf 'outside\n' > "$OUTSIDE_DIR/escape.txt"
ln -s "$OUTSIDE_DIR/escape.txt" "$SYMLINK_REPO/escape.txt"
cat > "$TMP_ROOT/symlink.json" <<'EOF_SYMLINK'
{
  "verdict": "needs-attention",
  "findings": [
    {"file": "escape.txt", "line_start": 1, "line_end": 1, "severity": "medium", "description": "symlink escape"}
  ]
}
EOF_SYMLINK
if python3 "$VALIDATE_SCRIPT" --repo "$SYMLINK_REPO" --input "$TMP_ROOT/symlink.json" > "$TMP_ROOT/symlink.out.json"; then
  fail "symlink escape should fail closed"
fi
grep -Eq 'fail-close|repo 外|仓库外' "$TMP_ROOT/symlink.out.json" || fail "symlink escape failure should explain the repo boundary"

cat > "$TMP_ROOT/unlocatable-high.json" <<'EOF_HIGH'
{
  "verdict": "needs-attention",
  "findings": [
    {"file": "sample.txt", "line_start": 99, "line_end": 99, "severity": "high", "description": "cannot locate"}
  ]
}
EOF_HIGH
if python3 "$VALIDATE_SCRIPT" --repo "$VALIDATION_REPO" --input "$TMP_ROOT/unlocatable-high.json" > "$TMP_ROOT/unlocatable-high.out.json"; then
  fail "unlocatable high-severity finding should fail closed"
fi

cat > "$TMP_ROOT/all-unlocatable-low.json" <<'EOF_LOW'
{
  "verdict": "needs-attention",
  "findings": [
    {"file": "sample.txt", "line_start": 77, "line_end": 77, "severity": "low", "description": "cannot locate"}
  ]
}
EOF_LOW
if python3 "$VALIDATE_SCRIPT" --repo "$VALIDATION_REPO" --input "$TMP_ROOT/all-unlocatable-low.json" > "$TMP_ROOT/all-unlocatable-low.out.json"; then
  fail "all-unlocatable findings should fail closed"
fi

PASS_TRANSCRIPT="$TMP_ROOT/pass-transcript.txt"
cat > "$PASS_TRANSCRIPT" <<'EOF_PASS_TRANSCRIPT'
中间过程输出

=== 循环结束 ===
结果：通过
总轮次：1
起始 SHA：abc1234
基线 stash SHA：无
循环新增文件：[]
EOF_PASS_TRANSCRIPT
if ! run_completion_check "$CHECK_SCRIPT" "$PASS_TRANSCRIPT" "review-fix-source-pass" "$TMP_ROOT/completion-pass.out" "$TMP_ROOT/completion-pass.err"; then
  fail "completion check should accept a valid final block from the source tree"
fi
[ ! -s "$TMP_ROOT/completion-pass.out" ] || fail "successful completion check should not emit a block decision"

INCOMPLETE_TRANSCRIPT="$TMP_ROOT/incomplete-transcript.txt"
cat > "$INCOMPLETE_TRANSCRIPT" <<'EOF_INCOMPLETE_TRANSCRIPT'
示例模板：
=== 循环结束 ===
结果：通过
总轮次：1
起始 SHA：abc1234
基线 stash SHA：无
循环新增文件：[]

实际最后输出：
处理中，尚未结束
EOF_INCOMPLETE_TRANSCRIPT
if run_completion_check "$CHECK_SCRIPT" "$INCOMPLETE_TRANSCRIPT" "review-fix-source-fail" "$TMP_ROOT/completion-fail.out" "$TMP_ROOT/completion-fail.err"; then
  fail "completion check should reject transcripts whose final block is only an earlier template"
fi
grep -q '最终输出块' "$TMP_ROOT/completion-fail.err" || fail "completion check should explain the final-block failure"
grep -q '"decision":"block"' "$TMP_ROOT/completion-fail.out" || fail "completion check should block on invalid final blocks"

RUNTIME_HOME="$TMP_ROOT/runtime-home/.claude"
mkdir -p "$RUNTIME_HOME/skills" "$RUNTIME_HOME/hooks/lib"
cp -R "$ROOT/claude/skills/review-fix-loop" "$RUNTIME_HOME/skills/"
cp "$ROOT/shared/hooks/lib/common.sh" "$RUNTIME_HOME/hooks/lib/common.sh"
RUNTIME_CHECK_SCRIPT="$RUNTIME_HOME/skills/review-fix-loop/scripts/completion_check.sh"
if ! run_completion_check "$RUNTIME_CHECK_SCRIPT" "$PASS_TRANSCRIPT" "review-fix-runtime-pass" "$TMP_ROOT/runtime-pass.out" "$TMP_ROOT/runtime-pass.err"; then
  fail "runtime-installed completion check should accept a valid final block"
fi
[ ! -s "$TMP_ROOT/runtime-pass.out" ] || fail "runtime completion check should not emit a block decision on success"

echo "[PASS] review-fix-loop skill helpers"

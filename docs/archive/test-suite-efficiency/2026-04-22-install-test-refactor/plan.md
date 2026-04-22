# Install Test Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Replace the slow monolithic install tests with a quality-preserving, domain-split install test suite and a single full/quick/profile/list runner.

**Architecture:** Add a focused install-test helper for isolated HOME setup, real install execution, per-case logging, assertions, and process-local baseline cloning. Migrate old systematic/runtime-audit cases into core, runtime-smoke, safety, runtime, and migration scripts, then update `tests/run-all.sh` and README to use only the new entrypoints.

**Tech Stack:** Bash test scripts, `install.sh`, existing `tests/lib/test-env.sh`, `jq`, shellcheck, `tools/community/check_task_plan_consistency.py`.

---

### Task 1: Lock runner and install-test migration contracts [T1]

Context: Start with RED coverage for the new runner contract. This task changes tests only and should fail before the runner and new install scripts exist.

Files:
- Modify: `tests/test-run-all-runner-contract.sh`
- Test: `tests/test-run-all-runner-contract.sh`

1. [T1] Replace the runner contract with assertions for the new install test files

Use this shape in `tests/test-run-all-runner-contract.sh`:

```bash
full_plan="$(bash "$RUNNER" --list)"
assert_contains "mode=full" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-core.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-runtime-smoke.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-safety.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-runtime.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-migration.sh" "$full_plan" "full plan"
assert_not_contains "test-install-systematic.sh" "$full_plan" "full plan"
assert_not_contains "test-install-runtime-audit.sh" "$full_plan" "full plan"

quick_plan="$(bash "$RUNNER" --quick --list)"
assert_contains "mode=quick" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-install-core.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-install-runtime-smoke.sh" "$quick_plan" "quick plan"
assert_not_contains "test-install-safety.sh" "$quick_plan" "quick plan"
assert_not_contains "test-install-runtime.sh" "$quick_plan" "quick plan"
assert_not_contains "test-install-migration.sh" "$quick_plan" "quick plan"
assert_not_contains "test-install-systematic.sh" "$quick_plan" "quick plan"
assert_not_contains "test-install-runtime-audit.sh" "$quick_plan" "quick plan"
```

2. [T1] Add profile/list/unknown-option contract checks

Keep the existing help and unknown-option assertions, and add list-only checks that do not create install output:

```bash
assert_contains "--full" "$help_output" "help output"
assert_contains "--quick" "$help_output" "help output"
assert_contains "--profile" "$help_output" "help output"
assert_contains "--list" "$help_output" "help output"
assert_contains "steps=" "$full_plan" "full plan"
assert_contains "steps=" "$quick_plan" "quick plan"
```

3. [T1] Run the runner contract and confirm RED

Run: `bash tests/test-run-all-runner-contract.sh`
Expected: FAIL because `tests/run-all.sh --list` still contains the old install systematic/runtime-audit entries and does not yet contain all new install entries.

### Task 2: Add install-test helper and migrate quick install coverage [T2]

Context: Build the shared test environment before moving scenarios. The helper must run real `install.sh`; it can clone a process-local baseline, but it must not create cross-run cache state.

Files:
- Create: `tests/lib/install-test-env.sh`
- Create: `tests/test-install-core.sh`
- Create: `tests/test-install-runtime-smoke.sh`
- Test: `tests/lib/install-test-env.sh`
- Test: `tests/test-install-core.sh`
- Test: `tests/test-install-runtime-smoke.sh`

1. [T2] Create `tests/lib/install-test-env.sh`

Define these functions and source existing fake openspec helpers:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"

INSTALL_TEST_TMP_ROOT=""
INSTALL_TEST_CURRENT_CASE=""
INSTALL_TEST_BASELINE_HOME=""

install_test_fail() {
  printf '[FAIL] %s\n' "$*" >&2
  if [ -n "${INSTALL_TEST_CURRENT_LOG:-}" ] && [ -f "$INSTALL_TEST_CURRENT_LOG" ]; then
    printf 'install log: %s\n' "$INSTALL_TEST_CURRENT_LOG" >&2
    tail -40 "$INSTALL_TEST_CURRENT_LOG" >&2 || true
  fi
  exit 1
}

install_test_case_start() {
  INSTALL_TEST_CURRENT_CASE="$1"
  printf '[CASE] %s\n' "$INSTALL_TEST_CURRENT_CASE"
}

install_test_case_pass() {
  printf '[PASS] %s\n' "$1"
}

install_test_init() {
  INSTALL_TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/org-install-tests.XXXXXX")"
  trap install_test_cleanup EXIT
}

install_test_cleanup() {
  if [ "${KEEP_TEST_HOME:-0}" = "1" ]; then
    printf '[KEEP_TEST_HOME] %s\n' "$INSTALL_TEST_TMP_ROOT"
    return 0
  fi
  [ -z "${INSTALL_TEST_TMP_ROOT:-}" ] || rm -rf "$INSTALL_TEST_TMP_ROOT"
}

install_test_new_home() {
  local name="$1"
  local home_dir="$INSTALL_TEST_TMP_ROOT/$name"
  mkdir -p "$home_dir/.claude" "$home_dir/.codex"
  printf '{"hooks":{}}\n' > "$home_dir/.claude/settings.json"
  printf 'model = "gpt-5"\n' > "$home_dir/.codex/config.toml"
  printf '%s\n' "$home_dir"
}

install_test_state_root() {
  printf '%s/.org-skills-state\n' "$1"
}

install_test_run_install() {
  local home_dir="$1"
  local log_file="$2"
  shift 2
  INSTALL_TEST_CURRENT_LOG="$log_file"
  env HOME="$home_dir" ORG_STATE_ROOT="$(install_test_state_root "$home_dir")" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" "$@" >"$log_file" 2>&1
}

install_test_run_install_fake_openspec() {
  local home_dir="$1"
  local log_file="$2"
  shift 2
  INSTALL_TEST_CURRENT_LOG="$log_file"
  run_with_fake_openspec "$home_dir" env HOME="$home_dir" ORG_STATE_ROOT="$(install_test_state_root "$home_dir")" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" "$@" >"$log_file" 2>&1
}

install_test_create_baseline_home() {
  local name="${1:-baseline}"
  INSTALL_TEST_BASELINE_HOME="$(install_test_new_home "$name")"
  install_test_run_install_fake_openspec "$INSTALL_TEST_BASELINE_HOME" "$INSTALL_TEST_TMP_ROOT/${name}.log" --target all --force --check quick
  printf '%s\n' "$INSTALL_TEST_BASELINE_HOME"
}

install_test_clone_baseline_home() {
  local name="$1"
  local target="$INSTALL_TEST_TMP_ROOT/$name"
  [ -n "$INSTALL_TEST_BASELINE_HOME" ] || install_test_fail "baseline home has not been created"
  cp -a "$INSTALL_TEST_BASELINE_HOME" "$target"
  printf '%s\n' "$target"
}

install_test_assert_file_exists() {
  [ -f "$1" ] || install_test_fail "$2: expected file exists at $1"
}

install_test_assert_file_absent() {
  [ ! -e "$1" ] || install_test_fail "$2: expected path absent at $1"
}

install_test_assert_file_contains() {
  grep -Fq "$2" "$1" || install_test_fail "$3: expected '$2' in $1"
}
```

2. [T2] Create `tests/test-install-core.sh` with quick-safe install protocol cases

Move these old systematic scenarios into `core` with `core:` case names:

```text
无 openspec CLI 依赖
dry-run 无副作用
冲突阻断生效
幂等安装生效
同版本安装会修复 product split skill 缺失
codex 同版本重装不覆盖 developer skill 本地修改
```

Use `install_test_new_home`, `install_test_run_install`, `install_test_run_install_fake_openspec`, and `run_without_openspec`. Keep the old assertions and output messages, but replace raw `/tmp/org_install_*.out` files with `$INSTALL_TEST_TMP_ROOT/<case>.log`.

3. [T2] Create `tests/test-install-runtime-smoke.sh` with fast runtime shape checks

Cover the quick runtime shape currently spread across `tests/test-install-smoke.sh` and the systematic idempotent case:

```text
Claude CLAUDE.md and key skills exist
Codex AGENTS.md and key skills exist
verify-change scripts exist in both runtimes
critical hooks/config files exist and are executable
developer.toml has concrete HOME and no {{HOME}}
installed-version metadata exists in external state root
legacy .org runtime metadata is absent
```

4. [T2] Run quick install tests

Run: `bash tests/test-install-core.sh`
Expected: PASS with only `[PASS] core: ...` case output.

Run: `bash tests/test-install-runtime-smoke.sh`
Expected: PASS with only `[PASS] runtime-smoke: ...` case output.

5. [T2] Run syntax checks for the helper and quick tests

Run: `bash -n tests/lib/install-test-env.sh tests/test-install-core.sh tests/test-install-runtime-smoke.sh`
Expected: no output.

### Task 3: Migrate full-only install coverage and delete old slow entries [T3]

Context: Move the safety, runtime repair, and migration cases out of the monolith. Do not use baseline clones for migration or safety cases.

Files:
- Create: `tests/test-install-safety.sh`
- Create: `tests/test-install-runtime.sh`
- Create: `tests/test-install-migration.sh`
- Create: `docs/test-suite-efficiency/2026-04-22-install-test-refactor/install-test-scenario-map.md`
- Delete: `tests/test-install-systematic.sh`
- Delete: `tests/test-install-runtime-audit.sh`
- Test: `tests/test-install-safety.sh`
- Test: `tests/test-install-runtime.sh`
- Test: `tests/test-install-migration.sh`

1. [T3] Create `tests/test-install-safety.sh`

Move these old systematic safety scenarios into `safety`:

```text
卸载安全保护生效
安装失败回滚生效
codex 卸载保留用户 hooks 并恢复 config baseline
codex 卸载恢复非标准 hooks 基线
卸载后状态目录清理生效
重复覆盖安装仍保留原始恢复基线
```

Each case must use `fresh-home` and keep old assertions against user-file preservation, rollback, uninstall cleanup, and config restoration.

2. [T3] Create `tests/test-install-runtime.sh`

Move runtime repair and cleanup cases into `runtime`:

```text
Claude hooks 默认合并并可恢复 baseline
codex toml 占位符替换生效
codex hooks.json 失效临时探针清理生效
退役 skill 残留清理生效
install runtime audit legacy residue cleanup
install retired skill-auditor cleanup
```

Use `baseline-clone` only for local-damage-and-repair cases. Keep `install runtime audit legacy residue cleanup` assertions from `tests/test-install-runtime-audit.sh`, and keep retired skill cleanup assertions from `tests/test-install-retired-skill-cleanup.sh` or leave that existing test in full if duplicating would reduce clarity.

3. [T3] Create `tests/test-install-migration.sh`

Move migration and legacy-state cases into `migration`:

```text
退役 product 软链接技能清理生效
旧版本遗留受管文件清理与恢复生效
运行目录旧元数据迁移生效
旧 .claude git 退役生效
```

Each case must use `constructed-legacy-home`.

4. [T3] Write the scenario mapping document

Create `docs/test-suite-efficiency/2026-04-22-install-test-refactor/install-test-scenario-map.md` with one row for every old `pass "..."` string from `tests/test-install-systematic.sh` and one row for `tests/test-install-runtime-audit.sh`.

The table columns must be:

```text
旧脚本 | 旧 case / pass 文案 | 新测试文件 | 环境类型 | quick/full | 保留的质量断言 | 处理状态
```

Use only these status values:

```text
migrated
merged-stronger
deleted-retired
deleted-duplicate
```

5. [T3] Delete old slow entry scripts after the new tests pass

Delete:

```text
tests/test-install-systematic.sh
tests/test-install-runtime-audit.sh
```

Do not delete `tests/test-install-smoke.sh` or `tests/test-install-retired-skill-cleanup.sh` unless their coverage is intentionally absorbed and the runner no longer needs them.

6. [T3] Run full-only install tests

Run: `bash tests/test-install-safety.sh`
Expected: PASS.

Run: `bash tests/test-install-runtime.sh`
Expected: PASS.

Run: `bash tests/test-install-migration.sh`
Expected: PASS.

### Task 4: Update runner, docs, and syntax/shell quality gates [T4]

Context: Once new tests exist, make `tests/run-all.sh` the single truth. Default remains full; quick explicitly selects fast install coverage.

Files:
- Modify: `tests/run-all.sh`
- Modify: `tests/test-run-all-runner-contract.sh`
- Modify: `README.md`
- Test: `tests/run-all.sh`
- Test: `tests/test-run-all-runner-contract.sh`

1. [T4] Update `tests/run-all.sh` shell file lists

Replace old install files in `SYNTAX_SHELL_FILES` and `FULL_TESTS` with:

```bash
"tests/lib/install-test-env.sh"
"tests/test-install-core.sh"
"tests/test-install-runtime-smoke.sh"
"tests/test-install-safety.sh"
"tests/test-install-runtime.sh"
"tests/test-install-migration.sh"
```

Remove:

```bash
"tests/test-install-systematic.sh"
"tests/test-install-runtime-audit.sh"
```

2. [T4] Replace extended-test skip logic with quick include logic

Use a helper that treats full-only install tests as excluded from quick:

```bash
is_full_only_test() {
  case "$1" in
    "tests/test-install-safety.sh"|"tests/test-install-runtime.sh"|"tests/test-install-migration.sh")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}
```

In `build_plan`, skip `is_full_only_test` only when `MODE=quick`.

3. [T4] Keep list/profile semantics unchanged

Preserve:

```text
--list executes build_plan only and exits before run_plan
--profile measures each executed step
unknown options call fail
```

4. [T4] Update README test commands

Document:

```text
bash tests/run-all.sh
bash tests/run-all.sh --quick
bash tests/run-all.sh --profile
bash tests/run-all.sh --quick --profile
bash tests/run-all.sh --list
```

State that `run-all.sh` defaults to full and that delivery/merge readiness requires full.

5. [T4] Run runner and shell quality gates

Run: `bash tests/run-all.sh --list`
Expected: PASS output contains new install tests and no old systematic/runtime-audit scripts.

Run: `bash tests/run-all.sh --quick --list`
Expected: PASS output contains core and runtime-smoke, excludes safety/runtime/migration.

Run: `bash tests/test-run-all-runner-contract.sh`
Expected: PASS.

Run: `bash -n tests/run-all.sh tests/lib/install-test-env.sh tests/test-install-*.sh`
Expected: no output.

Run: `shellcheck -x tests/run-all.sh tests/lib/install-test-env.sh tests/test-install-*.sh`
Expected: no output.

Run: `git diff --check`
Expected: no output.

### Task 5: Prove quality and efficiency end to end [T5]

Context: Close the small-chain with fresh evidence. If the current worktree has a pre-existing non-install failure, report it separately instead of hiding it.

Files:
- Test: `docs/test-suite-efficiency/2026-04-22-install-test-refactor/tasks.md`
- Test: `docs/test-suite-efficiency/2026-04-22-install-test-refactor/plan.md`
- Test: `tests/run-all.sh`

1. [T5] Run task-plan consistency

Run: `python3 tools/community/check_task_plan_consistency.py docs/test-suite-efficiency/2026-04-22-install-test-refactor/tasks.md docs/test-suite-efficiency/2026-04-22-install-test-refactor/plan.md`
Expected: PASS with 5 tasks.

2. [T5] Run quick profile proof

Run: `bash tests/run-all.sh --quick --profile`
Expected: PASS. Output must not include `test-install-systematic.sh` or `test-install-runtime-audit.sh`.

3. [T5] Run full profile proof

Run: `bash tests/run-all.sh --profile`
Expected: PASS, or fail only on a clearly identified pre-existing non-install blocker. Output must not include a single 500s+ `test-install-systematic.sh` step.

4. [T5] Update `tasks.md` checkboxes after evidence passes

Mark T1-T5 as `[x]` only after their AC commands have fresh passing evidence or a documented pre-existing blocker for the full run.

5. [T5] Run final diff hygiene check

Run: `git diff --check`
Expected: no output.

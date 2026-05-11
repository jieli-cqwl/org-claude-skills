# Test Signal Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the repository test gate so quick is fast and high-signal, full remains comprehensive, release/install owns heavy runtime integration, and static wording freezes no longer masquerade as quality tests.

**Architecture:** Keep existing shell-based orchestration but make `tests/run-all.sh` model test tiers explicitly. Preserve high-value behavior tests while moving slow install/runtime checks out of quick and replacing the first proven wording-freeze failure with a narrower contract check. CI uses the appropriate tier instead of always running full.

**Tech Stack:** Bash, GitHub Actions YAML, ripgrep (`rg`), jq, existing repository shell/Python tests.

---

## File Structure

- Modify `tests/run-all.sh`
  - Add explicit modes: `quick`, `full`, `release`.
  - Keep `full` as default for backward compatibility.
  - Make quick exclude heavy install/runtime tests and static wording-freeze tests.
  - Keep full comprehensive and release install-heavy.
  - Add an optional profiling mode that preserves failure status while making elapsed-time output reliable.
- Modify `tests/test-run-all-runner-contract.sh`
  - Update runner contract expectations for the new tier model.
  - Assert heavy install/runtime tests are absent from quick and present in release/full where appropriate.
  - Assert static wording-freeze tests are absent from quick but still present in full until individually cleaned.
- Modify `tests/test-product-stability-guidance-contract.sh`
  - Remove duplicated brittle title wording checks for `每轮对话节奏`.
  - Replace them with a behavior-relevant structure check that validates the conversation guide still has a per-turn rhythm section and required response modes.
  - Keep existing jq/schema/hook contract checks.
- Modify `.github/workflows/test.yml`
  - Run quick gate for push/pull_request by default.
  - Run full gate separately only where explicitly configured in this plan.
- Modify `.github/workflows/release.yml`
  - Run release gate before release-specific checks.
- No new docs beyond this plan unless implementation reveals a contract change that existing docs must reflect.

## Success Criteria

1. `bash tests/run-all.sh --quick --list` excludes heavy install/runtime tests and static wording-freeze tests.
2. `bash tests/run-all.sh --full --list` remains comprehensive and includes the full regression suite.
3. `bash tests/run-all.sh --release --list` includes install/runtime/release-heavy checks.
4. `bash tests/test-run-all-runner-contract.sh` passes and proves tier membership.
5. `bash tests/test-product-stability-guidance-contract.sh` passes without locking the exact title string `每轮对话节奏`.
6. A pipefail-safe quick profile command fails if any quick test fails and produces trustworthy elapsed-time lines.

---

### Task 1: Lock runner tier behavior with failing tests

**Files:**
- Modify: `tests/test-run-all-runner-contract.sh:32-99`
- Test: `tests/test-run-all-runner-contract.sh`

- [ ] **Step 1: Update help expectations for release mode**

In `tests/test-run-all-runner-contract.sh`, replace the help assertion block at lines 32-35 with:

```bash
help_output="$(bash "$RUNNER" --help)"
assert_contains "--quick" "$help_output" "help output"
assert_contains "--full" "$help_output" "help output"
assert_contains "--release" "$help_output" "help output"
assert_contains "--profile" "$help_output" "help output"
assert_contains "--list" "$help_output" "help output"
```

- [ ] **Step 2: Replace quick plan expectations with the new fast tier contract**

In `tests/test-run-all-runner-contract.sh`, replace lines 65-92 with:

```bash
quick_plan="$(bash "$RUNNER" --quick --list)"
assert_contains "mode=quick" "$quick_plan" "quick plan"
assert_contains "steps=" "$quick_plan" "quick plan"
assert_contains "excluded:" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tools/validate-contracts.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-run-all-runner-contract.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-review-fix-redesign-scenarios.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-context-contract-validator.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-context-contract-hook.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-context-recovery.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-install-core.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-install-runtime-smoke.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-install-safety.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-install-runtime.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-install-migration.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-install-retired-skill-cleanup.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-runtime-integrity.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-platform-runtime-noise.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-codex-skill-adapter.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-product-stability-guidance-contract.sh" "$quick_plan" "quick plan"
```

- [ ] **Step 3: Add release plan expectations**

Insert this block immediately after the quick plan assertions:

```bash
release_plan="$(bash "$RUNNER" --release --list)"
assert_contains "mode=release" "$release_plan" "release plan"
assert_contains "steps=" "$release_plan" "release plan"
assert_contains "bash $ROOT/tests/test-install-core.sh" "$release_plan" "release plan"
assert_contains "bash $ROOT/tests/test-install-runtime-smoke.sh" "$release_plan" "release plan"
assert_contains "bash $ROOT/tests/test-install-safety.sh" "$release_plan" "release plan"
assert_contains "bash $ROOT/tests/test-install-runtime.sh" "$release_plan" "release plan"
assert_contains "bash $ROOT/tests/test-install-migration.sh" "$release_plan" "release plan"
assert_contains "bash $ROOT/tests/test-install-retired-skill-cleanup.sh" "$release_plan" "release plan"
assert_contains "bash $ROOT/tests/test-runtime-integrity.sh" "$release_plan" "release plan"
assert_contains "bash $ROOT/tests/test-platform-runtime-noise.sh" "$release_plan" "release plan"
assert_contains "bash $ROOT/tests/test-codex-skill-adapter.sh" "$release_plan" "release plan"
assert_contains "bash $ROOT/tests/test-release-metadata.sh" "$release_plan" "release plan"
```

- [ ] **Step 4: Run the runner contract and confirm it fails**

Run:

```bash
bash tests/test-run-all-runner-contract.sh
```

Expected: FAIL because `tests/run-all.sh` does not yet support `--release` and still includes heavy tests in quick.

---

### Task 2: Implement explicit runner tiers

**Files:**
- Modify: `tests/run-all.sh:12-463`
- Test: `tests/test-run-all-runner-contract.sh`

- [ ] **Step 1: Update usage text**

In `tests/run-all.sh`, replace the usage text with:

```bash
usage() {
  cat <<'USAGE'
Usage:
  bash tests/run-all.sh [--full|--quick|--release] [--profile] [--list]

Options:
  --full      Run the complete regression suite. This is the default.
  --quick     Run fast, high-signal checks for local iteration and pull requests.
  --release   Run full regression plus install/runtime/release-heavy gates.
  --profile   Print elapsed seconds for each executed step.
  --list      Print the planned steps without executing them.
  -h, --help  Show this help text.
USAGE
}
```

- [ ] **Step 2: Add release mode parsing**

In the argument parsing `case`, insert after the `--quick)` block:

```bash
    --release)
      MODE="release"
      shift
      ;;
```

- [ ] **Step 3: Replace `is_full_only_test` with tier predicates**

Replace `is_full_only_test()` with these functions:

```bash
is_release_heavy_test() {
  case "$1" in
    "tests/test-install-core.sh"|\
    "tests/test-install-runtime-smoke.sh"|\
    "tests/test-install-safety.sh"|\
    "tests/test-install-runtime.sh"|\
    "tests/test-install-migration.sh"|\
    "tests/test-install-retired-skill-cleanup.sh"|\
    "tests/test-runtime-integrity.sh"|\
    "tests/test-platform-runtime-noise.sh"|\
    "tests/test-codex-skill-adapter.sh")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_static_wording_test() {
  case "$1" in
    "tests/test-product-stability-guidance-contract.sh"|\
    "tests/test-standard-chain-cutover.sh"|\
    "tests/test-skill-refiner-agent-loop.sh"|\
    "tests/test-product-role-split-contract.sh"|\
    "tests/test-product-capability-structure-redesign.sh"|\
    "tests/test-review-fix-redesign-contract.sh"|\
    "tests/test-doc-management-rule-contract.sh")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

should_skip_for_mode() {
  local test_file="$1"

  if [ "$MODE" = "quick" ]; then
    if is_release_heavy_test "$test_file" || is_static_wording_test "$test_file"; then
      return 0
    fi
  fi

  return 1
}
```

- [ ] **Step 4: Update `build_plan` to use `should_skip_for_mode`**

Replace this block:

```bash
    if [ "$MODE" = "quick" ] && is_full_only_test "$test_file"; then
      continue
    fi
```

with:

```bash
    if should_skip_for_mode "$test_file"; then
      continue
    fi
```

- [ ] **Step 5: Update `list_plan` exclusion reporting**

Replace the quick-only exclusion block in `list_plan()` with:

```bash
  if [ "$MODE" = "quick" ]; then
    for test_file in "${FULL_TESTS[@]}"; do
      if should_skip_for_mode "$test_file"; then
        excluded_count=$((excluded_count + 1))
      fi
    done
    printf 'excluded_count=%s\n' "$excluded_count"
    for test_file in "${FULL_TESTS[@]}"; do
      if should_skip_for_mode "$test_file"; then
        printf 'excluded: %s\n' "$test_file"
      fi
    done
  fi
```

- [ ] **Step 6: Run the runner contract**

Run:

```bash
bash tests/test-run-all-runner-contract.sh
```

Expected: PASS.

- [ ] **Step 7: Inspect tier lists**

Run:

```bash
bash tests/run-all.sh --quick --list
bash tests/run-all.sh --full --list
bash tests/run-all.sh --release --list
```

Expected:
- quick list excludes release-heavy and static wording tests.
- full list includes all tests in `FULL_TESTS`.
- release list includes all tests in `FULL_TESTS`.

---

### Task 3: Replace the proven wording-freeze failure with a contract-level check

**Files:**
- Modify: `tests/test-product-stability-guidance-contract.sh:95-128`
- Test: `tests/test-product-stability-guidance-contract.sh`

- [ ] **Step 1: Remove duplicated exact title checks**

In `tests/test-product-stability-guidance-contract.sh`, delete both lines that exactly assert:

```bash
assert_present '每轮对话节奏' "$CONVERSATION_GUIDE"
```

- [ ] **Step 2: Add a helper for heading-level section detection**

Insert after `assert_absent()`:

```bash
assert_heading_present() {
  local heading="$1"
  local file="$2"

  rg -n "^## ${heading}$" "$file" >/dev/null 2>&1 || fail "missing heading in $file: $heading"
}
```

- [ ] **Step 3: Add a less brittle per-turn section check**

At the first deleted-title location, insert:

```bash
assert_heading_present '每轮节奏' "$CONVERSATION_GUIDE"
assert_present '每轮回复按三个意图组织' "$CONVERSATION_GUIDE"
assert_present '定位' "$CONVERSATION_GUIDE"
assert_present '推进' "$CONVERSATION_GUIDE"
assert_present '验证' "$CONVERSATION_GUIDE"
```

Do not re-add the second duplicated title assertion.

- [ ] **Step 4: Run the product stability contract test**

Run:

```bash
bash tests/test-product-stability-guidance-contract.sh
```

Expected: PASS, unless another static wording assertion in the same file exposes another stale wording freeze.

- [ ] **Step 5: If another stale wording assertion fails, classify before editing**

If the command fails, inspect the failing pattern and apply exactly one of these actions:

```text
- If the assertion checks a stable JSON/YAML/schema/hook/template field, keep it and fix the source only if the source is wrong.
- If the assertion checks an exact Markdown heading/phrase with no consumer anchor, remove or replace it with a structure-level check.
- If the assertion checks a legacy forbidden path or dangerous capability, keep it unless there is evidence the legacy guard is obsolete.
```

Then rerun:

```bash
bash tests/test-product-stability-guidance-contract.sh
```

Expected: PASS.

---

### Task 4: Make CI use the right test tier

**Files:**
- Modify: `.github/workflows/test.yml:27-29`
- Modify: `.github/workflows/release.yml:88-90`
- Test: `bash tests/run-all.sh --quick --list`, `bash tests/run-all.sh --release --list`

- [ ] **Step 1: Update pull request/push CI to quick gate**

In `.github/workflows/test.yml`, replace:

```yaml
      - name: Run tests
        run: |
          bash tests/run-all.sh
```

with:

```yaml
      - name: Run quick gate
        run: |
          bash tests/run-all.sh --quick
```

- [ ] **Step 2: Update release workflow to release gate**

In `.github/workflows/release.yml`, replace:

```yaml
      - name: Run repository gate
        run: |
          bash tests/run-all.sh
```

with:

```yaml
      - name: Run release gate
        run: |
          bash tests/run-all.sh --release
```

- [ ] **Step 3: Verify YAML still contains intended commands**

Run:

```bash
grep -n "tests/run-all.sh" .github/workflows/test.yml .github/workflows/release.yml
```

Expected output includes:

```text
.github/workflows/test.yml:29:          bash tests/run-all.sh --quick
.github/workflows/release.yml:90:          bash tests/run-all.sh --release
```

---

### Task 5: Verify profile command behavior with pipefail-safe invocation

**Files:**
- Modify: none
- Test: `tests/run-all.sh`

- [ ] **Step 1: Run a pipefail-safe quick profile**

Run:

```bash
set -o pipefail; bash tests/run-all.sh --quick --profile 2>&1 | tee /tmp/org-run-all-quick-profile-after.log
```

Expected: command exits 0 and prints `[profile] PASS ...` for every quick step.

- [ ] **Step 2: Summarize quick profile duration**

Run:

```bash
grep '^\[profile\]' /tmp/org-run-all-quick-profile-after.log | awk '{sum+=$3} END {print sum}'
```

Expected: numeric total seconds. It should be materially lower than the observed partial baseline of 693s before step 22.

- [ ] **Step 3: Print the slowest quick steps**

Run:

```bash
grep '^\[profile\]' /tmp/org-run-all-quick-profile-after.log | sort -nr -k3 | head -20
```

Expected: no install/runtime-heavy tests in the slowest quick steps because they are excluded from quick.

---

### Task 6: Final verification gate

**Files:**
- Test-only task

- [ ] **Step 1: Run targeted tests**

Run:

```bash
bash tests/test-run-all-runner-contract.sh
bash tests/test-product-stability-guidance-contract.sh
```

Expected: both PASS.

- [ ] **Step 2: Run quick gate**

Run:

```bash
bash tests/run-all.sh --quick
```

Expected: PASS.

- [ ] **Step 3: List full and release gates without executing long suites**

Run:

```bash
bash tests/run-all.sh --full --list
bash tests/run-all.sh --release --list
```

Expected: both commands exit 0 and list comprehensive gates including install/runtime/release-heavy tests.

- [ ] **Step 4: Review changed files**

Run:

```bash
git diff -- tests/run-all.sh tests/test-run-all-runner-contract.sh tests/test-product-stability-guidance-contract.sh .github/workflows/test.yml .github/workflows/release.yml
```

Expected: diff only changes tiering, the first wording-freeze sample, and CI tier commands.

---

## Self-Review Notes

- Spec coverage: plan covers tiering, real/weak/static test distinction, CI tier use, the known stale wording failure, and pipefail-safe profile verification.
- Placeholder scan: no TBD/TODO placeholders remain.
- Scope guard: this is the first closed loop, not the entire repository-wide static wording cleanup. Follow-up batches should reuse the same classification model after this runner/tier foundation lands.

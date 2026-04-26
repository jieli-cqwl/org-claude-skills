# Small-Chain Execution Router Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Add deterministic small-chain execution routing after `writing-plans`, with serial, parallel, and blocked decisions plus a login fixture proving the flow.

**Architecture:** `writing-plans` creates `tasks.md`, `plan.md`, `execution-routing-input.json`, and a plan-stage `worklog.md` handoff. A deterministic router script writes `execution-route.json`; a Stop hook invokes it only for active small-chain plan handoffs; serial execution stays on `subagent-driven-development`; parallel execution is a local superpowers wrapper with route evidence consumed by closeout checks.

**Tech Stack:** Python 3 standard library, Bash tests, YAML contracts, Markdown skill files, existing `validate_context_contract.py` and `check_task_plan_consistency.py`.

---

### Task 1: Router core and route contract [T1]

Context: Build the deterministic control point first. The router must read active workset artifacts, compute stable hashes, decide `serial / parallel / blocked`, and never infer from chat history.

Files:
- Create: `tools/community/small_chain_execution_router.py`
- Create: `tests/test-small-chain-execution-router.sh`
- Create: `tests/fixtures/small-chain-execution-router/serial/execution-routing-input.json`
- Create: `tests/fixtures/small-chain-execution-router/parallel/execution-routing-input.json`
- Create: `tests/fixtures/small-chain-execution-router/blocked-high-risk/execution-routing-input.json`
- Create: `tests/fixtures/small-chain-execution-router/stale/execution-routing-input.json`

1. [T1] Write the failing router shell test with fixtures for the four core outcomes.

```bash
bash tests/test-small-chain-execution-router.sh
```

Expected: FAIL because `tools/community/small_chain_execution_router.py` does not exist.

2. [T1] Implement a Python CLI with this shape.

```python
def main(argv: list[str]) -> int:
    args = parse_args(argv)
    route = build_route(args.repo_root, args.feature_path, args.workset)
    write_route(route, args.repo_root, args.feature_path, args.workset)
    print(json.dumps(route, ensure_ascii=False, sort_keys=True))
    return 0 if route["decision"] != "blocked" else 2
```

3. [T1] Implement stable hashes.

```python
def sha256_text(text: str) -> str:
    normalized = text.replace("\r\n", "\n").strip() + "\n"
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()

def sha256_json(data: object) -> str:
    payload = json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()
```

4. [T1] Implement the decision rules.

```python
HIGH_RISK_PREFIXES = (
    "contracts/",
    "shared/hooks/",
    "tools/community/validate_",
    "install.sh",
    "community/SOURCES.yaml",
)

def decide(requested_mode: str, tasks: list[RouteTask]) -> str:
    if requested_mode == "serial":
        return "serial"
    if requested_mode != "parallel":
        return "blocked"
    if has_dependency_edges(tasks) or has_shared_writes(tasks) or touches_high_risk(tasks):
        return "blocked"
    return "parallel"
```

5. [T1] Validate that `execution-routing-input.json` task IDs exactly match `tasks.md` and `plan.md`, and block stale `execution-route.json` until an explicit `--force-refresh`.

6. [T1] Run the test and fix until it passes.

Run: `bash tests/test-small-chain-execution-router.sh`
Expected: `[PASS] small-chain execution router`

### Task 2: Plan-stage Stop hook [T2]

Context: The hook is the automation bridge. It must detect the latest managed small-chain plan handoff from `worklog.md`, invoke the router, and return a continuation or stop payload.

Files:
- Create: `shared/hooks/managed/small_chain_execution_router.py`
- Modify: `shared/hooks/registry.json`
- Create: `tests/test-small-chain-execution-router-hook.sh`

1. [T2] Write a failing hook test that builds a temporary managed small-chain fixture and invokes the hook.

```bash
bash tests/test-small-chain-execution-router-hook.sh
```

Expected: FAIL because the hook wrapper is missing.

2. [T2] Implement hook root discovery using the same participating-repo pattern as `context_contract_validator.py`.

```python
def is_participating_repo(root: Path) -> bool:
    return (root / "contracts" / "active-doc-scope.yaml").is_file()
```

3. [T2] Select the current active small-chain workset from hook cwd when possible, otherwise require a unique plan-stage workset.

4. [T2] Parse the latest worklog block and gate on `stage: plan`.

```python
if fields.get("mode") != "small-chain" or fields.get("stage") != "plan":
    return emit_allow()
```

5. [T2] Invoke the router with a timeout and emit Stop payloads, including missing route-input blocked output.

```python
payload = {
    "continue": False,
    "stopReason": reason,
    "systemMessage": reason,
}
```

6. [T2] Register the hook in `shared/hooks/registry.json` as a Codex Stop runtime hook with a 30 second timeout.

7. [T2] Run the hook test and context tests.

Run: `bash tests/test-small-chain-execution-router-hook.sh`
Expected: `[PASS] small-chain execution router hook`

### Task 3: small-chain contract and writing-plans propagation [T3]

Context: The chain contract and writing-plans skill must name the router node and its artifacts, otherwise LLM routing and tests will continue to assume direct serial execution.

Files:
- Modify: `contracts/small-chain.yaml`
- Modify: `community/superpowers/skills/writing-plans/SKILL.md`
- Modify: `community/superpowers/skills/using-superpowers/SKILL.md`
- Modify: `contracts/superpowers-boundary.yaml`
- Modify: `README.md`
- Modify: `tests/test-small-chain-boundary.sh`

1. [T3] Extend `contracts/small-chain.yaml` with `small-chain-execution-router` between `writing-plans` and env setup.

2. [T3] Add `execution-routing-input.json` as a writing-plans output consumed by the router, and `execution-route.json` as a router output consumed by serial and parallel execution.

3. [T3] Update `writing-plans` execution handoff text so completion means `tasks.md`, `plan.md`, `execution-routing-input.json`, plan-stage worklog, self-review, and consistency audit.

4. [T3] Update README current chain and constraints to remove “execution uniformly收口到 subagent-driven-development” as the only path.

5. [T3] Update boundary tests to assert the new route node and artifacts.

Run: `bash tests/test-small-chain-boundary.sh`
Expected: `[PASS] small-chain boundary`

### Task 4: Parallel execution wrapper and install visibility [T4]

Context: Parallel execution must be a local small-chain wrapper, not an upstream body rewrite. It needs installation visibility and a clear evidence contract.

Files:
- Create: `community/superpowers/skills/parallel-subagent-development/SKILL.md`
- Modify: `contracts/superpowers-boundary.yaml`
- Modify: `install.sh`
- Modify: `tests/test-single-source-layout.sh`
- Modify: `tests/test-small-chain-boundary.sh`

1. [T4] Create `parallel-subagent-development/SKILL.md` with inputs `tasks.md`, `plan.md`, `execution-route.json`, isolated worktrees, and outputs `parallel-execution-report.json`.

2. [T4] Require bounded parallelism, per-task or per-group write ownership, no shared-file writes, merge evidence, task status updates in `tasks.md`, and final handoff to `verification-before-completion`.

3. [T4] Add the skill to the selected and auto-invocable superpowers lists in `install.sh`.

4. [T4] Add description override text.

5. [T4] Update single-source and boundary tests.

Run: `bash tests/test-single-source-layout.sh`
Expected: PASS

### Task 5: verify-change route evidence and documentation [T5]

Context: Closeout must not accept parallel execution without route and evidence. This task updates the narrative and tests so verification catches missing parallel evidence.

Files:
- Modify: `community/superpowers/skills/verify-change/SKILL.md`
- Modify: `community/superpowers/skills/subagent-driven-development/SKILL.md`
- Modify: `community/superpowers/skills/verification-before-completion/SKILL.md`
- Modify: `README.md`
- Modify: `tests/test-closeout-routing.sh`
- Modify: `tests/test-small-chain-boundary.sh`

1. [T5] Update `verify-change` to require `execution-route.json` and `parallel-execution-report.json` when route decision is `parallel`.

2. [T5] Clarify `subagent-driven-development` is the serial executor for `decision=serial`.

3. [T5] Clarify `verification-before-completion` collects route evidence before `verify-change`.

4. [T5] Update tests to assert route evidence appears in the closeout path.

Run: `bash tests/test-closeout-routing.sh`
Expected: PASS

### Task 6: Login fixture end-to-end route validation [T6]

Context: Prove the automation on a small concrete requirement. The fixture models a simple login feature with independent UI and auth-service tasks and then mutates route input to prove stale detection.

Files:
- Create: `tests/test-small-chain-execution-router-login-flow.sh`
- Create: `tests/fixtures/small-chain-execution-router/login/design.md`
- Create: `tests/fixtures/small-chain-execution-router/login/tasks.md`
- Create: `tests/fixtures/small-chain-execution-router/login/plan.md`
- Create: `tests/fixtures/small-chain-execution-router/login/execution-routing-input.json`

1. [T6] Build the login fixture with two independent tasks: `T1` auth service and `T2` login form.

2. [T6] Assert the hook writes `execution-route.json` with `decision=parallel` and `worktree_policy=per_task_worktree`.

3. [T6] Mutate `execution-routing-input.json` after route generation and assert the router blocks on stale `routing_input_hash`.

Run: `bash tests/test-small-chain-execution-router-login-flow.sh`
Expected: `[PASS] small-chain execution router login flow`

### Task 7: Final verification and small-chain closeout readiness [T7]

Context: Finish only when direct evidence proves the router, hook, contracts, install visibility, and login fixture all work together.

Files:
- Modify: `docs/feature--small-chain--execution-router/2026-04-26-execution-router/tasks.md`
- Create: `docs/feature--small-chain--execution-router/2026-04-26-execution-router/verify-change-report.md`
- Modify: `docs/feature--small-chain--execution-router/worklog.md`

1. [T7] Run all targeted proving commands.

```bash
bash tools/validate-contracts.sh
bash tests/test-small-chain-boundary.sh
bash tests/test-small-chain-execution-router.sh
bash tests/test-small-chain-execution-router-hook.sh
bash tests/test-small-chain-execution-router-login-flow.sh
bash tests/test-closeout-routing.sh
bash tests/test-single-source-layout.sh
```

2. [T7] Mark each completed task in `tasks.md` only after its AC command passes.

3. [T7] Write `verify-change-report.md` with PASS only if all direct proving commands pass.

4. [T7] Append a `stage: verify` worklog record pointing to `verify-change-report.md`.

### Task 8: Small-chain quality gate hardening [T8]

Context: Close the process gap exposed by the post-verify review. The small-chain flow must require negative failure-matrix planning and adversarial review evidence for contract-grade or runtime-gate changes before `verify-change` can pass.

Files:
- Modify: `community/superpowers/skills/writing-plans/SKILL.md`
- Modify: `community/superpowers/skills/verification-before-completion/SKILL.md`
- Modify: `community/superpowers/skills/verify-change/SKILL.md`
- Modify: `community/superpowers/skills/requesting-code-review/SKILL.md`
- Modify: `community/superpowers/skills/using-superpowers/SKILL.md`
- Modify: `contracts/small-chain.yaml`
- Modify: `contracts/superpowers-boundary.yaml`
- Modify: `README.md`
- Modify: `tests/test-small-chain-boundary.sh`
- Modify: `tests/test-closeout-routing.sh`
- Modify: `docs/feature--small-chain--execution-router/2026-04-26-execution-router/process-retrospective.md`

1. [T8] Add the planning gate that requires a contract-grade failure matrix.

Run: `bash tests/test-small-chain-boundary.sh`
Expected: PASS and asserts `Contract-Grade Failure Matrix` plus `Failure matrix completeness`.

2. [T8] Add the closeout gate that requires `code-review-result.json` for contract-grade/runtime-gate changes.

Run: `bash tests/test-closeout-routing.sh`
Expected: PASS and asserts `requesting-code-review`, `Code Review Evidence Gate`, and `code-review-result.json`.

3. [T8] Update the chain contract, boundary contract, README, and review skill handoff text.

Run: `bash tools/validate-contracts.sh`
Expected: PASS.

4. [T8] Record why verify-change alone was insufficient.

Run: `test -f docs/feature--small-chain--execution-router/2026-04-26-execution-router/process-retrospective.md`
Expected: PASS.

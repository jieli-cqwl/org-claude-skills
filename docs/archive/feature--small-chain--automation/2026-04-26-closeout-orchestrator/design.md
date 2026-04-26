# Small-Chain Closeout Automation Design

## Why

After `writing-plans`, small-chain work is mostly execution and mechanical gatekeeping. Today the agent still has to remember when to run implementation, fresh verification, `verify-change`, PR creation, auto-merge, and archive. That creates drift risk: a skipped gate can make archive look complete before the change is integrated on the target branch.

This change introduces a deterministic closeout orchestrator and contract updates so the default path becomes: implement from the approved plan, verify with fresh evidence, create a PR, enable GitHub auto-merge, and archive only after the PR is merged into the target branch.

## Scope

- In scope: Add a small-chain closeout automation helper that locates the managed workset, validates closeout preconditions, creates a PR, enables auto-merge, detects merge completion, archives the workset, appends the feature changelog, and updates `contracts/active-doc-scope.yaml`.
- In scope: Document the automation route in small-chain contracts and README without rewriting upstream Superpowers bodies outside declared overlay files.
- In scope: Add targeted tests for fail-closed behavior, PR auto-merge command construction, archive lifecycle updates, and contract visibility.
- Out of scope: Running LLM implementation agents from hooks, bypassing `verify-change`, bypassing branch protection, force-merging protected branches, or archiving unmerged PR work.
- Out of scope: Changing standard-chain lifecycle, product canonical JSON contracts, or non-small-chain completion gates.

## Approach

Create `tools/community/small_chain_closeout.py` as a deterministic orchestrator. It will not launch model work from hooks. Instead, it will own the mechanical closeout path after the implementation has produced complete `tasks.md`, fresh verification evidence, and a `verify-change-report.md` with `PASS`.

The helper will expose subcommands:

- `status`: read the managed feature and workset and return the next mechanical action.
- `create-pr`: fail closed unless tasks are complete, task-plan consistency passes, and `verify-change-report.md` is `PASS` with no CRITICAL findings; then run `gh pr create` and `gh pr merge --auto`.
- `archive`: fail closed unless the PR is merged or the current branch is already the target branch with no pending branch/worktree action; then move the workset to `docs/archive/{feature}/{workset}`, copy the latest `worklog.md` into the archive entry, append `docs/{feature}/CHANGELOG.md`, and mark the scope registry entry as legacy through `tools/community/update_active_doc_scope.py`.

Hooks remain short-lived enforcement points. They may validate context and block unsafe completion, but they must not perform long-running implementation or merge operations. CI and GitHub branch protection remain the integration authority after PR creation.

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| Hook launches the entire chain | Fully automatic from a visible runtime event | Long-running hooks are fragile, can recurse into agent work, and make failures hard to recover | Rejected |
| Local auto-merge directly into target branch | Fastest path to archive | Bypasses PR review surfaces and branch protection; high blast radius if target branch is shared | Rejected |
| PR auto-merge with deterministic archive after merge | Keeps branch protection as the integration authority; minimizes human involvement to exceptions | Requires GitHub auto-merge/CI to be configured | Accepted |

## Key Decisions

- D1: The automation helper is deterministic and script-based. Reason: lifecycle gates, git state, PR state, and archive moves are stable machine checks; model judgment belongs in implementation and review skills.
- D2: PR auto-merge is the default integration policy. Reason: it removes routine human intervention while preserving CI and branch protection as the actual merge authority.
- D3: Archive only runs after merge evidence. Reason: `archive` currently requires `integrated_on_target_branch`, and no helper may weaken that contract.
- D4: Hooks only enforce or route; they do not run long tasks. Reason: hook failure contracts must remain fast, readable, and fail-closed.

## Goals & Success Criteria

| Goal | Success Criteria | Verification |
|------|------------------|--------------|
| G1 Mechanical closeout route | A CLI helper can identify whether a workset should create PR, wait for merge, archive, or block | `python3 tools/community/small_chain_closeout.py status --feature docs/feature--small-chain--automation` in fixtures/tests |
| G2 PR auto-merge gate | `create-pr` refuses incomplete tasks, missing/stale verify reports, or CRITICAL findings; when valid, it calls `gh pr create` and `gh pr merge --auto` | Targeted shell test with a fake `gh` executable and invalid fixture cases |
| G3 Archive gate | `archive` refuses unmerged PR state; when merged, it moves the workset, copies worklog, appends changelog, and marks registry legacy | Targeted shell test on a temporary repo fixture plus `validate_context_contract.py` |
| G4 Contract visibility | README and small-chain boundary contract describe the PR auto-merge route and archive preconditions | `bash tests/test-small-chain-closeout-automation.sh` plus existing boundary tests |
| G5 No runtime regression | Existing small-chain, hooks, and contract validation continue to pass | `bash tools/validate-contracts.sh`, `bash tests/test-small-chain-boundary.sh`, `bash tests/test-superpowers-boundary.sh`, `bash tests/test-codex-skill-adapter.sh` |

## Change Scope

| File or Area | Change Type | Size |
|--------------|-------------|------|
| `tools/community/small_chain_closeout.py` | create | medium |
| `tests/test-small-chain-closeout-automation.sh` | create | medium |
| `contracts/small-chain.yaml` | modify | small |
| `contracts/superpowers-boundary.yaml` | modify | small |
| `README.md` | modify | small |
| `docs/feature--small-chain--automation/*` | create | small |
| `contracts/active-doc-scope.yaml` | modify | small |

## Invariants

- `tasks.md` remains the only small-chain task completion truth.
- `plan.md` remains execution guidance and must not hold checkbox completion state.
- `verify-change` remains required before PR creation, merge, or archive.
- Any CRITICAL finding blocks integration and archive.
- Archive requires evidence that the change is integrated on the target branch.
- Hooks must fail closed and must not silently downgrade to weaker validation.
- `community/superpowers` upstream body fidelity remains governed by `contracts/superpowers-boundary.yaml`.

## Downstream Impact

| Consumer | Impact | Propagation Needed |
|----------|--------|--------------------|
| Codex and Claude users | Get a deterministic helper for mechanical closeout after implementation | Yes: README documents command and policy |
| Context recovery tools | See the feature change as legacy after archive | Yes: registry update uses existing lifecycle helper |
| Hooks registry | No new long-running hook is introduced | No: current hook contract remains unchanged |
| Small-chain skills | Closeout route is clarified, not replaced | Yes: boundary contract references automation policy |
| CI / GitHub branch protection | Becomes the integration authority after PR creation | No repository-side config change in this task; helper fails if `gh` cannot enable auto-merge |

## Contract-Grade Preflight

| Check | Answer |
|-------|--------|
| Current vs Target | Current HEAD has manual closeout after `verify-change`; target phase adds a deterministic helper for PR auto-merge and post-merge archive. Migration phase is bootstrap for this new managed feature. Cutover owner is `feature-runtime-owner`. |
| Source of Truth Matrix | Task progress: active workset `tasks.md`; execution steps: active workset `plan.md`; verification result: active workset `verify-change-report.md`; branch/PR state: git and `gh pr view`; archive lifecycle: `contracts/active-doc-scope.yaml`; handoff: `worklog.md`. Conflict priority is registry + active workset over historical docs. |
| Closed Vocabulary / Grammar | CLI statuses: `block`, `create_pr`, `wait_for_merge`, `archive`, `done`. Failure output uses `decision: block`, `reason`, `path`, `expected`, `actual`, `next_action`. Archive refs use `docs/archive/{feature_name}/{workset_name}`. |
| Ownership / Waiver | Helper and tests are owned by runtime maintainers; registry updates use `context_registry_owner`; waiver approver is the relevant owner in `contracts/context-artifact-ownership.yaml`. Mechanical checks are the new targeted test plus existing contract tests. |
| Failure Contract | Missing artifacts, incomplete tasks, task-plan mismatch, verify FAIL, CRITICAL findings, missing `gh`, PR create failure, auto-merge failure, unmerged PR, unreachable archive refs, or context validation failure all block with fixed failure output. No guessing from unmanaged docs. |
| Implementation Surface | Allowed files are limited to the helper, targeted test, README, contracts, and this feature's docs/worklog/registry entry. Cutover order: tests first, helper, docs/contracts, contract validation, targeted tests, then broader regression. |
| Proving Categories | G1-G4 map to targeted tests and fixture state. G5 maps to existing contract and runtime adapter tests. PR behavior is proven with a fake `gh` for command shape and fail-closed behavior; real GitHub behavior remains delegated to `gh`/branch protection. |
| Existing Contract Diff | Checked `README.md`, `contracts/small-chain.yaml`, `contracts/superpowers-boundary.yaml`, `community/superpowers/skills/*`, `shared/hooks/registry.json`, `tools/community/update_active_doc_scope.py`, and existing small-chain/hook tests. No current contract allows archive before integration. |

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| GitHub auto-merge is unavailable | Helper cannot remove the last manual step | Fail closed with actionable reason; do not archive |
| Fake `gh` tests overstate real GitHub behavior | Local tests only prove command shape and failure handling | Treat GitHub/CI as external integration authority; do not claim merge until `gh pr view` or git state proves it |
| Worklog archive copy drifts from recovery expectations | Legacy recovery could fail | Copy feature `worklog.md` into the archived workset and run `validate_context_contract.py` |
| Automation masks a failed verification step | Broken work could reach PR or archive | Require complete tasks, consistency checker, and PASS verify report before PR creation |
| Helper grows into an agent runner | Hooks or scripts become brittle and hard to debug | Keep helper deterministic; explicitly keep LLM implementation out of scope |

## Spec Self-Review

- Placeholder scan: Clear; no TBD/TODO/pending placeholders.
- Internal consistency: Clear; PR auto-merge is the only integration route, archive remains post-merge.
- Scope check: Clear; one helper plus tests and contract docs.
- Ambiguity check: Clear; hooks do not run long tasks, and archive requires merge evidence.
- Design completeness: D1-D9 are covered.

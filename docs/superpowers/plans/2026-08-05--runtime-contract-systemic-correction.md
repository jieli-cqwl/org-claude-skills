# Runtime Contract Systemic Correction Implementation Plan

**Goal:** Remove prompt-specific runtime guidance while preserving the reusable constraints that made the original scenarios safer.

**Architecture:** Keep `shared/assistant.md` as the routing entry. Move mechanism detail into owned references, make scene composition additive, and prove behavior with regression, transfer, and near-miss cases rather than prose assertions.

**Tech Stack:** Markdown runtime contracts, JSON eval cases, existing Python rule-runtime evaluator, shell gates.

---

### Task 1: Add behavior cases that expose overfitting

**Files:**
- Modify: `tools/eval/scenarios/assistant-entry/evals.json`
- Modify: `tools/eval/contracts/rule-runtime-eval.json`

1. Add domain-transfer cases for opaque tokens, mobile OAuth failures, worker-owned entitlement derivation, bounded shortcuts, and near-miss document changes.
2. Give every case required and forbidden scene contracts; do not assert runtime prose.
3. Run the focused cases against `origin/main` and retain the failing evidence as the RED baseline.

### Task 2: Correct runtime ownership and routing

**Files:**
- Modify: `shared/assistant.md`
- Modify: `shared/rules/code-changes.md`
- Create: `shared/reference/authentication-and-authorization.md`
- Modify: `shared/reference/测试规范.md`
- Modify: `shared/reference/系统调试.md`
- Modify: `shared/reference/全栈开发.md`
- Modify: `shared/reference/constants-and-configuration.md`
- Modify: `shared/reference/error-handling.md`
- Modify: `shared/reference/code-structure-reuse.md`
- Modify: `shared/reference/code-comments.md`

1. Trigger scenes from problem domain, decision impact, and risk, independent of request format.
2. Make multi-scene composition additive at the entry and remove recursive routing from references.
3. Replace scenario answers with mechanism-neutral invariants and conditional guidance.
4. Keep configuration ownership separate from runtime failure behavior.
5. Keep SQL/schema semantic comments proportional to applicable semantics.

### Task 3: Prove and package the runtime correction

1. Run targeted contract and install tests.
2. Run `bash tests/run-all.sh --quick`.
3. Run fresh focused regression and transfer evals twice per configuration.
4. Review `git diff` for prompt leakage, duplicate ownership, and unrelated changes.
5. Commit only the runtime correction and its behavior cases.

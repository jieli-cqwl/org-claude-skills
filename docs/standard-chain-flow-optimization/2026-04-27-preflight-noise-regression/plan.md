# Standard Chain Flow Optimization Implementation Plan

> **For agentic workers:** REQUIRED NEXT STEP: run `implementation-router`. Implement only after `execution-route.json` chooses `serial` or `parallel`.

**Goal:** Reduce standard-chain LLM context load by moving mechanical checks and repeated facts into contracts, scripts, validators, fixtures, and audit records while proving the full login homepage chain from `product-director` through signoff.

**Architecture:** Canonical contracts own schemas, failure codes, field ownership, and closed vocabularies. Shared checker helpers emit versioned routing JSON. Role core CLIs validate preflight and completion from explicit argv. Hook adapters translate runtime payloads into those CLIs and fail closed. Skill bodies keep role judgment, hard gates, protocol, precise script entrypoints, triggered references, and output contracts. The delegated login homepage pilot supplies fresh end-to-end proof.

**Tech Stack:** Bash role scripts, Python 3 validators, JSON Schema, YAML contracts, canonical JSON fixtures, Markdown skill files, existing standard-chain validators, existing hook registry, and repo test shell scripts.

---

### Task 1: Failure routing registry and result schema [T1]

Context: Build the shared failure contract first so every checker and skill text points to the same truth.

Files:
- Create: `contracts/standard-chain-failure-routing.yaml`
- Create: `contracts/canonical/schemas/runtime/failure-routing-result.schema.json`
- Create when derived runtime lookup is needed: `shared/runtime/standard-chain-failure-routing.json`
- Create: `tests/test-standard-chain-failure-routing-contract.sh`
- Modify when schema discovery requires it: `contracts/canonical/registry-bundle.yaml`
- Modify when contract validation needs coverage: `tools/dev/validate-contracts.sh`

1. [T1] Write the failing routing contract test for valid PASS, valid WARN, valid BLOCKED, missing required field, unknown status, unknown failure code, and unmapped condition fallback to `UNREGISTERED_FAILURE_CODE`.

Run: `bash tests/test-standard-chain-failure-routing-contract.sh`
Expected: FAIL because the registry and schema are not present.

2. [T1] Add `contracts/standard-chain-failure-routing.yaml` with registered entries for baseline pass, missing artifact, malformed artifact, stale evidence, ambiguous target, missing human confirmation, unregistered failure code, adapter timeout, adapter output overflow, unauthorized scope, and handoff not ready.

3. [T1] Add `failure-routing-result.schema.json` with required fields `schema_version`, `status`, `stage`, `failure_code`, `owner`, `next_action`, `safe_to_continue`, `human_decision_required`, `continuation_condition`, `evidence_refs`, and `user_message`.

4. [T1] Add a derived runtime catalog only if scripts need fast lookup, and prove it contains no code absent from `contracts/standard-chain-failure-routing.yaml`.

5. [T1] Wire the new test into contract validation only after the standalone test proves the schema and registry.

Run: `bash tests/test-standard-chain-failure-routing-contract.sh`
Expected: PASS.

Run: `bash tools/validate-contracts.sh`
Expected: PASS.

### Task 2: Shared checker runtime and role profile catalogs [T2]

Context: Give role scripts one small runtime surface instead of repeating JSON construction and profile facts in every skill.

Files:
- Create: `shared/skills/lib/standard-chain-routing.sh`
- Create: `shared/runtime/standard-chain-preflight-profiles.json`
- Create: `shared/runtime/standard-chain-completion-profiles.json`
- Create: `tests/test-standard-chain-checker-contract.sh`

1. [T2] Write the failing shared checker test for schema-valid routing JSON, argv-only core command behavior, stdin rejection by core CLIs, malformed argv fail-closed output, WARN without continuation condition rejection, and exact ten-role profile coverage.

Run: `bash tests/test-standard-chain-checker-contract.sh`
Expected: FAIL because the shared runtime and profiles are missing.

2. [T2] Implement `standard-chain-routing.sh` with functions for registered code lookup, routing JSON emission, schema validation handoff, safe boolean rendering, evidence ref normalization, and core checker argv validation.

3. [T2] Add preflight and completion profile catalogs for `product-director`, `product-manager`, `design`, `test-design`, `tech-lead`, `delivery-owner`, `developer`, `verify`, `review`, and `qa`.

4. [T2] Ensure catalogs contain role-owned checks only and reference registered failure codes without defining new policy.

Run: `bash tests/test-standard-chain-checker-contract.sh`
Expected: PASS.

### Task 3: Preflight core checkers and hook adapters [T3]

Context: Preflight must answer “can this role begin?” before LLM context is spent on role work.

Files:
- Create: `shared/skills/product-director/scripts/check_preflight.sh`
- Create: `shared/skills/product-director/scripts/preflight_check.sh`
- Create: `shared/skills/product-manager/scripts/check_preflight.sh`
- Create: `shared/skills/product-manager/scripts/preflight_check.sh`
- Create: `shared/skills/design/scripts/check_preflight.sh`
- Create: `shared/skills/design/scripts/preflight_check.sh`
- Create: `shared/skills/test-design/scripts/check_preflight.sh`
- Create: `shared/skills/test-design/scripts/preflight_check.sh`
- Create: `shared/skills/tech-lead/scripts/check_preflight.sh`
- Create: `shared/skills/tech-lead/scripts/preflight_check.sh`
- Create: `shared/skills/delivery-owner/scripts/check_preflight.sh`
- Create: `shared/skills/delivery-owner/scripts/preflight_check.sh`
- Create: `shared/skills/developer/scripts/check_preflight.sh`
- Create: `shared/skills/developer/scripts/preflight_check.sh`
- Create: `shared/skills/verify/scripts/check_preflight.sh`
- Create: `shared/skills/verify/scripts/preflight_check.sh`
- Create: `shared/skills/review/scripts/check_preflight.sh`
- Create: `shared/skills/review/scripts/preflight_check.sh`
- Create: `shared/skills/qa/scripts/check_preflight.sh`
- Create: `shared/skills/qa/scripts/preflight_check.sh`
- Create: `tests/test-standard-chain-preflight-profiles.sh`
- Modify when hook registration is needed: `shared/hooks/registry.json`
- Modify role script manifests when present: `shared/skills/{role}/scripts/manifest.json`

1. [T3] Write the failing preflight test with positive fixtures and negative cases for missing artifacts, malformed artifacts, stale refs, ambiguous active selection, missing human confirmation, Director entry without existing product artifacts, adapter timeout, adapter output overflow, and adapter/core semantic drift.

Run: `bash tests/test-standard-chain-preflight-profiles.sh`
Expected: FAIL because the preflight core and adapter scripts are missing.

2. [T3] Implement each `check_preflight.sh` as argv-only, read-only, idempotent, and profile-backed.

3. [T3] Implement each `preflight_check.sh` as the hook-facing adapter that reads runtime payload, resolves explicit arguments, invokes `check_preflight.sh`, enforces timeout/output limits, and returns the same routing semantics for equivalent input.

4. [T3] Update manifests and hook registry only where needed to expose adapter entrypoints without changing install or release behavior.

Run: `bash tests/test-standard-chain-preflight-profiles.sh`
Expected: PASS.

### Task 4: Completion core checkers and hook adapters [T4]

Context: Completion must answer “can this role hand off?” and preserve existing hook compatibility while moving policy into core CLIs.

Files:
- Create: `shared/skills/product-director/scripts/check_completion.sh`
- Create: `shared/skills/product-manager/scripts/check_completion.sh`
- Create: `shared/skills/design/scripts/check_completion.sh`
- Create: `shared/skills/test-design/scripts/check_completion.sh`
- Create: `shared/skills/tech-lead/scripts/check_completion.sh`
- Create: `shared/skills/delivery-owner/scripts/check_completion.sh`
- Create: `shared/skills/developer/scripts/check_completion.sh`
- Create: `shared/skills/verify/scripts/check_completion.sh`
- Create: `shared/skills/review/scripts/check_completion.sh`
- Create: `shared/skills/qa/scripts/check_completion.sh`
- Modify: `shared/skills/product-director/scripts/completion_check.sh`
- Modify: `shared/skills/product-manager/scripts/completion_check.sh`
- Modify: `shared/skills/design/scripts/completion_check.sh`
- Modify: `shared/skills/test-design/scripts/completion_check.sh`
- Modify: `shared/skills/tech-lead/scripts/completion_check.sh`
- Modify: `shared/skills/delivery-owner/scripts/completion_check.sh`
- Modify: `shared/skills/developer/scripts/completion_check.sh`
- Modify: `shared/skills/verify/scripts/completion_check.sh`
- Modify: `shared/skills/review/scripts/completion_check.sh`
- Modify: `shared/skills/qa/scripts/completion_check.sh`
- Create: `tests/test-standard-chain-completion-profiles.sh`
- Modify when sequencing metadata must match the chosen flow: `contracts/standard-chain.yaml`
- Modify when hook metadata must match adapter behavior: `shared/hooks/registry.json`
- Modify role script manifests when present: `shared/skills/{role}/scripts/manifest.json`

1. [T4] Write the failing completion test with positive fixtures and negative cases for missing canonical output, malformed output, stale proof, missing handoff readiness, missing pilot delegated basis, hook payload compatibility, adapter timeout, adapter output overflow, and adapter/core semantic drift.

Run: `bash tests/test-standard-chain-completion-profiles.sh`
Expected: FAIL because core completion scripts and delegation are missing.

2. [T4] Implement each `check_completion.sh` as argv-only and profile-backed, using existing canonical validators where they already express the contract.

3. [T4] Convert existing `completion_check.sh` scripts into adapters that preserve hook payload compatibility and delegate policy to `check_completion.sh`.

4. [T4] Align delivery sequencing metadata and tests so the main execution path is `developer -> verify -> review -> qa`, while preserving existing artifact consumption contracts.

Run: `bash tests/test-standard-chain-completion-profiles.sh`
Expected: PASS.

Run: `bash tests/test-standard-chain-skill-structure.sh`
Expected: PASS after adapter paths and manifests stay discoverable.

### Task 5: Content-quality validator and audit gate [T5]

Context: Noise removal needs a gate that catches ambiguous prose and unaudited deletion before active skill text is changed.

Files:
- Create: `tools/community/validate_standard_chain_content_quality.py`
- Create: `tests/test-standard-chain-content-quality.sh`
- Create: `tests/fixtures/standard-chain-content-quality/valid-skill.md`
- Create: `tests/fixtures/standard-chain-content-quality/invalid-hidden-must-in-why.md`
- Create: `tests/fixtures/standard-chain-content-quality/invalid-how-with-file-command.md`
- Create: `tests/fixtures/standard-chain-content-quality/invalid-unowned-failure.md`
- Create: `tests/fixtures/standard-chain-content-quality/valid-noise-migration-audit.json`
- Create: `tests/fixtures/standard-chain-content-quality/invalid-delete-without-proof.json`

1. [T5] Write fixture-driven failing tests for valid content layers, hidden MUST inside `Why`, concrete file/field commands inside `How`, unowned failure statements, repeated source-of-truth claims, vague ambiguous actions, valid audit records, and invalid `delete` records.

Run: `bash tests/test-standard-chain-content-quality.sh`
Expected: FAIL because the validator is missing.

2. [T5] Implement the validator so it can run against fixture files and the active standard-chain skill set.

3. [T5] Keep the validator focused on ambiguity and migration accountability; do not make shorter skill length a success criterion.

Run: `bash tests/test-standard-chain-content-quality.sh`
Expected: PASS on fixtures.

### Task 6: Standard-chain skill-body migration and noise audit [T6]

Context: Apply the validator to the real ten-role skill bodies and migrate mechanical or repeated text to the owning runtime surface.

Files:
- Modify: `shared/skills/product-director/SKILL.md`
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/test-design/SKILL.md`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/developer/SKILL.md`
- Modify: `shared/skills/verify/SKILL.md`
- Modify: `shared/skills/review/SKILL.md`
- Modify: `shared/skills/qa/SKILL.md`
- Create: `docs/standard-chain-flow-optimization/2026-04-27-preflight-noise-regression/noise-migration-audit.json`
- Modify when active structure assertions need new sections: `tests/test-standard-chain-skill-structure.sh`

1. [T6] For each touched skill body, classify every removed or substantially rewritten normative segment into one content layer and one migration action.

2. [T6] Move mechanical preconditions to script entrypoints, repeated schema facts to canonical contract refs, display templates to projections or existing output references, long methodology to triggered references, obsolete history to archive/delete records, and role-crossing failure language to the owner or routing registry.

3. [T6] Add an audit entry with `source_file`, `source_anchor`, `content_layer`, `migration_action`, `destination_ref`, `consumer`, `reason`, and `verification_ref` for every migrated segment.

Run: `bash tests/test-standard-chain-skill-structure.sh`
Expected: PASS.

Run: `bash tests/test-standard-chain-content-quality.sh`
Expected: PASS against active standard-chain skills and audit records.

### Task 7: Delegated login homepage pilot proof and fixture synchronization [T7]

Context: Prove the new chain by traversing the login homepage pilot, not by making old fixture JSON green.

Files:
- Create: `docs/standard-chain-flow-optimization/2026-04-27-preflight-noise-regression/delegated-pilot-proof.json`
- Create: `docs/standard-chain-flow-optimization/2026-04-27-preflight-noise-regression/process-retrospective.md`
- Create when structured validation is needed: `tools/community/validate_standard_chain_delegated_pilot.py`
- Create: `tests/test-standard-chain-delegated-pilot-proof.sh`
- Modify: `tests/test-standard-chain-login-homepage-pilot.sh`
- Modify active login fixture artifacts under `tests/fixtures/standard-chain-pilots/login-homepage-pilot/phase-1`

1. [T7] Write the failing delegated pilot proof test for missing proof, missing retrospective, missing stage traversal, missing confirmation basis, fixture/proof plan-task ref mismatch, and developer-report fixture missing `self_testing.coverage_review`.

Run: `bash tests/test-standard-chain-delegated-pilot-proof.sh`
Expected: FAIL because the delegated proof and validator are missing.

2. [T7] Traverse or reconstruct the login homepage pilot from `product-director` through delivery signoff using current contracts and record every delegated confirmation with basis.

3. [T7] Update fixture artifacts only when the proof records the generated or updated artifact, fixture sync ref, and the current schema requirement being satisfied.

4. [T7] Write the process retrospective with context-load observations, unclear instructions, preflight failures, completion failures, failure routing quality, schema/fixture drift, and role boundary friction.

Run: `bash tests/test-standard-chain-delegated-pilot-proof.sh`
Expected: PASS.

Run: `bash tests/test-standard-chain-login-homepage-pilot.sh`
Expected: PASS.

### Task 8: Final verification and closeout readiness [T8]

Context: Finish only when direct evidence proves contracts, scripts, skill text, pilot proof, and regression commands together.

Files:
- Modify: `docs/standard-chain-flow-optimization/2026-04-27-preflight-noise-regression/tasks.md`
- Create: `docs/standard-chain-flow-optimization/2026-04-27-preflight-noise-regression/verify-change-report.md`
- Modify: `docs/standard-chain-flow-optimization/worklog.md`

1. [T8] Run all targeted proving commands.

```bash
bash tests/test-standard-chain-failure-routing-contract.sh
bash tests/test-standard-chain-checker-contract.sh
bash tests/test-standard-chain-preflight-profiles.sh
bash tests/test-standard-chain-completion-profiles.sh
bash tests/test-standard-chain-content-quality.sh
bash tests/test-standard-chain-skill-structure.sh
bash tests/test-standard-chain-delegated-pilot-proof.sh
bash tests/test-standard-chain-login-homepage-pilot.sh
bash tools/validate-contracts.sh
python3 tools/community/validate_context_contract.py --repo-root .
bash tests/run-all.sh --quick
```

Expected: PASS for every command.

2. [T8] Run full regression when local runtime cost is acceptable.

```bash
bash tests/run-all.sh
```

Expected: PASS, or a concrete blocker recorded in `verify-change-report.md` without treating quick regression as a full-regression substitute.

3. [T8] Update `tasks.md` only for genuinely completed tasks and write `verify-change-report.md` with command, exit code, proof target, and residual risk.

4. [T8] Append the final worklog handoff with `state_ref` pointing to `verify-change-report.md` and `next_ref` pointing to the closeout or archive step.

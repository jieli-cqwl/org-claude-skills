# P0/P1 Remap

结论：P0/P1 的可证明字段合同项已进入实现；`follow-up-cleanup` 不代表终极目标降级，只表示该项已有部分基础，本轮按证据补齐 active contract/test/validator 缺口。

| issue_id | severity | remap | field_contract_basis |
| --- | --- | --- | --- |
| FLOW-001 | P0 | mapped-to-field-gap | QA full frozen task coverage maps to developer-report/verify-result active task refs, tasks.json coverage, active registry entries, and QA preflight set coverage. Current artifacts show fields/scripts exist; matrix keeps freshness/gate fields and implementation must preserve per-task coverage. |
| FLOW-002 | P0 | mapped-to-field-gap | Target changes map to target-change.invalidates_refs, superseded_evidence_refs, rebaseline_required, rebaseline_owner, required_fresh_proof_after_rebaseline; old user-decision target-change usage is cleanup. |
| SKILL-001 | P0 | mapped-to-field-gap | Fresh review after QA fixer path is already required by delivery-owner prose; remaining gap is to make fix-result fields first-class in field-consumption and freshness validation so post-fix verifier -> fresh code-reviewer -> QA cannot reuse stale review evidence. |
| SKILL-002 | P0 | mapped-to-field-gap | Typed signoff proof maps to signoff-package.runtime_evidence_matrix and artifact-registry active runtime entries; F reclassifies C move as keep/strengthen. |
| FLOW-003 | P1 | follow-up-cleanup | Delivery-owner stage_inputs now split DO-S1/DO-S5/DO-S6/DO-S7/DO-S8; remaining work is synchronizing tests/contracts around minimal fields. |
| FLOW-004 | P1 | follow-up-cleanup | Runtime evidence terminal issue is no longer represented as terminal for developer-report/review/verify in current standard-chain; remaining cleanup is validator/test guard against terminal-on-consumed-artifact recurrence. |
| FLOW-005 | P1 | follow-up-cleanup | QA no longer has code-review-result as required standard-chain input; delivery-owner owns review gate. Cleanup should prevent stale tests/docs from claiming QA consumes code-review-result. |
| FLOW-006 | P1 | follow-up-cleanup | verify-result.gate_result is enum PASS/ISSUE/BLOCKED and QA preflight requires PASS. Cleanup is active search for SPEC_OK/free-string assumptions. |
| FLOW-007 | P1 | follow-up-cleanup | DO intake now loads baseline artifacts and returns safe_for_baseline_audit=true with safe_to_dispatch=false; remaining cleanup is contract/test sync. |
| FLOW-008 | P1 | follow-up-cleanup | qa-result.obligation_results is already in standard-chain key_fields and field-consumption; F says reclassify C move as keep/verify coverage. |
| FLOW-009 | P1 | mapped-to-field-gap | Artifact registry runtime_artifact_policy exists in schema/template but field-consumption/requiredness and active runtime coverage validation still need contract hardening. |
| FLOW-010 | P1 | follow-up-cleanup | delivery-state now references shared-core stage/status/action and conditionally requires recovery fields; remaining cleanup is template/test coverage. |
| FLOW-011 | P1 | mapped-to-field-gap | Director lock trace must use nested director_confirmation.locked_field_digest. The flat locked_field_digest key_fields entries are active contract drift, not a user decision; migrate field-consumption/validators/tests to nested or dotted paths and delete the flat alias. |
| FLOW-012 | P1 | follow-up-cleanup | intake_preflight_check now distinguishes safe_for_baseline_audit from safe_to_dispatch=false; cleanup is stale wording/test sync. |
| SKILL-003 | P1 | mapped-to-field-gap | QA route semantics do not need a new user decision: PASS+ALLOW is the only release path; FAIL routes to fix/develop/review loop; CONDITIONAL/NOT_RUN/N_A or CONDITIONAL_ALLOW/BLOCK/DEFER must block commit and require owner/user routing with basis fields. Remaining gap is a deterministic route matrix validator. |
| SKILL-004 | P1 | follow-up-cleanup | progress_signal enum and delivery-owner prose now exclude bare owner_changed as progress; cleanup is status-card/test signal sync. |
| SKILL-005 | P1 | mapped-to-field-gap | owner_action_consumption exists and is required by delivery-owner/consistency flow; keep field and strengthen field-consumption/tests for advisory owner action closure. |

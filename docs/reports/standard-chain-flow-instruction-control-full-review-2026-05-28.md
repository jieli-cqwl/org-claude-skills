# Standard-chain Flow & Instruction Control Full Review

Date: 2026-05-28

## Conclusion

This review found 4 accepted P0 issues and 13 accepted P1 issues that must be repaired before the `product-director -> delivery-owner` chain can reliably support one human owner plus an agent team delivering real requirements.

The highest-risk failures are not wording polish. They are control-plane breaks: QA can admit incomplete per-task verification, scope/AC changes can reuse stale evidence, QA fixes can bypass fresh code review, and signoff can rely on logical or QA-only evidence instead of typed runtime coverage.

## Review scope

Reviewed scope:

- Flow contracts: `contracts/standard-chain.yaml`, `contracts/standard-chain-field-consumption.yaml`, `shared/runtime/standard-chain-catalog.json`.
- Runtime contracts, schemas, templates, and scripts under `shared/skills/*/contracts`, `shared/skills/*/templates`, and `shared/skills/*/scripts`.
- Instruction control in standard-chain skills from `product-director` through `delivery-owner`, including sidecar `fix`, `review`, `qa`, `verify`, and `consistency-audit`/auditor paths.
- Existing calibration report as prior evidence, with all findings re-deduped and rechecked.

Out of scope:

- GO/NO-GO readiness decision.
- Homepage dogfood acceptance.
- Repair implementation.
- Style-only rewrites that do not affect flow or instruction control.

## Method

Four read-only reviewers independently covered flow contract, flow runtime, instruction control, and skill-flow compatibility. A separate cross-review normalized the findings. I then rechecked P0/P1 evidence against the current workspace before writing this report.

Accepted findings had to include all five contract elements: exact location, evidence, impact on one-human-plus-agent-team delivery, severity, and repair direction. Weak, duplicate, readiness-centered, or style-only findings were rejected.

## Accepted P0 issues

```json
{
  "issue_id": "FLOW-001",
  "direction": "FLOW",
  "severity": "P0",
  "issue_type": "FLOW_SET_COVERAGE_ISSUE",
  "location": "shared/skills/qa/scripts/preflight_check.py:138",
  "claim": "QA preflight only checks discovered verify-result files and cannot prove every frozen task has a current final PASS.",
  "evidence": [
    "contracts/standard-chain.yaml:102-104 makes developer-report and verify-result optional QA inputs",
    "shared/skills/qa/scripts/preflight_check.py:138-159 globs verify-result candidates and checks only those candidates",
    "shared/skills/delivery-owner/SKILL.md:101-105 says every task in the QA batch must have developer evidence and verifier PASS before QA"
  ],
  "impact_on_goal": "A multi-task phase can reach QA with only partial verification coverage, so one task's PASS can mask another unverified task and produce phase-level fake completion.",
  "repair_direction": "Make QA preflight load tasks.json and active artifact-registry, then require each in-scope task to have current developer-report and final verify-result gate_result=PASS with matching baseline/active refs.",
  "reference_gap": null,
  "reviewer_confidence": "high"
}
```

Second check: confirmed `validate_verifier()` only globs verify-result candidates and never joins against the frozen task set.

```json
{
  "issue_id": "FLOW-002",
  "direction": "FLOW",
  "severity": "P0",
  "issue_type": "FLOW_RECOVERY_ISSUE",
  "location": "shared/skills/delivery-owner/contracts/user-decision.schema.json:3",
  "claim": "scope/AC/goal changes are recorded through a signoff/risk-style user-decision contract that has no evidence invalidation or rebaseline semantics.",
  "evidence": [
    "shared/skills/delivery-owner/SKILL.md:129-130 says scope/range裁决 writes user-decision.json",
    "shared/skills/delivery-owner/contracts/user-decision.schema.json:3 describes signoff or risk-acceptance decisions",
    "shared/skills/delivery-owner/contracts/user-decision.schema.json:61-75 lacks invalidates_refs, rebaseline_required, fresh_proof_after, or superseded evidence fields",
    "contracts/standard-chain.yaml:216-217 says delivery-owner must escalate scope_change/design_change/business_risk_acceptance/sign_off_rejection"
  ],
  "impact_on_goal": "After the user changes AC or scope, old tasks, verify, review, and QA evidence can still be used to close the new target.",
  "repair_direction": "Split decision types. Signoff and risk acceptance may use user-decision; scope/AC/goal/design changes must return to product/tech baseline freezing, mark affected artifacts superseded, and require fresh proof.",
  "reference_gap": null,
  "reviewer_confidence": "high"
}
```

Second check: confirmed the schema only requires generic decision, basis, digests, and task refs; it has no target-change invalidation model.

```json
{
  "issue_id": "SKILL-001",
  "direction": "INSTRUCTION_CONTROL",
  "severity": "P0",
  "issue_type": "SKILL_EVIDENCE_ISSUE",
  "location": "shared/skills/delivery-owner/SKILL.md:107-113",
  "claim": "QA FAIL fixer path can change code without requiring fresh code-review.",
  "evidence": [
    "shared/skills/delivery-owner/SKILL.md:101-104 requires fresh verifier and code-reviewer after code-review fixes",
    "shared/skills/delivery-owner/SKILL.md:111-113 says QA FAIL routes to fixer and then reruns affected verifier / QA only",
    "shared/skills/delivery-owner/SKILL.md:153 requires code-review blocking issues closed before QA, but does not cover code changes after that review"
  ],
  "impact_on_goal": "Code changed after a code-review PASS can enter closeout using stale review evidence, so final submitted code is not actually covered by review.",
  "repair_direction": "Any code change after a code-review PASS must invalidate affected code-review-result and trigger affected verifier, fresh code-reviewer, then affected QA. Closeout consumes only evidence produced after the last code change.",
  "reference_gap": "The reference behavior-control style binds gate approval to the exact content being approved; this path lets old approval cover new code.",
  "reviewer_confidence": "high"
}
```

Second check: confirmed DO-S6 and DO-S7 have asymmetric freshness rules.

```json
{
  "issue_id": "SKILL-002",
  "direction": "INSTRUCTION_CONTROL",
  "severity": "P0",
  "issue_type": "SKILL_EVIDENCE_ISSUE",
  "location": "shared/skills/delivery-owner/SKILL.md:123",
  "claim": "delivery-owner closeout allows logical evidence references, while signoff-package does not require typed runtime evidence coverage.",
  "evidence": [
    "shared/skills/delivery-owner/SKILL.md:123 says evidence may be expressed with logical references for /commit handoff",
    "shared/skills/delivery-owner/contracts/signoff-package.schema.json:77-97 only requires decision_basis_refs as a canonicalRefArray",
    "shared/skills/delivery-owner/templates/signoff-package.template.json:36-67 cites qa-result refs for decision basis and goal closure",
    "contracts/standard-chain.yaml:144-146 signoff key_fields do not require developer/review/verify/QA/consistency coverage"
  ],
  "impact_on_goal": "A natural-language summary or QA-only refs can replace the full runtime proof chain, creating fake signoff for one human owner.",
  "repair_direction": "Add a typed runtime evidence matrix to signoff-package: developer-report, verify-result, code-review-result, qa-result obligation_results, consistency-audit-result, producer, status, freshness, and active registry checks. Logical summaries may explain evidence but cannot replace canonical refs.",
  "reference_gap": "The reference behavior-control style separates explanatory summaries from admissible proof; this instruction lets summaries stand in for proof.",
  "reviewer_confidence": "high"
}
```

Second check: confirmed signoff schema/template lacks artifact-type coverage and freshness requirements.

## Accepted P1 issues

```json
{
  "issue_id": "FLOW-003",
  "direction": "FLOW",
  "severity": "P1",
  "issue_type": "FLOW_IO_ISSUE",
  "location": "contracts/standard-chain.yaml:130-134",
  "claim": "delivery-owner required inputs mix kickoff baseline artifacts with closeout/runtime artifacts.",
  "evidence": [
    "contracts/standard-chain.yaml:132-134 requires artifact-registry, code-review-result, developer-report, verify-result, qa-result, and consistency-audit-result together",
    "shared/skills/delivery-owner/SKILL.md:66 says baseline consistency-audit input must not require developer-report, verify-result, code-review-result, or qa-result"
  ],
  "impact_on_goal": "Delivery-owner kickoff can be blocked by future artifacts, or agents may bypass required inputs to start work.",
  "repair_direction": "Split delivery-owner inputs by stage: DO-S1 kickoff baseline, DO-S5 execution evidence, DO-S6 review, DO-S7 QA, and DO-S8 closeout/signoff.",
  "reference_gap": null,
  "reviewer_confidence": "high"
}
```

```json
{
  "issue_id": "FLOW-004",
  "direction": "FLOW",
  "severity": "P1",
  "issue_type": "FLOW_TERMINAL_ISSUE",
  "location": "contracts/standard-chain.yaml:74-98",
  "claim": "developer-report, code-review-result, and verify-result are marked terminal while downstream consumers still depend on them.",
  "evidence": [
    "contracts/standard-chain.yaml:74-78,85-87,95-97 mark these runtime artifacts terminal",
    "contracts/standard-chain-field-consumption.yaml:1013-1164 declares downstream verify/review/QA/delivery-owner consumption"
  ],
  "impact_on_goal": "Recovery or routing logic can treat intermediate runtime evidence as an endpoint and skip later quality gates.",
  "repair_direction": "Remove terminal semantics from downstream-consumed runtime artifacts, or replace it with explicit archival semantics and declared consumers.",
  "reference_gap": null,
  "reviewer_confidence": "high"
}
```

```json
{
  "issue_id": "FLOW-005",
  "direction": "FLOW",
  "severity": "P1",
  "issue_type": "FLOW_IO_ISSUE",
  "location": "contracts/standard-chain.yaml:101-103",
  "claim": "The contract says QA requires and consumes code-review-result, but QA skill and preflight do not depend on or check it.",
  "evidence": [
    "contracts/standard-chain.yaml:102 lists code-review-result as QA required input",
    "contracts/standard-chain-field-consumption.yaml:1053-1061 says review.gate_result is consumed by QA gate",
    "shared/skills/qa/SKILL.md:41-43 says QA does not depend on developer-report / code-review-result for QA conclusions",
    "shared/skills/qa/scripts/preflight_check.py:172-190 does not load or validate code-review-result"
  ],
  "impact_on_goal": "QA may proceed while code review is missing or failed, and a human owner may wrongly believe the QA gate consumed review closure.",
  "repair_direction": "Choose one authority: either QA preflight mechanically verifies canonical code-review-result PASS/active refs, or standard-chain removes code-review-result from QA required input and makes delivery-owner DO-S6 the sole review gate.",
  "reference_gap": null,
  "reviewer_confidence": "high"
}
```

```json
{
  "issue_id": "FLOW-006",
  "direction": "FLOW",
  "severity": "P1",
  "issue_type": "FLOW_STATE_ISSUE",
  "location": "shared/skills/verify/contracts/verify-result.schema.json:17-19",
  "claim": "verify final gate_result is an unconstrained string and QA accepts SPEC_OK as admission.",
  "evidence": [
    "shared/skills/verify/contracts/verify-result.schema.json:17-19 defines gate_result as string without enum",
    "shared/skills/qa/SKILL.md:61 accepts PASS or SPEC_OK",
    "shared/skills/qa/scripts/preflight_check.py:153-159 accepts PASS or SPEC_OK"
  ],
  "impact_on_goal": "SPEC_OK is an intermediate spec-review state but can admit QA before full verification phases pass.",
  "repair_direction": "Constrain final verify gate_result to PASS / ISSUE / BLOCKED. Keep SPEC_OK only inside phase_verdicts.spec_review, and make QA accept only final PASS.",
  "reference_gap": null,
  "reviewer_confidence": "high"
}
```

```json
{
  "issue_id": "FLOW-007",
  "direction": "FLOW",
  "severity": "P1",
  "issue_type": "FLOW_SET_COVERAGE_ISSUE",
  "location": "shared/skills/delivery-owner/scripts/intake_preflight_check.py:287-303",
  "claim": "delivery-owner intake preflight does not validate the full baseline set, plan readiness, or cross-unit obligations before reporting safe_to_dispatch.",
  "evidence": [
    "shared/skills/delivery-owner/scripts/intake_preflight_check.py:297-303 loads tasks.json, artifact-registry.json, and existing test-cases only",
    "contracts/standard-chain.yaml:60-63 makes plan.json planning_readiness, implementation_path, and user_confirmation delivery-owner/developer/verify/QA inputs",
    "contracts/standard-chain.yaml:52-54 makes cross_unit_obligations a test-cases key field",
    "shared/skills/delivery-owner/SKILL.md:61-67 requires scope, AC, dependencies, qa_handoff_contract, cross_unit_obligations, and blocking gaps to be consumed"
  ],
  "impact_on_goal": "Delivery-owner can start dispatch from an incomplete or unsafe planning baseline, especially in multi-unit flows.",
  "repair_direction": "Make intake preflight load and validate brief, phase-prd, plan, design, tasks, and all relevant test-cases; require planning_readiness=READY, confirmed plan/task refs, complete qa_handoff_contract, cross_unit_obligations coverage, and no blocking gaps.",
  "reference_gap": null,
  "reviewer_confidence": "high"
}
```

```json
{
  "issue_id": "FLOW-008",
  "direction": "FLOW",
  "severity": "P1",
  "issue_type": "FLOW_TRACE_ISSUE",
  "location": "contracts/standard-chain.yaml:105-107",
  "claim": "QA obligation_results are required by qa-result schema but absent from standard-chain QA key_fields and field consumption.",
  "evidence": [
    "shared/skills/qa/contracts/qa-result.schema.json:118-207 requires obligation_results",
    "contracts/standard-chain.yaml:105-107 QA key_fields omit obligation_results",
    "contracts/standard-chain-field-consumption.yaml has no obligation_results consumer mapping",
    "shared/skills/delivery-owner/SKILL.md:119 requires qa-result.obligation_results before full advisory audit"
  ],
  "impact_on_goal": "Delivery-owner can consume QA summary without proving each QA handoff obligation and cross-unit obligation is closed.",
  "repair_direction": "Add obligation_results to QA key_fields and field-consumption. Require one-to-one coverage against qa_handoff_contract and relevant cross_unit_obligations.",
  "reference_gap": null,
  "reviewer_confidence": "high"
}
```

```json
{
  "issue_id": "FLOW-009",
  "direction": "FLOW",
  "severity": "P1",
  "issue_type": "FLOW_OPERABILITY_ISSUE",
  "location": "shared/skills/delivery-owner/contracts/artifact-registry.schema.json:20-28",
  "claim": "runtime artifact registry does not close owner, timing, active uniqueness, or runtime evidence coverage responsibilities.",
  "evidence": [
    "shared/skills/delivery-owner/contracts/artifact-registry.schema.json:20-28 only requires active_revision_id and revisions",
    "shared/skills/delivery-owner/templates/artifact-registry.template.json:18-113 includes baseline artifacts and delivery-state but no developer-report, verify-result, code-review-result, qa-result, or consistency-audit-result",
    "contracts/standard-chain.yaml:172-173 defines active_artifact_truth as artifact-registry.active_revision_id",
    "shared/skills/verify/scripts/preflight_check.py depends on the active registry to find developer-report entries"
  ],
  "impact_on_goal": "A human owner or downstream agent may have to guess current runtime evidence paths from the filesystem, risking stale evidence reuse.",
  "repair_direction": "Define per-stage required active artifact types, uniqueness rules for active entries, and producer or delivery-owner append responsibility before handoff to the next role.",
  "reference_gap": null,
  "reviewer_confidence": "high"
}
```

```json
{
  "issue_id": "FLOW-010",
  "direction": "FLOW",
  "severity": "P1",
  "issue_type": "FLOW_STATE_ISSUE",
  "location": "shared/skills/delivery-owner/contracts/delivery-state.schema.json:14-21",
  "claim": "delivery-state loosens shared-core stage/action enums and does not require recovery-critical blocker/owner/resume fields.",
  "evidence": [
    "shared/skills/lib/contracts/shared-core.schema.json:393-474 defines control_action and current_stage enums",
    "shared/skills/delivery-owner/contracts/delivery-state.schema.json:14-21 redefines current_stage/status/control_action as free strings",
    "shared/skills/delivery-owner/contracts/delivery-state.schema.json:110-124 has blocker fields but required list at 126-135 omits them",
    "contracts/standard-chain.yaml:171-174 makes delivery-state.current_stage the stage truth"
  ],
  "impact_on_goal": "After interruption, the canonical state can be syntactically valid but semantically unmappable, and may omit blocker owner or resume conditions.",
  "repair_direction": "Reference shared-core enums directly and conditionally require blocker_id, blocker_owner, blocker_basis_refs, resume_stage, next_action, and resume_condition when blocked or paused.",
  "reference_gap": null,
  "reviewer_confidence": "high"
}
```

```json
{
  "issue_id": "FLOW-011",
  "direction": "FLOW",
  "severity": "P1",
  "issue_type": "FLOW_AUTHORITY_ISSUE",
  "location": "contracts/standard-chain.yaml:23-32",
  "claim": "Director lock fields are required in PM-refined schemas but absent from standard-chain key_fields, field consumption, and delivery-owner intake checks.",
  "evidence": [
    "shared/skills/product-manager/contracts/brief.schema.json:87-123 requires director_confirmation.locked_field_digest and locked_fields",
    "shared/skills/product-manager/contracts/phase-prd.schema.json requires director_confirmation",
    "contracts/standard-chain.yaml:26-32 PM brief/phase-prd key_fields omit director_confirmation and locked_field_digest",
    "shared/skills/delivery-owner/scripts/intake_preflight_check.py:297-303 does not read brief or phase-prd"
  ],
  "impact_on_goal": "Final delivery cannot mechanically prove PM refinement still preserves product-director locked root problem, scope, goals, and exit conditions.",
  "repair_direction": "Add director_confirmation and locked_field_digest to key_fields and field-consumption; delivery-owner or consistency-auditor must verify digests before execution and signoff.",
  "reference_gap": null,
  "reviewer_confidence": "high"
}
```

```json
{
  "issue_id": "FLOW-012",
  "direction": "FLOW",
  "severity": "P1",
  "issue_type": "FLOW_OPERABILITY_ISSUE",
  "location": "shared/skills/delivery-owner/scripts/intake_preflight_check.py:257-272",
  "claim": "delivery-owner intake reports safe_to_dispatch=true before the baseline consistency-audit required by the skill has run.",
  "evidence": [
    "shared/skills/delivery-owner/scripts/intake_preflight_check.py:263-272 success_payload returns safe_to_dispatch=true",
    "shared/skills/delivery-owner/scripts/intake_preflight_check.py:287-303 validate() only validates tasks, registry, and test-cases",
    "shared/skills/delivery-owner/SKILL.md:66-68 says preflight is followed by baseline consistency-audit and blocked_layers/CRITICAL/required_owner_action must stop before DO-S2 or developer dispatch"
  ],
  "impact_on_goal": "Automation or a human owner can interpret intake PASS as dispatch permission and skip the required baseline drift audit.",
  "repair_direction": "Rename this result to safe_for_baseline_audit, or require baseline audit result input before any safe_to_dispatch=true state. Status cards should distinguish intake PASS from dispatch-ready.",
  "reference_gap": null,
  "reviewer_confidence": "high"
}
```

```json
{
  "issue_id": "SKILL-003",
  "direction": "INSTRUCTION_CONTROL",
  "severity": "P1",
  "issue_type": "SKILL_FLOW_COMPATIBILITY_ISSUE",
  "location": "shared/skills/delivery-owner/SKILL.md:111-113",
  "claim": "delivery-owner only defines QA PASS/FAIL routing and lacks routes for CONDITIONAL_ALLOW, BLOCK, DEFER, NOT_RUN, or N_A states.",
  "evidence": [
    "shared/skills/qa/contracts/qa-result.schema.json:17-35 allows gate_result PASS/FAIL/CONDITIONAL/NOT_RUN/N_A and release_recommendation ALLOW/CONDITIONAL_ALLOW/BLOCK/DEFER",
    "shared/skills/qa/scripts/completion_check.sh:116-124 only adds extra requirements when gate_result=FAIL",
    "shared/skills/delivery-owner/SKILL.md:111-113 only branches qa agent PASS or FAIL"
  ],
  "impact_on_goal": "Conditional release, deferred QA, or not-run QA can be mishandled as either pass or generic fail without the correct owner decision, waiver, or fresh proof path.",
  "repair_direction": "Define delivery-owner routing for each QA gate/release recommendation combination, including user-decision packages, waiver requirements, blocked owner, and resume conditions.",
  "reference_gap": "The reference behavior-control style binds each terminal state word to a next owner action; this skill leaves state words unbound.",
  "reviewer_confidence": "high"
}
```

```json
{
  "issue_id": "SKILL-004",
  "direction": "INSTRUCTION_CONTROL",
  "severity": "P1",
  "issue_type": "SKILL_PROCESS_ISSUE",
  "location": "shared/skills/delivery-owner/SKILL.md:24-26",
  "claim": "owner_changed and generic new evidence can count as progress, weakening the no-progress stop rule.",
  "evidence": [
    "shared/skills/delivery-owner/SKILL.md:24-26 counts owner change as progress",
    "shared/skills/delivery-owner/SKILL.md:94-96 repeats the same progress set",
    "shared/skills/delivery-owner/templates/status-card.template.md:15 lists owner_changed as progress_signal"
  ],
  "impact_on_goal": "Agent loops can avoid the two-round no-progress stop by moving ownership or adding evidence that does not change the active gap judgment.",
  "repair_direction": "Define progress as evidence that closes or narrows the current gap, changes the gap judgment, or routes to a more authoritative owner with next_action and resume_condition. Bare owner_changed should not count.",
  "reference_gap": "The reference behavior-control style closes common escape paths; this wording leaves a responsibility-movement escape path.",
  "reviewer_confidence": "high"
}
```

```json
{
  "issue_id": "SKILL-005",
  "direction": "INSTRUCTION_CONTROL",
  "severity": "P1",
  "issue_type": "SKILL_GATE_ISSUE",
  "location": "shared/skills/delivery-owner/SKILL.md:17-18",
  "claim": "advisory owner action consumption is not structured as a named owner action/result/evidence update.",
  "evidence": [
    "shared/skills/delivery-owner/SKILL.md:17-18 says advisory owner action must be consumed before development",
    "shared/skills/delivery-owner/SKILL.md:119-120 repeats the requirement before signoff",
    "shared/skills/delivery-owner/SKILL.md:149-155 checklist says owner action consumed or paused, without a structured result field"
  ],
  "impact_on_goal": "delivery-owner may treat reading or summarizing advisory findings as closure, rather than routing the required owner action and recording proof.",
  "repair_direction": "Define owner_action_consumption with action_id, required owner, routed_to, result, evidence_ref, state_update, and reopen condition. Delivery-owner may route and record, not self-clear advisory obligations.",
  "reference_gap": "The reference behavior-control style turns ambiguous verbs into concrete owner actions and gate outcomes.",
  "reviewer_confidence": "medium"
}
```

## P2/P3 summary

Accepted P2:

- `SKILL-006`: `shared/skills/delivery-owner/SKILL.md:4` frontmatter description carries too much process detail. It may encourage treating the description as an execution summary instead of reading hard gates. Repair by limiting description to trigger and role scope.

Tracked but not accepted as P0/P1:

- `fix-result` has consumers in `standard-chain.yaml` but no field-consumption section. This is real, but current evidence did not prove review/verify/QA would incorrectly accept a blocked or escalated fix-result; track as P2 follow-up unless fresh proof shows a direct closeout failure.
- `tasks.user_confirmation` is required by tasks schema and delivery-owner intake but absent from `standard-chain.yaml` key_fields. This is a trace cleanup item; current script gate prevents immediate execution bypass.
- `review` vs `code-reviewer` and `consistency-audit` vs `consistency-auditor` naming drift should be checked during later consistency governance, but was not accepted as a current delivery blocker.

P3: none accepted.

## Rejected findings and why rejected

- Dogfood readiness / GO-NO-GO claims: rejected because this review is not a readiness gate.
- Homepage-specific acceptance claims: rejected because homepage/dogfood can only be evidence, not the review center.
- Pure wording clarity claims without behavior risk: rejected.
- Flowchart missing one path, preflight failure codes not expanded inline, or status card always first: rejected as style/readability issues without direct delivery-control failure.
- PM delivery confirmation lacking a named user action: downgraded to needs-followup. Some risk overlaps FLOW-002, but current evidence was weaker than accepted stale-evidence and scope-change issues.
- Producer authority naming split between `product`, `product-director`, and `product-manager`: mostly merged into FLOW-011 where director lock trace has concrete schema/contract evidence; standalone naming drift was rejected.
- QA `issue_ledger.owner_hint` role coverage: needs-followup, but weaker than accepted QA state route and obligation coverage issues.

## Cross-review notes

Repeated root causes:

1. Collection validators check existence of some artifact, not full set coverage.
2. State words are split across schema, skill prose, status cards, and report templates without a single canonical transition model.
3. Evidence freshness after code or target changes is under-specified.
4. The artifact registry is treated as recovery truth, but runtime producer registration and active coverage are not enforced.
5. Skill prose sometimes uses strong verbs such as consume, pass, ready, dispatch, and evidence without binding them to a named owner action or structured artifact.

Deduping decisions:

- `SPEC_OK` issues from instruction and flow reviewers were merged into FLOW-006.
- QA conditional/deferred/not-run routing was kept as SKILL-003 because the behavioral escape path is primarily in delivery-owner routing prose.
- Logical evidence refs and signoff coverage were merged into SKILL-002 because the most dangerous escape path is the delivery-owner instruction plus weak schema.
- Runtime registry owner and active coverage issues were merged into FLOW-009.
- Director/PM authority drift was only accepted where it affects director lock digest trace, FLOW-011.

## P0/P1 repair roadmap

1. Repair P0 set coverage and freshness first.
   - Fix FLOW-001 QA per-task coverage.
   - Fix FLOW-002 scope/AC/goal rebaseline and evidence invalidation.
   - Fix SKILL-001 fresh code-review after QA/fixer code changes.
   - Fix SKILL-002 typed signoff evidence coverage.

2. Repair canonical state and admission gates.
   - Fix FLOW-006 final verify gate enum and QA admission.
   - Fix SKILL-003 QA conditional/deferred/not-run delivery-owner routes.
   - Fix FLOW-010 delivery-state enums and recovery-required fields.

3. Repair delivery-owner kickoff and runtime truth.
   - Fix FLOW-003 stage-dependent delivery-owner inputs.
   - Fix FLOW-007 intake preflight baseline/plan/cross-unit coverage.
   - Fix FLOW-012 safe_to_dispatch versus baseline audit state.
   - Fix FLOW-009 artifact registry active runtime coverage and registration ownership.

4. Repair trace and consumer alignment.
   - Fix FLOW-004 terminal semantics.
   - Fix FLOW-005 code-review-result QA contract mismatch.
   - Fix FLOW-008 QA obligation_results field consumption.
   - Fix FLOW-011 director lock trace into key_fields/field-consumption and DO/consistency checks.
   - Fix SKILL-004 no-progress escape path and SKILL-005 advisory owner action consumption.

Retest after repairs:

- Add contract/schema/script tests for per-task set coverage and cross-unit coverage.
- Add fixture where one task lacks verify PASS and assert QA preflight blocks.
- Add fixture where scope/AC changes and assert old runtime evidence is superseded.
- Add fixture where QA fixer modifies code and assert code-review is required again.
- Add signoff fixture missing one runtime artifact type and assert signoff blocks.
- Add recovery fixture with blocked delivery-state and assert recover path reports blocker owner, active artifact, next action, and resume condition.

## Follow-up review plan

After repairs, run a focused follow-up review in this order:

1. P0 regression review: prove no fake QA PASS, stale evidence reuse, stale code-review reuse, or logical signoff evidence remains.
2. State-machine review: verify current_stage/control_action/status words map across canonical JSON, status card, report, and scripts.
3. Registry/freshness review: verify every producer or delivery-owner append responsibility and active runtime coverage.
4. Instruction-control review: re-read delivery-owner, QA, verify, and fix around pass/ready/consume/evidence/dispatch words.
5. One additional full-scope pass must find no new P0/P1 before declaring this review scope closed.

## Known environment/input risks

- The working tree had pre-existing modified files and untracked report/spec directories before this report was written. This review did not revert or modify those files.
- `contracts/active-doc-scope.yaml` state was not treated as a delivery blocker because this task is not a live dogfood readiness gate.
- Some useful cleanup candidates were intentionally not accepted as P0/P1 because they lacked a direct north-star failure chain in this review scope.

# Standard-chain Flow & Instruction Control Calibration Report

Date: 2026-05-28

## Verdict

Calibration passed with contract adjustments required before full review.

Both reviewers produced evidence-backed findings that match the intended review style:

- Flow reviewer found contract and runtime-flow problems in the `developer -> verify -> QA -> delivery-owner` slice.
- Instruction reviewer found sentence-level delivery-owner skill problems that can change agent behavior.

The review method is sharp enough to continue, but the contract needs a few refinements before full-scale review.

## Calibration Scope

Contract:

- `docs/superpowers/specs/2026-05-28--standard-chain-flow-instruction-control-review--contract.md`

Plan:

- `docs/superpowers/specs/2026-05-28--standard-chain-flow-instruction-control-calibration--plan.md`

Flow slice:

- `developer -> verify -> QA -> delivery-owner`

Skill sample:

- `shared/skills/delivery-owner/SKILL.md`

Reference skill:

- `/Users/lijieli/.claude/skills/brainstorming/SKILL.md`

## Accepted Flow Issues

### FLOW-001: delivery-owner required inputs mix kickoff and closeout artifacts

Severity: P1

Type: `FLOW_IO_ISSUE`

Evidence:

- `contracts/standard-chain.yaml:130-135`
- `shared/skills/delivery-owner/SKILL.md:59-68`
- `shared/skills/delivery-owner/SKILL.md:89-124`

Impact:

Delivery-owner is the coordinator after frozen tasks, but the global contract requires artifacts that only exist after delivery-owner dispatches downstream agents. This can either block kickoff incorrectly or make teams bypass required inputs.

Repair direction:

Split delivery-owner inputs by stage: kickoff baseline inputs, then stage-specific runtime artifacts for developer, verify, review, QA, consistency, and closeout.

### FLOW-002: runtime artifacts are marked terminal despite downstream consumers

Severity: P1

Type: `FLOW_IO_ISSUE`

Evidence:

- `contracts/standard-chain.yaml:74-78`
- `contracts/standard-chain.yaml:85-87`
- `contracts/standard-chain.yaml:95-97`
- `contracts/standard-chain-field-consumption.yaml:1013-1164`

Impact:

A dispatcher or handoff reader could treat developer-report, code-review-result, or verify-result as chain endpoints even though verify, QA, and delivery-owner still consume them.

Repair direction:

Remove terminal semantics from runtime artifacts with downstream consumers. Declare actual consumers or define a separate archival marker.

### FLOW-003: QA can pass preflight without complete per-task verify coverage

Severity: P0

Type: `FLOW_TRACE_ISSUE`

Evidence:

- `contracts/standard-chain.yaml:101-104`
- `shared/skills/qa/scripts/preflight_check.py:137-159`
- `shared/skills/qa/scripts/preflight_check.py:171-188`
- `shared/skills/qa/SKILL.md:56-61`
- `contracts/standard-chain-field-consumption.yaml:1102-1164`

Impact:

In a multi-task phase, QA may see at least one passing verify-result and continue even if another task lacks verification. A phase-level QA PASS could then mask unverified work.

Repair direction:

Make `tasks.json` required for QA and validate that every in-scope task has a current developer-report and verify-result with `gate_result=PASS` and matching baseline/active refs.

### FLOW-004: verify gate_result allows SPEC_OK as QA admission signal

Severity: P1

Type: `FLOW_STATE_ISSUE`

Evidence:

- `shared/skills/verify/contracts/verify-result.schema.json:17-19`
- `shared/skills/verify/SKILL.md:33-35`
- `shared/skills/verify/SKILL.md:97-127`
- `shared/skills/qa/SKILL.md:56-61`
- `shared/skills/qa/scripts/preflight_check.py:151-159`

Impact:

`SPEC_OK` is an intermediate spec-review result, but QA accepts it like final verify PASS. This can skip later verification phases.

Repair direction:

Constrain final `gate_result` to `PASS | ISSUE | BLOCKED`. Keep `SPEC_OK` only under phase verdicts. QA accepts only final `PASS` plus all required subphase verdicts.

### FLOW-005: QA obligation proof chain is absent from standard-chain key fields and field consumption

Severity: P1

Type: `FLOW_TRACE_ISSUE`

Evidence:

- `contracts/standard-chain.yaml:105-107`
- `contracts/standard-chain-field-consumption.yaml:1166-1267`
- `shared/skills/qa/SKILL.md:105`
- `shared/skills/qa/contracts/qa-result.schema.json:118-207`
- `shared/skills/delivery-owner/SKILL.md:119`

Impact:

Delivery-owner can receive QA summary without the obligation-level proof chain needed to verify browser, regression, exploratory, and handoff obligations.

Repair direction:

Add `obligation_results` to QA key fields and field consumption. Require one-to-one mapping to `qa_handoff_contract[].obligation_id`.

### FLOW-006: runtime artifact registry handoff has no clear owner

Severity: P1

Type: `FLOW_OPERABILITY_ISSUE`

Evidence:

- `shared/skills/verify/scripts/preflight_check.py:219-250`
- `shared/skills/verify/scripts/preflight_check.py:335-340`
- `shared/skills/developer/SKILL.md:99-109`
- `shared/skills/delivery-owner/SKILL.md:126-133`
- `shared/skills/delivery-owner/templates/artifact-registry.template.json:18-113`

Impact:

Developer can write a valid report, but verify may not find it through the active artifact registry. The human owner and agents then must guess between filesystem paths and registry truth.

Repair direction:

Define who appends runtime artifacts to `artifact-registry` and when. Either every producer registers its artifact before handoff, or delivery-owner registers before dispatching the next role.

### FLOW-007: delivery state vocabulary is split across several sources

Severity: P1

Type: `FLOW_STATE_ISSUE`

Evidence:

- `shared/skills/lib/contracts/shared-core.schema.json:392-402`
- `shared/skills/lib/contracts/shared-core.schema.json:459-473`
- `shared/skills/delivery-owner/contracts/delivery-state.schema.json:14-21`
- `shared/skills/delivery-owner/templates/status-card.template.md:3-23`
- `shared/skills/delivery-owner/templates/delivery-report.template.md:3-15`

Impact:

A human owner may see a status card state that tools cannot map to canonical delivery-state fields. Recovery and automation become unreliable.

Repair direction:

Use shared-core enums directly or define a delivery-owner state machine with explicit mappings for JSON, status card, and report text.

### FLOW-008: signoff package can omit full runtime evidence coverage

Severity: P1

Type: `FLOW_TRACE_ISSUE`

Evidence:

- `shared/skills/delivery-owner/templates/signoff-package.template.json:36-66`
- `shared/skills/delivery-owner/contracts/signoff-package.schema.json:77-97`
- `shared/skills/delivery-owner/SKILL.md:119-123`
- `tools/community/validate_readiness_contract.py:450-505`

Impact:

The signoff package can look valid while only citing QA summary evidence. One human owner must then manually inspect history to know whether developer, verify, code review, QA, and consistency evidence all closed.

Repair direction:

Require structured evidence coverage for developer-report, verify-result, code-review-result, qa-result, and consistency-audit-result, with freshness and active-registry checks.

## Accepted Instruction Control Issues

### SKILL-001: advisory owner action consumption is not判定

Severity: P0

Type: `SKILL_GATE_ISSUE`

Evidence:

- `shared/skills/delivery-owner/SKILL.md:18`
- `shared/skills/delivery-owner/SKILL.md:67`
- `shared/skills/delivery-owner/SKILL.md:120`
- `/Users/lijieli/.claude/skills/brainstorming/SKILL.md:130`

Impact:

Delivery-owner can interpret “consume” as reading or summarizing an advisory action, then continue past CRITICAL findings or required owner actions.

Repair direction:

Define consumption as a named owner action with artifact/result/evidence ref and state update. Delivery-owner may route and record, not self-clear advisory obligations.

### SKILL-002: QA fixer path omits fresh code review after code changes

Severity: P0

Type: `SKILL_EVIDENCE_ISSUE`

Evidence:

- `shared/skills/delivery-owner/SKILL.md:112`
- `shared/skills/delivery-owner/SKILL.md:103`
- `shared/skills/delivery-owner/SKILL.md:153`

Impact:

Fixer can change code after a code-review PASS, then proceed through verify/QA without fresh code review.

Repair direction:

Any code change after code-review PASS must trigger fresh affected verify, fresh code-review, then affected QA. Closeout uses only evidence after the last code change.

### SKILL-003: progress signal can be satisfied without substantive gap progress

Severity: P1

Type: `SKILL_PROCESS_ISSUE`

Evidence:

- `shared/skills/delivery-owner/SKILL.md:25`
- `shared/skills/delivery-owner/SKILL.md:94`
- `shared/skills/delivery-owner/templates/status-card.template.md:15`

Impact:

Agent loops can avoid the no-progress stop rule by changing owner or adding weak evidence unrelated to the active gap.

Repair direction:

Define progress as evidence that changes the current gap judgment, closes or narrows the gap, or routes to a more correct authority with next action and resume condition.

### SKILL-004: logical evidence references can replace concrete evidence refs

Severity: P0

Type: `SKILL_EVIDENCE_ISSUE`

Evidence:

- `shared/skills/delivery-owner/SKILL.md:123`
- `shared/skills/delivery-owner/contracts/signoff-package.schema.json:42-49`
- `shared/skills/delivery-owner/templates/status-card.template.md:18-19`

Impact:

A natural-language summary can be used as proof in signoff or commit handoff, creating fake evidence closure.

Repair direction:

Require canonical artifact refs for evidence. Logical summaries can explain evidence but cannot replace artifact refs, freshness, producer, status, and stale checks.

### SKILL-005: scope/AC裁决 is mixed into user-decision signoff/risk flow

Severity: P0

Type: `SKILL_FLOW_COMPATIBILITY_ISSUE`

Evidence:

- `shared/skills/delivery-owner/SKILL.md:130`
- `shared/skills/delivery-owner/contracts/user-decision.schema.json:3`
- `shared/skills/delivery-owner/contracts/user-decision.schema.json:61-75`

Impact:

When the user changes scope or AC, delivery-owner may write a user decision and continue with old tasks and evidence.

Repair direction:

Split decision types. Signoff and risk acceptance can write `user-decision.json`; scope/AC/goal changes must return to product/tech baseline freezing and invalidate affected evidence.

### SKILL-006: READY_FOR_COMMIT and DELIVERED are混用

Severity: P1

Type: `SKILL_OUTPUT_ISSUE`

Evidence:

- `shared/skills/delivery-owner/SKILL.md:124`
- `shared/skills/delivery-owner/SKILL.md:133`
- `shared/skills/delivery-owner/SKILL.md:162`

Impact:

The human owner can see a delivery report before commit result exists, confusing preparation with delivery.

Repair direction:

Before commit, produce only signoff package and commit handoff with `READY_FOR_COMMIT`. Produce delivery report only after commit result is recorded and state becomes `DELIVERED`.

### SKILL-007: delivery-owner description carries execution-summary risk

Severity: P2

Type: `SKILL_TRIGGER_ISSUE`

Evidence:

- `shared/skills/delivery-owner/SKILL.md:4`
- `/Users/lijieli/.claude/skills/brainstorming/SKILL.md:2`

Impact:

A model may treat the frontmatter description as an execution summary and skip正文 gates.

Repair direction:

Restrict description to trigger conditions and role scope. Move process details and commit mentions into正文 gates.

## Rejected Or Deferred Candidates

### From Flow Review

- Duplicate baseline/active task refs in `standard-chain.yaml`: real cleanup candidate, but calibration did not prove direct flow failure in this slice.
- `review` vs `code-reviewer` naming drift: potential naming issue, but current task packet tooling accepts `code-reviewer`.
- QA `issue_ledger.owner_hint` missing some roles: plausible routing issue, but current evidence is weaker than accepted items.
- Dogfood readiness claims: rejected because this review is not a dogfood readiness gate.
- `consistency-audit` vs `consistency-auditor` naming drift: defer to a later slice focused on consistency role.

### From Instruction Review

- Broad role sentence in delivery-owner: not accepted because later gates provide concrete constraints.
- Status card always first: not accepted because it has recovery value.
- One developer agent per task: not accepted because it prevents responsibility mixing.
- Flowchart missing one user pause path: polish issue, weaker than accepted findings.
- Preflight failure codes not expanded inline: not accepted because adjacent text defines output categories.

## Cross-Review Notes

The two reviewer outputs agree on several root themes:

1. Evidence freshness is not consistently enforced across code changes, QA fixes, and signoff.
2. State vocabulary and state endpoints are not tight enough for reliable recovery.
3. Runtime artifact registration and evidence refs are too weak for one human owner to safely delegate and resume.
4. Scope/AC changes are the highest-risk path for old evidence reuse.
5. The new review contract successfully shifted the review away from homepage readiness and toward flow/instruction control issues.

## Contract Adjustments Required

Before full review, update the contract with these refinements:

1. Add `reference_gap` to the issue format for instruction issues.
2. Define that instruction issues may overlap flow issues when a sentence creates the behavioral escape path.
3. Add a stage-dependent input rule: kickoff inputs and closeout inputs must not be judged as one global required set.
4. Define strict `terminal` semantics: no artifact with downstream consumers may be terminal unless it has explicit archival semantics.
5. Add state vocabulary mapping checks across canonical JSON, status cards, reports, and handoff text.
6. Add set-coverage checks for scripts that validate collections, especially task-to-result coverage.
7. Add severity guidance for preparation states reported as completion states.
8. Add explicit scrutiny for status words such as consume, ready, closed, confirmed, authorized, pass, done, delivered, and accepted.

## Calibration Pass Criteria Review

- At least one accepted FLOW issue has exact evidence: passed.
- At least one accepted INSTRUCTION_CONTROL issue cites exact sentence/paragraph location: passed.
- Accepted issues explain impact on one human plus agent team delivery: passed.
- Accepted P0/P1 issues include repair direction: passed.
- Weak findings were rejected rather than preserved: passed.
- Dogfood readiness was not used as the center of the claims: passed.

## Decision

Proceed to update the review contract, then launch the full review.

Do not start full review until the contract adjustments above are applied.

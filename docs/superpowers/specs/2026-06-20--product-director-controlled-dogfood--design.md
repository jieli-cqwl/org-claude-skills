# Product-director Controlled Dogfood Design

## Objective

Define a staged, evidence-first dogfood process for `product-director` on real complex-demand intake.

The immediate decision is not whether `standard-chain` is ready, whether `delivery-owner` can run real delivery, or whether `product-director` should become a daily/default skill. The decision is whether a low-cost real transcript trial can prove that `product-director` handles complex-demand intake without fake closure, stage jumps, over-processing simple work, or weak downstream baselines.

## Current Evidence Boundary

Current repository evidence supports a narrow trial only:

- `docs/reports/skill-best-practice-model-standard-chain-trial-review-2026-06-19.md` marks `product-director` as `CONDITIONAL` for controlled complex-demand dogfood.
- `shared/skills/product-director/evals/dogfood/team-pilot-readiness.json` requires 5 real complex-demand transcript reviews before promotion beyond team pilot.
- `contracts/standard-chain-invocation-policy.yaml` keeps routing non-persistent: inline route rationale only, no canonical route-decision artifact, no runtime state, and no required `worklog.md` entry.
- `docs/reports/2026-06-01--standard-chain-controlled-pilot-pr-closeout.md` is historical evidence only. It states the previous pilot feature directory was removed and the active scope entry was cleared, so it cannot be reused as current handoff input.

## Non-goals

- Do not start a live dogfood run from this design.
- Do not create or modify `contracts/active-doc-scope.yaml`.
- Do not create `brief.json`, `phase-prd.json`, `worklog.md`, or other standard-chain canonical artifacts.
- Do not run `delivery-owner` as a real delivery owner.
- Do not claim `product-director -> delivery-owner` full-chain readiness.
- Do not promote `product-director` to daily/default use, simple-request handling, or full standard-chain replacement.

## Staged Trial Model

### Stage 0: Route Precheck

Every candidate request is first checked against `contracts/standard-chain-invocation-policy.yaml`.

Eligible requests:

- New or materially changed complex demand.
- Root problem, success standard, scope, risk, or Phase baseline is unclear or changing.
- Director-level WHY and boundary judgment would materially affect downstream product work.

Ineligible requests:

- Simple factual question, path/status lookup, or explanation request.
- Direct implementation request with frozen scope and no Director-locked fact changes.
- Research, review, or evidence pilot that does not change canonical artifacts or readiness status.

Output: inline route rationale only. This precheck must not create persistent route state.

### Stage 1: One-transcript Smoke

Run `product-director` on exactly one real complex-demand transcript.

Purpose:

- Detect fatal adoption or behavior problems before spending time on a larger sample.
- Check whether the skill asks one decision-changing blocking fact per turn.
- Check whether the user experience is tolerable enough to continue.

Pass condition:

- No in-scope blocker across the 8 readiness dimensions from `team-pilot-readiness.json`.
- No premature final artifact write.
- No downstream handoff beyond `product-manager`.
- Reviewer can identify at least one concrete quality control the skill applied, or record that no incremental value was observed.

Failure action:

- Stop expansion to Stage 2.
- Record the failed dimension, transcript evidence, likely skill or routing cause, and recommended repair.

### Stage 2: Three-transcript Stability Sample

Run up to three real complex-demand transcripts after Stage 1 passes.

The sample should cover different demand shapes when available:

- Business growth, conversion, retention, or revenue demand.
- Stability, technical debt, operational efficiency, or quality demand.
- Workflow, compliance, support, or cross-team coordination demand.

Pass condition:

- All completed transcripts have no in-scope blocker.
- No repeated warning pattern appears across two or more transcripts.
- At least two transcripts show concrete value compared with baseline-risk review, such as preventing fake closure, narrowing an ambiguous success standard, or rerouting a simple/direct request out of Director flow.

Failure action:

- Stop before promotion gate.
- Classify whether the failure is skill design, route policy, user-input quality, missing evidence, or unsupported demand class.

### Stage 3: Five-transcript Promotion Gate

Promotion beyond team pilot requires 5 complete real complex-demand transcript reviews.

Promotion target is limited to `default_complex_demand_entry`.

Promotion is still not allowed for:

- Daily/default skill use.
- Simple request handling.
- Full standard-chain readiness.
- `delivery-owner` real delivery readiness.

Pass condition:

- 5 complete transcript reviews.
- Zero in-scope blocker across all 8 readiness dimensions.
- All route decisions are inline and non-persistent.
- Every transcript has source evidence strong enough for independent review after any required redaction.
- No unresolved privacy, authority, or user-confirmation issue remains.

## Review Dimensions

Each transcript must be reviewed against the existing `team-pilot-readiness.json` dimensions:

1. `no_interrogation`
2. `no_pretend_closure`
3. `no_stage_jump`
4. `success_standard_closure`
5. `director_why_only`
6. `explicit_confirmation_before_finalization`
7. `handoff_to_product_manager_only`
8. `simple_request_reroute`

Each dimension verdict must include:

- `verdict`: `PASS`, `FAIL`, `BLOCKED`, or `NOT_APPLICABLE`.
- `evidence_ref`: transcript line, redacted excerpt anchor, or reviewer note.
- `reason`: why the verdict follows from the evidence.
- `impact`: whether the finding blocks expansion or only becomes a monitored risk.

## Evidence Record Shape

The implementation plan should define a concrete record location. Recommended future shape:

`shared/skills/product-director/evals/dogfood/real-transcript-review-YYYY-MM-DD/`

The record set should contain:

- `plan.json`: stage, sample target, reviewer, allowed demand classes, and stop conditions.
- `transcripts/`: raw or redacted transcript references. Raw private data may stay outside the repository if a stable evidence digest and sufficient redacted excerpt are recorded.
- `reviews/PD-DOGFOOD-{N}.json`: one review per transcript.
- `summary.json`: aggregate verdict, promotion effect, unresolved blockers, and next action.

Minimum per-transcript fields:

- `review_id`
- `stage`
- `request_summary`
- `demand_class`
- `route_rationale`
- `transcript_ref`
- `transcript_redaction_status`
- `dimension_verdicts`
- `baseline_risk_review`
- `blocking_findings`
- `expansion_decision`
- `reviewer`
- `reviewed_at`

## Baseline-risk Review

The trial should not run a full no-skill baseline for every transcript by default. That would make the first evidence step too expensive.

Instead, every transcript gets a lightweight baseline-risk review:

- What likely failure would happen without `product-director` or without the route policy?
- Did the skill prevent that failure?
- Did the skill add process cost without visible quality gain?

For Stage 3 promotion, at least two transcripts should receive a stronger baseline comparison if the lightweight review does not clearly show incremental value.

## Stop Conditions

Stop the staged trial immediately when any of these occur:

- The skill writes or claims final artifacts before explicit `产品总监确认`.
- A transcript treats inferred facts as confirmed baseline.
- The skill jumps into PM detail, UX design, implementation HOW, UNIT, AC, or task planning before Director confirmation.
- The skill asks bundled survey-style questions instead of one decision-changing blocking fact.
- The skill routes a simple request or frozen direct implementation request into full Director process.
- Transcript evidence cannot be reviewed because required evidence is missing, over-redacted, or privacy-sensitive without a usable digest.
- The user rejects the interaction cost as unacceptable for complex-demand intake.

## Privacy And Evidence Handling

Real transcripts may contain business-sensitive information.

Allowed evidence forms:

- Full transcript in a protected non-repo location plus digest and redacted excerpts in the repository.
- Fully redacted repository transcript if it preserves the decision-relevant turns.
- Reviewer note only when the underlying transcript cannot be stored, provided the note records why stronger evidence is unavailable and what claim it can and cannot prove.

Disallowed evidence forms:

- Summary-only claims without turn-level support.
- Redaction that removes the decision point being evaluated.
- Raw secrets, credentials, private user data, or customer-identifying details in repository files.

## Decision States

Stage decisions:

- `EXPAND_TO_STAGE_2`
- `STOP_FOR_REPAIR`
- `COLLECT_MORE_STAGE_2_SAMPLE`
- `PROMOTION_ALLOWED_FOR_COMPLEX_DEMAND_ENTRY`
- `PROMOTION_BLOCKED`

Promotion must remain blocked if any in-scope blocker exists, any transcript is unverifiable, or the sample is not real complex-demand intake.

## Verification For This Design

This design is complete when:

- It separates smoke, stability sample, and promotion gate.
- It preserves the 5-transcript promotion requirement without making 5 transcripts a start-up prerequisite.
- It keeps routing non-persistent and does not introduce a second source of truth.
- It excludes `delivery-owner` real delivery and full-chain readiness.
- It defines review dimensions, evidence shape, stop conditions, and privacy handling.
- It cannot be misread as starting dogfood or authorizing promotion.

## Next Step After Approval

After this design is reviewed and accepted, write an implementation plan that creates the record templates and validation checks for the staged dogfood package.

Do not execute real transcript review until a real complex-demand candidate is selected and the evidence handling path is confirmed.

# Standard Skill Operating Quality Audit

## Problem Statement

The current lifecycle work added D9 existence review for the 12 standard-chain Skills. That solved one missing loop: every Skill now has an `eval-type`, eval metadata, and a lifecycle review record. Later empirical batches and the `developer` pilot also showed a gap in the first design: a portfolio decision such as `retain`, `optimize`, `merge candidate`, or `retire candidate` can collapse the discussion into "keep or remove this Skill" before the Skill's operating quality is understood.

That collapse is risky. A Skill can fail capability uplift while still preserving a valuable workflow preference. A Skill can also have strong D9 evidence while its text, role boundary, output contract, or runtime gate is noisy. The next review pass must separate these questions:

1. Is this Skill a healthy operating unit?
2. Does this Skill still deserve to exist as a standalone Skill?
3. Given both answers, what governance action follows?

## Goal

Design a full review framework for the 12 standard-chain Skills that combines operating quality, D1-D9 standards, and lifecycle disposition. The framework must let us evaluate each Skill one by one, then assess the entire portfolio with a consistent rubric.

## Non-Goals

- Do not optimize or retire any Skill in this design step.
- Do not rerun all empirical evals in this design step.
- Do not change lifecycle review JSON schema in this design step.
- Do not treat the portfolio matrix as a substitute for Skill content and operating quality review.
- Do not fold unrelated CI dependency cleanup into this work.

## Standard-Chain Scope

The audit covers these 12 standard-chain Skills:

| Group | Skills |
| --- | --- |
| Product and planning | `product-director`, `product-manager`, `design`, `test-design`, `tech-lead` |
| Delivery execution | `delivery-owner`, `developer`, `verify`, `review`, `qa`, `fix` |
| Cross-chain quality | `consistency-audit` |

## Core Design

The review has three layers.

### Layer 1: Skill Operating Quality Audit

This layer evaluates whether the Skill is a healthy workflow role and runtime unit. It is broader than prose quality and narrower than lifecycle disposition.

| Dimension | Review question | Evidence |
| --- | --- | --- |
| Role clarity | What does this Skill own, and what does it explicitly not own? | `SKILL.md` role section, upstream/downstream contracts, role catalog |
| LLM responsibility | Which tasks require LLM judgment, explanation, decomposition, or escalation? | workflow steps, HARD-GATE, exception handling |
| Engineering responsibility | Which checks belong to scripts, schemas, hooks, validators, or CI instead of LLM prose? | `scripts/`, `contracts/canonical`, completion gates, tests |
| Trigger and routing | Does the frontmatter route correct requests and avoid neighboring Skill conflicts? | description, eval prompts, adapter exposure |
| Inputs and preconditions | Are required files, user confirmations, state refs, and missing-input behavior explicit? | precondition sections, canonical artifact paths |
| Workflow clarity | Can a fresh model execute the steps without hidden session memory? | ordered process, branch conditions, stop states |
| Output contract | Are output paths, schemas, required fields, consumers, and derived views clear? | output section, templates, schemas |
| Evidence chain | Can every PASS, status, and decision trace to concrete evidence? | evidence refs, report anchors, proving commands |
| Runtime gate coverage | Are deterministic checks present for machine-verifiable claims? | completion scripts, tests, run-all wiring |
| Noise and duplication | Does the Skill duplicate templates, upstream duties, downstream duties, or eval-specific wording? | repeated sections, retired terms, stale docs |
| Context cost | Is `SKILL.md` lean, and are low-frequency details behind progressive disclosure? | line counts, reference contracts |
| Maintainability risk | Is there one fact source for schema, templates, gates, and role boundaries? | Sync contracts, changelog, tests |

Layer 1 output is a per-Skill operating audit record:

```text
Skill: <name>
Operating quality: PASS | PARTIAL | FAIL
Top issues:
- <issue with file/path evidence>
LLM-owned content:
- <judgment or workflow content>
Engineering-owned content:
- <script/schema/gate content>
Recommended operating action:
- keep as-is | edit Skill text | move to reference | move to script/schema | remove duplicate
```

### Layer 2: D1-D9 Evidence Review

This layer applies the existing `Skill质量标准.md`, `Skill能力有效性标准.md`, and `Skill生命周期管理.md`.

D1-D8 assess operating quality through the existing standard dimensions: routing, context budget, artifact contract, permission boundary, flow control, verification, compatibility, and human reuse.

D9 assesses existence rationale:

| Value type | Question | Evidence |
| --- | --- | --- |
| `capability_uplift` | Does the Skill improve outcomes versus no Skill? | with-skill / without-skill summaries, grader dimensions |
| `encoded_preference` | Does the Skill preserve the user's workflow preferences? | preference anchors, fidelity summaries, user-confirmed anchors |
| `mixed` | Do both capability and preference claims hold? | both evidence streams, interpreted separately |
| process preference | Does the Skill enforce a real workflow boundary even when uplift is low? | runtime gates, handoff evidence, role isolation evidence |

Layer 2 output is a D1-D9 evidence table per Skill. D9 cannot override hard D1-D8 failures. D1-D8 cannot decide standalone existence without D9 evidence.

### Layer 3: Portfolio Disposition Matrix

This layer combines Layer 1 and Layer 2 into a governance action.

| Disposition | Meaning | Required evidence |
| --- | --- | --- |
| `retain` | Standalone Skill remains justified. | Operating quality PASS or manageable PARTIAL, D9 value evidence strong, overlap low |
| `optimize` | Keep active, but fix quality, fidelity, noise, or evidence gaps. | Value signal exists, operating issues are concrete and fixable |
| `merge candidate` | Durable rules are valuable, but standalone Skill value is weak or duplicated. | Strong reusable contracts, high overlap with another Skill or shared standard |
| `retire candidate` | Standalone Skill has weak value and high cost or overlap. | D9 weak, operating quality weak or redundant, impact plan still required |

The matrix is a final summary, not the audit itself. Every disposition must link back to Layer 1 and Layer 2 evidence.

## Evaluation Flow

1. Freeze the review roster of 12 standard-chain Skills.
2. For each Skill, run Layer 1 operating audit.
3. For each Skill, run D1-D9 evidence review using existing lifecycle artifacts.
4. Classify the Skill into the portfolio matrix.
5. Review cross-Skill overlap and shared-rule extraction candidates.
6. Produce a portfolio-level governance report.
7. Only after the portfolio report, choose optimization, merge, or retirement tasks.

## Data Flow

```text
SKILL.md + references + scripts + schemas + tests
  -> Skill Operating Quality Audit

evals/evals.json + lifecycle-review.json + eval summaries
  -> D1-D9 Evidence Review

Operating Quality + D1-D9 Evidence + overlap analysis
  -> Portfolio Disposition Matrix

Portfolio Matrix
  -> prioritized follow-up tasks
```

## Error Handling and Decision Rules

- If a Skill lacks lifecycle review data, classify D9 as `evidence gap`; do not infer retain.
- If empirical eval has infrastructure failure, do not update lifecycle metrics from that run.
- If operating quality has a hard runtime gate failure, disposition cannot be `retain`.
- If a Skill is a process-preference role, do not use `uplift = 0.0` alone as a retirement decision.
- If two Skills duplicate rules, identify the single fact source before optimizing either text.
- If retirement is recommended, create an impact plan and request human confirmation before moving files or removing runtime entries.

## Testing and Verification Strategy

The implementation plan must add deterministic tests before full execution:

1. Audit rubric contract test: verifies all Layer 1 dimensions are present and named consistently.
2. Portfolio matrix contract test: verifies every disposition cites operating quality and D9 evidence.
3. Infra-failure guard test: verifies eval summaries with infrastructure failures cannot update lifecycle metrics.
4. Roster coverage test: verifies all 12 standard-chain Skills are included exactly once.
5. Report schema test: verifies per-Skill audit records have evidence refs and next actions.

Empirical eval runs remain evidence, not the only proof. Deterministic tests protect the review pipeline itself.

## Open Decisions for Implementation Planning

1. Whether Layer 1 records should be Markdown only or canonical JSON plus Markdown projection.
2. Whether process preference becomes a formal `eval-type` value or remains a D9 interpretation inside `encoded_preference` / `mixed`.
3. Whether the first full run covers all 12 Skills in one batch or three batches by workflow stage.
4. Whether portfolio recommendations are stored beside each Skill or in one portfolio report.

## Recommended First Implementation Slice

Start with a read-only audit framework:

- Add a design-backed rubric template for Layer 1.
- Generate one manual pilot record for `developer` and one for `product-manager`.
- Validate that the final portfolio decision cites both operating quality and D9 evidence.
- After the pilot format is stable, run the other 10 Skills.

This keeps the next execution step bounded and prevents another single-Skill rabbit hole.

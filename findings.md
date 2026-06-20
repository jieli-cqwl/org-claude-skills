# Findings & Decisions

## Requirements
- The user agrees with a double-layer best-practice review: flow-level review first, then skill-level review.
- The user wants multiple agents to review from different dimensions.
- The user wants separate agents to challenge the review conclusions and distrust weak evidence or unsupported opinions.
- The current request is to guardrail the overall concept for omissions and ambiguity.
- The revised goal must answer whether standard-chain and key skills are ready for controlled dogfood, not whether the team can broadly rely on them.
- Scope correction: before judging standard-chain or dogfood readiness, first research and define what makes an agent Skill best-practice, including format, content, workflow, behavior induction, validation, and runtime integration.
- User approved moving from the design document into an execution plan for the Skill best-practice research package.

## Research Findings
- Current proposed architecture: double-layer review, positive independent reviewers, red-team challengers, main adjudication.
- Current proposed evidence principle: separate facts, inferences, and unknowns; P0/P1 require current repository path:line evidence.
- Current risk: without explicit scope boundaries, agents may mix flow design assessment, skill content assessment, repair design, and actual execution.
- Gap: "best practice" must be operationalized. Without a reference model, agents may confuse external popularity, internal preference, and verified team-readiness criteria.
- Gap: flow-level review needs a declared "fitness-to-purpose" criterion before scoring. A flow can be valid for high-risk delivery while inefficient for light tasks; that should not automatically become a defect unless it violates the stated target scenario.
- Gap: skill-level review should reuse existing audit dimensions and evidence-level rules instead of inventing a parallel rubric.
- Gap: red-team agents need bounded attack surfaces. If they re-review everything, they will duplicate positive reviewers and create noise.
- Gap: conclusions need a resolution state such as `accepted`, `downgraded`, `rejected`, `blocked`, or `needs-user-decision`; otherwise the final report cannot show how challenges were handled.
- Gap: external references need an explicit source boundary. gstack and superpowers can supply mechanism patterns, but cannot prove this repo's process right or wrong.
- Gap: the design should define no-write boundaries for review agents. Otherwise the review may mutate the evidence under review.
- Gap: the previous goal was too process-shaped. A clearer goal must name the decision it enables: dogfood readiness, blockers, limits, and next action.
- First-principles finding: static review can inspect design, contracts, evidence surfaces, and known failure modes, but it cannot prove real agent behavior, execution cost, user adoption, or repeatability.
- First-principles finding: "team-ready" requires real-run evidence across multiple tasks/users or at least staged dogfood evidence; it cannot be granted by this review design alone.
- Dogfood readiness should answer whether one controlled real requirement can exercise the chain without predictable fake progress, stale evidence, artifact drift, or unbounded agent loops.
- Dogfood readiness is not release readiness, production readiness, or team rollout readiness.
- The prior agent dispatch direction was wrong because it investigated standard-chain dogfood readiness before defining Skill best-practice criteria.
- Correct research direction: build a source-backed Skill best-practice model, then later apply it to this repo's Skills and flow.
- Epistemic risk: defining "best Skill" dimensions before validating the dimensions can create circular evaluation. The rubric itself must be treated as a hypothesis and challenged before it is used.
- Corrected framing: first discover and validate what dimensions are legitimate, then evaluate Skills. Do not assume the initial dimensions are true.
- Stronger correction: do not predefine weakly understood dimensions at all. First collect authoritative and high-signal evidence, classify source authority, extract claims, compare sources, then derive candidate dimensions.
- Current execution plan should include local/runtime Skill-writing guidance because it exposes concrete structure, trigger, progressive-disclosure, validation, and evaluation expectations. These sources still remain evidence, not authority.
- Evidence collection result: official sources, public workflow sources, local/runtime guidance, and empirical failure evidence converge on several failure modes: bad trigger/discovery, context overload, vague actionability, missing validation evidence, stale/partial evidence, ambiguous handoff states, and authority bias.
- Description wording remains contested: some sources say description should include what the Skill does and when to use it, while local writing guidance warns workflow summaries can cause agents to skip the Skill body. This cannot become a scoring standard without target-runtime trigger eval evidence.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Keep gstack and superpowers as comparison mechanisms, not authorities | External popularity cannot prove this repository's process is correct or wrong. |
| Require challenger agents to attack evidence, assumptions, severity, and conclusion chain | Red-team value comes from falsification, not adding more opinions. |
| Main agent adjudicates instead of agent voting | Voting can preserve weak consensus; adjudication can enforce evidence rules. |
| Add a pre-review reference model phase | Prevents "best practice" from becoming a vague standard. |
| Add formal conclusion states | Makes red-team challenges auditable and prevents unresolved objections from disappearing. |
| Define review output as a dogfood-readiness decision | The useful result is whether the flow/skills deserve controlled real-task trial, what blocks that trial, and what evidence must be collected next. |
| Reserve `team-ready` for post-dogfood evidence | Prevents static review from overclaiming reliability, adoption, cost, or repeatability. |
| Define dogfood as a controlled evidence-gathering run | The review should grant permission to learn from a bounded real run, not permission to trust the process broadly. |
| Stop dogfood-readiness research and reset to Skill best-practice research | User explicitly corrected the scope before the research completed. |
| Treat best-practice dimensions as hypotheses | Prevents self-confirming evaluation where the rubric only proves our prior assumptions. |
| Use bottom-up evidence discovery before rubric design | Avoids pretending to know what best-practice Skill quality means before source-backed research. |
| Add an explicit execution plan before research | Keeps source collection, claim extraction, synthesis, counterexamples, and adversarial review in the approved order. |
| Include runtime Skill-writing guides in the source inventory | Avoids missing the current environment's concrete Skill-design constraints while preserving the no-authority-bias rule. |
| Treat the final model as provisional, not a local Skill verdict | The package defines later evaluation guidance; it does not judge any current repository Skill. |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Earlier conversation drifted toward lightweight-process redesign | Current scope explicitly reset to review design only. |
| Current draft lacks explicit no-write/evidence-freeze boundary for reviewers | Add as a must-have correction before executing any agent review. |

## Resources
- `README.md`: repo declares standard-chain as first-party local business flow and Superpowers as separate third-party mirror.
- `contracts/standard-chain.yaml`: standard-chain contract entry.
- `shared/skills/skill-quality-audit/references/audit-dimensions.md`: existing skill audit dimensions.
- `shared/skills/skill-quality-audit/SKILL.md`: existing formal skill quality audit mechanism.
- `docs/superpowers/specs/2026-06-18--skill-best-practice-research--design.md`: formal design doc for evidence-first Skill best-practice research.
- `docs/superpowers/plans/2026-06-19--skill-best-practice-research.md`: execution plan for the evidence-first Skill best-practice research package.

## Skill Best-practice Research Package
- Source inventory: `docs/reports/skill-best-practice-research-2026-06-19/source-inventory.md`
- Claim extraction: `docs/reports/skill-best-practice-research-2026-06-19/claim-extraction.md`
- Failure-mode map: `docs/reports/skill-best-practice-research-2026-06-19/failure-mode-map.md`
- Counterexamples: `docs/reports/skill-best-practice-research-2026-06-19/counterexamples.md`
- Adversarial review: `docs/reports/skill-best-practice-research-2026-06-19/adversarial-review.md`
- Provisional model: `docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md`

## Provisional Model Trial Application
- Trial review: `docs/reports/skill-best-practice-model-standard-chain-trial-review-2026-06-19.md`
- Decision: `product-director` is `CONDITIONAL` for controlled complex-demand dogfood; `delivery-owner` is `CONDITIONAL_EVIDENCE_PILOT_ONLY`, not normal delivery dogfood.
- Key finding: the provisional model is useful as an illustrative analysis scaffold, but this trial does not validate it as a scoring standard. It needs chain-composition, incremental-uplift, freshness-window, real-transcript, manual-routing, reference-loading, and operational-cost criteria before broad Skill audits.
- Key risk: `delivery-owner` has strong control design, but lifecycle state remains `optimize` and recent judgment eval evidence still contains QA/fixer and Task Packet visibility failures; full-flow closeout must not be trusted without closing or explicitly accepting those gaps.

## Standard-chain Invocation Policy
- Policy: `contracts/standard-chain-invocation-policy.yaml`
- Decision: `product-director` remains manual and scoped to complex-demand intake. The policy is a non-persistent route guardrail: route/bypass rationale can be stated inline in the current response or handoff, but it does not define a canonical route-decision artifact, runtime state, or required `worklog.md` entry.
- Route precedence: route wins over bypass when root problem, success standard, scope, risk, or Phase baseline is missing/changing, or when current work would create/modify standard-chain canonical artifacts or claim downstream standard-chain readiness.
- Blocking rule: only standard-chain canonical artifact creation/modification or downstream readiness claims are blocked when route conditions are present, route precedence is violated, or downstream would patch Director-locked facts. Simple factual work, frozen-scope direct implementation, research, review, or evidence pilots remain outside blocking scope when they do not write canonical artifacts or claim readiness.
- Known adjacent risk: README still references `worklog.md`, but current worktree has no `worklog.md` and `contracts/active-doc-scope.yaml` has no scope entries. This invocation policy explicitly does not repair or depend on that unrelated recovery-path drift.

## Product-director Controlled Dogfood Design
- Design: `docs/superpowers/specs/2026-06-20--product-director-controlled-dogfood--design.md`
- Planned implementation: `docs/superpowers/plans/2026-06-20--product-director-controlled-dogfood.md` defines templates, synthetic fixtures, a validator, and quick-gate wiring. It does not create live transcript evidence.
- Decision: run staged dogfood rather than a heavy upfront 5-transcript gate. Stage 1 uses one real complex-demand transcript as a smoke test, Stage 2 expands to a three-transcript stability sample, and Stage 3 keeps the existing five-transcript promotion gate.
- Boundary: the design does not start dogfood, does not create active scope, does not create standard-chain canonical artifacts, and does not authorize `delivery-owner` real delivery or full-chain readiness.
- Evidence model: each transcript is reviewed against the 8 existing `team-pilot-readiness.json` dimensions, with route rationale, transcript evidence, baseline-risk review, blocking findings, expansion decision, and privacy/redaction status.

## Visual/Browser Findings
- No visual/browser artifacts used in this guardrail pass.

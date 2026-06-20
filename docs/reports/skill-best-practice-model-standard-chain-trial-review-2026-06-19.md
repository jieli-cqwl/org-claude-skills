# Skill Best-practice Model Standard-chain Trial Review

## Scope

This is a trial application of the provisional Skill quality model to two high-risk standard-chain Skills:

- `shared/skills/product-director/SKILL.md` as the complex-demand intake entry.
- `shared/skills/delivery-owner/SKILL.md` as the delivery orchestration and closeout controller.

This review does not edit any Skill, does not assess the whole `product-director -> delivery-owner` chain, and does not claim team rollout readiness. It is an illustrative trial of whether the provisional model can structure a controlled evidence-collection decision.

## Decision

| Target | Decision | Meaning |
| --- | --- | --- |
| `product-director` | CONDITIONAL | Suitable for controlled team dogfood on complex-demand intake, not as a daily/default skill or full-chain readiness proof. |
| `delivery-owner` | CONDITIONAL_EVIDENCE_PILOT_ONLY | Only suitable for fixture-backed or human-shadowed evidence collection. It is not ready for unattended real delivery, full live subagent dispatch, or closeout trust. |
| Provisional model | ILLUSTRATIVE, NOT VALIDATED | It helped surface readiness limits, but this trial does not validate the model. It still needs scoring thresholds, current targeted validation, chain-composition, uplift, freshness, and real-transcript criteria before broad Skill audits. |

## Model Preconditions Applied

The model itself says it must not be used to score a repository Skill until the target job and downstream consumer are confirmed (`docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md:3-6`). For this trial:

- `product-director` job: co-create and freeze Director WHY/boundary baseline for complex demand; downstream consumer is `product-manager`.
- `delivery-owner` job: consume frozen tasks and evidence, dispatch role agents, control loops, assemble closeout, and hand off to `/commit`; downstream consumers include runtime artifacts, role agents, user decision, and `/commit`.

The model also warns that format/discoverability is not behavior proof (`docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md:11-20`, `docs/reports/skill-best-practice-research-2026-06-19/adversarial-review.md:11-20`) and that actionability must be paired with realistic behavior evidence (`docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md:15-16`, `docs/reports/skill-best-practice-research-2026-06-19/adversarial-review.md:13-16`).

## Product-director Trial Review

### Conclusion

`product-director` is **CONDITIONAL for controlled complex-demand dogfood**.

It has strong boundaries, handoff semantics, finalization gates, and regression evidence. It is not proven ready for default team use because its own dogfood artifact requires 5 real complex-demand transcript reviews before promotion, and historical evals cannot prove live adoption quality.

### Supporting Evidence

| Principle | Evidence | Judgment |
| --- | --- | --- |
| PR-001 discoverability / invocation | Frontmatter declares `user-invocable: true`, `disable-model-invocation: true`, argument hint, and allowed tools (`shared/skills/product-director/SKILL.md:1-9`). | Manual invocation is explicit. Automatic trigger risk is intentionally reduced, so trigger-description scoring is lower priority than slash-command usage evidence. |
| PR-003 actionability | The checklist forces ordered context exploration, stage closure, single blocking fact, recommendation, section approval, final artifacts only after explicit confirmation, gates, and handoff (`shared/skills/product-director/SKILL.md:21-36`). | Strong process actionability for complex demand intake. |
| PR-006 readiness evidence | Hard gate forbids freezing before explicit `产品总监确认` (`shared/skills/product-director/SKILL.md:13-16`); final artifact writing requires explicit confirmation and gate checks (`shared/skills/product-director/references/final-artifacts.md:3-11`, `shared/skills/product-director/references/final-artifacts.md:22-35`). | Good protection against fake baseline closure. |
| PR-007 terminal state semantics | Handoff is only to product-manager after final gates (`shared/skills/product-director/SKILL.md:35-36`); standard-chain contract says product-director outputs `brief.json` and `phase-{N}/phase-prd.json` to product-manager (`contracts/standard-chain.yaml:4-16`). | Strong owner boundary. |
| PR-004 scripts / gates | Script manifest defines completion and projection render scripts with denied shell/network args and verification commands (`shared/skills/product-director/scripts/manifest.json:1-50`). | Deterministic gates exist for high-risk finalization. |
| PR-005 behavior evidence | With-skill full rerun passed 24/24 expectations (`tools/eval/results/product-director-eval-20260509/with-skill-full-rerun/summary.json:94-99`); systemic hardening rerun passed 27/27 (`tools/eval/results/standard-chain-systemic-baseline-2026-06-11/pd-hardening-6-cases-closed-facts-direct-recommendation-low-reasoning/summary.json:112-117`). | Supports controlled dogfood, not broad readiness. |

### Main Gaps

| Gap | Evidence | Failure Mode |
| --- | --- | --- |
| Real team adoption is unproven. | Dogfood readiness artifact says next action is to review 5 real complex-demand transcripts before promotion (`shared/skills/product-director/evals/dogfood/team-pilot-readiness.json:10-23`) and lists residual risk that evals do not prove live team adoption quality (`shared/skills/product-director/evals/dogfood/team-pilot-readiness.json:90-99`). | Polished eval behavior may not survive real dialogue, unclear business context, or team variance. |
| Skill uplift is not uniformly strong. | Without-skill product-director eval still passed 22/24 expectations, 91.67% (`tools/eval/results/product-director-eval-20260509/without-skill/summary.json:97-102`). | A "good Skill" claim can overstate value if baseline already handles many scripted cases. The value may be concentrated in specific failure modes, not all intake work. |
| Scope must stay narrow. | The dogfood artifact explicitly excludes daily/default use, simple requests, direct implementation requests, and full standard-chain readiness (`shared/skills/product-director/evals/dogfood/team-pilot-readiness.json:5-23`, `shared/skills/product-director/evals/dogfood/team-pilot-readiness.json:74-80`). | Over-triggering the Director flow could slow simple work and erode team trust. |
| Manual routing is an operational dependency. | `product-director` disables model invocation (`shared/skills/product-director/SKILL.md:1-9`), and lifecycle review says team pilot is allowed only for complex standard-chain intake while promotion requires 5 transcript reviews (`shared/skills/product-director/evals/lifecycle-review.json:56-63`). | If teams do not know when to invoke it, complex requests may bypass the entry baseline or simple requests may be over-processed. |
| Final JSON gates do not fully prove co-creation quality. | The dogfood dimensions require transcript evidence for one blocking fact, no pretend closure, no stage jump, success-standard closure, Director WHY only, and explicit confirmation (`shared/skills/product-director/evals/dogfood/team-pilot-readiness.json:24-72`). | A final artifact can pass gates after correction while the real conversation still burdens the user or freezes weak assumptions. |

### Product-director Trial Decision

Use it only for **complex demand intake where Director WHY/boundary alignment is actually the bottleneck**. Do not use it as the default entry for simple edits, direct implementation, or already-scoped tasks.

## Delivery-owner Trial Review

### Conclusion

`delivery-owner` is **CONDITIONAL_EVIDENCE_PILOT_ONLY**.

It has the strongest structure of the two Skills: hard gates, preflight, baseline consistency-audit, task packets, loop bounds, stale-evidence rules, state artifacts, signoff package, user decision, and `/commit` handoff. But its own lifecycle decision remains `optimize`, live role-agent dispatch and larger comparative samples are not proven, and recent judgment evals still show failures in QA/fixer loop and packet visibility. That blocks even a normal controlled real-delivery dogfood claim; the next safe use is evidence collection with human override.

### Supporting Evidence

| Principle | Evidence | Judgment |
| --- | --- | --- |
| PR-001 discoverability / invocation | Frontmatter declares `user-invocable: true`, `disable-model-invocation: true`, argument hint, and allowed tools including `Agent` (`shared/skills/delivery-owner/SKILL.md:1-9`). | Manual invocation and tool surface are explicit. |
| PR-003 actionability | Hard gates require frozen tasks, baseline audit, qualified Task Packet, bounded loops, and user-decision pause (`shared/skills/delivery-owner/SKILL.md:13-31`). | Strong precondition and stop-boundary control. |
| PR-003 / PR-007 workflow semantics | Flow defines DO-S1 through DO-S8d and explicit pause paths (`shared/skills/delivery-owner/SKILL.md:37-59`). Outputs require status card, Task Packet, user decision package, `delivery-state.json`, registry updates, signoff package, and `/commit` handoff (`shared/skills/delivery-owner/SKILL.md:183-195`). | Strong owner/action/artifact semantics. |
| PR-004 scripts / validation | Preflight, task-packet, completion, and behavior-replay scripts are declared with denied shell/network args, timeouts, output/input roots, failure states, and verification commands (`shared/skills/delivery-owner/scripts/manifest.json:1-207`). | Good low-freedom support for fragile operations. |
| PR-006 evidence freshness | QA/fix path requires affected verifier, fresh code-reviewer, and affected QA rerun after fixer changes (`shared/skills/delivery-owner/SKILL.md:113-123`); final closeout consumes current evidence matrix (`shared/skills/delivery-owner/SKILL.md:125-130`). | Directly targets stale-evidence and fake-completion failures. |
| PR-007 terminal states | `READY_FOR_COMMIT` is not `DELIVERED`; `DELIVERED` requires `/commit` result (`shared/skills/delivery-owner/SKILL.md:146-150`). `/commit` handoff fields and forbidden actions are explicit (`shared/skills/delivery-owner/SKILL.md:153-180`). | Strong terminal-state protection. |
| PR-003 downstream contract | Standard-chain contract defines delivery-owner stage inputs and outputs including `delivery-state.json`, `artifact-registry.json`, `signoff-package.json`, `user-decision.json`, and `target-change.json` (`contracts/standard-chain.yaml:128-177`). | Contract alignment is explicit. |
| PR-005 behavior evidence | Low-context with-skill rerun passed 32/32 (`tools/eval/results/delivery-owner-behavior-20260430-low-context-blind-with-skill-final/summary.json:58-63`), while low-context without-skill rerun passed only 8/32, 25% (`tools/eval/results/delivery-owner-behavior-20260430-low-context-blind-without-skill-rerun1/summary.json:94-99`). | Strong targeted uplift evidence for a limited low-context sample, but weaker than the newer judgment-eval failures and lifecycle boundary for real-pilot readiness. |

### Main Gaps

| Gap | Evidence | Failure Mode |
| --- | --- | --- |
| Recent judgment eval is not fully green. | `delivery-owner-judgment-guide-20260508-with-skill-rerun1` has 7 failed expectations out of 100 (`tools/eval/results/delivery-owner-judgment-guide-20260508-with-skill-rerun1/summary.json:235-246`). | Cannot claim complete full-flow behavior reliability. |
| QA/fixer loop still has high-risk failures. | `qa-fixer-fail-loop-reruns` failed 5/15 expectations, including fixer dispatch, fixer packet, root-cause/minimal-fix evidence, and fresh PASS before `/commit` (`tools/eval/results/delivery-owner-judgment-guide-20260508-with-skill-rerun1/summary.json:82-105`). | This is exactly the path that protects against stale evidence and premature closeout. |
| Packet visibility failed in at least one run. | `role-agent-available-delegation` failed "输出 bounded task packet"; finding says packet was only a file link and not visible in response (`tools/eval/results/delivery-owner-judgment-guide-20260508-with-skill-rerun1/summary.json:21-44`). | A downstream executor may not receive enough actionable context, causing handoff failure. |
| Lifecycle boundary is still `optimize`, not retain. | Lifecycle review decision is `optimize` (`shared/skills/delivery-owner/evals/lifecycle-review.json:1-6`); it says full live subagent dispatch and larger-scale behavior evals are not yet proven (`shared/skills/delivery-owner/evals/lifecycle-review.json:75-78`) and formal decision remains optimize (`shared/skills/delivery-owner/evals/lifecycle-review.json:153-154`). | The strongest local decision artifact blocks stronger readiness wording. |
| Control surface is heavy. | The Skill requires multiple stage artifacts, registry state, signoff package, user decision, target-change routing, and commit handoff (`shared/skills/delivery-owner/SKILL.md:183-227`). | Good for high-risk delivery; too expensive for lightweight work. Misuse could create process drag. |

### Delivery-owner Trial Decision

Use it only in a **controlled evidence pilot** where:

- A human delivery owner shadows every pause, user decision, and `/commit` boundary.
- QA/fixer and closeout paths are treated as high-risk observation points.
- No real end-to-end delivery pilot, unattended `/commit`, live role-agent dispatch claim, or `DELIVERED` claim is allowed until the known judgment-eval failures are closed or explicitly isolated as the observation target in a fixture-backed pilot.

## What The Trial Suggests About The Provisional Model

### The model was useful, not validated

It forced the review to distinguish:

- Manual discoverability from actual trigger behavior.
- Polished instructions from realistic behavior evidence.
- Script/schema existence from complete runtime readiness.
- Controlled dogfood from broad team rollout.
- Local workflow assumptions from universal best practice.

Without PR-005 and PR-006, both Skills would look more ready from documentation alone. The eval, lifecycle, and dogfood evidence changed the decision strength. This is evidence that the model is useful as an analysis scaffold; it is not proof that the model is validated as a scoring standard. The model's own later-use guidance still requires target-specific evidence collection, adversarial review, and bounded readiness claims before scoring (`docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md:62-64`).

### The model is incomplete

| Missing Or Weak Area | Evidence From Trial | Needed Hardening |
| --- | --- | --- |
| Uplift over baseline | Product-director without-skill already passed 91.67% on one summary (`tools/eval/results/product-director-eval-20260509/without-skill/summary.json:97-102`). | Add an "incremental value / prevented critical failure" criterion. Passing with-skill is weaker when baseline also passes. |
| Chain-composition readiness | Product-director and delivery-owner can each be conditional, but full-chain risk compounds at handoffs and stale evidence boundaries. | Add a chain-level criterion: handoff artifacts, freshness, and authority must be proven across adjacent Skills, not only inside one Skill. |
| Evidence freshness window | Some evidence is historical; current files may have changed. PR-006 requires current scope-matching evidence but does not define how fresh is fresh enough. | Require current targeted validation or a dated evidence freshness rule before readiness claims. |
| Real transcript standard | Product-director already requires 5 real transcript reviews before promotion (`shared/skills/product-director/evals/dogfood/team-pilot-readiness.json:10-23`). | Make real-run transcript review a standard for high-judgment co-creation Skills. |
| Manual-routing reliability | `product-director` is intentionally manual/user-invocable, so normal trigger-description criteria do not prove it will be used at the right time. | Add an invocation-policy criterion for Skills that disable automatic model invocation. |
| Reference-loading correctness | `product-director` relies on stage-specific references; progressive disclosure alone does not prove the agent loads the right reference at the right stage. | Add a stage/reference-selection criterion for multi-stage workflow Skills. |
| Operational cost / fitness | Delivery-owner is intentionally heavy. The model's progressive-disclosure principle does not fully capture team process cost. | Add a fitness-to-purpose check: high-control Skills are valid only for high-risk scenarios where the control cost is justified. |

## Recommended Next Actions

1. Run `product-director` on 5 real complex-demand transcripts before promotion, using the existing dogfood dimensions in `shared/skills/product-director/evals/dogfood/team-pilot-readiness.json`; require zero in-scope blockers and explicitly record which critical failures the Skill prevented compared with a no-Skill baseline review.
2. Add a standard-chain invocation policy that states when teams must manually call `product-director`, when to bypass it, and who owns the routing decision; fail the policy if a complex demand can enter PM/tech-lead without an explicit Director-baseline decision.
3. Close the known `delivery-owner` judgment failures first, or run only a fixture-backed evidence pilot whose explicit purpose is to observe those failures under human override. A real delivery pilot requires QA/fixer loop and packet visibility evidence to be green or manually accepted as residual risk by the user.
4. Create a second-stage "chain composition" review after those pilots: `product-director -> product-manager -> design/test-design -> tech-lead -> delivery-owner`, focused only on artifact freshness, authority, and handoff breakpoints.

## Bottom Line

The direction is reasonable, but the decision should be scoped tightly:

- Do not start by rewriting Skills.
- Do not declare the full flow ready.
- Do use the provisional model to gate controlled real trials.
- Treat the next evidence target as real usage behavior, not more static confidence.

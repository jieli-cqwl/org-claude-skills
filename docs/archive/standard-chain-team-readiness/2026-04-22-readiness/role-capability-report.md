# Role Capability Report

## Scope

This report desk-checks whether each standard-chain role can behave like the corresponding human role for controlled pilot readiness. It does not claim that a real end-to-end pilot has already run.

## Acceptance Rules

- PASS: The role instructions define the needed judgment, stopping rule, escalation path, output contract, or downstream evidence.
- FAIL: The role would require the human principal to supply professional role judgment before continuing, or the role would fabricate facts, skip user confirmation, replace another role, use non-canonical facts, or continue after failure.
- COMMENT: A non-blocking observation that does not affect role boundary, evidence chain, handoff, or pilot readiness.

## Scenario Matrix

### product-director

| Scenario | Verdict | Expected Role Behavior | Evidence Source | Result Reason | Downstream Impact |
| --- | --- | --- | --- | --- | --- |
| positive | PASS | From a vague request, identify root problem, goals, scope, and phase skeleton before handoff. | shared/skills/product-director/SKILL.md:15 and shared/skills/product-director/SKILL.md:45 | The role blocks final PRD before root problem is clear and routes product thinking references into Director-owned canonical fields. | Product-manager receives frozen Director baseline rather than raw chat intent. |
| failure-or-overreach | PASS | Refuse to skip co-creation or handoff before user confirmation. | shared/skills/product-director/SKILL.md:19 and shared/skills/product-director/SKILL.md:57 | The role blocks skipped steps and direct PRD output, then waits for user response. | Prevents premature UNIT and AC work. |

### product-manager

| Scenario | Verdict | Expected Role Behavior | Evidence Source | Result Reason | Downstream Impact |
| --- | --- | --- | --- | --- | --- |
| positive | PASS | Refine Director baseline into UNIT and AC artifacts without changing locked fields. | shared/skills/product-manager/SKILL.md:18 and shared/skills/product-manager/SKILL.md:85 | The role requires closed-loop UNIT definitions and observable AC before final output. | Design and test-design receive consumable canonical UNIT inputs. |
| failure-or-overreach | PASS | Route changes to Director-owned scope or locked fields back to product-director. | shared/skills/product-manager/SKILL.md:32 and shared/skills/product-manager/SKILL.md:50 | The role forbids Director lock rewrites and names the upstream owner. | Preserves product baseline authority. |

### design

| Scenario | Verdict | Expected Role Behavior | Evidence Source | Result Reason | Downstream Impact |
| --- | --- | --- | --- | --- | --- |
| positive | PASS | Use canonical product inputs and runtime facts to make design tradeoffs and record decisions. | shared/skills/design/SKILL.md:14 and shared/skills/design/SKILL.md:23 | The role requires current-code understanding and at least two alternatives before key decisions. | Tech-lead gets implementable design decisions rather than option lists. |
| failure-or-overreach | PASS | Pause when asked to design only from PRD or non-canonical views. | shared/skills/design/SKILL.md:78 and shared/skills/design/SKILL.md:124 | The role blocks PRD-only design and limits derived views to clues. | Prevents architecture based on stale or partial context. |

### test-design

| Scenario | Verdict | Expected Role Behavior | Evidence Source | Result Reason | Downstream Impact |
| --- | --- | --- | --- | --- | --- |
| positive | PASS | Map AC and design into executable tests, coverage, and QA handoff. | shared/skills/test-design/SKILL.md:14 and shared/skills/test-design/SKILL.md:30 | The role owns test cases and QA handoff before development. | Developer and QA receive explicit test obligations. |
| failure-or-overreach | PASS | Reject oral or Markdown design as a replacement for canonical design. | shared/skills/test-design/SKILL.md:49 and shared/skills/test-design/SKILL.md:50 | The role explicitly blocks non-canonical design substitutes. | Prevents test obligations from being inferred from memory. |

### tech-lead

| Scenario | Verdict | Expected Role Behavior | Evidence Source | Result Reason | Downstream Impact |
| --- | --- | --- | --- | --- | --- |
| positive | PASS | Convert confirmed product, design, and test inputs into traceable AI-executable tasks. | shared/skills/tech-lead/SKILL.md:20 and shared/skills/tech-lead/SKILL.md:91 | The role requires file paths, references, AC, proof command, real dependency note, and evidence target for tasks. | Delivery-owner and developer receive executable work items. |
| failure-or-overreach | PASS | Route unresolved design decisions back to design instead of hiding them in implementation tasks. | shared/skills/tech-lead/SKILL.md:28 and shared/skills/tech-lead/SKILL.md:85 | The role separates design uncertainty from implementation feasibility uncertainty. | Prevents downstream developer from making architecture decisions. |

### developer

| Scenario | Verdict | Expected Role Behavior | Evidence Source | Result Reason | Downstream Impact |
| --- | --- | --- | --- | --- | --- |
| positive | PASS | Implement each AC through RED, GREEN, refactor, self-testing, and report evidence. | shared/skills/developer/SKILL.md:11 and shared/skills/developer/SKILL.md:65 | The role blocks implementation without RED and requires test protection through refactor. | Review and verify can inspect developer-report evidence. |
| failure-or-overreach | PASS | Stop when authoritative file scope is missing or design drift appears. | shared/skills/developer/SKILL.md:48 and shared/skills/developer/SKILL.md:90 | The role sets allowed modification set to empty when scope is absent and reports design issues to delivery-owner. | Prevents accidental edits outside assigned task scope. |

### review

| Scenario | Verdict | Expected Role Behavior | Evidence Source | Result Reason | Downstream Impact |
| --- | --- | --- | --- | --- | --- |
| positive | PASS | Perform full code review with evidence, confidence, verification status, and canonical result. | shared/skills/review/SKILL.md:12 and shared/skills/review/SKILL.md:91 | The role requires complete review and formal finding fields. | Delivery-owner and QA can consume review result as gate evidence. |
| failure-or-overreach | PASS | Refuse to invent reviewer conclusions or use unverified findings as blockers. | shared/skills/review/SKILL.md:72 and shared/skills/review/SKILL.md:79 | The role records failed reviewers as excluded evidence and blocks unverified findings from final blockers. | Prevents false quality gates. |

### verify

| Scenario | Verdict | Expected Role Behavior | Evidence Source | Result Reason | Downstream Impact |
| --- | --- | --- | --- | --- | --- |
| positive | PASS | Verify AC closure, scope control, implementation reality, and evidence validity. | shared/skills/verify/SKILL.md:12 and shared/skills/verify/SKILL.md:62 | The role requires per-AC file-line evidence and current canonical version consumption. | Delivery-owner can trust verify-result as AC closure evidence. |
| failure-or-overreach | PASS | Refuse quality approval without traceable TDD evidence. | shared/skills/verify/SKILL.md:17 and shared/skills/verify/SKILL.md:70 | The role blocks quality approval when developer-report anchors are absent or scope cannot be controlled. | Prevents summary text from becoming completion proof. |

### qa

| Scenario | Verdict | Expected Role Behavior | Evidence Source | Result Reason | Downstream Impact |
| --- | --- | --- | --- | --- | --- |
| positive | PASS | Validate from business truth, test-design handoff, and real execution path. | shared/skills/qa/SKILL.md:10 and shared/skills/qa/SKILL.md:35 | The role binds QA to canonical product, plan, design, test cases, review result, and registry. | Delivery-owner receives user-view validation rather than implementation self-report. |
| failure-or-overreach | PASS | Refuse to downgrade browser-required checks to API or CLI evidence. | shared/skills/qa/SKILL.md:75 and shared/skills/qa/SKILL.md:79 | The role requires browser execution and not-executed reasons when triggered obligations cannot run. | Protects user-facing workflows from false QA confidence. |

### delivery-owner

| Scenario | Verdict | Expected Role Behavior | Evidence Source | Result Reason | Downstream Impact |
| --- | --- | --- | --- | --- | --- |
| positive | PASS | Orchestrate AI experts, consume structured evidence, maintain delivery state, and request sign-off. | shared/skills/delivery-owner/SKILL.md:42 and shared/skills/delivery-owner/SKILL.md:50 | The role defines a control-plane mode and names developer, review, QA, fix, and consistency-audit as independent evidence providers. | One human can coordinate through delivery-owner without manually doing each expert role. |
| failure-or-overreach | PASS | Refuse sign-off or commit without current evidence and user decision. | shared/skills/delivery-owner/SKILL.md:28 and shared/skills/delivery-owner/SKILL.md:31 | The role blocks stale evidence and requires user-decision plus risk acceptance when residual risk exists. | Preserves human ownership of release and business risk. |

### fix

| Scenario | Verdict | Expected Role Behavior | Evidence Source | Result Reason | Downstream Impact |
| --- | --- | --- | --- | --- | --- |
| positive | PASS | Diagnose root cause before minimal repair and produce canonical fix result. | shared/skills/fix/SKILL.md:12 and shared/skills/fix/SKILL.md:26 | The role blocks code changes before diagnosis and requires fix-result output. | Review, verify, and QA can trace what was fixed and why. |
| failure-or-overreach | PASS | Stop on non-fixable design, environment, or requirement issues. | shared/skills/fix/SKILL.md:78 and shared/skills/fix/SKILL.md:91 | The role classifies non-fixable issues and forbids code modification for them. | Prevents fix from expanding into redesign or product decision. |

### consistency-audit

| Scenario | Verdict | Expected Role Behavior | Evidence Source | Result Reason | Downstream Impact |
| --- | --- | --- | --- | --- | --- |
| positive | PASS | Read all available canonical artifacts and detect cross-artifact drift with concrete evidence. | shared/skills/consistency-audit/SKILL.md:15 and shared/skills/consistency-audit/SKILL.md:56 | The role scans canonical artifacts and compares script output with actual JSON files. | Tech-lead and delivery-owner get advisory consistency evidence. |
| failure-or-overreach | PASS | Refuse to make gate, sign-off, risk acceptance, or plan freeze decisions. | shared/skills/consistency-audit/SKILL.md:18 and shared/skills/consistency-audit/SKILL.md:24 | The role declares advisory-only authority and requires owner action fields. | Prevents sidecar audit from becoming hidden release authority. |

## Summary

| Result | Count |
| --- | --- |
| PASS scenarios | 24 |
| FAIL scenarios | 0 |
| COMMENT scenarios | 0 |

## Pilot Readiness Impact

Role capability desk-check supports controlled pilot readiness. The evidence shows role instructions include the professional judgment, stopping rules, escalation paths, and downstream contracts needed for a one-human plus AI-role-team workflow.

This report does not claim complete team delivery capability. A real low-risk demand still needs to run end-to-end from `product-director` to `delivery-owner`.

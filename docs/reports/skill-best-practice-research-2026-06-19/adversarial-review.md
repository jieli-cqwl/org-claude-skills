# Skill Best-practice Adversarial Review

## Purpose

Attack the candidate model before it can be used as a scoring standard.

## Challenges

| Challenge ID | Attack Role | Target Principle ID | Challenge | Evidence Or Reasoning | Resolution | Model Update |
| --- | --- | --- | --- | --- | --- | --- |
| ADV-001 | Authority-bias attacker | PR-001 | Official docs define metadata and descriptions, but that does not prove a Skill will trigger correctly in a real repo. | CLM-002, CLM-009, CLM-013, and CLM-038 all point to trigger behavior, but CLM-013 and CLM-038 require evaluation. | closed | PR-001 kept but requires target-runtime trigger evidence when risk matters. |
| ADV-002 | Generalization attacker | PR-002 | Progressive disclosure could be misused to hide essential instructions in unread references. | CLM-010 and CLM-012 say supporting files must be referenced and loaded as needed; CE-004 shows prose/actionability can fail independently. | accepted-risk | PR-002 limited to lean activation plus discoverable supporting resources. |
| ADV-003 | Predictive-validity attacker | PR-003 | Actionable instructions may improve document quality but still fail to predict agent behavior. | CLM-018 supports executor-facing plan actionability; CLM-005 and CLM-036 support planning/intent capture; CLM-005 does not prove behavior by itself. | accepted-risk | PR-003 is necessary but not sufficient; PR-005 supplies usage evidence requirement. |
| ADV-004 | Generalization attacker | PR-004 | Requiring scripts may over-engineer simple judgment Skills. | CLM-033 ties low freedom to fragile tasks, while CLM-001 and CLM-010 make scripts optional. | closed | PR-004 marked scenario-specific, not universal. |
| ADV-005 | Verification attacker | PR-005 | Baseline or with-skill comparisons can be expensive and may not fit subjective Skills. | CLM-013 and CLM-037 support evaluation; CLM-039 is local discipline. None proves a universal eval strength. | accepted-risk | PR-005 says stronger claims need stronger evidence; qualitative review is allowed for subjective tasks. |
| ADV-006 | Circularity attacker | PR-006 | This principle may simply restate this repository's previous failures rather than general Skill quality. | CLM-007, CLM-026, CLM-027, and empirical CLM-030/031 independently support scope-matching evidence. | closed | PR-006 remains empirically supported and most relevant to readiness/review/QA Skills. |
| ADV-007 | Predictive-validity attacker | PR-007 | Structured owner actions might make docs heavier without improving outcomes. | Empirical CLM-032 shows ambiguous strong verbs caused handoff/closeout risk; CLM-041 supports loophole closure for discipline Skills. | accepted-risk | PR-007 limited to multi-step behavior-control Skills. |
| ADV-008 | Authority-bias attacker | PR-008 | The model itself uses official docs and popular workflow repos; it may still privilege them implicitly. | Source inventory separates class and limits; CLM-017, CLM-021, CLM-027, CLM-028 are explicitly mechanism/local-assumption evidence only. | closed | PR-008 kept as a guardrail for later application. |
| ADV-009 | Verification attacker | PR-009 | Security review requirement is too broad unless bundled capabilities are present. | CLM-016 directly frames Skills as installable software; CLM-010 and CLM-012 mention scripts/tools. | closed | PR-009 scoped to scripts, broad tool access, network calls, or file access. |
| ADV-010 | Circularity attacker | PR-010 | The model tries to resolve description style but sources conflict. | CLM-009 and CLM-036 support descriptive triggers; CLM-040 warns process summaries can shortcut body loading. | accepted-risk | PR-010 remains contested and non-scoring without trigger eval. |

## Resolution Summary

| Resolution | Count | Meaning |
| --- | ---: | --- |
| closed | 6 | Model updated or evidence supplied. |
| accepted-risk | 4 | Limitation remains but is bounded in scope. |
| blocked | 0 | No candidate principle is blocked from provisional use after scope limits. |
| rejected | 0 | No challenge was refuted by hand-waving; each changed or bounded the model. |

## Attack-role Coverage Matrix

| Principle ID | Authority-bias | Circularity | Predictive-validity | Generalization | Verification |
| --- | --- | --- | --- | --- | --- |
| PR-001 | ADV-001 challenged official-source overreach. | Not primary: derived from runtime metadata claims, not a local assumed rubric. | Covered through trigger-eval requirement in ADV-001. | Bounded to target runtime in model. | Covered through trigger evidence requirement in ADV-001. |
| PR-002 | Source-scoped by source inventory. | Not primary: repeated across official/runtime sources. | CE-004 shows it does not prove actionability. | ADV-002 challenged overgeneralization. | Bounded to discoverable supporting resources in ADV-002. |
| PR-003 | Source-scoped by source inventory. | Not primary: derived from official planning guidance, workflow plan templates, and empirical handoff failures. | ADV-003 challenged document quality vs behavior. | Bounded to workflow/audit/planning/handoff Skills. | Paired with PR-005 because actionability alone is insufficient. |
| PR-004 | Source-scoped by source inventory. | Not primary: scripts are optional in source claims. | CE-005 checks deterministic prose failure. | ADV-004 challenged overgeneralization. | Requires task-specific evidence before requiring scripts. |
| PR-005 | Source-scoped by source inventory. | Not primary: it is an evidence requirement, not a content dimension. | ADV-005 challenged eval cost and subjectivity. | Bounded by risk and objective verifiability. | ADV-005 keeps qualitative review acceptable for subjective tasks. |
| PR-006 | Source-scoped by source inventory. | ADV-006 challenged whether this only restates local failures. | Empirical CLM-030/031 support stale/partial evidence risk. | Bounded to readiness/review/QA/high-risk workflow Skills. | Requires scope-matching current evidence. |
| PR-007 | Source-scoped by source inventory. | Not primary: based on empirical ambiguous-state failures. | ADV-007 challenged whether structure improves outcomes. | Bounded to multi-step behavior-control Skills. | Requires concrete owner actions/artifacts/outcomes when terminal states matter. |
| PR-008 | ADV-008 directly attacks authority bias. | Helps prevent circular source use. | Not primary: evidence-use rule, not behavior predictor. | Bounded as a research/evaluation guardrail. | Requires later target-specific evidence before scoring. |
| PR-009 | Source-scoped by source inventory. | Not primary: based on security/trust source claims. | Not a behavior predictor; a risk-control requirement. | ADV-009 challenged broadness and bounded it. | Applies only when scripts/tools/network/file access are present. |
| PR-010 | Source conflict makes authority bias explicit. | ADV-010 challenges circular wording preference. | Trigger behavior must be validated. | Bounded to trigger-sensitive Skills. | Non-scoring until target-runtime trigger eval exists. |

## Model Hardening Changes

- Avoided treating format compliance as behavior proof.
- Marked scripts/security and owner-action requirements as scenario-specific.
- Kept trigger-description style contested unless tested on the target runtime.
- Preserved source-class boundaries so external workflow mechanisms cannot become local standards without later evidence.

# Provisional Skill Quality Model

## Status

This model is provisional. It is derived from the claim extraction, failure-mode map, counterexamples, and adversarial review in this package. It must not be used to score a repository Skill until the target Skill's intended job and downstream consumer are confirmed.

## Candidate Principle Register

| Principle ID | Candidate Principle | Derived From Claim IDs | Failure Mode Rationale | Status | Scope | Limits | Counterexample Status | Red-team Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PR-001 | A Skill must be discoverable on its target runtime: required metadata is valid, trigger text matches real task language, and manual/automatic invocation is explicit. | CLM-001, CLM-002, CLM-003, CLM-008, CLM-009, CLM-013, CLM-034, CLM-038, CLM-040 | Reduces FM-001 and FM-002. | cross-source-supported | All Skills with runtime discovery. | Trigger wording differs by runtime; description-only evidence is insufficient. | passes-counterexample | closed |
| PR-002 | A Skill should keep activation context lean and use progressive disclosure for heavy references, examples, assets, or scripts. | CLM-002, CLM-010, CLM-011, CLM-015, CLM-034, CLM-037 | Reduces FM-003. | cross-source-supported | Skills with nontrivial references or resources. | No universal line/token threshold was proven. | passes-counterexample | accepted-risk |
| PR-003 | A Skill's instructions must be directly actionable for its intended job: inputs, outputs, boundaries, gates, and handoff artifacts are explicit enough for downstream use. | CLM-004, CLM-005, CLM-018, CLM-026, CLM-029, CLM-032, CLM-036 | Reduces FM-004, FM-005, FM-011, and FM-012. | cross-source-supported | Workflow, audit, planning, and handoff Skills. | Lightweight helper Skills may need less structure; actionability alone does not prove runtime behavior. | passes-counterexample | accepted-risk |
| PR-004 | Fragile, repetitive, deterministic, or high-risk operations should be bounded by scripts, schemas, validators, or explicit low-freedom procedures instead of broad prose alone. | CLM-001, CLM-010, CLM-012, CLM-033, CLM-041 | Reduces FM-006 and FM-014. | scenario-specific | Deterministic transforms, validation, fragile setup, safety-sensitive operations. | Not every Skill needs code; scripts introduce maintenance and security obligations. | passes-counterexample | closed |
| PR-005 | A Skill is not proven effective until tested on realistic tasks against the failure it is meant to prevent; stronger claims need baseline, with-skill comparison, or execution evidence. | CLM-007, CLM-013, CLM-019, CLM-035, CLM-037, CLM-039 | Reduces FM-007 and FM-008. | cross-source-supported | Skills whose behavior can be observed or compared. | Some subjective tasks require qualitative review rather than simple assertions. | passes-counterexample | accepted-risk |
| PR-006 | Completion, readiness, and severity claims must cite current evidence at the same scope as the claim; stale, partial, logical, or indirect evidence cannot close a changed target. | CLM-007, CLM-024, CLM-026, CLM-027, CLM-030, CLM-031, CLM-032 | Reduces FM-009, FM-010, FM-011, and FM-013. | empirically-supported | Audit, review, QA, release, and high-risk workflow Skills. | Evidence freshness rules are most critical where work changes over time. | passes-counterexample | closed |
| PR-007 | Behavior-control Skills should bind strong verbs and terminal states to concrete owner actions, artifacts, or allowed outcomes. | CLM-024, CLM-026, CLM-032, CLM-041 | Reduces FM-012 and FM-018. | empirically-supported | Multi-step handoff, QA, review, and release Skills. | May be excessive for small single-shot utility Skills. | passes-counterexample | accepted-risk |
| PR-008 | Source authority must be scoped: official docs prove product behavior; workflow repositories prove mechanisms; local files prove local assumptions; none alone proves universal best practice. | CLM-014, CLM-017, CLM-021, CLM-027, CLM-028, CLM-029 | Reduces FM-015. | cross-source-supported | Research and evaluation work. | This is an evidence-use rule, not a runtime Skill feature. | passes-counterexample | closed |
| PR-009 | Security and trust review is required when a Skill bundles scripts, broad tool access, network calls, or file access. | CLM-010, CLM-012, CLM-016, CLM-023 | Reduces FM-014 and FM-017. | source-backed | Resource-heavy or tool-enabled Skills. | Depth depends on actual permissions and execution environment. | not-applicable | closed |
| PR-010 | Description style must be validated against target trigger behavior; sources disagree on how much workflow summary belongs in description. | CLM-009, CLM-013, CLM-038, CLM-040 | Reduces FM-001 and FM-016. | contested | Trigger-sensitive Skills. | Keep as non-scoring context unless trigger eval evidence exists. | weakened | accepted-risk |

## Rejected Or Non-principles

| Item | Why Rejected Or Deferred |
| --- | --- |
| Popularity, stars, author reputation, or community buzz | These expose adoption or interest, not task correctness or behavior reliability. |
| "Official source says it, therefore universal" | Official sources are strong only within their product surface or format scope. |
| "All Skills need scripts" | Sources support scripts for deterministic, repetitive, fragile, or high-risk work; instruction-only Skills are legitimate. |
| "Shorter is always better" | Progressive disclosure is supported, but minimum useful instruction depends on task complexity. |
| "Good frontmatter proves a good Skill" | Format and trigger metadata are necessary for discovery but insufficient for behavior. |
| "A local audit scorecard is already the model" | The local scorecard is evidence of current assumptions and must be challenged before scoring. |

## Validated Principles

- PR-001: Runtime discoverability and invocation mode must be explicit and tested where possible.
- PR-002: Progressive disclosure should keep always-loaded context lean while making supporting resources discoverable.
- PR-003: Instructions must be actionable for the Skill's intended job and downstream consumer.
- PR-005: Effectiveness claims need realistic usage evidence, not just polished instructions.
- PR-006: Readiness and completion claims require current, scope-matching evidence.
- PR-007: Multi-step behavior-control Skills need concrete state, owner action, and artifact semantics.
- PR-008: Source authority must remain scoped and cannot substitute for evidence.

## Scenario-specific Principles

- PR-004: Use scripts, schemas, validators, or low-freedom procedures for deterministic, repetitive, fragile, or high-risk work.
- PR-009: Apply security/trust review when bundled resources, broad tool access, network calls, or filesystem operations are present.

## Rejected Ideas

- Do not treat workflow repository popularity as proof.
- Do not score local Skills against the local audit scorecard until this model is explicitly mapped to each target Skill's intended job.
- Do not use description wording alone as proof that the Skill will trigger correctly.
- Do not require full TDD-style baseline evaluation for every subjective or low-risk Skill without a reasoned scope decision.

## Unknowns

- Which exact metrics best predict future agent behavior across runtimes.
- How much description process detail is optimal for each model/runtime combination.
- What line-count or token threshold creates context harm for different Skill types.
- How much evidence is enough for low-risk helper Skills versus high-risk delivery-control Skills.

## Later Application Guidance

This model may be used to evaluate a repository Skill only after confirming the target Skill's intended job, runtime surface, invocation mode, downstream consumer, and risk level. Contested or unknown principles must remain non-scoring context. A later review should map relevant principles to the target Skill, collect current file and runtime evidence, run adversarial review, and keep readiness claims bounded to what the evidence proves.

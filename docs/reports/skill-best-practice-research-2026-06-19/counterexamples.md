# Skill Best-practice Counterexamples

## Purpose

Test whether candidate principles can identify misleading or failing Skills. Counterexamples are used to weaken or reject principles that only describe polished documents.

## Counterexamples

| Counterexample ID | Source Ref | Failure Type | Why It Looks Acceptable | Actual Failure | Principles That Catch It | Principles That Miss It | Model Update |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CE-001 | Synthetic, derived from CLM-008 and CLM-009 | Clear format but unreliable behavior | Has valid `SKILL.md`, name, description, and directory layout. | Trigger description is broad and no realistic trigger eval was run; it over-triggers adjacent work. | PR-001, PR-005, PR-010 | Format-only readings of PR-001 | PR-001 must require target-runtime trigger evidence when trigger risk matters. |
| CE-002 | `docs/reports/standard-chain-flow-instruction-control-full-review-2026-05-28.md:41-49` | Detailed process but weak failure handling | QA preflight appears to verify results and has concrete script logic. | It checks discovered candidates rather than proving every in-scope frozen task has current final PASS. | PR-006, PR-007 | PR-002 | Evidence coverage must match the claim scope. |
| CE-003 | `docs/reports/standard-chain-flow-instruction-control-full-review-2026-05-28.md:63-95` | Stale evidence accepted after target change | Review/verify/QA artifacts exist and may have passed earlier. | Scope/AC/code changes can reuse old evidence without invalidation or fresh proof. | PR-006, PR-007 | PR-001, PR-002 | Freshness and invalidation are core for readiness-style Skills. |
| CE-004 | Synthetic, derived from CLM-018 and CLM-026 | Output no downstream consumer can use | Skill produces a polished Markdown summary with helpful prose. | No typed artifact, no exact file refs, no status fields, and no downstream handoff contract. | PR-003, PR-006, PR-007 | PR-010 | Actionability must be judged against downstream consumption, not prose quality. |
| CE-005 | Synthetic, derived from CLM-010, CLM-033, and CLM-041 | Prose used where deterministic checks are needed | Instructions tell the agent to "carefully validate" a fragile transform. | No script/schema/check exists, so the agent repeatedly reimplements or skips the check. | PR-004, PR-005, PR-009 | PR-002 | PR-004 remains scenario-specific but required when determinism or safety is material. |
| CE-006 | `https://github.com/obra/superpowers/blob/main/README.md` lines 384-397 | Popular workflow mistaken for proof | The workflow is coherent, maintained, and widely discussed. | Popularity and coherent structure do not prove it works for this repository or target Skill. | PR-008 | All direct runtime principles | Source authority scoping is mandatory before applying any external mechanism. |
| CE-007 | `/Users/lijieli/.agents/skills/writing-skills/SKILL.md:95-158` vs `/Users/lijieli/.agents/skills/skill-creator/SKILL.md:66-68` | Conflicting source guidance | One source says description should include what the Skill does and when; another warns workflow summaries can cause shortcut behavior. | A simple wording rule would overgeneralize and break one context. | PR-001, PR-010 | PR-003 | Description style remains contested unless backed by target-runtime trigger eval. |

## Counterexample Result

- Principles that only checked format were weakened.
- Principles requiring scope-matching evidence, trigger evaluation, downstream handoff, and authority scoping survived the counterexamples.
- Synthetic counterexamples were not used alone to reject a principle; they identify failure questions that the adversarial review must test.

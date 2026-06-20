# Skill Best-practice Failure-mode Map

## Purpose

Map extracted claims to the agent failures they reduce. A failure mode without source-backed claims remains unknown.

## Failure Modes

| Failure Mode ID | Failure Mode | Supporting Claim IDs | Source Coverage | Remaining Unknowns |
| --- | --- | --- | --- | --- |
| FM-001 | Skill is not discoverable or triggers in the wrong situations. | CLM-002, CLM-003, CLM-009, CLM-013, CLM-034, CLM-038, CLM-040 | multi-source | Need runtime-specific trigger tests for each target agent surface. |
| FM-002 | Skill format is syntactically invalid or relies on unsupported fields. | CLM-001, CLM-008, CLM-009, CLM-011, CLM-012, CLM-016 | multi-source | Format validation does not prove the Skill works on real tasks. |
| FM-003 | Skill body or references overload context or hide needed instructions. | CLM-002, CLM-010, CLM-015, CLM-034, CLM-037 | multi-source | No universal size threshold was proven. |
| FM-004 | Agent begins execution before goal, scope, constraints, and done criteria are clear. | CLM-004, CLM-005, CLM-017, CLM-021, CLM-022, CLM-036 | multi-source | Some small tasks may not require full planning. |
| FM-005 | Executor-facing output is too vague to run or review. | CLM-004, CLM-018, CLM-026, CLM-029 | multi-source | Exact required structure depends on the workflow's downstream consumer. |
| FM-006 | Fragile or deterministic work is expressed only as prose. | CLM-001, CLM-010, CLM-012, CLM-033, CLM-041 | multi-source | Need task-specific evidence before requiring scripts. |
| FM-007 | Skill appears valid on paper but has not been tested against realistic usage. | CLM-007, CLM-013, CLM-019, CLM-035, CLM-037, CLM-039 | multi-source | The right eval strength depends on risk and objective verifiability. |
| FM-008 | No baseline or counterfactual evidence shows the Skill changed behavior. | CLM-035, CLM-037, CLM-039 | multi-source | Baselines may be expensive or impossible for subjective tasks. |
| FM-009 | Verification accepts partial, stale, or indirect evidence. | CLM-007, CLM-019, CLM-026, CLM-027, CLM-030, CLM-031 | multi-source + empirical | Need target-specific proof that checks cover the acceptance scope. |
| FM-010 | Scope or code changes reuse old review/QA/signoff evidence. | CLM-031, CLM-032 | empirical | Current repository state was not rechecked in this research. |
| FM-011 | Handoff artifacts are not structured for downstream consumption. | CLM-018, CLM-026, CLM-032 | multi-source + empirical | Need to know each target Skill's downstream consumer before scoring. |
| FM-012 | Strong wording such as pass, ready, consume, or evidence is not bound to a concrete owner action or artifact. | CLM-024, CLM-026, CLM-032, CLM-041 | multi-source + empirical | Not every Skill needs a formal state machine. |
| FM-013 | A Skill mutates the evidence or target while claiming to audit it. | CLM-024, CLM-029 | single-source + empirical | Mostly relevant to review/audit Skills. |
| FM-014 | Security and permissions risks in bundled scripts/resources are not reviewed. | CLM-010, CLM-012, CLM-016 | multi-source | Security review depth depends on actual tool/file/network access. |
| FM-015 | Workflow repositories or local rules are treated as universal authority. | CLM-017, CLM-021, CLM-027, CLM-028 | multi-source | Requires adversarial review to prevent authority bias. |
| FM-016 | Skill wording teaches the wrong behavior pattern for the observed failure. | CLM-038, CLM-040, CLM-041 | local formal system | Needs empirical wording tests for confidence. |
| FM-017 | Environment, version, or runtime state drifts under the Skill. | CLM-011, CLM-015, CLM-022, CLM-037 | multi-source | Runtime checks are product-specific. |
| FM-018 | A broad role command hides responsibility boundaries and mixes review, QA, and release concerns. | CLM-021, CLM-023, CLM-029, CLM-032 | multi-source + empirical | Role split can be useful, but only when inputs/outputs are concrete. |

## Under-sourced Areas

| Area | Current Evidence | Status |
| --- | --- | --- |
| Predictive validity of a Skill quality model | Local and official sources recommend evals, but no source proves a general scoring model predicts future agent behavior. | unknown |
| Universal wording style | Sources conflict on whether descriptions should include "what it does" versus only "when to use." | contested |
| Universal line-count or token threshold | Several sources recommend concise `SKILL.md` files and progressive disclosure, but thresholds are runtime- and task-dependent. | unknown |
| Required use of scripts | Sources support scripts for deterministic/repetitive/fragile work, not for every Skill. | scenario-specific |

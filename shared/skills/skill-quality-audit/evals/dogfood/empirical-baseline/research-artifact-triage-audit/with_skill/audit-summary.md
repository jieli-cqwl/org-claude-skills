# Research Skill Audit Summary

## Verdict

`conditional`

The research Skill has clear scenario value and a strong source-targeting workflow, but team use should stay conditional until formal report completion is actually locked by runtime and deterministic validation gates.

## Scorecard

| Dimension | Score | Evidence | Reason |
| --- | ---: | --- | --- |
| Real Use Capability | 9 | E3 | Explicit team-use scenario and Decision Package consumer. |
| Trigger And Routing | 6.5 | E3 | Adjacent routing is strong, but source adapter policy conflicts with manual runtime surface. |
| Instruction Contract | 8 | E3 | Critical workflow instructions are executable; formal completion is the weak path. |
| Workflow Causality | 8.5 | E3 | Source targeting feeds evidence qualification, judgment, and decision package in order. |
| Output And Handoff | 7 | E3 | Useful report output, weakened by incomplete deterministic formal completion checks. |
| Determinism And Validation | 5.5 | E3 | Existing gates pass but miss runtime registration and formal completion requirements. |
| Runtime Integration | 5.5 | E3 | Runtime surface, source adapter, and hook registry are not fully aligned. |
| Evidence And Evals | 7.5 | E3 | Prompt/eval/retain evidence exists; current gates miss the kept findings. |
| Noise And Maintainability | 8 | E3 | Mostly concise; completion truth is spread across too many surfaces. |

Verdict cap: P1 findings remain, so the Skill cannot be `fit`.

## Findings

### RESEARCH-P1-001 P1: Formal report completion gate is not registered in the runtime hook registry

Evidence: `shared/skills/research/SKILL.md:24`, `shared/skills/research/scripts/completion_check.sh:3`, `shared/hooks/registry.json:3`, and `shared/hooks/registry.json:289`. The independent probe also printed `registry_has_research_gate= False`.

Impact: A team can believe formal research completion is runtime-gated while installed runtimes do not dispatch the target completion check, allowing incomplete research reports to pass handoff without deterministic enforcement.

Repair target: shared/hooks/registry.json plus any hook-rendering tests that assert research completion gate registration

Verification hint: Register the research completion gate or explicitly retire the script from runtime claims; then run a focused install/runtime or hook-registry test proving research appears in skill_completion_gates and is dispatched.

### RESEARCH-P1-002 P1: Formal report validator accepts reports missing Self-Review and User Confirmation

Evidence: `shared/skills/research/SKILL.md:24`, `shared/skills/research/projections/research-report-template.md:198`, `shared/skills/research/projections/research-report-template.md:208`, `tests/test-research-skill-contract.sh:196`, and `tests/test-research-skill-contract.sh:228`. The independent probe also printed `valid_fixture_has_report_self_review= False` and `valid_fixture_has_user_confirmation_gate= False`.

Impact: Formal research artifacts can pass the deterministic contract without the self-review and confirmation state that downstream teams rely on before accepting or handing off a judgment.

Repair target: shared/skills/research/scripts/completion_check.sh and tests/test-research-skill-contract.sh

Verification hint: Extend completion_check.sh to require Report Self-Review and User Confirmation Gate evidence for formal reports, update valid/invalid fixtures, then rerun bash tests/test-research-skill-contract.sh and bash tests/run-focused.sh research.

### RESEARCH-P2-003 P2: Source OpenAI adapter allows implicit invocation despite manual runtime surface

Evidence: `shared/skills/research/agents/openai.yaml:7`, `contracts/skill-runtime-surface.json:308-312`, `install.sh:2191-2193`, and `tools/skills/apply_skill_runtime_surface.py:169-203`.

Impact: The source package presents a routing policy that contradicts the active runtime contract. Maintainers or direct adapter consumers can treat research as auto-routable even though the repo's runtime surface says it should be explicit.

Repair target: `shared/skills/research/agents/openai.yaml` or the adapter-generation path that owns source OpenAI policy.

Verification hint: Align the source adapter with the manual runtime surface or document why source adapters are intentionally generated differently; then run the Codex runtime surface tests that check manual implicit-invocation policy.

## Repair Handoff

| Target | Action | Owner |
| --- | --- | --- |
| `shared/hooks/registry.json` plus hook rendering tests | Register research completion_check as an active completion gate or remove runtime-gate claims. | runtime integration maintainer |
| `shared/skills/research/scripts/completion_check.sh` and `tests/test-research-skill-contract.sh` | Require Report Self-Review and User Confirmation Gate evidence for formal reports. | research skill maintainer |
| `shared/skills/research/agents/openai.yaml` | Align source adapter policy with manual runtime surface or document source/runtime split. | Codex adapter maintainer |

## Validation

- Formal validator command: `python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/research-artifact-triage-audit/with_skill/skill-audit-report.json`
- Validator output: `[PASS] skill audit report valid`
- Local verification: `bash tests/run-focused.sh research` passed 13/13 focused gates.

## Residual Risk

- No target Skill files were modified.
- Current focused research gates pass despite the P1 findings; that is a test coverage blind spot, not a refutation.

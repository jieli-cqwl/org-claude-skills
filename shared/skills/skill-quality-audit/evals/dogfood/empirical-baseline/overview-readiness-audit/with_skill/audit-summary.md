# Overview Skill Audit Summary

## Verdict

`conditional` with overall score `6.9 / 10`.

`shared/skills/overview` has a clear real-use scenario and a usable workflow contract, but it is not team-ready yet. The deciding issues are one P1 runtime safety defect in the directory-tree helper, weak executable eval coverage, and source/runtime routing drift.

## Scorecard

| Dimension | Score | Evidence | Reason |
| --- | ---: | --- | --- |
| Real Use Capability | 8.5 | E3 | Scenario, user value, output, and downstream consumer are explicit. |
| Trigger And Routing | 6.5 | E3 | Trigger text is clear, but source OpenAI policy conflicts with manual runtime surface. |
| Instruction Contract | 7.5 | E3 | Hard gates and step output contracts are executable, with minor runtime/maintenance noise. |
| Workflow Causality | 8.0 | E3 | Scan, mode confirmation, module map, document generation, and user confirmation feed each other. |
| Output And Handoff | 8.0 | E3 | Output path, template fields, and completion proof are explicit. |
| Determinism And Validation | 5.0 | E3 | Scripts exist, but `dir-tree.sh` has eval fallback and behavior gates are mostly prose. |
| Runtime Integration | 6.0 | E3 | Runtime surface and install self-heal exist, but source adapter remains contradictory. |
| Evidence And Evals | 4.5 | E2 | Prompt fixtures exist; executable overview evals/fixtures are absent. |
| Noise And Maintainability | 6.0 | E2 | Mostly compact, but sync maintenance text is embedded in runtime workflow. |

Verdict cap: `conditional` because one P1 remains and weighted score is below 8.

## Findings

- `OVERVIEW-P1-001` P1: dir-tree fallback builds a shell command with eval from overview inputs.
  Evidence: `shared/skills/overview/SKILL.md:52`, `shared/skills/overview/scripts/dir-tree.sh:9`, `shared/skills/overview/scripts/dir-tree.sh:10`, `shared/skills/overview/scripts/dir-tree.sh:26`.
  Impact: A required scan helper can execute unintended shell fragments in fallback environments, affecting safe team use and making the user-supplied project path an unsafe runtime input.
  Repair target: `shared/skills/overview/scripts/dir-tree.sh`.
  Verification hint: Replace eval with an argument-array or loop-based find implementation, validate DEPTH as a positive integer, preserve ignore semantics, then test paths containing spaces and shell metacharacters.

- `OVERVIEW-P2-001` P2: overview behavior is represented by prompt fixtures, not executable readiness gates.
  Evidence: `shared/skills/overview/test-prompts.json:5`; target `evals/` and `fixtures/` are absent; `tests/test-platform-runtime-noise.sh:266` checks path rendering only.
  Impact: no deterministic proof for scan-before-write, mode confirmation, blocked states, Mermaid check, or final confirmation.
  Repair target: `shared/skills/overview/evals` or focused gate-plan coverage.
  Verification hint: add executable evals/tests for failure paths and completion proof.

- `OVERVIEW-P2-002` P2: source OpenAI adapter contradicts manual runtime contract before install self-heal.
  Evidence: `shared/skills/overview/agents/openai.yaml:7`, `contracts/skill-runtime-surface.json:232`, `tools/skills/apply_skill_runtime_surface.py:262`.
  Impact: installed output is protected, but source package and runtime contract disagree.
  Repair target: `shared/skills/overview/agents/openai.yaml` or generated-source policy contract.
  Verification hint: make source and installed adapter policy converge, then run install/runtime surface checks.

- `OVERVIEW-P3-001` P3: maintainer sync clauses are mixed into runtime user workflow.
  Evidence: `shared/skills/overview/SKILL.md:54`, `shared/skills/overview/SKILL.md:56`.
  Impact: minor attention-economy drag for the executing agent.
  Repair target: `shared/skills/overview/SKILL.md` and maintenance docs/tests.
  Verification hint: keep runtime steps limited to user-request execution contracts.

## Repair Handoff

- `shared/skills/overview/scripts/dir-tree.sh`: remove `eval`, validate depth, preserve ignore semantics, add edge-case tests.
- `shared/skills/overview/evals` or `tests/gate-plan.json`: add executable behavior coverage for overview readiness.
- `shared/skills/overview/agents/openai.yaml`: align source policy with manual runtime surface or mark it generated.
- `shared/skills/overview/SKILL.md`: move maintainer sync clauses out of runtime workflow.

## Validation

JSON report path: `shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/overview-readiness-audit/with_skill/skill-audit-report.json`

Validator command: `python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/overview-readiness-audit/with_skill/skill-audit-report.json`

Validator output: `[PASS] skill audit report valid`

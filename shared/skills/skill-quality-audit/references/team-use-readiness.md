# Team-Use Readiness Acceptance

Use this reference before issuing or accepting a team-use readiness verdict. It is a final acceptance lens over the scorecard, not an extra scoring dimension.

## Source Boundary

```json readiness_contract
{
  "contract_id": "skill-quality-audit.team-use-readiness",
  "verdict_scope": "repository_custom_team_use_readiness",
  "official_certification": false,
  "generic_agent_skills_compliance": false,
  "target_users": ["team_members"],
  "target_activity": "audit_existing_skills",
  "allowed_verdicts": ["fit", "conditional", "unfit", "blocked"],
    "required_outputs": ["confirmed_alignment", "formal_report", "repair_handoff", "validation_evidence"],
  "evidence_guardrails": ["checklist_not_evidence", "structure_content_coherence"],
  "source_boundaries": [
    {
      "id": "openai_codex_skills_doc",
      "can_prove": ["codex_skill_authoring_model", "progressive_disclosure", "description_trigger_metadata"],
      "cannot_prove": ["team_use_readiness", "repository_report_schema", "mandatory_optional_directories"]
    },
    {
      "id": "open_agent_skills_specification",
      "can_prove": ["portable_skill_package_conventions"],
      "cannot_prove": ["openai_official_certification", "repository_custom_readiness"]
    },
    {
      "id": "repository_custom_contract",
      "can_prove": ["report_schema", "empirical_baseline", "runtime_surface", "static_quality_gates"],
      "cannot_prove": ["generic_agent_skills_compliance", "readiness_for_untested_skill_classes"]
    }
  ]
}
```

This repository's `team-use readiness` verdict means team members can use `skill-quality-audit` to audit existing Skills and receive a formal `fit`, `conditional`, `unfit`, or `blocked` decision with repair handoff under this repository's custom contract.

It does not represent OpenAI official certification, generic Agent Skills compliance, or readiness for every Skill type outside the tested boundary.

Use source labels precisely:

- `openai_codex_skills_doc`: Codex Skill authoring model, progressive disclosure, and `description` trigger metadata.
- `open_agent_skills_specification`: portable Skill package conventions.
- `repository_custom_contract`: this repo's report schema, empirical baseline, runtime surface, and static quality checks.

## Readiness State

Readiness state:

- `contract-hardened`: deterministic report, evidence, and handoff gates exist, but semantic audit capability is not yet proven.
- `conditional-team-use`: core gates pass, but one or more acceptance capabilities still need broader eval or field evidence.
- `team-ready`: all five capabilities below are proven by current evidence and both the confirmed alignment validator and formal report validator pass.

The `brainstorming` benchmark matters because its structure is a target-directed state machine: each loaded sentence moves the agent toward a clearer goal, blocks a common wrong turn, or defines the next handoff state.

## Scenario Capability

Success standard: The audit names the real user scenario, target Skill consumer, expected decision, and why a team should use the audit instead of direct prompting or generic code review.

Failure mode: The report scores a Skill without first proving what problem the Skill is supposed to solve, who consumes the result, or what “ready” means for that team.

Required evidence: Confirmed alignment artifact, Target Skill trigger, expected output, consumer path, and completion standard cited from active files or current user-supplied scope.

## Structure-Content Coherence

Success standard: The audit checks whether each major structure gives the agent a target, next action, evidence requirement, stop condition, or handoff state that later work consumes.

Failure mode: The audit treats a checklist, flowchart, table, section count, or borrowed `brainstorming` shape as proof of quality. A checklist is not evidence by itself.

Required evidence: For each praised or criticized structure, name the target state it creates, the next action that consumes it, and the failure that appears when that structure is missing, duplicated, or decorative.

## Evidence Integrity

Success standard: Findings distinguish observed facts, inferred claims, and verification results. P0/P1 findings survive direct refutation checks and severity calibration.

Failure mode: The audit accepts stale paths, fake checked surfaces, unrelated command output, title-only summaries, or severity labels unsupported by current file evidence.

Required evidence: Current `path:line` citations, structured evidence checks for P0/P1, validator output, and matching `executed_verification.supports` for E4 claims.

## Repairable Handoff

Success standard: The output gives a separate repair window enough information to act without replaying the whole audit.

Failure mode: The report provides a verdict or scorecard but leaves the repair owner guessing which file, behavior, downstream consumer, or verification proves the fix.

Required evidence: Each finding includes impact, repair target, verification hint, and a handoff target grouped by file or owned artifact.

## Attention Economy

Success standard: Every loaded instruction, reference, gate, and output field has a consumer or a blocking purpose.

Failure mode: Hard gates contain non-blocking detail, references are loaded without a retrieval target, roles sound professional but do not constrain decisions, or prose repeats what deterministic validators already enforce.

Required evidence: For each large block, identify its consumer. If the consumer is a schema, script, test, or hook, keep the prose as route/context only and let the deterministic artifact enforce the rule.

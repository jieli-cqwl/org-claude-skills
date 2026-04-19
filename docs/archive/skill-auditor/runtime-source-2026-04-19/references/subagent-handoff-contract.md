# SubAgent And Handoff Contract

Trigger: Use this when auditing SubAgent usage, fork isolation, full preload, or pipeline handoff.
Read: Skill body, agent prompts, eval cases, handoff artifacts, and pipeline outputs.
Expect: Skill defines HOW; SubAgent defines WHO/WHAT; handoff defines WHERE, OUTPUT, evidence, and next consumer.
Consume: Eval dataset, `audit_skill.py`, coverage report, and human review consume this contract.
Evidence: Handoff fixture, fork isolation case, full preload case, pipeline handoff case, and conflict adjudication evidence.
Sync: Update eval fixtures when handoff fields or agent boundaries change.

## Fork Input

Required fields: `task`, `scope`, `input_refs`, `required_context`, `excluded_context`, `allowed_tools`, `expected_output`, and `acceptance_basis`.

## Handoff Output

Required fields: `scope`, `consumer`, `evidence`, `uncertainty`, `blockers`, `output_contract`, `acceptance_basis`, `decision_required`, and `next_step`.

Pipeline stages add `stage_id` and `input_from`.

## Minimal Example

A well-formed fork+handoff for a permission audit SubAgent:

```
Fork Input:
  task: "Audit permission boundary for target Skill"
  scope: "shared/skills/target-skill/SKILL.md"
  input_refs: ["SKILL.md", "./rules/permission-profiles.md"]
  required_context: ["frontmatter allowed-tools", "script manifest"]
  excluded_context: ["unrelated Skills", "global rules"]
  allowed_tools: ["Read", "Glob", "Grep"]
  expected_output: "permission findings in skill-audit.json format"
  acceptance_basis: "each finding has file_ref, evidence_refs, and dimension"

Handoff Output:
  scope: "permission boundary"
  consumer: "audit_skill.py merge step"
  evidence: ["grep output for allowed-tools", "manifest.json validation"]
  uncertainty: "hook adapter boundary not checked"
  blockers: []
  output_contract: "findings array matching skill-audit.schema.json"
  acceptance_basis: "zero FAIL without evidence_refs"
  decision_required: false
  next_step: "merge into parent audit"
```

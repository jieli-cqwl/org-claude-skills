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

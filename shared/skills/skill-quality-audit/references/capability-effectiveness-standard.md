# Capability Effectiveness Standard

Use this before a formal audit. The standard is co-created with the user during the review stage; repository contracts and target Skill self-description can seed it, but cannot confirm it.

## Required Fields

Record the confirmed standard in `alignment.capability_effectiveness_standard`:

- `real_task_scenarios`: the real work the user expects the Skill to improve.
- `success_criteria`: observable outcomes that prove the agent can do the work.
- `failure_modes`: ways the Skill can induce the agent to fail in real tasks.
- `unacceptable_risks`: risks that block `fit` unless proven resolved.
- `evidence_requirements`: evidence needed before a claim can leave residual risk.
- `confirmation_evidence`: file-line evidence that records the user confirmation used by the formal alignment.

## Layered Judgment

Do not trade instruction quality against capability effectiveness. Use this order:

1. **Instruction Hygiene**: instructions are clear enough for the LLM to execute without guessing actor, condition, object, output, or failure state.
2. **Attention Economy**: loaded content has a consumer, blocks a wrong turn, or defines an output; noise and duplicate prose dilute compliance.
3. **Behavior Induction**: the content makes the agent take the right actions, ask the right confirmation question, preserve unknowns, and avoid premature verdicts.
4. **Capability Effectiveness**: the induced behavior satisfies the user-confirmed real-task standard.

Failure at an earlier layer is evidence against later layers. Passing an earlier layer is not enough to prove later layers.

## Formal Audit Gate

Before issuing a readiness verdict:

- `user_confirmation.confirmed_scope_ref` must cite the co-created `capability_effectiveness_standard`.
- `capability_effectiveness_standard.confirmation_evidence` must cite a current file-line confirmation record for confirmed alignments.
- `content_behavior_audit` must cover every confirmed target capability.
- `fit` requires supported instruction hygiene, attention economy, behavior induction, failure-mode coverage, unproven-risk disposition, and per-field evidence checks.

If any part is not proven, keep it as a finding or residual risk. Do not convert unknowns into `fit`.

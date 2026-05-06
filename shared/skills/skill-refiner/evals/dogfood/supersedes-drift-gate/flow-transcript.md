# skill-refiner supersedes drift gate transcript

Requirement: prove conclusion drift is recorded and resolved before final operation freeze.

### SR-S2

real_scenario: Prove that a confirmed optimize-only refinement baseline cannot silently drift into a create operation later in SR-R.
business_constraint: The fixture may only write dogfood evidence; no production Skill creation is allowed.
expected_outcome_signal: SR-R4 records the create drift as a supersedes candidate, pauses for user confirmation, rejects create, and SR-F1 freezes final_operation=optimize.
observed_pain: Confirmed conclusions can dilute over long co-creation and silently turn into a different operation.
protected_capability_candidate: Keep the existing tiny router Skill and the optimize-only baseline unless the user explicitly changes direction.
entry_point_candidate: Flow is the candidate entry point; concrete drift handling remains deferred to SR-R4 and SR-F1.
located_carrier: shared/skills/skill-refiner/evals/dogfood/supersedes-drift-gate
open_questions: No open questions for this drift fixture; the user decision is encoded in the supersedes confirmation.

### SR-R4

Detected drift: SR-R4 proposed final_operation=create against the SR-S2 optimize-only baseline.
Stopped for user decision before target file changes.
User confirmation: reject create drift and keep final_operation=optimize.

### SR-F1

整体策略确认: final_operation=optimize after supersedes resolution.

### SR-E1

Executed once after freeze: wrote dogfood transcript, ledger, and result only.

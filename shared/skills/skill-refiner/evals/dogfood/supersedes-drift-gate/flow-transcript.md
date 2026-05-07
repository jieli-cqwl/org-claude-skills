# skill-refiner supersedes drift gate transcript

Requirement: prove conclusion drift is recorded and resolved before final operation freeze.

### SR-S2

场景：Prove a confirmed optimize-only baseline cannot silently drift into create later in SR-R.
约束：The fixture may only write dogfood evidence; no production Skill creation is allowed.
想看到的变化：SR-R4 records create drift, pauses for decision, rejects create, and SR-F1 freezes optimize.
观察到的不适：Confirmed conclusions can dilute over long co-creation and turn into a different operation.
要保留的能力：Keep the existing tiny router Skill and optimize-only baseline unless the user changes direction.
候选切入点：Flow; concrete drift handling remains deferred to SR-R4 and SR-F1.
承载：shared/skills/skill-refiner/evals/dogfood/supersedes-drift-gate
待确认：No open questions for this drift fixture.

### SR-R4

Detected drift: SR-R4 proposed final_operation=create against the SR-S2 optimize-only baseline.
Stopped for user decision before target file changes.
User confirmation: reject create drift and keep final_operation=optimize.

### SR-F1

整体策略确认: final_operation=optimize after supersedes resolution.

### SR-E1

Executed once after freeze: wrote dogfood transcript, ledger, and result only.

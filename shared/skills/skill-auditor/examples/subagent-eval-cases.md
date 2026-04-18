# SubAgent Eval Cases

Positive: fork isolation receives only explicit input refs and returns structured findings.
Negative: fork task depends on hidden main conversation history.
Boundary: pipeline handoff passes `stage_id`, `input_from`, evidence, blockers, and next consumer.
Consumer: Eval dataset and end-to-end coverage use these cases.

| Case | Expected |
| --- | --- |
| fork isolation with required context | PASS |
| SubAgent `skills:` full preload acknowledged | PASS |
| pipeline handoff missing `input_from` | FAIL |
| conflict adjudication without evidence | FAIL |

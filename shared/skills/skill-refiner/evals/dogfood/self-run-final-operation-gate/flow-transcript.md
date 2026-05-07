# skill-refiner self dogfood flow transcript

Requirement: optimize `tiny-review-router` so requests to create a code-review Skill first locate existing review capability and defer final operation to SR-F1.

### SR-S1

Current judgment: target carrier is `input/SKILL.md`; quality layer is First-party hardening; issue maps to S3, S4, S6, and E2.
Confirmation: accepted for this self-run fixture.

### SR-S2

已闭合事实：A code-review Skill request may already be covered by existing review capability; this self-run fixture must avoid runtime install and the full slow suite.
推荐理解：Treat the early create instruction as an intake pain and defer create/optimize choice until SR-F1.
关键假设：If no existing review capability can be searched, the Trigger and Flow conclusions must be reopened.
用户动作：Accept this fixture baseline or replace the capability-lookup assumption.

### SR-S3

Current judgment: professional domain is Skill routing and capability reuse, not direct Skill creation.
Best-practice target: route, compare, freeze, then execute.
Confirmation: accepted for this self-run fixture.

### SR-S4

Current judgment: consumers are the user, the refined `SKILL.md`, the result JSON, validator, and this dogfood test.
Candidate signal: input says "Final decision: create a new code-review Skill immediately."

### SR-R1

Trigger confirmed: route code-review Skill requests without claiming creation as the first action.

### SR-R2

Responsibility confirmed: own capability routing and final operation freeze; do not own direct creation before evidence.

### SR-R3

Input confirmed: required input is user scenario plus existing review capability search results.

### SR-R4

Flow confirmed: locate existing capability, register candidate operations, freeze final operation, execute once.

### SR-R5

Output confirmed: report candidates, final operation, changed files, proof commands, and risks.

### SR-R6

Resource confirmed: keep this as a small SOP; no new reference or schema is needed for the tiny fixture.

### SR-R7

Determinism confirmed: result JSON and shell test prove field shape and output behavior.

### SR-R8

Eval confirmed: `tests/test-skill-refiner-self-dogfood-flow.sh` proves this run.

### SR-R9

Cleanup confirmed: remove the early-create instruction from the output.

### SR-R10

Runtime confirmed: no runtime registration changes are needed for this fixture.

### SR-F1

整体策略确认: final_operation=optimize.
No output file was written before SR-F1.

### SR-E1

Executed once: wrote `output/SKILL.md` and `skill-refiner-result.json` for the frozen optimize operation.

### SR-V1

Validation passed: validator, self-dogfood shell test, and output behavior checks all pass.

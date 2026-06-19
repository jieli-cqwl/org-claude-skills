# Skill Best-practice Evidence Research Design

## Objective

Build an evidence-first research process that discovers what makes an agent Skill effective before this repository uses any rubric to judge its own Skills.

The immediate decision is not whether `standard-chain` is good, whether its Skills are ready, or whether a dogfood run should start. The immediate decision is whether we can produce a source-backed, challenge-tested model for Skill quality that is strong enough to use in a later review.

## Non-goals

- Do not assess `product-director`, `product-manager`, `design`, `test-design`, `tech-lead`, or `delivery-owner`.
- Do not decide `standard-chain` flow quality or dogfood readiness.
- Do not edit any Skill, contract, schema, test, fixture, or runtime config.
- Do not treat gstack, Superpowers, OpenAI, Anthropic, or this repository as automatic authority.
- Do not start from a predefined rubric and search for evidence that supports it.

## Core Risk

The main risk is circular evaluation:

1. We assume what dimensions define a good Skill.
2. We review Skills using those dimensions.
3. We conclude the review is rigorous because the dimensions were followed.

This design prevents that by treating every quality dimension as an unproven hypothesis until it is supported by sources, cross-source comparison, failure-mode logic, counterexamples, and adversarial review.

## Research Principle

Research order is fixed:

1. Collect sources.
2. Classify source authority and scope.
3. Extract claims without converting them into a rubric.
4. Map each claim to the agent failure mode it claims to prevent.
5. Compare claims across sources.
6. Search for counterexamples.
7. Challenge candidate principles.
8. Only then derive a provisional Skill quality model.

Any step that skips evidence extraction and jumps to dimensions is out of scope.

## Source Classes

Each source must be classified before use.

| Class | Examples | Use | Limit |
| --- | --- | --- | --- |
| Official source | Product docs, official Skill manuals, official examples | Strong evidence for that product surface | Not universal unless cross-source supported |
| High-signal workflow | gstack, Superpowers, other maintained agent workflows | Mechanism examples and tested patterns | Popularity is not evidence of general truth |
| Local formal system | `skill-quality-audit`, local schemas, tests, runtime contracts | Evidence for this repository's current assumptions | May encode local bias |
| Empirical failure evidence | Bugs, eval failures, review reports, observed bad Skills | Validates failure modes | May be anecdotal or context-specific |
| Maintainer explanation | README rationale, design notes, issue discussions | Useful intent and tradeoff context | Not proof of effectiveness |
| Model inference | Analysis without direct source support | Hypothesis generation only | Cannot justify a standard |

## Claim Extraction

For each source, researchers must extract atomic claims before synthesis.

Claim fields:

- `source_ref`: URL or repository path with line reference when possible.
- `source_class`: one source class from above.
- `claim`: what the source asserts or demonstrates.
- `surface`: format, trigger, workflow, behavior control, validation, runtime, maintenance, or failure handling.
- `failure_mode`: what agent failure this claim prevents or reduces.
- `scope`: where the claim applies.
- `evidence_strength`: direct source, cross-source, empirical, inferred, or unknown.
- `limits`: where the claim should not be generalized.

Researchers must not rewrite claims into polished principles at this stage.

## Candidate Principle Promotion

A claim can become a candidate principle only if it passes at least one of these gates:

- It appears independently across multiple high-signal sources.
- It is supported by official source guidance and does not conflict with other strong sources.
- It explains a recurring empirical failure mode.
- It is necessary for runtime safety, handoff correctness, or evidence integrity in agent work.

Each promoted principle receives one status:

- `source-backed`: direct strong source support.
- `cross-source-supported`: multiple independent sources support it.
- `empirically-supported`: failure or eval evidence supports it.
- `scenario-specific`: valid only in a bounded context.
- `contested`: plausible but challenged by counterexample or source conflict.
- `weak`: insufficient evidence; keep as hypothesis.
- `rejected`: refuted, overbroad, or not useful.

Only `source-backed`, `cross-source-supported`, `empirically-supported`, and explicitly bounded `scenario-specific` principles can enter the provisional model.

## Counterexample Requirement

The research must actively search for bad or misleading Skills, not only strong examples.

Counterexamples should include at least:

- A Skill with clear format but unreliable behavior.
- A Skill with a detailed process but weak failure handling.
- A Skill that over-triggers or steals adjacent work.
- A Skill that produces outputs no downstream consumer can use.
- A Skill that relies on prose where deterministic checks are needed.

If the candidate model cannot identify why a counterexample fails, the model is incomplete.

## Adversarial Review

Red-team reviewers attack the model, not this repository's Skills.

Required attack roles:

- Authority-bias attacker: challenges whether sources are being treated as truth instead of evidence.
- Circularity attacker: checks whether principles were assumed before evidence was gathered.
- Predictive-validity attacker: asks whether the principle predicts agent behavior or only document quality.
- Generalization attacker: checks whether a principle is universal, local, or scenario-specific.
- Verification attacker: checks whether the principle can be tested, observed, or falsified.

Every red-team challenge must be resolved as:

- `closed`: model updated or evidence supplied.
- `accepted-risk`: limitation remains but is explicitly bounded.
- `blocked`: evidence insufficient; principle cannot be used.
- `rejected`: challenge refuted with evidence.

## Provisional Model Output

The final research output is a model package, not a verdict on current Skills.

Required artifacts:

1. **Evidence Map**
   - Source inventory.
   - Source authority classification.
   - Extracted claims.
   - Source limits.

2. **Failure-mode Map**
   - Agent failures a Skill should prevent.
   - Claims and sources tied to each failure mode.
   - Unknown or under-sourced failure modes.

3. **Candidate Principle Register**
   - Principle statement.
   - Status.
   - Supporting claims.
   - Counterexamples checked.
   - Red-team resolution.
   - Scope and limits.

4. **Provisional Skill Quality Model**
   - Only validated principles.
   - Scenario-specific labels where needed.
   - Explicit non-principles and rejected ideas.

5. **Application Guidance**
   - How to use the model later to evaluate this repository's Skills.
   - What the model cannot prove.
   - What additional evidence is required before scoring local Skills.

## Completion Criteria

The research design is complete only when:

- No quality dimension appears before source-backed claim extraction.
- Every candidate principle has source refs and a failure-mode rationale.
- Cross-source support is separated from scenario-specific evidence.
- Counterexamples were used to test the model.
- Red-team challenges have recorded outcomes.
- Unknowns remain unknown instead of being converted into weak standards.
- The output cannot be misread as an assessment of current `standard-chain` Skills.

## Later Use

After this research produces a provisional model, a separate approved plan may apply it to this repository.

That later review should proceed in this order:

1. Confirm the target Skill's intended job.
2. Select only model principles relevant to that job.
3. Review the Skill against those principles.
4. Preserve contested or unknown principles as non-scoring context.
5. Use red-team review before any readiness verdict.

No local Skill should be judged against a principle that has not survived the evidence and challenge process.

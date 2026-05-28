# Skill Audit Summary

Verdict: conditional.

Finding F-001 / P1 / Instruction contract is too weak.

Evidence: tests/fixtures/skill-quality-audit/evidence-target.md:3 uses vague action.

Impact: The Skill cannot be executed reliably.

Repair target: shared/skills/skill-quality-audit/evals/fixtures/target-skills/good-skill/SKILL.md Workflow

Verification hint: Raise Instruction Contract score to at least 5 before using conditional.

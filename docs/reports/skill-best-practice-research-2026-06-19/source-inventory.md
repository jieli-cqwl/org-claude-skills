# Skill Best-practice Source Inventory

## Scope

This inventory selects sources for discovering what makes an agent Skill effective. It does not judge this repository's current Skills, `standard-chain`, or dogfood readiness.

## Source Selection Rules

- Prefer official or primary sources.
- Treat community workflows as mechanism examples, not authorities.
- Include local formal systems only as evidence of this repository's current assumptions.
- Include empirical failure evidence when it exposes actual agent or Skill failure modes.
- Exclude popularity, marketing claims, star counts, author reputation, and unsourced opinions as effectiveness evidence.

## Access Date

- Local environment date: 2026-06-19 PDT.
- Public web source checks were run from this environment on 2026-06-19 PDT; subagent reports also recorded 2026-06-20 UTC for web access.

## Sources

| Source ID | Source | Class | Access / Ref | Why Included | Scope Limit | Status |
| --- | --- | --- | --- | --- | --- | --- |
| SRC-001 | `https://developers.openai.com/codex/skills` | Official source | Accessed 2026-06-19 PDT; verified lines 672-700 | Official Codex guidance for agent skills, progressive disclosure, invocation, and skill structure | OpenAI/Codex-specific unless cross-source supported | selected |
| SRC-002 | `https://developers.openai.com/codex/learn/best-practices` | Official source | Accessed 2026-06-19 PDT; verified lines 681-725 | Official Codex guidance for task context, planning, reusable guidance, and turning repeated work into skills | OpenAI/Codex-specific unless cross-source supported | selected |
| SRC-003 | `https://agentskills.io/specification` | Official source | Accessed 2026-06-19 PDT; verified lines 71-155 | Open Agent Skills format specification for `SKILL.md`, optional directories, and progressive disclosure | Format-focused; not a complete behavior-quality model | selected |
| SRC-004 | `https://code.claude.com/docs/en/skills` | Official source | Accessed 2026-06-19 PDT; verified lines 115-135 | Official Claude Code guidance for creating and using skills | Claude Code-specific unless cross-source supported | selected |
| SRC-005 | `https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview` | Official source | Accessed 2026-06-19 PDT; verified lines 160-230 | Official Claude API Agent Skills overview for skill purpose, packaging, and usage | Anthropic API-specific unless cross-source supported | selected |
| SRC-006 | `https://github.com/obra/superpowers` | High-signal workflow | Accessed 2026-06-19 PDT; README lines 224-251; `writing-plans/SKILL.md` lines 8-18 and 128-154; `test-driven-development/SKILL.md` lines 8-128; `systematic-debugging/SKILL.md` lines 8-190 | Maintained workflow skill set with explicit process discipline | Workflow-specific, not universal authority | selected |
| SRC-007 | `https://github.com/garrytan/gstack` | High-signal workflow | Accessed 2026-06-19 PDT; README lines 34-41, 171-207; `spec/SKILL.md` lines 1-18 and 23-30; `ship/SKILL.md` lines 1-31 and 33-142 | Agentic coding workflow with role/process mechanisms | Workflow-specific, not universal authority | selected |
| SRC-008 | `shared/skills/skill-quality-audit/SKILL.md` | Local formal system | `shared/skills/skill-quality-audit/SKILL.md:1-143` | Local formal audit method for Skill readiness | May encode local bias | selected |
| SRC-009 | `shared/skills/skill-quality-audit/references/audit-dimensions.md` | Local formal system | `shared/skills/skill-quality-audit/references/audit-dimensions.md:1-50` | Local candidate dimensions and evidence levels | Must be treated as evidence, not pre-approved scoring standard | selected |
| SRC-010 | `docs/reports/standard-chain-flow-instruction-control-full-review-2026-05-28.md` | Empirical failure evidence | `docs/reports/standard-chain-flow-instruction-control-full-review-2026-05-28.md:1-482` | Prior evidence-backed review of flow and instruction-control failures | Context-specific; must not overgeneralize | selected |
| SRC-011 | `/Users/lijieli/.codex/skills/.system/skill-creator/SKILL.md` | Local/runtime formal system | `/Users/lijieli/.codex/skills/.system/skill-creator/SKILL.md:1-416` | Codex runtime guidance for skill structure, progressive disclosure, resources, validation, and iteration | Runtime-specific; may reflect product assumptions | selected |
| SRC-012 | `/Users/lijieli/.agents/skills/skill-creator/SKILL.md` | Local/runtime formal system | `/Users/lijieli/.agents/skills/skill-creator/SKILL.md:1-485` | Agent skill creation guidance for trigger design, test prompts, evaluation, and iteration | Runtime-specific; may reflect local workflow assumptions | selected |
| SRC-013 | `/Users/lijieli/.agents/skills/writing-skills/SKILL.md` | Local/runtime formal system | `/Users/lijieli/.agents/skills/writing-skills/SKILL.md:1-689` | Skill-writing guidance focused on pressure scenarios, discovery, trigger descriptions, token efficiency, and validation | Superpowers-specific; must not become an unchallenged scoring standard | selected |

## Source Use Boundaries

- Official sources can support claims about their own product surface or the open format they specify.
- Workflow repositories can support mechanism claims, not universal effectiveness claims.
- Local formal systems can expose this repository's current assumptions, but those assumptions remain hypotheses until cross-checked.
- Historical failure reports can expose concrete failure modes, but they do not prove the current code still has those failures.
- No source in this inventory is sufficient by itself to define a complete Skill quality model.

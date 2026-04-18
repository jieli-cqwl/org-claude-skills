# Source Map Coverage

Trigger: Use this when checking whether course-derived methods and local Harness decisions are covered.
Read: Source markers, examples, evals, references, and coverage report.
Expect: C09-C14, C99, L, O, and S are separated by evidence strength and consumer.
Consume: Contract tests, eval runner, coverage report, and human review consume this map.
Evidence: Coverage row links marker, method, task, plan step, and fresh command.
Sync: Update this file when source marker usage or task mapping changes.

## Marker Origin

- **C09-C14, C99**: Derived from Claude Code course modules (Skill anatomy, triggers, resources, SubAgent, scripts, distribution, testing).
- **L**: Local rules and install checks specific to this org.
- **O**: Official Anthropic `skill-creator` documentation and Skill anatomy.
- **S**: Local Harness Engineering design decisions (JSON fact source, schema, semantic validation).

## Coverage

| Marker | Coverage |
| --- | --- |
| C09 | `description`, frontmatter, Skills/Tools/SubAgent/Hooks boundary |
| C10 | manual-only, `$ARGUMENTS`, `!command`, allowed-tools, hooks, failure path |
| C11 | Quick Reference, QUICKREF, INDEX, contract references, SLASH_COMMAND_TOOL_CHAR_BUDGET |
| C12 | fork, SubAgent full preload, pipeline, handoff, conflict adjudication |
| C13 | scripts, templates, skill-local rules, execution maturity |
| C14 | Push/Pull, skills marketplace, cross-platform, self-contained, namespace, monorepo, distribution |
| C99 | 5/10/30 metric, reuse pattern, Test Case, reusable dataset, benchmark evidence |
| L | Local rules, install checks, context budget, completion discipline |
| O | Official `skill-creator`, Skill anatomy, adapter compatibility |
| S | Harness Engineering, JSON fact source, schema, semantic validator, rollback |

# Noise Taxonomy

Noise is content without a consumer, content that weakens responsibility boundaries, or content that moves deterministic control into prose.

## Categories

| Noise | Signal | Repair |
| --- | --- | --- |
| No consumer | A field, paragraph, or artifact is never read by runtime, tests, scripts, downstream Skills, or users. | Delete it. |
| Runtime leakage | Installer, hook, adapter, or gate internals appear in the Skill body without changing the workflow. | Move to runtime docs or tests. |
| Method prose | The Skill explains philosophy instead of telling the agent what to do. | Compile into action, gate, output, or delete. |
| Duplicate machine contract | SKILL.md, schema, template, and tests all define the same fields. | Keep schema/template/test as truth; route to them. |
| Weak negative pileup | Many prohibitions but no positive action. | Replace with owner, input, workflow, output, and stop condition. |
| Old-name residue | Active runtime, install, test, eval, or README paths still require a retired Skill. | Rewrite active consumers or delete stale artifacts. |
| Vague success | Words such as "quality", "clear", or "complete" lack evidence criteria. | Add score, field, command, consumer, or verification. |

## Keep Conditions

Keep content only when it is:

- executed by the current workflow.
- consumed by schema, script, test, eval, runtime, downstream Skill, or user handoff.
- a hard safety or completion boundary.
- a fixture or example used by active tests.

Historical content belongs in archive or eval snapshots only when no active path treats it as current truth.

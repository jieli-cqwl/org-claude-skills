# Runtime Noise Contract

Trigger: Use this when active Skill text contains legacy names, migration history, temporary notes, examples, or retrospective detail.
Read: Active `SKILL.md`, adapters, references, install exposure, archive paths, fixtures, and tests that mention old names or historical states.
Expect: Active runtime contains only current behavior contracts; history lives in archive, fixtures, or migration docs with a current consumer.
Consume: Skill Harness reviewers, migration tests, and content-order checks consume this policy.
Evidence: Cite each noisy `file:line`, classify its current consumer, and name the cleanup or archive action.
Sync: Update this file when archive policy, migration allowlists, or active runtime naming changes.

## Classification

| Class | Active Runtime Allowed | Requirement |
| --- | --- | --- |
| Current contract | Yes | Directly affects current routing, gates, or completion |
| Test fixture | No, unless in tests | Covered by a deterministic test path |
| Migration doc | No, unless in migration docs | Names owner and exit condition |
| Archive history | No | Stored under `docs/archive/` |

## Retired Names

Retired Skill names may appear only as migration context, fixtures, eval inputs, or archive material. They must not be active aliases, adapter prompts, compatibility entries, or install targets.

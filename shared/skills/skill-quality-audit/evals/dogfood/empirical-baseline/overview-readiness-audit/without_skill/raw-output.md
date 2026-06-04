# overview readiness audit - without_skill baseline

## Scope

- Target skill: `shared/skills/overview`
- Run id: `2026-06-04-sqa-fresh-baseline-001`
- Run mode: `without_skill`
- Source boundary: repository custom team-use readiness
- Constraint honored: did not read or use `shared/skills/skill-quality-audit/SKILL.md`, its `references`, `contracts`, `scripts`, `evals`, `tests`, or validator methodology.
- Evidence inspected: target `SKILL.md`, target `references/`, target `projections/`, target `scripts/`, target `agents/openai.yaml`, target `test-prompts.json`, plus the shared script helper used by target scripts.
- Fresh checks run:
  - `bash shared/skills/overview/scripts/project-detect.sh /Users/lijieli/org-claude-skills` returned JSON with `project_type`, `language`, `framework`, `entry_files`, `config_files`.
  - `bash shared/skills/overview/scripts/dir-tree.sh /Users/lijieli/org-claude-skills 2` exited `1` with no tree output in this workspace where `tree` is not installed.
  - `jq . shared/skills/overview/test-prompts.json` passed.

## Readiness Checks

| Check | Result | Reason |
| --- | --- | --- |
| Scenario Capability | PARTIAL | The skill defines a clear project-overview workflow and completion boundary, but the required directory-tree proof command can fail in a normal environment without `tree`, blocking Step 1. |
| Structure-Content Coherence | PARTIAL | The skill is generally organized, but it has duplicated output requirements, one mis-nested output bullet, and minor mismatch between "max 8 agents" and "merge 8 agent results." |
| Evidence Integrity | PARTIAL | It strongly requires code scanning, key-file evidence, and user confirmation, but the evidence pipeline is weakened by the broken `dir-tree.sh` fallback and by the template lacking a durable evidence/proof section. |
| Repairable Handoff | PARTIAL | Step contracts and failure states make recovery possible, but incomplete proof-location guidance means another agent may inherit a generated overview without the scan outputs, mode choice, or confirmation record. |
| Attention Economy | PASS | Main skill is short enough to scan, supporting files are small, and heavy details are mostly pushed to references/scripts. Duplication exists but is not large enough to make the skill unusable. |

Anchor score: 1/5 PASS, pass rate 0.2.

## Core Findings

### 1. Required `dir-tree.sh` proof command is not reliable when `tree` is absent

Evidence:

- `shared/skills/overview/SKILL.md:51` requires `bash {{SKILLS_HOME}}/overview/scripts/dir-tree.sh <项目路径> 3` during project scan.
- `shared/skills/overview/SKILL.md:100` repeats that fresh execution of `dir-tree.sh` must succeed before completion.
- `shared/skills/overview/scripts/dir-tree.sh:16-27` falls back to `eval find "$PROJECT_DIR" -maxdepth "$DEPTH" -type d $EXCLUDES ...` when `tree` is unavailable.
- In the current workspace, `command -v tree` returned `no-tree`.
- Fresh run of `bash shared/skills/overview/scripts/dir-tree.sh /Users/lijieli/org-claude-skills 2` exited `1` with no usable output.
- `bash -x` showed unquoted exclude globs expanding to real workspace paths such as `tests/__pycache__/...` and `.git/...`, corrupting the `find` expression before it reaches `awk`.

Judgment: This is the main readiness blocker. The skill's own hard gate depends on a command that can silently fail under a common dependency condition. Because the script suppresses `find` stderr with `2>/dev/null`, the agent/user gets an empty failure path rather than an actionable directory tree or clear error.

Recommendation:

- Replace string-built `EXCLUDES` plus `eval` with a safe `find` expression built from an array, or quote each `-path` pattern so shell glob expansion cannot occur.
- Remove stderr suppression until the script can report structured failures.
- Add a regression test for the fallback path when `tree` is not installed and ignored directories exist.

### 2. Auto project snapshot can contradict the selected project path

Evidence:

- `shared/skills/overview/SKILL.md:27-36` embeds shell snapshot commands using `find .`, feature-file probes in the current directory, and README head reads from the current directory.
- `shared/skills/overview/SKILL.md:40-43` says project path should come from the user argument or current working directory after explicit path handling.
- `shared/skills/overview/SKILL.md:51` says the real scan should run through the target scripts with `<项目路径>`.

Judgment: The shell snapshot section can collect facts from the process CWD before the skill has confirmed the requested project path. If the user passes a different path, this creates misleading early evidence and may bias mode selection.

Recommendation:

- Remove the auto snapshot block or convert it into instructions that run only after the project path is resolved.
- Make target scripts the single source of initial scan facts.

### 3. Proof evidence is required, but the output artifact has no durable evidence section

Evidence:

- `shared/skills/overview/SKILL.md:49` requires each step to form output with `consumer`, `acceptance`, `failure_state`, and `proof`.
- `shared/skills/overview/SKILL.md:64-69` defines proof expectations for scan output, mode choice, key file refs, document path, grep check, and user confirmation.
- `shared/skills/overview/SKILL.md:107` requires proof evidence to be recorded.
- `shared/skills/overview/projections/project-overview-template.md:1-42` includes product perspective, architecture diagram, module table, onboarding path, tech stack, and structure tree, but no explicit evidence/proof log or unresolved-gaps section.

Judgment: Evidence expectations are strong in the process text, but the generated `docs/项目概览.md` template does not preserve the evidence. That makes later review and handoff weaker, especially because user confirmation is a hard completion condition.

Recommendation:

- Add a concise `## 验证证据` section to the template with scan commands, mode confirmation, key file refs, Mermaid grep result, and user confirmation/feedback sync status.
- Add `## 未覆盖缺口` for auxiliary agent failures or unknown project areas.

### 4. Structure is mostly coherent but has avoidable drift

Evidence:

- `shared/skills/overview/SKILL.md:56-62` and `shared/skills/overview/SKILL.md:91-96` duplicate the output requirements.
- `shared/skills/overview/SKILL.md:61` appears indented under "新手入门指南" even though "技术栈速查表 + 项目结构树" is a top-level output requirement.
- `shared/skills/overview/SKILL.md:54-55` says "最多启用 8 个 agent" but also says the main agent merges "8 个 agent" results; `references/agent-assignments.md:5` also says max 8, not always 8.

Judgment: None of these are catastrophic alone, but they increase instruction ambiguity and make compliance harder to judge.

Recommendation:

- Keep one canonical output list and point the other section to it.
- Fix the indentation at line 61.
- Say "合并已启用 agent 的返回结果" instead of "合并 8 个 agent 的返回结果."

### 5. Existing strengths worth preserving

Evidence:

- `shared/skills/overview/SKILL.md:13-21` has a concrete goal, completion boundary, and hard gates.
- `shared/skills/overview/SKILL.md:38-45` gives explicit path and blockage handling.
- `shared/skills/overview/references/mode-selection.md:3-28` clearly forces user-confirmed mode selection and forbids default auto-continue.
- `shared/skills/overview/references/agent-assignments.md:3-38` gives bounded agent roles, return formats, conflict handling, and failure handling.
- `shared/skills/overview/test-prompts.json` is valid JSON and covers three realistic trigger shapes.

Judgment: The skill has the right authoring instincts: scan before summarizing, cite key files, force mode confirmation, and define blocked states. The readiness gap is mostly implementation reliability and durable proof capture, not lack of scenario understanding.

## Suggested Repair Order

1. Fix `dir-tree.sh` fallback and add a regression check for no-`tree` environments.
2. Move or remove the auto project snapshot so all initial facts come from the resolved project path.
3. Add durable evidence and gap sections to `project-overview-template.md`.
4. Deduplicate output requirements and fix the agent-count wording.
5. Re-run the three target test prompts after repair and compare whether outputs preserve scan evidence, mode choice, generated doc path, and user confirmation status.

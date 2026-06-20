---
name: skill-pull
user-invocable: true
description: "外部 Skill 拉取与安装编排。Use when 检查或更新 Anthropic/Vercel/Superpowers/skills.sh 来源、adapter-bearing 来源的 Codex adapters 或运行时安装结果。"
disable-model-invocation: true
---

# Skill Pull

Use this skill for the daily automated update flow that keeps external runtime skills current and proves the local Claude Code and Codex runtimes can use them after installation.

## HARD-GATE

- Stop when `community/SOURCES.yaml` is missing or fails source-lock validation.
- Stop when an upstream candidate is blocked, ambiguous, or lacks a stable ref.
- Stop after any validation or install failure; preserve the generated worktree and branch for diagnosis.
- Do not run the final install command until every validation command and the quick install gate passes.
- Do not delete failed worktrees, logs, branches, or generated diffs before reporting the blocker.

## Goal

Goal: pull managed external Skill sources and prove the local Claude Code and Codex runtime exposure still works after installation. Completion boundary: source lock, vendored content, adapter-bearing source outputs, validation results, update-worktree install, merge to `main`, local `main` install, cleaned successful worktree/branch, and commit are all reported with evidence.

## Managed Sources

Read `community/SOURCES.yaml` as the source lock. The default managed runtime sources are:

- `anthropic_skills`
- `superpowers`
- `vercel_skills`
- `vercel_agent_browser`
- `alchaincyf_darwin_skill`
- `nextlevelbuilder_ui_ux_pro_max`
- `panniantong_agent_reach`
- `skills_sh_alirezarezvani_code_to_prd`
- `skills_sh_baoyu_markdown_to_html`
- `skills_sh_bb_browser`
- `skills_sh_github_prd`
- `skills_sh_github_prompt_optimizer`
- `skills_sh_graphify`
- `skills_sh_humanizer_zh`
- `skills_sh_mattpocock_to_prd`
- `skills_sh_notebooklm`
- `skills_sh_othmanadi_planning_with_files`
- `skills_sh_self_improving_agent`
- `skills_sh_softaworks_mermaid_diagrams`

## Workflow

流程表：

| Step | Input | Action | Output | Consumer | Acceptance | Failure state | Proof |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1. Candidate check | `community/SOURCES.yaml` | Run `scripts/check_candidates.py` | Candidate list or current-state result | skill-pull | Each source has current/candidate/blocker state | Stop on blocked or ambiguous candidate | command output |
| 2. Update worktree | Candidate list | Run `scripts/run_update.py` | `.worktrees/` worktree, update branch, changed source lock | validations | Worktree exists and source lock changed only for accepted candidates | Preserve worktree and branch | branch path and diff |
| 3. Source sync | Update worktree | Execute source-specific sync scripts | Vendored content and adapter-bearing source outputs | validations and install | Generated files match source lock | Preserve generated files and logs | git diff and sync logs |
| 4. Validation | Updated worktree | Run required validation commands | Validation result set | install gate | Every command passes | Stop before install | command outputs |
| 5. Quick install gate | Validated worktree | Run `bash install.sh --target all --check quick` | Quick install result | final install gate | check command passes | Stop before final install | command output |
| 6. Final install and commit | Passed quick install gate | Run `bash install.sh --target all`, commit branch | Installed runtime, branch, commit | merge | install and commit both pass | Preserve worktree/branch and report blocker | install output and commit hash |
| 7. Merge, release, local install | Commit branch | Fast-forward merge to `main`, run local install from `main`, remove successful worktree and branch | Updated `main`, local runtime install, no successful temporary worktree | user | merge, local install, cleanup all pass | Preserve worktree/branch and report blocker | merge output, install output, worktree list |
| 8. Report | Main commit, validations, install results | Run `scripts/summarize_changes.py` | Conversation report | user | report includes source updates, validation, install, local install, main commit | Report failed phase and next action | report sections |

## Worktree Policy

Use branch names like `codex/skill-pull-YYYYMMDD`, with a numeric suffix when the branch already exists. A success fast-forwards `main`, runs local install from merged `main`, removes the successful worktree, and deletes the temporary branch. A failure preserves the worktree and branch so the exact diff, generated files, logs, and failing state remain available for diagnosis.

## Validation Gates

The skill-pull workflow must not silently skip failed steps. These commands are required before the final install command:

```bash
python3 tools/community/source_lock_check.py
bash tests/test-community-tools.sh
python3 tools/community/check_superpowers_upstream_fidelity.py
bash tests/test-single-source-layout.sh
bash tests/test-codex-skill-adapter.sh
bash install.sh --target all --check quick
```

`bash install.sh --target all --check quick` proves the real Claude and Codex runtime exposure without running the full repository regression suite. Do not run `bash tests/test-install-runtime-smoke.sh` or the full gate plan separately in daily skill-pull; the source-specific validation commands above cover the external-source risks, and the quick install gate keeps runtime exposure fast enough to run every update.

Only after those pass may skill-pull run:

```bash
bash install.sh --target all
```

## Conversation Report

## Output Contract

Output format: conversation report plus committed update branch.
Consumer: user, runtime installer, and future source-lock audits.
Validation: each report section must cite command output, branch path, commit hash, or preserved blocker evidence.

Successful runs report these sections:

## Source updates
List each source as `current_ref -> candidate_ref`.

## Upstream changes
Summarize release tags, default branch refs, or notable upstream notes available from candidate lookup.

## Runtime exposure changes
State whether install exposure behavior changed. Only adapter-bearing sources may refresh Codex adapters; Superpowers must remain plain official `SKILL.md` files.

## Validation results
List each validation command and its pass result.

## Install result
Report both `bash install.sh --target all` results: the update-worktree install before commit and the local install from merged `main`.

## Branch and commit
Report the update branch name and final commit hash on `main`.

Blocked runs report the failed phase, failed command, preserved worktree path, return code, duration, stdout/stderr evidence, and next action.

## Completion Check

- [ ] Command evidence recorded for candidate check, validation, quick install gate, update-worktree install, merge, local main install, cleanup, and summary.
- [ ] Successful run reports source updates, upstream changes, runtime exposure changes, validation results, install result, local install result, branch, and commit.
- [ ] Blocked run reports failed phase, failed command, preserved worktree path, return code, duration, stdout/stderr evidence, and next action.
- [ ] No failed validation or install step was bypassed.

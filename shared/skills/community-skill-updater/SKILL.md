---
name: community-skill-updater
description: 外部 community Skill 更新与安装编排。Use when 检查或更新 Anthropic/Vercel/Superpowers/persona 来源、Codex adapters 或运行时安装结果。
disable-model-invocation: true
---

# Community Skill Updater

Use this skill for the daily automated update flow that keeps external runtime skills current and proves the local Claude Code and Codex runtimes can use them after installation.

## HARD-GATE

- Stop when `community/SOURCES.yaml` is missing or fails source-lock validation.
- Stop when an upstream candidate is blocked, ambiguous, or lacks a stable ref.
- Stop after any validation or install failure; preserve the generated worktree and branch for diagnosis.
- Do not run the real install until every validation command and full dry-run install passes.
- Do not delete failed worktrees, logs, or generated diffs before reporting the blocker.

## Goal

Goal: update managed external community Skill sources and prove the local Claude Code and Codex runtime exposure still works after installation. Completion boundary: source lock, vendored content, adapters, validation results, install result, branch, and commit are all reported with evidence.

## Managed Sources

Read `community/SOURCES.yaml` as the source lock. The default managed runtime sources are:

- `anthropic_skills`
- `superpowers`
- `vercel_skills`
- `vercel_agent_browser`
- `alchaincyf_darwin_skill`
- `nextlevelbuilder_ui_ux_pro_max`

OpenSpec is excluded from daily updates. Keep it in source-lock validation only because this repository treats OpenSpec as historical concept and artifact context, not runtime skill content.

## Workflow

流程表：

| Step | Input | Action | Output | Consumer | Acceptance | Failure state | Proof |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1. Candidate check | `community/SOURCES.yaml` | Run `scripts/check_candidates.py` | Candidate list or current-state result | updater | Each source has current/candidate/blocker state | Stop on blocked or ambiguous candidate | command output |
| 2. Update worktree | Candidate list | Run `scripts/run_update.py` | `.worktrees/` worktree, update branch, changed source lock | validations | Worktree exists and source lock changed only for accepted candidates | Preserve worktree and branch | branch path and diff |
| 3. Source sync | Update worktree | Execute source-specific sync scripts | Vendored content and Codex adapters | validations and install | Generated files match source lock | Preserve generated files and logs | git diff and sync logs |
| 4. Validation | Updated worktree | Run required validation commands | Validation result set | install gate | Every command passes | Stop before install | command outputs |
| 5. Dry-run install | Validated worktree | Run `bash install.sh --target all --check full` | Full check result | real install gate | check command passes | Stop before real install | command output |
| 6. Install and commit | Passed dry-run | Run `bash install.sh --target all`, commit branch | Installed runtime, branch, commit | user | install and commit both pass | Preserve worktree/branch and report blocker | install output and commit hash |
| 7. Report | Branch, commit, validations | Run `scripts/summarize_changes.py` | Conversation report | user | report includes source updates, validation, install, branch | Report failed phase and next action | report sections |

## Worktree Policy

Use branch names like `codex/community-skill-update-YYYYMMDD`, with a numeric suffix when the branch already exists. A success removes the worktree and keeps the branch and commit. A failure preserves the worktree and branch so the exact diff, generated files, logs, and failing state remain available for diagnosis.

## Validation Gates

The updater must not silently skip failed steps. These commands are required before the real install:

```bash
python3 tools/community/source_lock_check.py
bash tests/test-community-tools.sh
python3 tools/community/check_superpowers_upstream_fidelity.py
bash tests/test-single-source-layout.sh
bash tests/test-codex-skill-adapter.sh
bash tests/test-install-runtime-smoke.sh
bash install.sh --target all --check full
```

Only after those pass may the updater run:

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

## Local adapter changes
State whether Codex adapters or install exposure behavior changed.

## Validation results
List each validation command and its pass result.

## Install result
Report the `bash install.sh --target all` result.

## Branch and commit
Report the update branch and commit hash.

Blocked runs report the failed phase, failed command, preserved worktree path, evidence, and next action.

## Completion Check

- [ ] Command evidence recorded for candidate check, validation, dry-run install, real install, and summary.
- [ ] Successful run reports source updates, upstream changes, adapter changes, validation results, install result, branch, and commit.
- [ ] Blocked run reports failed phase, failed command, preserved worktree path, evidence, and next action.
- [ ] No failed validation or install step was bypassed.

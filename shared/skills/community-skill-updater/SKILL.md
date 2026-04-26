---
name: community-skill-updater
description: 外部 community Skill 更新与安装编排。Use when 检查或更新 Anthropic/Vercel/Superpowers/persona 来源、Codex adapters 或运行时安装结果。
disable-model-invocation: true
---

# Community Skill Updater

Use this skill for the daily automated update flow that keeps external runtime skills current and proves the local Claude Code and Codex runtimes can use them after installation.

## Managed Sources

Read `community/SOURCES.yaml` as the source lock. The default managed runtime sources are:

- `anthropic_skills`
- `superpowers`
- `vercel_skills`
- `vercel_agent_browser`
- `alchaincyf_darwin_skill`
- `nextlevelbuilder_ui_ux_pro_max`

OpenSpec is excluded from daily updates. Keep it in source-lock validation only because this repository treats OpenSpec as historical concept and artifact context, not runtime skill content.

## Execution Flow

1. Run `scripts/check_candidates.py` to compare managed source refs with latest stable upstream candidates.
2. If every managed source is current, report the checked sources and stop without leaving a branch or worktree.
3. If any source is blocked, stop and report the blocker.
4. Run `scripts/run_update.py` to create an isolated `.worktrees/` worktree and update `community/SOURCES.yaml`.
5. Let existing source-specific scripts sync vendored content and Codex adapters.
6. Run repository validations before installing into the user runtime.
7. Run `bash install.sh --target all --check full`.
8. Run `bash install.sh --target all`.
9. Commit the update branch after validation and install pass.
10. Use `scripts/summarize_changes.py` to report the result in the conversation.

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

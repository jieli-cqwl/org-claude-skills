# Community Skill Updater Design

## Problem Statement

`org-claude-skills` vendors external skills under `community/` from upstream sources such as Anthropic, Superpowers, Vercel, Alchaincyf, and NextLevelBuilder. Those upstream projects continue to iterate, while this repository also maintains local Codex adapters, install-time exposure rules, and Superpowers overlay behavior.

Today, the version actually downloaded by sync scripts is controlled by `community/SOURCES.yaml`, and installation later copies the vendored repository content into Claude Code and Codex runtime directories. This creates a recurring maintenance need: update external skill content to the newest stable upstream version, keep local adapters correct, prove installation still works, and tell the team what changed. Doing this manually is error-prone because source locks, generated adapters, tests, worktree cleanup, and local runtime installation must stay in sync.

## Goals And Success Criteria

The new `community-skill-updater` skill enables a daily automated update flow for external runtime skill sources. A successful run checks upstream candidates, updates managed source locks when newer stable refs exist, syncs vendored content, refreshes local Codex adapters through existing sync scripts, validates repository contracts, installs the result into local Claude Code and Codex runtimes, commits the update on an isolated branch, releases the worktree, and reports the result in the conversation.

The run is successful only when the following outcomes are all true: managed source candidates were checked; `community/SOURCES.yaml` was updated when needed; vendored skill directories and Codex adapters match the selected refs; source lock, community tool, layout, Codex adapter, install smoke, and install check validations passed; `bash install.sh --target all` completed; an update branch contains the commit when files changed; successful worktrees were removed; and the conversation includes source ref changes, upstream change summary, local adapter summary, validation evidence, install result, branch, and commit hash.

If no managed source has an update, the skill reports the checked sources and current refs without creating a lasting branch or worktree. If any required step fails, the run is blocked, the failed worktree is preserved, and the conversation reports the failed phase, command, path, and recommended next action.

## Approach

Create a first-party skill at `shared/skills/community-skill-updater/`. The skill is a workflow entrypoint plus a small deterministic script layer. `SKILL.md` explains when to use the skill, the default source scope, how to handle automation, which failures block, and how to report results. Scripts perform repeatable operations that must not depend on model improvisation.

The default managed sources are `anthropic_skills`, `superpowers`, `vercel_skills`, `vercel_agent_browser`, `alchaincyf_darwin_skill`, and `nextlevelbuilder_ui_ux_pro_max`. `openspec` remains in source lock validation but is excluded from daily updates because this repository treats it as historical concept and artifact context, not as runtime skill content.

Candidate selection follows the repository goal of latest stable. For GitHub sources, the updater first queries the latest non-prerelease release through the GitHub releases API and uses the release target commit or tag commit as the candidate. If a repository has no release, the updater uses `git ls-remote --symref` and `git ls-remote` to resolve the default branch head commit. The selected candidate is compared with the locked `ref` in `community/SOURCES.yaml`.

The update runs in an isolated git worktree under the existing `.worktrees/` convention. Branch names use `codex/community-skill-update-YYYYMMDD`, with a suffix added on conflict. The updater modifies source lock refs and `captured_at` dates only for managed sources that are being updated. Existing sync scripts remain the source of truth for vendoring and adapter generation:

- `tools/community/sync_anthropic_skills_from_upstream.py`
- `tools/community/sync_vercel_skills_from_upstream.py`
- `tools/community/sync_alchaincyf_skills_from_upstream.py`
- `tools/community/sync_nextlevelbuilder_skills_from_upstream.py`
- `tools/community/sync_canonical_from_upstream.py` for the Superpowers overlay path

After synchronization, the updater runs the nearest validations for source locks, community tooling, source layout, Codex adapters, install smoke, and full install check. The real local install runs only after repository validations pass. This order prevents unvalidated upstream content from being installed into the user runtime.

On success, the updater commits the worktree branch and removes the worktree. It does not push or open a pull request by default. On failure, it leaves the worktree and branch intact so the exact diff, generated files, logs, and failed state are available for diagnosis.

Daily scheduling is not part of the skill source. A Codex Desktop thread heartbeat automation can wake the current conversation and invoke the skill. That automation is user-level runtime configuration, not repository state.

## Components

`SKILL.md` is the human-readable and model-readable workflow contract. It describes trigger phrases, managed sources, OpenSpec exclusion, worktree policy, validation order, blocking behavior, and final response shape.

`scripts/check_candidates.py` reads `community/SOURCES.yaml`, inspects upstream repositories, selects candidate refs, and emits structured JSON describing current refs, candidates, source status, and blockers.

`scripts/run_update.py` is the main orchestrator. It verifies prerequisites, creates the isolated worktree, applies candidate refs, calls existing sync scripts, runs validations, performs real installation, creates the commit, and cleans up successful worktrees.

`scripts/summarize_changes.py` converts structured candidate data, git diff information, validation results, and install results into a concise conversation summary. It does not create a persistent Markdown report.

The scripts share small helper functions where that reduces duplication, especially for source lock loading, command execution with captured output, branch naming, and result JSON writing.

## Alternatives Considered

A pure process skill was considered. It would only document steps in `SKILL.md` and let the model perform each update directly. This is too fragile for a daily workflow because ref selection, lock edits, worktree cleanup, and validation result capture need deterministic behavior.

A full automation platform was also considered. It would add persistent reports, history tracking, PR creation, and notifications. This is heavier than the current need. The team only needs the update result in the conversation, while repository history already records committed file changes.

The chosen design uses a workflow skill plus focused scripts. It keeps the model responsible for judgment and communication, while scripts handle repeatable repository operations.

## Change Scope

The implementation scope is limited to adding `shared/skills/community-skill-updater/`, its bundled scripts, tests for the new script behavior, and minimal installation or runtime metadata updates needed to expose the first-party skill. Existing `tools/community/sync_*` scripts remain the vendoring source of truth and are changed only if a test proves they cannot support the updater contract.

The default source scope excludes `openspec`. The updater does not write long-lived daily reports, does not push branches, does not open pull requests, and does not merge update branches. It also does not change the rule that `community/SOURCES.yaml` is the version lock source.

## Invariants

`community/SOURCES.yaml` remains the authoritative source lock for external sources. Existing vendored upstream skill bodies remain upstream-owned unless the current repository already declares an overlay or generated adapter boundary.

Local Codex adapters are generated through the existing source-specific sync scripts. Superpowers runtime overlays must continue to respect `contracts/superpowers-boundary.yaml`; overlay anchor failures are blockers, not situations for automatic guessing.

Successful updates must be isolated from the user's current working tree. A successful run removes its worktree after committing. A failed run preserves its worktree and branch for diagnosis. The updater must not silently skip a failed source, test, or install step.

Runtime installation is part of completion. Repository tests passing without a real `bash install.sh --target all` does not satisfy the skill goal because the downstream consumers are Claude Code and Codex.

## Downstream Impact

Claude Code and Codex are the primary downstream consumers. After a successful update and install, their local runtime skill directories, adapters, hooks, and configuration reflect the updated repository state according to `install.sh`.

Team members consuming update results get a conversation summary instead of a repository report. The summary explains which external sources changed, what upstream changed, what local adapters or exposure behavior changed, which validations passed, and where the update commit lives.

Future maintainers get a narrow first-party skill that delegates to existing source sync scripts rather than creating a second vendoring implementation.

## Risks

Upstream repositories may not have reliable release discipline. The candidate rule mitigates this by preferring releases or stable tags, but default-branch fallback can still bring behavior changes. Validation and installation gates are therefore mandatory.

External skill sets can add, remove, or rename skills. That can invalidate adapter metadata maps or install exposure rules. The updater blocks rather than inventing adapter metadata.

Superpowers overlays can drift when upstream text changes. Overlay anchor misses must block because guessing could corrupt the local small-chain runtime.

Real installation changes the user's local Claude Code and Codex runtime. Running it after repository validation reduces the chance of installing broken content, and a failed install still blocks completion.

Network access, GitHub availability, and local git state can interrupt daily automation. The updater must report these as blockers with evidence rather than treating them as no-update results.

## Candidate Lookup Decision

Candidate lookup uses Python standard-library HTTP calls for GitHub latest release metadata, then uses `git ls-remote` as the fallback and as the source of commit resolution. Tests use local fixtures for source-lock parsing, candidate comparison, branch naming, and failure classification, plus a fake command runner for orchestration paths. Real network calls are covered by the daily runtime flow rather than unit tests, because the final update proof must come from live upstream refs and real repository validation.

# Community Vercel Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Vendor `find-skills` and `agent-browser` into the repo as a new `community/vercel` source and make them installable in Claude/Codex runtimes.

**Architecture:** Reuse the existing community source pipeline: vendored source tree under `community/`, locked upstream refs in `community/SOURCES.yaml`, Codex `openai.yaml` adapters under `community/*/codex/skills`, and staged runtime composition in `install.sh`. Add one sync script so future updates do not require manual copying.

**Tech Stack:** Bash install pipeline, Python sync tooling, shell-based repo tests, vendored Markdown skill assets.

---

### Task 1: Vercel source tree and source lock [T1]

Files:
- Create: `community/vercel/skills/find-skills/**`
- Create: `community/vercel/skills/agent-browser/**`
- Create: `community/vercel/codex/skills/find-skills/agents/openai.yaml`
- Create: `community/vercel/codex/skills/agent-browser/agents/openai.yaml`
- Modify: `community/SOURCES.yaml`

1. [T1] Write failing structure checks in `tests/test-single-source-layout.sh`
2. [T1] Run `bash tests/test-single-source-layout.sh`
   Expected: FAIL because `community/vercel` and the new source lock entries do not exist yet.
3. [T1] Vendor the two upstream skill directories into `community/vercel/skills/` and add matching Codex adapters.
4. [T1] Add `vercel_skills` and `vercel_agent_browser` entries to `community/SOURCES.yaml`.
5. [T1] Re-run `bash tests/test-single-source-layout.sh`
   Expected: PASS for the new community source layout checks.

### Task 2: Install pipeline integration [T2]

Files:
- Modify: `install.sh`
- Modify: `tests/test-install-smoke.sh`
- Modify: `tests/test-runtime-integrity.sh`

1. [T2] Write failing install/runtime assertions for the two Vercel skills.
2. [T2] Run `bash tests/test-install-smoke.sh`
   Expected: FAIL because runtime does not install `find-skills` / `agent-browser` yet.
3. [T2] Update `install.sh` to copy the Vercel source tree and overlay Codex adapters during Claude/Codex staging.
4. [T2] Re-run `bash tests/test-install-smoke.sh`
   Expected: PASS with both skills present in installed Claude/Codex runtimes.
5. [T2] Run `bash tests/test-runtime-integrity.sh`
   Expected: PASS with source lock and runtime integrity still valid after the new source is added.

### Task 3: Sync tooling and community validation [T3]

Files:
- Create: `tools/community/sync_vercel_skills_from_upstream.py`
- Modify: `tools/community/source_lock_check.py`
- Modify: `tests/test-community-tools.sh`

1. [T3] Write failing source-lock/tooling assertions covering the two new Vercel source nodes.
2. [T3] Run `bash tests/test-community-tools.sh`
   Expected: FAIL because `source_lock_check.py` and sync tooling do not know the new Vercel sources yet.
3. [T3] Add `sync_vercel_skills_from_upstream.py` and extend source-lock validation for the new source names/repos.
4. [T3] Re-run `bash tests/test-community-tools.sh`
   Expected: PASS with the new source lock and sync tooling checks.
5. [T3] Run `python3 community/superpowers/skills/verify-change/scripts/check_task_plan_consistency.py ./docs/community-vercel-skills/2026-04-12-vendor-selected-skills/tasks.md ./docs/community-vercel-skills/2026-04-12-vendor-selected-skills/plan.md`
   Expected: PASS.

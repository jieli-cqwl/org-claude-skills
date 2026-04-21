# Tasks - HV Analysis Skill
Created: 2026-04-21
Related plan: ./plan.md

## Acceptance Checklist

- [ ] T1 Add HV Analysis skill contract tests
  - AC: `bash tests/test-hv-analysis-skill-contract.sh` fails before the skill source exists, then checks source frontmatter, manual-only visibility, required references, required scripts, required evals, source policy terms, arxiv routing terms, PDF blocking terms, and valid JSON manifests.
  - Traces: First-party source; Source policy; arxiv routing; PDF rendering; Complete delivery
  - Depends: -
  - Complexity: moderate
- [ ] T2 Create `hv-analysis` skill source, references, and evals
  - AC: `shared/skills/hv-analysis/` contains `SKILL.md`, `agents/openai.yaml`, `references/methodology.md`, `references/source-policy.md`, `references/arxiv-policy.md`, `references/report-template.md`, `scripts/arxiv_search.py`, `scripts/render_report.py`, `scripts/manifest.json`, and `evals/evals.json`; `bash tests/test-hv-analysis-skill-contract.sh` passes while `python3 tests/test-hv-analysis-scripts.py` remains RED until T3 replaces script stubs with real behavior.
  - Traces: First-party source; Manual trigger; Source policy; arxiv routing; Complete delivery
  - Depends: T1
  - Complexity: moderate
- [ ] T3 Add deterministic arxiv and PDF scripts with tests
  - AC: `python3 tests/test-hv-analysis-scripts.py` first fails against T2 script stubs, then proves `arxiv_search.py` builds encoded arxiv API URLs and parses feed fixtures, and proves `render_report.py` creates a real PDF when a renderer is available or exits non-zero with a clear dependency failure without creating fake PDFs.
  - Traces: arxiv routing; PDF rendering; Complete delivery
  - Depends: T2
  - Complexity: moderate
- [ ] T4 Integrate `hv-analysis` into Claude and Codex runtime installation
  - AC: `hv-analysis` is listed as local manual-only; `bash tests/test-single-source-layout.sh`, `bash tests/test-install-smoke.sh`, `bash tests/test-runtime-integrity.sh`, and `bash tests/test-codex-skill-adapter.sh` prove Claude receives the skill, Codex receives the skill, and Codex runtime removes `agents/openai.yaml`.
  - Traces: Manual trigger; Claude and Codex install; Codex manual-only
  - Depends: T2
  - Complexity: moderate
- [ ] T5 Update docs and run final small-chain verification set
  - AC: `README.md` names `hv-analysis` as a first-party manual Skill; `python3 community/superpowers/skills/verify-change/scripts/check_task_plan_consistency.py docs/hv-analysis/2026-04-21-hv-analysis-skill/tasks.md docs/hv-analysis/2026-04-21-hv-analysis-skill/plan.md`, `bash tests/test-hv-analysis-skill-contract.sh`, `python3 tests/test-hv-analysis-scripts.py`, `bash tests/test-single-source-layout.sh`, `bash tests/test-install-smoke.sh`, `bash tests/test-runtime-integrity.sh`, and `bash tests/test-codex-skill-adapter.sh` pass.
  - Traces: First-party source; Manual trigger; Claude and Codex install; Codex manual-only; Source policy; arxiv routing; PDF rendering; Complete delivery
  - Depends: T1,T2,T3,T4
  - Complexity: simple

## Definition of Done

All tasks checked = ready for verify-change.

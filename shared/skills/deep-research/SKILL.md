---
name: deep-research
user-invocable: true
disable-model-invocation: true
description: "Deep Research Skill using 横纵分析法。Use when 用户调用 $deep-research，或要求 Deep Research/深度研究/横纵分析，并产出 Markdown + PDF 报告。"
allowed-tools: Read, Write, Bash, WebSearch, WebFetch
---

# Deep Research

## What This Skill Does

Use this skill only when the user explicitly invokes `$deep-research` or asks for Deep Research / 深度研究 / 横纵分析法 / 横纵分析 / 纵向横向分析 / 历时共时分析 for a deep research report.

It builds a longitudinal plus cross-sectional research report. The required artifacts are `research-report.md`, `research-report.pdf`, `sources.json`, and `run-notes.md`.

## HARD-GATE

- Confirm the research object before deep research. If the object or boundary is unclear, ask one concise clarification question.
- Use primary sources first, secondary sources second, and community sources only with sample bias notes in the source ledger.
- The report must follow the selected longitudinal/cross-sectional method; if the method is adapted or partially skipped, record the reason in run notes.
- Technology concepts, algorithms, research fields, model methods, and paper requests require academic paper routing unless the user explicitly excludes it or a concrete skip reason is recorded; do not add weak paper matches.
- Markdown is the fact source. PDF is derived from Markdown and cannot replace `research-report.md`.
- PDF rendering is required after Markdown is written. If PDF rendering fails, full completion is blocked. Preserve Markdown and report the failure.
- If `sources.json` cannot be written, full completion is blocked.
- Do not modify the existing generic `research` Skill for this task.

## Goal

Goal: produce a longitudinal plus cross-sectional deep research report for a confirmed research object. Completion boundary: `research-report.md`, `research-report.pdf`, `sources.json`, and `run-notes.md` exist in the output directory, with source evidence and render verification.

## Workflow

- Classify the input: research object, report mode, arxiv override, output directory.
- Choose report mode: quick onboarding by default; strict evidence mode when the user says 严肃版, 可审计版, 给团队看, 用于决策, 需要证据链, or equivalent wording.
- Create an output directory under `docs/deep-research--{date}--{slug}/` unless the user provides one.
- Collect sources and write `sources.json`.
- Write the longitudinal analysis, cross-sectional analysis, and intersection synthesis in `research-report.md`.
- Render `research-report.pdf` with `scripts/render_report.py`.
- Finish by reporting artifact paths and verification evidence for all required artifacts.

## Output Contract

Path: `docs/deep-research--{date}--{slug}/`.
Format: Markdown fact source, derived PDF, JSON source ledger, and Markdown run notes.
Consumer: user, future research readers, and source/audit review.
Validation: run `scripts/render_report.py` and verify all four required files exist.

```text
docs/deep-research--{date}--{slug}/
├── research-report.md
├── research-report.pdf
├── sources.json
└── run-notes.md
```

Full completion requires all four files. If any required file is missing, report the blocker and do not claim full completion.

## Reference Loading

- Trigger: report planning and writing; Read: `references/methodology.md`; Expect: report method, object-type adaptation, and quick versus strict mode; Consume: report outline and synthesis; Evidence: report contains longitudinal, cross-sectional, and intersection sections; Sync: methodology changes require updating this route, template, and evals.
- Trigger: evidence collection or source conflict; Read: `references/source-policy.md`; Expect: source priority, citation, conflict, and bias rules; Consume: `sources.json` and report citations; Evidence: source ledger lists source type and bias notes; Sync: source policy changes require updating this route, template, and evals.
- Trigger: academic or technical paper routing; Read: `references/arxiv-policy.md`; Expect: arxiv search and paper inclusion rules; Consume: paper search notes and source ledger; Evidence: included/excluded paper notes; Sync: arxiv policy changes require updating this route, scripts, and evals.
- Trigger: before writing `research-report.md`; Read: `references/report-template.md`; Expect: report section order and required headings; Consume: `research-report.md`; Evidence: Markdown matches template headings; Sync: template changes require updating this route and evals.

## Completion Check

- [ ] Research object and boundary are confirmed.
- [ ] `sources.json` exists and records source type, citation, and bias/conflict notes.
- [ ] `research-report.md` is the fact source and follows the selected method/template.
- [ ] `research-report.pdf` was rendered with `scripts/render_report.py`.
- [ ] `run-notes.md` records mode, commands, blockers, and verification evidence.

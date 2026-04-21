---
name: hv-analysis
user-invocable: true
disable-model-invocation: true
description: 横纵分析法 Deep Research Skill。Use when 用户手动调用 $hv-analysis，或明确要求用横纵分析法、纵向横向分析、历时/共时分析来研究产品、公司、技术概念、人物、事件或文化对象，并产出 Markdown + PDF 深度研究报告。
allowed-tools: Read, Write, Bash, WebSearch, WebFetch
---

# HV Analysis

## What This Skill Does

Use this skill only when the user explicitly invokes `$hv-analysis` or asks to use 横纵分析法 / 横纵分析 / 纵向横向分析 / 历时共时分析 for a deep research report.

It builds a longitudinal plus cross-sectional research report. The required artifacts are `research-report.md`, `research-report.pdf`, `sources.json`, and `run-notes.md`.

## Hard Gates

- Confirm the research object before deep research. If the object or boundary is unclear, ask one concise clarification question.
- Use primary sources first, secondary sources second, and community sources only with sample bias notes. Read `references/source-policy.md` before collecting evidence.
- Read `references/methodology.md` before writing the report.
- Read `references/arxiv-policy.md` when the object is a technology concept, algorithm, research field, model method, or when the user asks for papers.
- Markdown is the fact source. PDF is derived from Markdown and cannot replace `research-report.md`.
- Run `scripts/render_report.py` after Markdown is written. If PDF rendering fails, full completion is blocked. Preserve Markdown and report the failure.
- If `sources.json` cannot be written, full completion is blocked.
- Do not modify the existing generic `research` Skill for this task.

## Workflow

- Classify the input: research object, report mode, arxiv override, output directory.
- Choose report mode: quick onboarding by default; strict evidence mode when the user says 严肃版, 可审计版, 给团队看, 用于决策, 需要证据链, or equivalent wording.
- Create an output directory under `docs/hv-analysis/{date}-{slug}/` unless the user provides one.
- Collect sources and write `sources.json`.
- Write the longitudinal analysis, cross-sectional analysis, and intersection synthesis in `research-report.md`.
- Render `research-report.pdf` with `scripts/render_report.py`.
- Finish by reporting artifact paths and verification evidence for all required artifacts.

## Output Contract

```text
docs/hv-analysis/{date}-{slug}/
├── research-report.md
├── research-report.pdf
├── sources.json
└── run-notes.md
```

Full completion requires all four files. If any required file is missing, report the blocker and do not claim full completion.

## Reference Loading

- Read `references/methodology.md` for the report method, object-type adaptation, and quick versus strict mode.
- Read `references/source-policy.md` before evidence collection and when resolving conflicting sources.
- Read `references/arxiv-policy.md` when academic or technical paper routing applies.
- Read `references/report-template.md` before writing `research-report.md`.

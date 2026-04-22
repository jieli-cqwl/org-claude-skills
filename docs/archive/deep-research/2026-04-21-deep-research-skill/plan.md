# Deep Research Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Build a first-party manual `deep-research` Skill that turns a research object into a longitudinal plus cross-sectional Markdown report, a derived PDF, and traceable source notes.

**Architecture:** `shared/skills/deep-research/` is the source of truth. The Skill keeps routing and hard gates in `SKILL.md`, moves long methodology and evidence rules into `references/`, uses deterministic scripts for arxiv lookup and PDF rendering, and integrates into the existing manual-only install path.

**Tech Stack:** Markdown Skill files, Bash contract tests, Python standard library scripts, optional local PDF renderer detection, existing `install.sh` runtime staging.

---

## File Boundaries

- Create: `tests/test-deep-research-skill-contract.sh`
- Create: `tests/test-deep-research-scripts.py`
- Create: `shared/skills/deep-research/SKILL.md`
- Create: `shared/skills/deep-research/agents/openai.yaml`
- Create: `shared/skills/deep-research/references/methodology.md`
- Create: `shared/skills/deep-research/references/source-policy.md`
- Create: `shared/skills/deep-research/references/arxiv-policy.md`
- Create: `shared/skills/deep-research/references/report-template.md`
- Create: `shared/skills/deep-research/scripts/arxiv_search.py`
- Create: `shared/skills/deep-research/scripts/render_report.py`
- Create: `shared/skills/deep-research/scripts/manifest.json`
- Create: `shared/skills/deep-research/evals/evals.json`
- Modify: `install.sh`
- Modify: `tests/test-single-source-layout.sh`
- Modify: `tests/test-install-runtime-smoke.sh`
- Modify: `tests/test-runtime-integrity.sh`
- Modify: `tests/test-codex-skill-adapter.sh`
- Modify: `README.md`

### Task 1: Contract Tests [T1]

Context: Define the runtime and content contract before creating the Skill. The test must fail while `shared/skills/deep-research/` is absent and later guard manual-only routing, required resources, source policy, arxiv policy, PDF blocking, and JSON validity.

Files:
- Create: `tests/test-deep-research-skill-contract.sh`
- Test: `tests/test-deep-research-skill-contract.sh`

1. [T1] Write the failing contract test

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

skill_dir="$ROOT/shared/skills/deep-research"
skill_file="$skill_dir/SKILL.md"

test -f "$skill_file" || fail "missing deep-research SKILL.md"
grep -Fq 'name: deep-research' "$skill_file" || fail "wrong skill name"
grep -Fq 'user-invocable: true' "$skill_file" || fail "deep-research must be user-invocable"
grep -Fq 'disable-model-invocation: true' "$skill_file" || fail "deep-research must be manual-only"
grep -Fq '横纵分析法' "$skill_file" || fail "skill must name the method"
grep -Fq 'research-report.md' "$skill_file" || fail "skill must declare markdown artifact"
grep -Fq 'research-report.pdf' "$skill_file" || fail "skill must declare pdf artifact"
grep -Fq 'sources.json' "$skill_file" || fail "skill must declare source artifact"
grep -Fq 'full completion is blocked' "$skill_file" || fail "skill must block completion when required artifacts fail"

for ref in methodology.md source-policy.md arxiv-policy.md report-template.md; do
  test -f "$skill_dir/references/$ref" || fail "missing reference: $ref"
done

test -f "$skill_dir/scripts/manifest.json" || fail "missing script manifest"
test -f "$skill_dir/scripts/arxiv_search.py" || fail "missing arxiv script"
test -f "$skill_dir/scripts/render_report.py" || fail "missing pdf renderer script"
test -f "$skill_dir/evals/evals.json" || fail "missing evals"
test -f "$skill_dir/agents/openai.yaml" || fail "missing Codex adapter source"

python3 -m json.tool "$skill_dir/scripts/manifest.json" >/dev/null || fail "manifest must be valid JSON"
python3 -m json.tool "$skill_dir/evals/evals.json" >/dev/null || fail "evals must be valid JSON"

grep -Fq 'Primary sources' "$skill_dir/references/source-policy.md" || fail "source policy must define primary sources"
grep -Fq 'Community sources' "$skill_dir/references/source-policy.md" || fail "source policy must define community sources"
grep -Fq 'sample bias' "$skill_dir/references/source-policy.md" || fail "source policy must mention sample bias"
grep -Fq 'technology concepts' "$skill_dir/references/arxiv-policy.md" || fail "arxiv policy must cover technology concepts"
grep -Fq 'skip arxiv' "$skill_dir/references/arxiv-policy.md" || fail "arxiv policy must cover skip cases"
grep -Fq 'do not add weak matches' "$skill_dir/references/arxiv-policy.md" || fail "arxiv policy must reject weak matches"
grep -Fq 'Markdown is the fact source' "$skill_dir/references/report-template.md" || fail "report template must state markdown fact source"

grep -Fq '"skill_name": "deep-research"' "$skill_dir/evals/evals.json" || fail "evals skill name mismatch"
for eval_id in product-quickstart company-no-arxiv technology-arxiv strict-evidence pdf-render-failure; do
  grep -Fq "\"$eval_id\"" "$skill_dir/evals/evals.json" || fail "missing eval: $eval_id"
done

echo "[PASS] deep-research skill contract"
```

2. [T1] Run the test and verify RED

Run: `bash tests/test-deep-research-skill-contract.sh`

Expected: fails with `missing deep-research SKILL.md`.

3. [T1] Commit the RED test

```bash
git add tests/test-deep-research-skill-contract.sh
git commit -m "test: add deep research skill contract"
```

### Task 2: Skill Source And References [T2]

Context: Create the manual Skill and progressive references. `SKILL.md` should stay focused on when to use the Skill, what it produces, which references to load, and when to stop.

Files:
- Create: `shared/skills/deep-research/SKILL.md`
- Create: `shared/skills/deep-research/agents/openai.yaml`
- Create: `shared/skills/deep-research/references/methodology.md`
- Create: `shared/skills/deep-research/references/source-policy.md`
- Create: `shared/skills/deep-research/references/arxiv-policy.md`
- Create: `shared/skills/deep-research/references/report-template.md`
- Create: `shared/skills/deep-research/scripts/arxiv_search.py`
- Create: `shared/skills/deep-research/scripts/render_report.py`
- Create: `shared/skills/deep-research/scripts/manifest.json`
- Create: `shared/skills/deep-research/evals/evals.json`
- Test: `tests/test-deep-research-skill-contract.sh`

1. [T2] Create the source directories

```bash
mkdir -p \
  shared/skills/deep-research/agents \
  shared/skills/deep-research/references \
  shared/skills/deep-research/scripts \
  shared/skills/deep-research/evals
```

2. [T2] Write `SKILL.md`

```markdown
---
name: deep-research
user-invocable: true
disable-model-invocation: true
description: 横纵分析法 Deep Research Skill。Use when 用户手动调用 $deep-research，或明确要求用横纵分析法、纵向横向分析、历时/共时分析来研究产品、公司、技术概念、人物、事件或文化对象，并产出 Markdown + PDF 深度研究报告。
allowed-tools: Read, Write, Bash, WebSearch, WebFetch
---

# Deep Research

## What This Skill Does

Use this skill only when the user explicitly invokes `$deep-research` or asks to use 横纵分析法 / 横纵分析 / 纵向横向分析 / 历时共时分析 for a deep research report.

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
- Create an output directory under `docs/deep-research/{date}-{slug}/` unless the user provides one.
- Collect sources and write `sources.json`.
- Write the longitudinal analysis, cross-sectional analysis, and intersection synthesis in `research-report.md`.
- Render `research-report.pdf` with `scripts/render_report.py`.
- Finish by reporting artifact paths and verification evidence for all required artifacts.

## Output Contract

```text
docs/deep-research/{date}-{slug}/
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
```

3. [T2] Write `references/methodology.md`

```markdown
# Methodology

## Core Method

横纵分析法 uses two axes:

- Vertical analysis follows time. Reconstruct origin, first release or founding, major turning points, decision logic, constraints, crises, and causal history.
- Horizontal analysis freezes the current moment. Compare direct competitors, adjacent alternatives, previous-generation substitutes, and ecosystem position.
- Intersection synthesis combines both axes. Explain how historical choices created today's advantages, how past constraints became current liabilities, and which future paths are most plausible.

## Object-Type Adaptation

Product reports emphasize releases, positioning, user workflows, pricing, ecosystem, and competitors.
Company reports emphasize founding, financing, business model, leadership, strategy, market position, and comparable organizations.
Technology concept reports emphasize research lineage, core mechanism, technical variants, adoption, limitations, and competing approaches.
Person reports emphasize career trajectory, major decisions, contemporaries, institutional context, and influence.
Event reports emphasize causes, timeline, actors, turning points, comparable events, and consequences.
Game or cultural object reports emphasize production history, genre lineage, audience, mechanics, cultural context, and comparable works.

## Report Modes

Quick onboarding mode prioritizes readability, story arc, and a usable cognitive map.

Strict evidence mode adds source coverage notes, conflict table, confidence labels, strongest opposing evidence, invalidation conditions, and open verification questions.

## Writing Rules

Write the vertical section as narrative, not a dry timeline.
Write the horizontal section as analysis, using tables only to support comparison.
The intersection section must add new judgment rather than summarize previous sections.
```

4. [T2] Write `references/source-policy.md`

```markdown
# Source Policy

## Source Tiers

Primary sources include official docs, release notes, source repositories, papers, standards, company announcements, filings, direct interviews, and direct statements. Use these for factual claims whenever available.

Secondary sources include media reports, analyst notes, books, high-quality blogs, and conference coverage. Use these for context and interpretation, not to override primary sources.

Community sources include forums, GitHub issues, social posts, reviews, comments, Discord or Slack excerpts provided by the user, and informal user reports. Use these for sentiment and workflow evidence with explicit sample bias notes.

## Evidence Records

Each source in `sources.json` must include:

- `title`
- `url`
- `tier`
- `published_or_accessed`
- `claims_supported`
- `limitations`

## Conflict Handling

When sources conflict, record the conflicting claims, dates, and current judgment. Strict mode must include strongest opposing evidence and invalidation conditions.

## Sample Bias

User sentiment and community reports are not representative by default. Label sample bias and avoid turning anecdotes into hard conclusions.
```

5. [T2] Write `references/arxiv-policy.md`

```markdown
# arxiv Policy

## When To Query

Query arxiv for technology concepts, algorithms, research fields, model methods, academic terms, and any request that asks for papers, academic background, or research progress.

Skip arxiv for companies, products, people, games, business events, and geopolitical events unless the user explicitly asks for papers.

## Relevance Rules

Prefer papers whose title, abstract, and category directly match the research object.
Do not add weak matches for volume.
If no strong match exists, record that no strong arxiv evidence was found.

## Script Use

Use `scripts/arxiv_search.py --query "<query>" --max-results 5`.
The script must use timeouts and output JSON.
If a required arxiv query fails, full completion is blocked until fixed or the user changes scope.
```

6. [T2] Write `references/report-template.md`

```markdown
# Report Template

Markdown is the fact source. PDF is a generated reading artifact.

## Quick Mode Structure

# [Research Object] 横纵分析报告

## Executive Summary
## Research Scope
## Vertical Analysis
## Horizontal Analysis
## Intersection Synthesis
## Sources And Notes
## Unverified Or Conflicting Information

## Strict Mode Additions

Add these sections:

## Evidence Coverage
## Source Conflict Table
## Confidence Labels
## Strongest Opposing Evidence
## Invalidation Conditions
## Open Verification Questions
```

7. [T2] Write `scripts/manifest.json`

```json
{
  "scripts": {
    "arxiv_search.py": {
      "purpose": "Query arxiv API and return structured JSON for relevant papers.",
      "network": true,
      "timeout_seconds": 20,
      "inputs": ["query", "max-results"],
      "outputs": ["JSON list of paper metadata"],
      "failure_state": "Full completion is blocked when arxiv lookup is required and this script fails."
    },
    "render_report.py": {
      "purpose": "Render research-report.md into research-report.pdf without modifying the Markdown fact source.",
      "network": false,
      "timeout_seconds": 30,
      "inputs": ["markdown path", "pdf path"],
      "outputs": ["real PDF file"],
      "failure_state": "Full completion is blocked when PDF rendering fails."
    }
  }
}
```

8. [T2] Write script stubs

`shared/skills/deep-research/scripts/arxiv_search.py`:

```python
#!/usr/bin/env python3
"""Temporary arxiv_search entry point replaced by Task 3."""
from __future__ import annotations

import sys


def main() -> int:
    print("arxiv_search.py behavior is unavailable until Task 3", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
```

`shared/skills/deep-research/scripts/render_report.py`:

```python
#!/usr/bin/env python3
"""Temporary render_report entry point replaced by Task 3."""
from __future__ import annotations

import sys


def main() -> int:
    print("render_report.py behavior is unavailable until Task 3", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
```

9. [T2] Write `evals/evals.json`

```json
{
  "skill_name": "deep-research",
  "evals": [
    {
      "id": "product-quickstart",
      "prompt": "$deep-research 帮我研究 Claude Code，默认快速入门版。",
      "expected_output": "Creates a longitudinal product history, cross-sectional comparison, intersection synthesis, sources.json, markdown report, and PDF report.",
      "files": []
    },
    {
      "id": "company-no-arxiv",
      "prompt": "$deep-research 帮我研究 Anthropic，默认模式，不要把论文塞进报告。",
      "expected_output": "Treats Anthropic as a company, skips arxiv by default, prioritizes primary company and filing-style sources where available.",
      "files": []
    },
    {
      "id": "technology-arxiv",
      "prompt": "$deep-research 研究 RAG 的技术脉络和同期路线。",
      "expected_output": "Treats RAG as a technology concept and uses arxiv routing for paper evidence.",
      "files": []
    },
    {
      "id": "strict-evidence",
      "prompt": "$deep-research 用严肃可审计版研究 MCP 协议，给团队做决策参考。",
      "expected_output": "Adds evidence coverage, conflict table, confidence labels, opposing evidence, invalidation conditions, and open questions.",
      "files": []
    },
    {
      "id": "pdf-render-failure",
      "prompt": "$deep-research 研究一个技术概念，但 PDF 渲染依赖缺失。",
      "expected_output": "Preserves markdown and sources, reports PDF blocker, and does not claim full completion.",
      "files": []
    }
  ]
}
```

10. [T2] Write `agents/openai.yaml`

```yaml
interface:
  display_name: "Deep Research"
  short_description: "Research with longitudinal and cross-sectional analysis"
  default_prompt: "Use $deep-research to research the requested object with longitudinal and cross-sectional analysis, then create Markdown and PDF artifacts."
policy:
  allow_implicit_invocation: false
```

11. [T2] Run the contract test

Run: `bash tests/test-deep-research-skill-contract.sh`

Expected: PASS.

12. [T2] Run the script tests and keep RED for T3

Run: `python3 tests/test-deep-research-scripts.py`

Expected: FAIL because `build_query_url` and `parse_feed` are absent from the arxiv script stub.

13. [T2] Commit the Skill source

```bash
git add shared/skills/deep-research tests/test-deep-research-skill-contract.sh
git commit -m "feat: add deep research skill source"
```

### Task 3: Deterministic Scripts [T3]

Context: Add scripts that can be tested without live external writes. `arxiv_search.py` may access the arxiv API when used by the Skill, but tests use fixtures. `render_report.py` must create a real PDF when a renderer is present and fail clearly when no renderer is available.

Files:
- Create: `shared/skills/deep-research/scripts/arxiv_search.py`
- Create: `shared/skills/deep-research/scripts/render_report.py`
- Create: `tests/test-deep-research-scripts.py`
- Test: `tests/test-deep-research-scripts.py`
- Test: `tests/test-deep-research-skill-contract.sh`

1. [T3] Write script tests

```python
#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARXIV_SCRIPT = ROOT / "shared/skills/deep-research/scripts/arxiv_search.py"
RENDER_SCRIPT = ROOT / "shared/skills/deep-research/scripts/render_report.py"


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


class ArxivSearchTests(unittest.TestCase):
    def test_build_query_url_encodes_query_and_limit(self):
        module = load_module(ARXIV_SCRIPT, "arxiv_search")
        url = module.build_query_url("retrieval augmented generation", 7)
        self.assertIn("search_query=all%3Aretrieval%20augmented%20generation", url)
        self.assertIn("max_results=7", url)

    def test_parse_feed_returns_structured_papers(self):
        module = load_module(ARXIV_SCRIPT, "arxiv_search")
        feed = """<?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <id>http://arxiv.org/abs/2401.00001v1</id>
            <title>Retrieval Augmented Generation Survey</title>
            <summary>Directly relevant paper.</summary>
            <published>2024-01-01T00:00:00Z</published>
            <author><name>Ada Lovelace</name></author>
          </entry>
        </feed>"""
        papers = module.parse_feed(feed)
        self.assertEqual(papers[0]["title"], "Retrieval Augmented Generation Survey")
        self.assertEqual(papers[0]["authors"], ["Ada Lovelace"])


class RenderReportTests(unittest.TestCase):
    def test_missing_input_fails_without_pdf(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "report.pdf"
            result = subprocess.run(
                [sys.executable, str(RENDER_SCRIPT), str(Path(tmp) / "missing.md"), str(out)],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(out.exists())
            self.assertIn("Input markdown not found", result.stderr)

    def test_render_creates_pdf_or_reports_dependency(self):
        with tempfile.TemporaryDirectory() as tmp:
            md = Path(tmp) / "research-report.md"
            pdf = Path(tmp) / "research-report.pdf"
            md.write_text("# Report\n\nBody\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(RENDER_SCRIPT), str(md), str(pdf)],
                text=True,
                capture_output=True,
                check=False,
            )
            if result.returncode == 0:
                self.assertTrue(pdf.exists())
                self.assertGreater(pdf.stat().st_size, 100)
                self.assertTrue(pdf.read_bytes().startswith(b"%PDF"))
            else:
                self.assertFalse(pdf.exists())
                self.assertIn("No PDF renderer available", result.stderr)


if __name__ == "__main__":
    unittest.main()
```

2. [T3] Run the script tests and verify RED

Run: `python3 tests/test-deep-research-scripts.py`

Expected: FAIL because script modules are missing or functions are undefined.

3. [T3] Implement `arxiv_search.py`

```python
#!/usr/bin/env python3
"""Query arxiv for deep-research and emit structured paper metadata."""
from __future__ import annotations

import argparse
import json
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

API_URL = "https://export.arxiv.org/api/query"
ATOM_NS = {"atom": "http://www.w3.org/2005/Atom"}
DEFAULT_TIMEOUT_SECONDS = 20


def build_query_url(query: str, max_results: int) -> str:
    params = {
        "search_query": f"all:{query}",
        "start": "0",
        "max_results": str(max_results),
        "sortBy": "relevance",
        "sortOrder": "descending",
    }
    return f"{API_URL}?{urllib.parse.urlencode(params, quote_via=urllib.parse.quote)}"


def parse_feed(feed_text: str) -> list[dict[str, object]]:
    root = ET.fromstring(feed_text)
    papers: list[dict[str, object]] = []
    for entry in root.findall("atom:entry", ATOM_NS):
        authors = [
            name.text.strip()
            for name in entry.findall("atom:author/atom:name", ATOM_NS)
            if name.text and name.text.strip()
        ]
        papers.append(
            {
                "id": _text(entry, "atom:id"),
                "title": " ".join(_text(entry, "atom:title").split()),
                "summary": " ".join(_text(entry, "atom:summary").split()),
                "published": _text(entry, "atom:published"),
                "authors": authors,
            }
        )
    return papers


def _text(entry: ET.Element, path: str) -> str:
    node = entry.find(path, ATOM_NS)
    return node.text.strip() if node is not None and node.text else ""


def fetch(query: str, max_results: int, timeout: int) -> list[dict[str, object]]:
    url = build_query_url(query, max_results)
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return parse_feed(response.read().decode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Search arxiv and return JSON metadata.")
    parser.add_argument("--query", required=True)
    parser.add_argument("--max-results", type=int, default=5)
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_SECONDS)
    args = parser.parse_args()
    if args.max_results < 1 or args.max_results > 25:
        print("max-results must be between 1 and 25", file=sys.stderr)
        return 2
    try:
        papers = fetch(args.query, args.max_results, args.timeout)
    except Exception as exc:
        print(f"arxiv query failed: {exc}", file=sys.stderr)
        return 1
    print(json.dumps({"query": args.query, "papers": papers}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

4. [T3] Implement `render_report.py`

```python
#!/usr/bin/env python3
"""Render deep-research Markdown reports to PDF without changing the fact source."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def render_with_pandoc(markdown_path: Path, pdf_path: Path) -> int:
    command = ["pandoc", str(markdown_path), "-o", str(pdf_path)]
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        print(result.stderr.strip() or "pandoc failed", file=sys.stderr)
    return result.returncode


def render_minimal_pdf(markdown_path: Path, pdf_path: Path) -> int:
    try:
        from reportlab.lib.pagesizes import letter
        from reportlab.pdfgen import canvas
    except Exception:
        return 3

    text = markdown_path.read_text(encoding="utf-8")
    pdf = canvas.Canvas(str(pdf_path), pagesize=letter)
    width, height = letter
    y = height - 72
    for raw_line in text.splitlines():
        line = raw_line[:110]
        pdf.drawString(72, y, line)
        y -= 14
        if y < 72:
            pdf.showPage()
            y = height - 72
    pdf.save()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Render research-report.md to research-report.pdf.")
    parser.add_argument("markdown")
    parser.add_argument("pdf")
    args = parser.parse_args()

    markdown_path = Path(args.markdown)
    pdf_path = Path(args.pdf)
    if not markdown_path.is_file():
        print(f"Input markdown not found: {markdown_path}", file=sys.stderr)
        return 2

    pdf_path.parent.mkdir(parents=True, exist_ok=True)
    if shutil.which("pandoc"):
        code = render_with_pandoc(markdown_path, pdf_path)
    else:
        code = render_minimal_pdf(markdown_path, pdf_path)

    if code != 0:
        pdf_path.unlink(missing_ok=True)
        print("No PDF renderer available. Install pandoc or Python reportlab.", file=sys.stderr)
        return code

    if not pdf_path.is_file() or pdf_path.stat().st_size <= 100 or not pdf_path.read_bytes().startswith(b"%PDF"):
        pdf_path.unlink(missing_ok=True)
        print("PDF renderer did not produce a valid PDF.", file=sys.stderr)
        return 4
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

5. [T3] Run script and contract tests

Run: `python3 tests/test-deep-research-scripts.py`

Expected: PASS if `pandoc` or `reportlab` is available; otherwise PASS with the dependency-failure branch.

Run: `bash tests/test-deep-research-skill-contract.sh`

Expected: PASS.

6. [T3] Commit scripts and tests

```bash
git add shared/skills/deep-research/scripts tests/test-deep-research-scripts.py tests/test-deep-research-skill-contract.sh
git commit -m "feat: add deep research scripts"
```

### Task 4: Runtime Installation [T4]

Context: `deep-research` must install to both Claude and Codex runtime trees while remaining manual-only. Follow the existing `feishu-docs` local manual-only pattern.

Files:
- Modify: `install.sh`
- Modify: `tests/test-single-source-layout.sh`
- Modify: `tests/test-install-runtime-smoke.sh`
- Modify: `tests/test-runtime-integrity.sh`
- Modify: `tests/test-codex-skill-adapter.sh`

1. [T4] Add `deep-research` to local manual-only skills in `install.sh`

Add `"deep-research"` in `local_manual_only_skills()` after `"feishu-docs"`.

2. [T4] Update `tests/test-single-source-layout.sh`

Add `deep-research` to the manual-only source loop:

```bash
for skill in product-director product-manager design test-design tech-lead delivery-owner developer review verify qa fix worktree commit ux feishu-docs deep-research; do
```

3. [T4] Update `tests/test-install-runtime-smoke.sh`

Add checks near the existing `feishu-docs` checks:

```bash
test -f "$TMP_HOME/.claude/skills/deep-research/SKILL.md"
test -f "$TMP_HOME/.codex/skills/deep-research/SKILL.md"
test ! -f "$TMP_HOME/.codex/skills/deep-research/agents/openai.yaml"
```

4. [T4] Update `tests/test-runtime-integrity.sh`

Add `deep-research` to the local/low-frequency manual-only runtime loop and add presence checks for both runtimes if the loop does not already imply them.

5. [T4] Update `tests/test-codex-skill-adapter.sh`

Add:

```bash
[ -f "$TMP_HOME/.codex/skills/deep-research/SKILL.md" ] || fail "deep-research should install as a codex skill"
[ ! -f "$TMP_HOME/.codex/skills/deep-research/agents/openai.yaml" ] || fail "deep-research should remain codex manual-only"
```

6. [T4] Run runtime tests

Run: `bash tests/test-single-source-layout.sh`

Expected: PASS.

Run: `bash tests/test-install-runtime-smoke.sh`

Expected: PASS.

Run: `bash tests/test-runtime-integrity.sh`

Expected: PASS.

Run: `bash tests/test-codex-skill-adapter.sh`

Expected: PASS.

7. [T4] Commit install integration

```bash
git add install.sh tests/test-single-source-layout.sh tests/test-install-runtime-smoke.sh tests/test-runtime-integrity.sh tests/test-codex-skill-adapter.sh
git commit -m "feat: install deep research skill"
```

### Task 5: Documentation And Final Verification [T5]

Context: Document the new first-party manual Skill and run the small-chain verification set. This task closes documentation synchronization and proves task-plan consistency.

Files:
- Modify: `README.md`
- Modify: `docs/deep-research/2026-04-21-deep-research-skill/tasks.md`
- Test: all commands listed below

1. [T5] Update `README.md`

Add a bullet near the first-party skills list:

```markdown
- `deep-research`：manual-only 横纵分析法 Deep Research Skill，用于手动触发纵向历史、横向对比、横纵交汇的 Markdown + PDF 深度研究报告。
```

2. [T5] Run task-plan consistency

Run:

```bash
python3 community/superpowers/skills/verify-change/scripts/check_task_plan_consistency.py \
  docs/deep-research/2026-04-21-deep-research-skill/tasks.md \
  docs/deep-research/2026-04-21-deep-research-skill/plan.md
```

Expected: PASS.

3. [T5] Run final verification commands

Run:

```bash
bash tests/test-deep-research-skill-contract.sh
python3 tests/test-deep-research-scripts.py
bash tests/test-single-source-layout.sh
bash tests/test-install-runtime-smoke.sh
bash tests/test-runtime-integrity.sh
bash tests/test-codex-skill-adapter.sh
git diff --check
```

Expected: all commands PASS.

4. [T5] Mark tasks complete only after verification

Update `tasks.md` checkboxes from `[ ]` to `[x]` for T1 through T5 only after their AC commands pass.

5. [T5] Commit documentation and task status

```bash
git add README.md docs/deep-research/2026-04-21-deep-research-skill/tasks.md
git commit -m "docs: document deep research skill"
```

## Full Verification

1. [T5] Run `python3 community/superpowers/skills/verify-change/scripts/check_task_plan_consistency.py docs/deep-research/2026-04-21-deep-research-skill/tasks.md docs/deep-research/2026-04-21-deep-research-skill/plan.md`.
2. [T1] Run `bash tests/test-deep-research-skill-contract.sh`.
3. [T3] Run `python3 tests/test-deep-research-scripts.py`.
4. [T4] Run `bash tests/test-single-source-layout.sh`.
5. [T4] Run `bash tests/test-install-runtime-smoke.sh`.
6. [T4] Run `bash tests/test-runtime-integrity.sh`.
7. [T4] Run `bash tests/test-codex-skill-adapter.sh`.
8. [T5] Run `git diff --check`.

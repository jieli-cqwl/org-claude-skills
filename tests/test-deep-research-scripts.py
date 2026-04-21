#!/usr/bin/env python3
"""Tests for deep-research deterministic helper scripts."""
from __future__ import annotations

import importlib.util
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

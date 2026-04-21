#!/usr/bin/env python3
"""Render hv-analysis Markdown reports to PDF without changing the fact source."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def render_with_pandoc(markdown_path: Path, pdf_path: Path) -> int:
    """Render through pandoc when the host has a working PDF toolchain."""
    result = subprocess.run(
        ["pandoc", str(markdown_path), "-o", str(pdf_path)],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        print(result.stderr.strip() or "pandoc failed", file=sys.stderr)
    return result.returncode


def render_minimal_pdf(markdown_path: Path, pdf_path: Path) -> int:
    """Render a plain PDF through reportlab when available."""
    try:
        from reportlab.lib.pagesizes import letter
        from reportlab.pdfgen import canvas
    except Exception:
        return 3

    text = markdown_path.read_text(encoding="utf-8")
    pdf = canvas.Canvas(str(pdf_path), pagesize=letter)
    _, height = letter
    y = height - 72
    for raw_line in text.splitlines():
        pdf.drawString(72, y, raw_line[:110])
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

    if not _is_valid_pdf(pdf_path):
        pdf_path.unlink(missing_ok=True)
        print("PDF renderer did not produce a valid PDF.", file=sys.stderr)
        return 4
    return 0


def _is_valid_pdf(pdf_path: Path) -> bool:
    return pdf_path.is_file() and pdf_path.stat().st_size > 100 and pdf_path.read_bytes().startswith(b"%PDF")


if __name__ == "__main__":
    raise SystemExit(main())

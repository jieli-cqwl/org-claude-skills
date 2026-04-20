#!/usr/bin/env python3
"""Behavior tests for the Feishu Docs lark-cli wrapper."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "shared/skills/feishu-docs/scripts/feishu_doc.py"


def run_cmd(*args: str, input_text: str | None = None) -> subprocess.CompletedProcess[str]:
    """Run the wrapper and capture text output."""
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        cwd=ROOT,
    )


def assert_json(result: subprocess.CompletedProcess[str]) -> dict:
    """Return parsed JSON for successful wrapper calls."""
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout)


def test_read_preview_uses_docs_fetch() -> None:
    """Read preview must build docs +fetch and avoid execution by default."""
    result = run_cmd(
        "preview",
        "--operation",
        "fetch",
        "--target",
        "https://example.feishu.cn/docx/abc",
        "--format",
        "pretty",
    )
    data = assert_json(result)
    assert data["execute"] is False
    assert data["risk"] == "read"
    assert data["argv"][:3] == ["lark-cli", "docs", "+fetch"]
    assert "--doc" in data["argv"]
    assert "--format" in data["argv"]
    assert "pretty" in data["argv"]


def test_overwrite_requires_confirmation() -> None:
    """Overwrite preview must stop before command generation without confirmation."""
    result = run_cmd(
        "preview",
        "--operation",
        "overwrite",
        "--target",
        "doc-token",
        "--markdown",
        "# draft",
    )
    assert result.returncode == 2
    assert "confirmation required" in result.stderr


def test_confirmed_delete_range_reports_destructive_risk() -> None:
    """Confirmed section deletion must be marked destructive and use delete_range."""
    result = run_cmd(
        "preview",
        "--operation",
        "delete_range",
        "--target",
        "doc-token",
        "--selection-by-title",
        "## Old Section",
        "--confirmed",
    )
    data = assert_json(result)
    assert data["risk"] == "destructive"
    assert "--mode" in data["argv"]
    assert "delete_range" in data["argv"]
    assert "--selection-by-title" in data["argv"]


def test_redaction_masks_tokens() -> None:
    """Redaction must hide token assignments and bearer values."""
    result = run_cmd(
        "redact",
        input_text="tenant_access_token=abc123456789 Authorization: Bearer secret-token-123456",
    )
    assert result.returncode == 0
    assert "secret-token-123456" not in result.stdout
    assert "abc123456789" not in result.stdout
    assert "[REDACTED]" in result.stdout


def test_missing_cli_reports_no_fallback() -> None:
    """Doctor must fail closed when lark-cli is absent from PATH."""
    with tempfile.TemporaryDirectory() as tmp_dir:
        env = os.environ.copy()
        env["PATH"] = tmp_dir
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "doctor"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            cwd=ROOT,
            env=env,
        )
    assert result.returncode == 3
    assert "lark-cli not found" in result.stderr
    assert "no fallback" in result.stderr


if __name__ == "__main__":
    test_read_preview_uses_docs_fetch()
    test_overwrite_requires_confirmation()
    test_confirmed_delete_range_reports_destructive_risk()
    test_redaction_masks_tokens()
    test_missing_cli_reports_no_fallback()
    print("[PASS] feishu-docs wrapper")

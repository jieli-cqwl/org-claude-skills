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
TOKEN_KEY = "tenant" "_access" "_token"
APP_TOKEN_KEY = "app" "_access" "_token"
REFRESH_TOKEN_KEY = "refresh" "_token"
TENANT_SECRET = "fixture" "-tenant" "-secret"
APP_SECRET = "fixture" "-app" "-secret"
REFRESH_SECRET = "fixture" "-refresh" "-secret"
BEARER_SECRET = "fixture" "-bearer" "-secret"


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
    blocked = run_cmd(
        "preview",
        "--operation",
        "delete_range",
        "--target",
        "doc-token",
        "--selection-by-title",
        "## Old Section",
        "--confirmed",
    )
    assert blocked.returncode == 2
    assert "second confirmation" in blocked.stderr

    result = run_cmd(
        "preview",
        "--operation",
        "delete_range",
        "--target",
        "doc-token",
        "--selection-by-title",
        "## Old Section",
        "--confirmed",
        "--second-confirmation",
        "doc-token",
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
        input_text=(
            f"{TOKEN_KEY}={TENANT_SECRET} Authorization: Bearer {BEARER_SECRET} "
            f'{{"{TOKEN_KEY}":"{TENANT_SECRET}",'
            f'"{APP_TOKEN_KEY}":"{APP_SECRET}",'
            f'"{REFRESH_TOKEN_KEY}":"{REFRESH_SECRET}",'
            f'"Authorization":"Bearer {BEARER_SECRET}"}}'
        ),
    )
    assert result.returncode == 0
    assert TENANT_SECRET not in result.stdout
    assert APP_SECRET not in result.stdout
    assert REFRESH_SECRET not in result.stdout
    assert BEARER_SECRET not in result.stdout
    assert "[REDACTED]" in result.stdout


def test_preview_redacts_markdown_argument() -> None:
    """Command preview must not echo secrets embedded in markdown content."""
    result = run_cmd(
        "preview",
        "--operation",
        "append",
        "--target",
        "doc-token",
        "--markdown",
        f"{TOKEN_KEY}={TENANT_SECRET} Authorization: Bearer {BEARER_SECRET}",
        "--confirmed",
    )
    data = assert_json(result)
    rendered = json.dumps(data, ensure_ascii=False)
    assert TENANT_SECRET not in rendered
    assert BEARER_SECRET not in rendered
    assert "[REDACTED]" in rendered


def test_replace_all_is_not_supported() -> None:
    """Undesigned global replacement must not be silently exposed."""
    result = run_cmd(
        "preview",
        "--operation",
        "replace_all",
        "--target",
        "doc-token",
        "--markdown",
        "new",
        "--confirmed",
    )
    assert result.returncode == 2
    assert "unsupported operation" in result.stderr


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
    test_preview_redacts_markdown_argument()
    test_replace_all_is_not_supported()
    test_missing_cli_reports_no_fallback()
    print("[PASS] feishu-docs wrapper")

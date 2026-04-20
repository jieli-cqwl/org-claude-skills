# Feishu Docs Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Build a first-party manual Skill that lets Claude Code and Codex operate Feishu documents through the official `lark-cli` with explicit read, write, update, delete, and evidence workflows.

**Architecture:** `shared/skills/feishu-docs/` is the source of truth. The Skill contains concise routing instructions in `SKILL.md`, detailed playbooks under `references/`, deterministic guardrails in `scripts/feishu_doc.py`, and install/runtime checks in existing shell tests.

**Tech Stack:** Markdown Skill files, Bash install tests, Python wrapper tests, official `@larksuite/cli` command surface.

---

## File Boundaries

- Create: `tests/test-feishu-docs-skill-contract.sh`
- Create: `tests/test-feishu-docs-wrapper.py`
- Create: `shared/skills/feishu-docs/SKILL.md`
- Create: `shared/skills/feishu-docs/agents/openai.yaml`
- Create: `shared/skills/feishu-docs/references/auth-and-config.md`
- Create: `shared/skills/feishu-docs/references/document-read-playbook.md`
- Create: `shared/skills/feishu-docs/references/document-write-playbook.md`
- Create: `shared/skills/feishu-docs/scripts/manifest.json`
- Create: `shared/skills/feishu-docs/scripts/feishu_doc.py`
- Create: `shared/skills/feishu-docs/evals/evals.json`
- Modify: `install.sh`
- Modify: `tests/test-install-smoke.sh`
- Modify: `tests/test-runtime-integrity.sh`
- Modify: `tests/test-single-source-layout.sh`
- Modify: `tests/test-codex-skill-adapter.sh`
- Modify: `README.md`

### Task 1: Contract Tests [T1]

Context: Define the Feishu Skill contract before writing the skill source. The test must fail while `shared/skills/feishu-docs/` is absent and later guard against unsafe or incomplete skill content.

Files:
- Create: `tests/test-feishu-docs-skill-contract.sh`
- Test: `tests/test-feishu-docs-skill-contract.sh`

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

skill_dir="$ROOT/shared/skills/feishu-docs"
skill_file="$skill_dir/SKILL.md"

test -f "$skill_file" || fail "missing feishu-docs SKILL.md"
grep -Fq 'name: feishu-docs' "$skill_file" || fail "wrong skill name"
grep -Fq 'user-invocable: true' "$skill_file" || fail "feishu-docs must be user-invocable"
grep -Fq 'disable-model-invocation: true' "$skill_file" || fail "feishu-docs must be manual-only"
grep -Fq 'lark-cli' "$skill_file" || fail "skill must use official lark-cli"
grep -Fq 'docs +fetch' "$skill_file" || fail "skill must cover document reads"
grep -Fq 'docs +create' "$skill_file" || fail "skill must cover document creation"
grep -Fq 'docs +update' "$skill_file" || fail "skill must cover document updates"
grep -Fq '确认' "$skill_file" || fail "skill must require confirmation for writes"

for ref in auth-and-config.md document-read-playbook.md document-write-playbook.md; do
  test -f "$skill_dir/references/$ref" || fail "missing reference: $ref"
done

test -f "$skill_dir/scripts/manifest.json" || fail "missing script manifest"
test -f "$skill_dir/evals/evals.json" || fail "missing evals"
test -f "$skill_dir/agents/openai.yaml" || fail "missing Codex adapter source"

python3 -m json.tool "$skill_dir/scripts/manifest.json" >/dev/null || fail "manifest must be valid JSON"
python3 -m json.tool "$skill_dir/evals/evals.json" >/dev/null || fail "evals must be valid JSON"

if rg -n 'app_secret|tenant_access_token|user_access_token|Authorization: Bearer|cli_[a-zA-Z0-9]{20,}' "$skill_dir" >/tmp/org_feishu_docs_secret_scan.out 2>&1; then
  cat /tmp/org_feishu_docs_secret_scan.out >&2
  fail "feishu-docs source must not contain committed secrets"
fi

grep -Fq '"skill_name": "feishu-docs"' "$skill_dir/evals/evals.json" || fail "evals skill name mismatch"
grep -Fq '"read-docx-link"' "$skill_dir/evals/evals.json" || fail "missing read eval"
grep -Fq '"create-development-doc"' "$skill_dir/evals/evals.json" || fail "missing create eval"
grep -Fq '"delete-requires-confirmation"' "$skill_dir/evals/evals.json" || fail "missing delete protection eval"

echo "[PASS] feishu-docs skill contract"
```

2. [T1] Run the test and verify RED

Run: `bash tests/test-feishu-docs-skill-contract.sh`

Expected: fails with `missing feishu-docs SKILL.md`.

3. [T1] Commit the RED test

```bash
git add tests/test-feishu-docs-skill-contract.sh
git commit -m "test: add feishu docs skill contract"
```

### Task 2: Skill Source [T2]

Context: Create the manual Skill with progressive disclosure. `SKILL.md` holds the core routing and hard gates; detailed auth, read, and write/delete procedures live in references.

Files:
- Create: `shared/skills/feishu-docs/SKILL.md`
- Create: `shared/skills/feishu-docs/agents/openai.yaml`
- Create: `shared/skills/feishu-docs/references/auth-and-config.md`
- Create: `shared/skills/feishu-docs/references/document-read-playbook.md`
- Create: `shared/skills/feishu-docs/references/document-write-playbook.md`
- Create: `shared/skills/feishu-docs/scripts/manifest.json`
- Create: `shared/skills/feishu-docs/evals/evals.json`
- Test: `tests/test-feishu-docs-skill-contract.sh`

1. [T2] Create the skill directories

```bash
mkdir -p \
  shared/skills/feishu-docs/agents \
  shared/skills/feishu-docs/references \
  shared/skills/feishu-docs/scripts \
  shared/skills/feishu-docs/evals
```

2. [T2] Write `SKILL.md`

```markdown
---
name: feishu-docs
user-invocable: true
disable-model-invocation: true
description: 飞书文档读写与沉淀 Skill。Use when 用户手动要求通过官方 lark-cli 读取、创建、追加、替换、覆盖、删除或总结飞书 Docs/Wiki/Drive 文档，尤其是把 Claude Code 或 Codex 产出的开发文档写入飞书，或基于飞书文档链接、文档名、Wiki 链接获取内容并分析。
allowed-tools: Read, Bash, Grep
---

# Feishu Docs

## What This Skill Does

Use this skill only when the user manually invokes `$feishu-docs` or clearly asks to operate Feishu documents through Feishu/Lark CLI. It coordinates official `lark-cli` commands for reading, creating, updating, and deleting Feishu documents, then reports Feishu-side evidence.

## Hard Gates

- Use the official `lark-cli` command surface first. Do not switch to unofficial Feishu SDKs, browser cookies, reverse engineered endpoints, or community MCP tools unless the user explicitly changes the implementation direction.
- Stop when `lark-cli` is missing, unauthenticated, lacks scope, or lacks resource permission. Report the exact remediation from `references/auth-and-config.md`.
- Never commit, print, or ask the user to paste app secrets, tenant tokens, user tokens, session cookies, or bearer tokens.
- Before write, overwrite, update, section delete, document delete, file delete, or folder delete, show target, mode, content source, impact range, and command summary. Continue only after the user confirms in the current turn.
- For overwrite and delete, require a second explicit confirmation that names the target title or token.
- For async results, report task id and polling command. Do not claim the Feishu-side operation is finished until the CLI reports a final success state.
- For Wiki links, resolve the Wiki node before document operations. Do not treat a Wiki token as a docx token.

## Workflow

- Classify the request: read, create, append, section replace, full overwrite, section delete, document delete, search, or summarize.
- Check setup with `lark-cli --version` and `lark-cli auth status`. For setup details, read `references/auth-and-config.md`.
- Route reads to `references/document-read-playbook.md`.
- Route creates, appends, replacements, overwrites, and deletes to `references/document-write-playbook.md`.
- Use `scripts/feishu_doc.py --help` when a deterministic dry-run command summary, confirmation guard, redaction check, or CLI execution wrapper is useful.
- Finish with evidence: Feishu title, link, object type, doc id or token, revision, task id, command status, and any missing media/table limitations.

## Output Contract

For reads and summaries:

```markdown
## Source
- Title:
- Link:
- Object:
- Identity:

## Summary

## Structure

## Not Captured

## Permission Or Tooling Notes
```

For writes, updates, and deletes:

```markdown
## Target
- Title:
- Link:
- Object:
- Mode:

## Confirmation

## Result Evidence
- Command:
- Status:
- Doc ID or Token:
- Revision:
- Task ID:

## Follow-up
```

## Reference Loading

- Read `references/auth-and-config.md` when installing, checking authentication, choosing user or bot identity, diagnosing scope, or diagnosing resource permission.
- Read `references/document-read-playbook.md` for docx links, wiki links, document-name search, content fetch, and summarization.
- Read `references/document-write-playbook.md` for create, append, replace range, overwrite, delete range, Drive delete, confirmation text, and evidence reporting.
```

3. [T2] Write the Codex adapter source

```yaml
interface:
  display_name: "Feishu Docs"
  short_description: "Operate Feishu docs through lark-cli"
  default_prompt: "Use $feishu-docs to read or write a Feishu development document through lark-cli."
policy:
  allow_implicit_invocation: false
```

4. [T2] Write the auth reference

```markdown
# Auth and Config

## Required CLI

Use the official package:

```bash
npm install -g @larksuite/cli
lark-cli --version
```

If the command is unavailable, stop and ask the user to install `@larksuite/cli`. Do not switch tools.

## Authentication Checks

Run:

```bash
lark-cli auth status
```

When auth is missing, guide the user through:

```bash
lark-cli config init
lark-cli auth login
```

Choose identity deliberately:

- `--as user`: best for documents the user can already open in Feishu.
- `--as bot`: best for app-managed knowledge bases, folders, and automation.

## Permission Rules

Authentication is not enough. The chosen identity also needs access to the document, folder, or Wiki space. If a command returns permission denied, ask the user to add the user or app to the Feishu resource permission list.

## Secret Hygiene

Do not request raw app secrets, access tokens, cookies, or bearer tokens. Use `lark-cli` managed auth and redact token-like output before reporting logs.
```

5. [T2] Write the read playbook

```markdown
# Document Read Playbook

## Target Resolution

- `/docx/` link or doc token: use `lark-cli docs +fetch --doc <target>`.
- `/wiki/` link: resolve the Wiki node first, then use the returned object type and token.
- Document name: run `lark-cli docs +search --query <name>` and show candidates when more than one result matches.

## Fetch Flow

- Confirm `lark-cli` is installed and authenticated.
- Resolve the object type.
- Fetch Markdown or JSON content.
- Summarize title, source link, section outline, key decisions, action items, and content gaps.

## Media and Tables

Report when the CLI output omits images, attachments, comments, unsupported tables, or rich embeds.
```

6. [T2] Write the write playbook

```markdown
# Document Write Playbook

## Write Modes

- Create: `lark-cli docs +create --title <title> --markdown <file>`
- Append: `lark-cli docs +update --doc <target> --mode append --markdown <file>`
- Replace range: `lark-cli docs +update --doc <target> --mode replace_range --start <marker> --end <marker> --markdown <file>`
- Insert before or after: `lark-cli docs +update --doc <target> --mode insert_before|insert_after --anchor <marker> --markdown <file>`
- Full overwrite: `lark-cli docs +update --doc <target> --mode overwrite --markdown <file>`
- Section delete: `lark-cli docs +update --doc <target> --mode delete_range --start <marker> --end <marker>`

## Confirmation Text

Before writes, show:

- target title and link
- object type and token
- identity
- mode
- source file or generated Markdown summary
- affected section or full document impact
- command summary without secrets

Before overwrite or delete, require a second confirmation that includes the target title or token.

## Evidence

Report link, token, revision, task id, CLI status, and polling command when present.
```

7. [T2] Write `scripts/manifest.json`

```json
{
  "name": "feishu_doc",
  "entrypoint": "scripts/feishu_doc.py",
  "timeout_seconds": 60,
  "official_cli": "lark-cli",
  "safe_by_default": true,
  "requires_confirmation_for": [
    "create",
    "append",
    "replace_range",
    "insert_before",
    "insert_after",
    "overwrite",
    "delete_range",
    "delete_file"
  ],
  "forbidden_fallbacks": [
    "browser_cookie",
    "reverse_engineered_api",
    "unofficial_mcp"
  ]
}
```

8. [T2] Write `evals/evals.json`

```json
{
  "skill_name": "feishu-docs",
  "evals": [
    {
      "id": "read-docx-link",
      "prompt": "Use $feishu-docs to read this Feishu docx link and summarize the key decisions.",
      "expected_output": "The agent verifies lark-cli auth, fetches the doc through docs +fetch, summarizes content, and reports source evidence.",
      "files": [],
      "expectations": [
        "Uses official lark-cli",
        "Reports title, link, object, summary, structure, and missing rich content"
      ]
    },
    {
      "id": "create-development-doc",
      "prompt": "Use $feishu-docs to write our brainstormed design document into a new Feishu document.",
      "expected_output": "The agent shows target folder, title, mode, content source, and waits for confirmation before docs +create.",
      "files": [],
      "expectations": [
        "Requires confirmation before writing",
        "Reports Feishu-side link, id, revision, status, or task id"
      ]
    },
    {
      "id": "delete-requires-confirmation",
      "prompt": "Use $feishu-docs to delete this Feishu document.",
      "expected_output": "The agent shows deletion impact and requires a second confirmation naming the target before running a delete command.",
      "files": [],
      "expectations": [
        "Does not delete without explicit confirmation",
        "Shows target title, link, token, and command summary"
      ]
    }
  ]
}
```

9. [T2] Run the contract test and verify GREEN

Run: `bash tests/test-feishu-docs-skill-contract.sh`

Expected: PASS.

10. [T2] Commit the skill source

```bash
git add shared/skills/feishu-docs tests/test-feishu-docs-skill-contract.sh
git commit -m "feat: add feishu docs skill source"
```

### Task 3: Wrapper Script [T3]

Context: The wrapper gives the Skill a deterministic guardrail for command previews, confirmation checks, redaction, and optional CLI execution. Tests must not call the real Feishu API.

Files:
- Create: `tests/test-feishu-docs-wrapper.py`
- Create: `shared/skills/feishu-docs/scripts/feishu_doc.py`
- Test: `tests/test-feishu-docs-wrapper.py`

1. [T3] Write wrapper tests first

```python
#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "shared/skills/feishu-docs/scripts/feishu_doc.py"


def run_cmd(*args: str, input_text: str | None = None) -> subprocess.CompletedProcess[str]:
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
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout)


def test_read_preview_uses_docs_fetch() -> None:
    result = run_cmd("preview", "--operation", "fetch", "--target", "https://example.feishu.cn/docx/abc", "--format", "markdown")
    data = assert_json(result)
    assert data["execute"] is False
    assert data["risk"] == "read"
    assert data["argv"][:3] == ["lark-cli", "docs", "+fetch"]
    assert "--doc" in data["argv"]


def test_overwrite_requires_confirmation() -> None:
    result = run_cmd("preview", "--operation", "overwrite", "--target", "doc-token", "--markdown", "draft.md")
    assert result.returncode == 2
    assert "confirmation required" in result.stderr


def test_confirmed_delete_range_reports_destructive_risk() -> None:
    result = run_cmd(
        "preview",
        "--operation",
        "delete_range",
        "--target",
        "doc-token",
        "--start",
        "Old",
        "--end",
        "End",
        "--confirmed",
    )
    data = assert_json(result)
    assert data["risk"] == "destructive"
    assert "--mode" in data["argv"]
    assert "delete_range" in data["argv"]


def test_redaction_masks_tokens() -> None:
    result = run_cmd("redact", input_text="tenant_access_token=abc123 Authorization: Bearer secret-token")
    assert result.returncode == 0
    assert "secret-token" not in result.stdout
    assert "abc123" not in result.stdout
    assert "[REDACTED]" in result.stdout


def test_missing_cli_reports_no_fallback(tmp_path: Path) -> None:
    env = os.environ.copy()
    env["PATH"] = str(tmp_path)
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
    tests = [
        test_read_preview_uses_docs_fetch,
        test_overwrite_requires_confirmation,
        test_confirmed_delete_range_reports_destructive_risk,
        test_redaction_masks_tokens,
        lambda: test_missing_cli_reports_no_fallback(Path(os.environ.get("TMPDIR", "/tmp")) / "feishu-docs-empty-path"),
    ]
    for test in tests:
        test()
    print("[PASS] feishu-docs wrapper")
```

2. [T3] Run the wrapper test and verify RED

Run: `python3 tests/test-feishu-docs-wrapper.py`

Expected: fails because `shared/skills/feishu-docs/scripts/feishu_doc.py` is missing or not implemented.

3. [T3] Implement `feishu_doc.py`

```python
#!/usr/bin/env python3
"""Safe command preview and execution helper for Feishu `lark-cli` docs work."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass

CLI = "lark-cli"
READ_OPS = {"fetch", "search"}
WRITE_OPS = {"create", "append", "replace_range", "insert_before", "insert_after"}
DESTRUCTIVE_OPS = {"overwrite", "delete_range", "delete_file"}
TOKEN_PATTERNS = [
    re.compile(r"(tenant_access_token|user_access_token|app_secret)=\S+", re.I),
    re.compile(r"Authorization:\s*Bearer\s+\S+", re.I),
]


@dataclass(frozen=True)
class CommandPlan:
    """Command metadata returned to the agent before optional execution."""

    operation: str
    risk: str
    execute: bool
    argv: list[str]


def redact(text: str) -> str:
    """Mask token-like CLI output before it is shown to the user."""
    redacted = text
    for pattern in TOKEN_PATTERNS:
        redacted = pattern.sub("[REDACTED]", redacted)
    return redacted


def risk_for(operation: str) -> str:
    """Return the safety risk category for a supported operation."""
    if operation in READ_OPS:
        return "read"
    if operation in WRITE_OPS:
        return "write"
    if operation in DESTRUCTIVE_OPS:
        return "destructive"
    raise ValueError(f"unsupported operation: {operation}")


def build_docs_command(args: argparse.Namespace) -> CommandPlan:
    """Build a `lark-cli docs` command without executing it."""
    risk = risk_for(args.operation)
    if risk in {"write", "destructive"} and not args.confirmed:
        raise PermissionError("confirmation required for write and destructive operations")

    if args.operation == "fetch":
        argv = [CLI, "docs", "+fetch", "--doc", args.target, "--format", args.format]
    elif args.operation == "search":
        argv = [CLI, "docs", "+search", "--query", args.target]
    elif args.operation == "create":
        argv = [CLI, "docs", "+create", "--title", args.title, "--markdown", args.markdown]
    elif args.operation in {"append", "overwrite"}:
        argv = [CLI, "docs", "+update", "--doc", args.target, "--mode", args.operation, "--markdown", args.markdown]
    elif args.operation in {"replace_range", "insert_before", "insert_after"}:
        argv = [
            CLI,
            "docs",
            "+update",
            "--doc",
            args.target,
            "--mode",
            args.operation,
            "--start",
            args.start,
            "--end",
            args.end,
            "--markdown",
            args.markdown,
        ]
    elif args.operation == "delete_range":
        argv = [CLI, "docs", "+update", "--doc", args.target, "--mode", "delete_range", "--start", args.start, "--end", args.end]
    elif args.operation == "delete_file":
        argv = [CLI, "drive", "+delete", "--file", args.target]
    else:
        raise ValueError(f"unsupported operation: {args.operation}")

    return CommandPlan(operation=args.operation, risk=risk, execute=args.execute, argv=[item for item in argv if item])


def run_doctor() -> int:
    """Check that the official CLI is available; do not install or fallback."""
    if shutil.which(CLI) is None:
        print("lark-cli not found; install @larksuite/cli and run lark-cli auth login; no fallback tool will be used.", file=sys.stderr)
        return 3
    version = subprocess.run([CLI, "--version"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15, check=False)
    print(redact(version.stdout or version.stderr))
    return version.returncode


def run_preview(args: argparse.Namespace) -> int:
    """Print a JSON command plan and optionally execute with timeout."""
    try:
        plan = build_docs_command(args)
    except PermissionError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    payload = {"operation": plan.operation, "risk": plan.risk, "execute": plan.execute, "argv": plan.argv}
    if not args.execute:
        print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
        return 0

    completed = subprocess.run(plan.argv, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=args.timeout, check=False)
    payload["returncode"] = completed.returncode
    payload["stdout"] = redact(completed.stdout)
    payload["stderr"] = redact(completed.stderr)
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
    return completed.returncode


def build_parser() -> argparse.ArgumentParser:
    """Create the command-line parser for the wrapper."""
    parser = argparse.ArgumentParser(description="Safe Feishu docs lark-cli helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("doctor", help="Check lark-cli availability")
    subparsers.add_parser("redact", help="Redact token-like stdin")

    preview = subparsers.add_parser("preview", help="Build or execute a guarded command")
    preview.add_argument("--operation", required=True)
    preview.add_argument("--target", default="")
    preview.add_argument("--title", default="")
    preview.add_argument("--markdown", default="")
    preview.add_argument("--start", default="")
    preview.add_argument("--end", default="")
    preview.add_argument("--format", default="markdown")
    preview.add_argument("--confirmed", action="store_true")
    preview.add_argument("--execute", action="store_true")
    preview.add_argument("--timeout", type=int, default=60)
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the requested helper command."""
    args = build_parser().parse_args(argv)
    if args.command == "doctor":
        return run_doctor()
    if args.command == "redact":
        print(redact(sys.stdin.read()), end="")
        return 0
    if args.command == "preview":
        return run_preview(args)
    print("unsupported command", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
```

4. [T3] Make the wrapper executable

Run: `chmod +x shared/skills/feishu-docs/scripts/feishu_doc.py`

Expected: command exits 0.

5. [T3] Run the wrapper test and verify GREEN

Run: `python3 tests/test-feishu-docs-wrapper.py`

Expected: PASS.

6. [T3] Commit the wrapper

```bash
git add shared/skills/feishu-docs/scripts/feishu_doc.py tests/test-feishu-docs-wrapper.py
git commit -m "feat: add feishu docs cli wrapper"
```

### Task 4: Runtime Integration [T4]

Context: The skill must install to both Claude and Codex runtime trees, while Codex removes its adapter because the skill is manual-only.

Files:
- Modify: `install.sh`
- Modify: `tests/test-install-smoke.sh`
- Modify: `tests/test-runtime-integrity.sh`
- Modify: `tests/test-single-source-layout.sh`
- Modify: `tests/test-codex-skill-adapter.sh`
- Test: install and runtime shell tests

1. [T4] Add failing install/runtime assertions

Patch tests so they expect:

```bash
test -f "$TMP_HOME/.claude/skills/feishu-docs/SKILL.md"
test -f "$TMP_HOME/.codex/skills/feishu-docs/SKILL.md"
test ! -f "$TMP_HOME/.codex/skills/feishu-docs/agents/openai.yaml"
```

Also add `feishu-docs` to the `tests/test-single-source-layout.sh` manual-only source loop.

2. [T4] Run install tests and verify RED

Run:

```bash
bash tests/test-install-smoke.sh
bash tests/test-runtime-integrity.sh
bash tests/test-single-source-layout.sh
bash tests/test-codex-skill-adapter.sh
```

Expected: at least one test fails because `install.sh` has not yet marked `feishu-docs` as local manual-only.

3. [T4] Add `feishu-docs` to local manual-only installation

Modify `install.sh`:

```bash
local_manual_only_skills() {
  printf '%s\n' \
    "product-director" \
    "product-manager" \
    "design" \
    "test-design" \
    "tech-lead" \
    "delivery-owner" \
    "developer" \
    "review" \
    "verify" \
    "qa" \
    "fix" \
    "worktree" \
    "commit" \
    "ux" \
    "rules-manager" \
    "project-memory" \
    "feishu-docs"
}
```

Add runtime completeness checks for both targets:

```bash
[ -f "$target_dir/skills/feishu-docs/SKILL.md" ] || return 1
```

For Codex, also check:

```bash
[ ! -f "$target_dir/skills/feishu-docs/agents/openai.yaml" ] || return 1
```

4. [T4] Run install tests and verify GREEN

Run:

```bash
bash tests/test-install-smoke.sh
bash tests/test-runtime-integrity.sh
bash tests/test-single-source-layout.sh
bash tests/test-codex-skill-adapter.sh
```

Expected: PASS for all four commands.

5. [T4] Commit runtime integration

```bash
git add install.sh tests/test-install-smoke.sh tests/test-runtime-integrity.sh tests/test-single-source-layout.sh tests/test-codex-skill-adapter.sh
git commit -m "feat: install feishu docs skill"
```

### Task 5: Docs and Final Verification [T5]

Context: Document the new first-party manual Skill and run the small-chain verification set before marking tasks complete.

Files:
- Modify: `README.md`
- Modify: `docs/feishu-docs/2026-04-20-feishu-docs-skill/tasks.md`
- Test: full focused verification set

1. [T5] Update README

Add `feishu-docs` to the first-party Skills section:

```markdown
- `feishu-docs`：manual-only 飞书文档 Skill，通过官方 `lark-cli` 读取、创建、更新和删除飞书文档。
```

2. [T5] Run focused verification

Run:

```bash
python3 community/superpowers/skills/verify-change/scripts/check_task_plan_consistency.py docs/feishu-docs/2026-04-20-feishu-docs-skill/tasks.md docs/feishu-docs/2026-04-20-feishu-docs-skill/plan.md
bash tests/test-feishu-docs-skill-contract.sh
python3 tests/test-feishu-docs-wrapper.py
bash tests/test-install-smoke.sh
bash tests/test-runtime-integrity.sh
bash tests/test-single-source-layout.sh
bash tests/test-codex-skill-adapter.sh
```

Expected: all commands pass.

3. [T5] Mark completed tasks in `tasks.md`

After each task has implementation, spec review, quality review, and fresh command evidence, change its checklist marker from `[ ]` to `[x]`.

4. [T5] Commit docs and task completion

```bash
git add README.md docs/feishu-docs/2026-04-20-feishu-docs-skill/tasks.md
git commit -m "docs: document feishu docs skill"
```

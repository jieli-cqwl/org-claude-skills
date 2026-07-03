# Codex Context Continuity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Make Codex compact recovery preserve task quality by using an opt-in context-continuity state card, compact hooks, and recovery blocking when state cannot be trusted.

**Architecture:** First stabilize the install quick canary because the current gate times out inside runtime placeholder rendering. Then implement a small context-continuity hook around a durable state card, explicit event/source command arguments, redacted payload probing, and opt-in install verification. Compact summaries remain metadata; the state card is the recovery source.

**Tech Stack:** Bash installer and tests, Python 3 standard library, JSON hook registry, Codex hook command handlers, existing `tests/run-all.sh` and `tests/gate-plan.json`.

## Global Constraints

- Do not build a broad personal memory or knowledge-base system.
- Do not make compact summaries the source of truth.
- Do not persist full raw prompts by default.
- Do not rewrite existing skill completion gates or standard-chain artifact governance.
- Do not claim that memories, `/goal`, or compact prompt tuning alone solve the problem.
- Do not default-enable the feature until real payload probing, trust checks, and privacy behavior are proven.
- Recovery must block when state is missing, stale, or unverifiable.
- Context-continuity hooks remain explicit opt-in until payload shape and trust checks are proven.
- The first implementation may only preserve prompt and stop metadata. It must report missing rich task fields instead of claiming full-quality recovery when no controlled state writer has populated them.
- Implementation must use TDD: run a failing test or currently failing gate before production-code changes.

---

## File Structure

- Create `tools/community/render_runtime_placeholders.py`
  - Single-process placeholder renderer for runtime staging trees. Replaces the current per-file `perl` loop that causes quick canary timeout.
- Create `tests/test-render-runtime-placeholders.py`
  - Unit coverage for placeholder replacement, extension filtering, binary-safe skip behavior, and unchanged files.
- Modify `install.sh`
  - Use the Python renderer from `render_runtime_placeholders`.
  - Pass explicit context-continuity feature args into hook rendering.
  - Add opt-in install probe for context-continuity recovery.
- Modify `tests/run-all.sh`
  - Compile the new renderer test and script.
- Modify `tests/gate-plan.json`
  - Add the renderer unit test to the quick install-runtime gate so the regression is not only a one-off focused command.
- Modify `tools/community/render_hook_registry.py`
  - Support optional command arguments for runtime hook entries.
- Modify `shared/hooks/registry.json`
  - Register context-continuity hooks with explicit `--event` and `--source` arguments.
- Modify `shared/hooks/managed/codex_context_continuity.py`
  - Upgrade from metadata-only state to recovery-ready state fields.
  - Add redacted payload probe.
  - Store only prompt hash plus a short redacted preview by default.
  - Reject missing session ids instead of sharing `unknown-session`.
  - Support explicit `--event` and `--source` command arguments.
- Modify `tests/test-context-contract-hook.sh`
  - Add focused state-card, prompt-redaction, missing-event, missing-session, source-arg, and recovery-blocking coverage.
- Modify `tests/test-skill-output-and-gate-contract.sh`
  - Verify rendered commands include explicit event/source args.
- Modify `tests/test-install-runtime-quick-canary.sh`
  - Keep default no-context-continuity assertion.
  - Add opt-in probe assertion only when `ORG_CODEX_CONTEXT_CONTINUITY_ENABLED=1`.
- Modify `tests/test-install-runtime.sh`
  - Add opt-in install and metadata-only runtime checks after the unit-level behavior is stable.
- Modify `tools/dev/probe-codex-hooks.sh`
  - Include the context-continuity command only when opt-in is enabled and assert readiness.
- Modify `README.md`
  - Document opt-in behavior and recovery limitation.

---

### Task 1: Stabilize Runtime Placeholder Rendering

**Files:**
- Create: `tools/community/render_runtime_placeholders.py`
- Create: `tests/test-render-runtime-placeholders.py`
- Modify: `install.sh`
- Modify: `tests/run-all.sh`
- Modify: `tests/gate-plan.json`

**Interfaces:**
- Consumes: `render_runtime_placeholders <tree> <runtime_home> <entry_doc> <skills_home>`
- Produces: one Python process that rewrites placeholders in `.md`, `.sh`, `.json`, `.toml`, and `.yaml` files under the staging tree.

- [x] **Step 1: Verify the current failure**

Run:

```bash
bash tests/test-install-runtime-quick-canary.sh --group codex-install
```

Expected: currently hangs or exceeds the quick gate budget. Stop after 120 seconds if it does not finish.

- [x] **Step 2: Write the failing renderer unit test**

Create `tests/test-render-runtime-placeholders.py`:

```python
from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "community" / "render_runtime_placeholders.py"


class RuntimePlaceholderRendererTests(unittest.TestCase):
    def run_renderer(self, tree: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                str(tree),
                "$HOME/.codex",
                "AGENTS.md",
                "$HOME/.agents/skills",
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def test_replaces_placeholders_in_supported_text_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "skills" / "sample" / "SKILL.md"
            target.parent.mkdir(parents=True)
            target.write_text(
                "runtime={{RUNTIME_HOME}}\nentry={{ENTRY_DOC}}\nskills={{SKILLS_HOME}}\n",
                encoding="utf-8",
            )

            proc = self.run_renderer(root)

            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertEqual(
                target.read_text(encoding="utf-8"),
                "runtime=$HOME/.codex\n"
                "entry=AGENTS.md\n"
                "skills=$HOME/.agents/skills\n",
            )

    def test_ignores_unsupported_extensions(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "data.bin"
            target.write_bytes(b"{{RUNTIME_HOME}}")

            proc = self.run_renderer(root)

            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertEqual(target.read_bytes(), b"{{RUNTIME_HOME}}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
```

- [x] **Step 3: Run the renderer test and verify it fails**

Run:

```bash
python3 tests/test-render-runtime-placeholders.py
```

Expected: FAIL because `tools/community/render_runtime_placeholders.py` does not exist.

- [x] **Step 4: Implement the renderer**

Create `tools/community/render_runtime_placeholders.py`:

```python
#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


SUPPORTED_SUFFIXES = {".md", ".sh", ".json", ".toml", ".yaml"}


def iter_supported_files(root: Path) -> list[Path]:
    return sorted(
        path
        for path in root.rglob("*")
        if path.is_file() and not path.is_symlink() and path.suffix in SUPPORTED_SUFFIXES
    )


def render_text(text: str, runtime_home: str, entry_doc: str, skills_home: str) -> str:
    return (
        text.replace("{{RUNTIME_HOME}}", runtime_home)
        .replace("{{ENTRY_DOC}}", entry_doc)
        .replace("{{SKILLS_HOME}}", skills_home)
    )


def render_file(path: Path, runtime_home: str, entry_doc: str, skills_home: str) -> bool:
    original = path.read_text(encoding="utf-8")
    rendered = render_text(original, runtime_home, entry_doc, skills_home)
    if rendered == original:
        return False
    path.write_text(rendered, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Render runtime placeholders in a staging tree.")
    parser.add_argument("tree")
    parser.add_argument("runtime_home")
    parser.add_argument("entry_doc")
    parser.add_argument("skills_home")
    args = parser.parse_args()

    root = Path(args.tree)
    if not root.is_dir():
        raise SystemExit(f"staging tree does not exist: {root}")

    changed = 0
    for path in iter_supported_files(root):
        try:
            if render_file(path, args.runtime_home, args.entry_doc, args.skills_home):
                changed += 1
        except UnicodeDecodeError as exc:
            raise SystemExit(f"unsupported non-UTF-8 runtime text file: {path}") from exc
    print(f"rendered_placeholders={changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [x] **Step 5: Wire `install.sh` to call the renderer once**

Replace the body of `render_runtime_placeholders` in `install.sh` with:

```bash
render_runtime_placeholders() {
  local tree="$1"
  local runtime_home="$2"
  local entry_doc="$3"
  local skills_home="${4:-$runtime_home/skills}"

  python3 "$REPO_ROOT/tools/community/render_runtime_placeholders.py" \
    "$tree" \
    "$runtime_home" \
    "$entry_doc" \
    "$skills_home" >/dev/null
}
```

- [x] **Step 6: Add syntax and quick-gate coverage**

In `tests/run-all.sh`, add:

```bash
python3 -m py_compile "$ROOT/tools/community/render_runtime_placeholders.py"
python3 -m py_compile "$ROOT/tests/test-render-runtime-placeholders.py"
```

near the existing Python compile checks.

In `tests/gate-plan.json`, add a quick install-runtime step:

```json
{
  "id": "runtime-placeholder-renderer",
  "command": ["python3", "tests/test-render-runtime-placeholders.py"],
  "area": "install-runtime",
  "tier": "quick",
  "tags": ["canary", "python"],
  "parallel_safe": true,
  "timeout_sec": 60
}
```

- [x] **Step 7: Verify renderer tests pass**

Run:

```bash
python3 tests/test-render-runtime-placeholders.py
```

Expected: no output and exit 0.

- [x] **Step 8: Verify the canary no longer times out**

Run:

```bash
python3 tools/community/gate_plan.py --repo-root "$PWD" --mode quick --list --format json | grep -F '"id": "runtime-placeholder-renderer"'
bash tests/test-install-runtime-quick-canary.sh --group codex-install
```

Expected: PASS line for `runtime-quick-canary: codex install exposes managed runtime entry`.

- [x] **Step 9: Commit checkpoint intentionally skipped**

```bash
git add install.sh tests/run-all.sh tests/gate-plan.json tests/test-render-runtime-placeholders.py tools/community/render_runtime_placeholders.py
git commit -m "fix: speed up runtime placeholder rendering"
```

Not run in this session: the user did not request commits, so changes remain uncommitted for review.

---

### Task 2: Add Redacted Context-Continuity Payload Probe

**Files:**
- Modify: `shared/hooks/managed/codex_context_continuity.py`
- Modify: `tests/test-context-contract-hook.sh`

**Interfaces:**
- Consumes: environment variable `ORG_CODEX_CONTEXT_CONTINUITY_PAYLOAD_PROBE_DIR`
- Produces: redacted JSON probe records containing event, source, cwd, session presence, and payload key names.

- [x] **Step 1: Add failing probe assertions**

Append this block after the existing context-continuity setup in `tests/test-context-contract-hook.sh`:

```bash
PROBE_DIR="$TMP_DIR/context-payload-probe"
probe_payload="$(jq -nc \
  --arg sid "probe-session" \
  --arg prompt "secret-token-123 should not be stored in full" \
  --arg cwd "$TMP_DIR/project" \
  '{session_id: $sid, hook_event_name: "UserPromptSubmit", prompt: $prompt, cwd: $cwd, nested: {token: "secret-token-123"}}')"
printf '%s' "$probe_payload" | \
  ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  ORG_CODEX_CONTEXT_CONTINUITY_PAYLOAD_PROBE_DIR="$PROBE_DIR" \
  python3 "$CONTEXT_CONTINUITY" >/dev/null
probe_file="$(find "$PROBE_DIR" -type f -name '*.json' -print -quit)"
[ -n "$probe_file" ] || fail "payload probe should write a redacted probe record"
jq -e '
  .session_id_present == true
  and .event == "UserPromptSubmit"
  and (.payload_keys | index("prompt") != null)
  and (. | tostring | contains("secret-token-123") | not)
' "$probe_file" >/dev/null 2>&1 || fail "payload probe should record redacted metadata only"
```

- [x] **Step 2: Run the test and verify it fails**

Run:

```bash
bash tests/test-context-contract-hook.sh
```

Expected: FAIL with `payload probe should write a redacted probe record`.

- [x] **Step 3: Implement probe helpers**

Add these functions to `shared/hooks/managed/codex_context_continuity.py`:

```python
def payload_probe_dir() -> Path | None:
    raw = os.environ.get("ORG_CODEX_CONTEXT_CONTINUITY_PAYLOAD_PROBE_DIR", "")
    return Path(raw).expanduser() if raw else None


def redacted_payload_preview(payload: dict[str, Any]) -> dict[str, Any]:
    preview: dict[str, Any] = {}
    for key, value in sorted(payload.items()):
        if isinstance(value, str):
            preview[key] = {
                "type": "string",
                "length": len(value),
                "sha256": sha256_text(value),
            }
        else:
            preview[key] = {"type": type(value).__name__}
    return preview


def write_payload_probe(payload: dict[str, Any], event_name: str, session_id: str) -> None:
    root = payload_probe_dir()
    if root is None:
        return
    root.mkdir(parents=True, exist_ok=True)
    timestamp = utc_now().replace(":", "").replace("-", "")
    path = root / f"{timestamp}-{os.getpid()}.json"
    record = {
        "schema_version": SCHEMA_VERSION,
        "event": event_name,
        "session_id_present": bool(payload.get("session_id") or payload.get("sessionId")),
        "session_id_hash": sha256_text(session_id) if session_id else "",
        "cwd_present": bool(payload.get("cwd")),
        "payload_keys": sorted(str(key) for key in payload.keys()),
        "payload_preview": redacted_payload_preview(payload),
        "recorded_at": utc_now(),
    }
    write_json(path, record)
```

- [x] **Step 4: Call the probe before event dispatch**

In `main()`, after `event_name`, `session_id`, and `payload` are available, call:

```python
write_payload_probe(payload, event_name, session_id)
```

- [x] **Step 5: Verify**

Run:

```bash
bash tests/test-context-contract-hook.sh
```

Expected: PASS.

- [x] **Step 6: Commit checkpoint intentionally skipped**

```bash
git add shared/hooks/managed/codex_context_continuity.py tests/test-context-contract-hook.sh
git commit -m "feat: add codex context payload probe"
```

Not run in this session: the user did not request commits, so changes remain uncommitted for review.

---

### Task 3: Pass Explicit Hook Event And Source Arguments

**Files:**
- Modify: `tools/community/render_hook_registry.py`
- Modify: `shared/hooks/registry.json`
- Modify: `shared/hooks/managed/codex_context_continuity.py`
- Modify: `tests/test-skill-output-and-gate-contract.sh`
- Modify: `tests/test-context-contract-hook.sh`

**Interfaces:**
- Consumes: optional registry field `args`
- Produces: rendered hook commands such as `codex_context_continuity.py --event SessionStart --source compact`

- [x] **Step 1: Add failing rendered-command assertions**

In `tests/test-skill-output-and-gate-contract.sh`, after the opt-in context-continuity render block, add:

```bash
jq -e '
  any(.hooks.PreCompact[]?.hooks[]?.command; contains("codex_context_continuity.py --event PreCompact"))
  and any(.hooks.PostCompact[]?.hooks[]?.command; contains("codex_context_continuity.py --event PostCompact"))
  and any(.hooks.SessionStart[]?.hooks[]?.command; contains("codex_context_continuity.py --event SessionStart --source compact"))
' "$opt_in_rendered" >/dev/null 2>&1 || fail "context continuity commands should pass explicit event/source args"
```

- [x] **Step 2: Run and verify failure**

Run:

```bash
bash tests/test-skill-output-and-gate-contract.sh
```

Expected: FAIL with `context continuity commands should pass explicit event/source args`.

- [x] **Step 3: Add argument rendering**

In `tools/community/render_hook_registry.py`, import `shlex`:

```python
import shlex
```

Add:

```python
def render_command_args(args: list[str] | None) -> str:
    if not args:
        return ""
    return " " + " ".join(shlex.quote(str(arg)) for arg in args)
```

In registry validation, reject malformed args:

```python
args = payload.get("args")
if args is not None and (
    not isinstance(args, list) or any(not isinstance(arg, str) for arg in args)
):
    raise ValueError(f"{hook_id}: args must be a list of strings")
```

Change command construction in `render_runtime_hook_entries` to:

```python
command = render_command(
    runtime_home, payload["launcher"], payload["command_rel"], python_launcher
) + render_command_args(payload.get("args"))
```

- [x] **Step 4: Add registry args**

Update context-continuity entries in `shared/hooks/registry.json`:

```json
"args": ["--event", "UserPromptSubmit"]
```

for the `UserPromptSubmit` entry,

```json
"args": ["--event", "Stop"]
```

for `Stop`,

```json
"args": ["--event", "PreCompact"]
```

for `PreCompact`,

```json
"args": ["--event", "PostCompact"]
```

for `PostCompact`, and

```json
"args": ["--event", "SessionStart", "--source", "compact"]
```

for `SessionStart`.

- [x] **Step 5: Support `--source` in the hook**

In `shared/hooks/managed/codex_context_continuity.py`, add:

```python
parser.add_argument("--source", help="Override hook source or matcher value.")
```

Add:

```python
def resolve_source(payload: dict[str, Any], override: str | None) -> str:
    return override or str(payload.get("source") or payload.get("matcher") or payload.get("trigger") or "")
```

Use:

```python
source = resolve_source(payload, args.source)
```

and change the `SessionStart` branch to:

```python
if event_name == "SessionStart":
    if source == "compact":
        emit_sessionstart_compact(state_path, state)
    return 0
```

- [x] **Step 6: Add missing source regression**

In `tests/test-context-contract-hook.sh`, add a case where the payload only has `hook_event_name: "SessionStart"` and the command supplies `--source compact`:

```bash
sessionstart_arg_output="$(printf '%s' "$sessionstart_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY" --event SessionStart --source compact)" \
  || fail "SessionStart compact source arg should emit recovery context"
printf '%s' "$sessionstart_arg_output" | jq -e '.hookSpecificOutput.additionalContext | contains("task_state_ref:")' >/dev/null 2>&1 \
  || fail "SessionStart source arg should drive compact recovery"
```

- [x] **Step 7: Verify**

Run:

```bash
bash tests/test-skill-output-and-gate-contract.sh
bash tests/test-context-contract-hook.sh
```

Expected: both PASS.

- [x] **Step 8: Commit checkpoint intentionally skipped**

```bash
git add tools/community/render_hook_registry.py shared/hooks/registry.json shared/hooks/managed/codex_context_continuity.py tests/test-skill-output-and-gate-contract.sh tests/test-context-contract-hook.sh
git commit -m "feat: pass explicit codex hook event args"
```

Not run in this session: the user did not request commits, so changes remain uncommitted for review.

---

### Task 4: Upgrade The State Card And Recovery Blocking

**Files:**
- Modify: `shared/hooks/managed/codex_context_continuity.py`
- Modify: `tests/test-context-contract-hook.sh`

**Interfaces:**
- Produces: state card fields from the design: `last_user_prompt_hash`, `last_user_prompt_preview`, `active_goal`, `scope_boundary`, `non_goals`, `latest_user_correction`, `current_phase`, `current_plan`, `completed_items`, `evidence_refs`, `pending_items`, `blockers`, `next_action`, `git_head`, and `truth_policy`.
- Produces: visible recovery block when required state is absent.

- [x] **Step 1: Add failing state-card assertions**

In `tests/test-context-contract-hook.sh`, replace the old raw prompt assertion (`.latest_user_prompt.preview == $correction`) and `status_card.objective == ""` assertions with:

```bash
jq -e '
  .active_goal == ""
  and .scope_boundary == ""
  and .non_goals == []
  and (.last_user_prompt_hash | type == "string" and length == 64)
  and (.last_user_prompt_preview | type == "string" and length <= 240)
  and .latest_user_correction == ""
  and .current_phase == ""
  and .current_plan == []
  and .completed_items == []
  and .evidence_refs == []
  and .pending_items == []
  and .blockers == []
  and .next_action == ""
  and (.truth_policy | contains("禁止猜测"))
' "$context_card" >/dev/null 2>&1 || fail "context continuity should initialize recovery-ready state fields"
```

- [x] **Step 2: Add missing-session regression**

Add:

```bash
missing_session_payload='{"hook_event_name":"UserPromptSubmit","prompt":"no session"}'
if printf '%s' "$missing_session_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY" >/dev/null 2>"$TMP_DIR/context-missing-session.err"; then
  fail "missing session id should fail visibly"
fi
assert_present "missing session_id" "$TMP_DIR/context-missing-session.err"
assert_path_absent "$CONTEXT_STATE/unknown-session.json"
```

Add a prompt privacy regression:

```bash
secret_prompt_payload="$(jq -nc \
  --arg sid "privacy-session" \
  --arg prompt "secret-token-123 should not be stored in full" \
  --arg cwd "$TMP_DIR/project" \
  '{session_id: $sid, hook_event_name: "UserPromptSubmit", prompt: $prompt, cwd: $cwd}')"
printf '%s' "$secret_prompt_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY" >/dev/null \
  || fail "privacy prompt should be recorded as redacted metadata"
assert_absent "secret-token-123" "$CONTEXT_STATE/privacy-session.json"
jq -e '
  (.last_user_prompt_hash | type == "string" and length == 64)
  and (.last_user_prompt_preview | contains("[REDACTED]"))
' "$CONTEXT_STATE/privacy-session.json" >/dev/null 2>&1 || fail "prompt preview should be short and redacted"
```

- [x] **Step 3: Run and verify failure**

Run:

```bash
bash tests/test-context-contract-hook.sh
```

Expected: FAIL on missing recovery-ready fields or missing-session behavior.

- [x] **Step 4: Replace `STATUS_CARD_DEFAULT` with top-level recovery fields**

In `shared/hooks/managed/codex_context_continuity.py`, define:

```python
RECOVERY_DEFAULTS = {
    "last_user_prompt_hash": "",
    "last_user_prompt_preview": "",
    "active_goal": "",
    "scope_boundary": "",
    "non_goals": [],
    "latest_user_correction": "",
    "current_phase": "",
    "current_plan": [],
    "completed_items": [],
    "evidence_refs": [],
    "pending_items": [],
    "blockers": [],
    "next_action": "",
    "git_head": "",
    "truth_policy": "恢复时优先读取 task_state_ref 和证据引用；证据不足必须报告 blocked，禁止猜测。",
}
```

In `load_state`, populate these fields without overwriting existing non-empty values.

Replace raw prompt preview storage with a short redacted preview. Keep full prompt text out of the state card:

```python
DEFAULT_PROMPT_PREVIEW_CHARS = 240
SECRET_PATTERN = re.compile(
    r"(?i)(secret|token|password|api[_-]?key)[A-Za-z0-9_:=\\-\"' ]{0,80}"
)


def redacted_prompt_preview(text: str) -> str:
    preview = text[:prompt_preview_limit()]
    return SECRET_PATTERN.sub("[REDACTED]", preview)
```

`record_user_prompt` must write:

```python
state["last_user_prompt_hash"] = sha256_text(prompt)
state["last_user_prompt_preview"] = redacted_prompt_preview(prompt)
```

Do not keep the legacy nested `latest_user_prompt.preview` raw text field.

- [x] **Step 5: Fail visibly on missing session**

Replace `sanitize_session_id` fallback behavior with:

```python
def required_session_id(payload: dict[str, Any]) -> str:
    raw = payload.get("session_id") or payload.get("sessionId")
    text = str(raw or "").strip()
    if not text:
        raise ValueError("missing session_id")
    return SESSION_SAFE.sub("_", text)[:160]
```

Use `required_session_id(payload)` in `main()`.

- [x] **Step 6: Update recovery context text**

Change `additional_context` to reference top-level fields:

```python
"1. 先读取 task_state_ref 的 active_goal、scope_boundary、latest_user_correction、current_phase、completed_items、evidence_refs、pending_items、blockers、next_action。",
"2. 若任何关键字段为空且 transcript/evidence 不足以恢复，报告 blocked，不继续执行。",
```

- [x] **Step 7: Verify**

Run:

```bash
bash tests/test-context-contract-hook.sh
```

Expected: PASS.

- [x] **Step 8: Commit checkpoint intentionally skipped**

```bash
git add shared/hooks/managed/codex_context_continuity.py tests/test-context-contract-hook.sh
git commit -m "feat: add recovery-ready codex state card"
```

Not run in this session: the user did not request commits, so changes remain uncommitted for review.

---

### Task 5: Wire Opt-In Install Probe And Trust Checks

**Files:**
- Modify: `install.sh`
- Modify: `tools/dev/probe-codex-hooks.sh`
- Modify: `tests/test-install-runtime-quick-canary.sh`
- Modify: `tests/test-install-runtime.sh`
- Modify: `tests/test-codex-hook-trust-audit.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: `ORG_CODEX_CONTEXT_CONTINUITY_ENABLED=1`
- Produces: opt-in hook registration, trusted-command audit expectation, and simulated recovery probe.

- [x] **Step 1: Add failing opt-in canary assertion**

Add a new case to `tests/test-install-runtime-quick-canary.sh`:

```bash
if [ "$GROUP" = "all" ] || [ "$GROUP" = "codex-context-continuity" ]; then
  install_test_case_start "runtime-quick-canary: codex context continuity opt-in probe"
  home_dir="$(install_test_new_home runtime-quick-canary-context-continuity)"
  (
    export ORG_CODEX_CONTEXT_CONTINUITY_ENABLED=1
    install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-quick-canary-context-continuity-install)" --target codex --check quick
  )
  install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/codex_context_continuity.py" "context continuity should install when explicitly enabled"
  install_test_assert_file_contains "$(install_test_log_path runtime-quick-canary-context-continuity-install)" "context continuity probe passed" "opt-in install should run recovery probe"
  install_test_case_pass "runtime-quick-canary: codex context continuity opt-in probe"
fi
```

Also update usage and group validation to include `codex-context-continuity`.

- [x] **Step 2: Run and verify failure**

Run:

```bash
ORG_CODEX_CONTEXT_CONTINUITY_ENABLED=1 bash tests/test-install-runtime-quick-canary.sh --group codex-context-continuity
```

Expected: FAIL because install does not yet emit `context continuity probe passed`.

- [x] **Step 3: Add install probe function**

Add to `install.sh`:

```bash
check_codex_context_continuity_probe() {
  local state_dir payload output

  codex_context_continuity_enabled || return 0
  state_dir="$(mktemp -d)"
  payload="$("$PYTHON_LAUNCHER" - "$PWD" <<'PY'
import json
import sys

print(json.dumps({
    "session_id": "install-context-continuity-probe",
    "hook_event_name": "SessionStart",
    "source": "compact",
    "cwd": sys.argv[1],
}))
PY
)"
  output="$(printf '%s' "$payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$state_dir" "$PYTHON_LAUNCHER" "$CODEX_DIR/hooks/managed/codex_context_continuity.py" --event SessionStart --source compact)"
  printf '%s' "$output" | grep -Fq 'task_state_ref:' || fail "Quick Check 失败: context continuity probe 未输出 task_state_ref"
  rm -rf "$state_dir"
  log "context continuity probe passed"
}
```

Call it in the Codex `quick_check` path after hook registration checks and before `check_codex_hook_trust`.

- [x] **Step 4: Update trust probe expectations**

In `install.sh`, update `required_codex_hook_commands` so context-continuity opt-in expects all five rendered commands with explicit args:

```bash
if codex_context_continuity_enabled; then
  printf '%s\n' \
    "$PYTHON_LAUNCHER $CODEX_DIR/hooks/managed/codex_context_continuity.py --event UserPromptSubmit" \
    "$PYTHON_LAUNCHER $CODEX_DIR/hooks/managed/codex_context_continuity.py --event Stop" \
    "$PYTHON_LAUNCHER $CODEX_DIR/hooks/managed/codex_context_continuity.py --event PreCompact" \
    "$PYTHON_LAUNCHER $CODEX_DIR/hooks/managed/codex_context_continuity.py --event PostCompact" \
    "$PYTHON_LAUNCHER $CODEX_DIR/hooks/managed/codex_context_continuity.py --event SessionStart --source compact"
fi
```

In `tools/dev/probe-codex-hooks.sh`, keep the context-continuity expected commands only under:

```bash
if [ "${ORG_CODEX_CONTEXT_CONTINUITY_ENABLED:-0}" = "1" ]; then
```

Expected commands must include the `--event` and `--source` args exactly because `audit_codex_hook_trust.py` matches full command strings.

In `tests/test-codex-hook-trust-audit.sh`, update the fake Codex app-server opt-in commands to emit the same five command strings and keep the expected ready count at 9.

- [x] **Step 5: Update README**

Add a short section:

```markdown
### Codex context continuity

Codex context continuity is opt-in:

```bash
ORG_CODEX_CONTEXT_CONTINUITY_ENABLED=1 bash install.sh --target codex --check quick
```

It records a compact recovery state card and probe metadata. It does not replace Codex memories and does not use compact summaries as truth. If recovery state is missing or stale, Codex must stop and ask for recovery evidence instead of continuing from guesses.
```

- [x] **Step 6: Verify**

Run:

```bash
ORG_CODEX_CONTEXT_CONTINUITY_ENABLED=1 bash tests/test-install-runtime-quick-canary.sh --group codex-context-continuity
bash tests/test-install-runtime-quick-canary.sh --group codex-install
bash tests/test-codex-hook-trust-audit.sh
```

Expected: all PASS.

- [x] **Step 7: Commit checkpoint intentionally skipped**

```bash
git add install.sh tools/dev/probe-codex-hooks.sh tests/test-install-runtime-quick-canary.sh tests/test-install-runtime.sh tests/test-codex-hook-trust-audit.sh README.md
git commit -m "feat: probe opt-in codex context continuity install"
```

Not run in this session: the user did not request commits, so changes remain uncommitted for review.

---

### Task 6: Final Gate And Handoff

**Files:**
- Modify only files touched by previous tasks if final polish is needed.

**Interfaces:**
- Produces: verified implementation with no uncommitted task residue except explicitly reported user WIP.

- [x] **Step 1: Run focused tests**

Run:

```bash
python3 tests/test-render-runtime-placeholders.py
bash tests/test-context-contract-hook.sh
bash tests/test-skill-output-and-gate-contract.sh
bash tests/test-install-runtime-quick-canary.sh --group codex-install
ORG_CODEX_CONTEXT_CONTINUITY_ENABLED=1 bash tests/test-install-runtime-quick-canary.sh --group codex-context-continuity
```

Expected: all PASS.

- [x] **Step 2: Run quick gate**

Run:

```bash
bash tests/run-all.sh --quick
```

Expected: `All tests passed`.

- [x] **Step 3: Inspect diff**

Run:

```bash
git diff --check
git status --short
```

Expected: `git diff --check` exits 0. `git status --short` shows only intentional files for the final task or is clean after commits.

- [x] **Step 4: Final commit intentionally skipped**

If Step 3 shows intentional uncommitted changes:

```bash
git add <intentional-files>
git commit -m "test: verify codex context continuity"
```

Use exact file paths from `git status --short`; do not stage unrelated user changes.

Not run in this session: the user did not request commits, so changes remain uncommitted for review.

---

## Self-Review

Spec coverage:

- Payload probing is covered by Task 2.
- Explicit event/source rendering is covered by Task 3.
- Recovery-ready state card and missing-state blocking are covered by Task 4.
- Opt-in install, trust, and recovery probe are covered by Task 5.
- Quick and focused validation are covered by Task 6.
- The current install canary timeout is covered first by Task 1.

No broad memory system is introduced. Compact summary remains metadata only. Default enablement remains blocked until opt-in behavior is stable.

## Execution Evidence

- `ORG_CODEX_CONTEXT_CONTINUITY_ENABLED=1 python3 tools/community/audit_codex_hook_trust.py --cwd /Users/lijieli/org-claude-skills --require-ready`: `ready=12 not_ready=0 extra_not_ready=0`.
- `ORG_CODEX_CONTEXT_CONTINUITY_ENABLED=1 bash install.sh --target codex --check quick`: `context continuity probe passed`, `ready=10 not_ready=0 extra_not_ready=0`, `Quick Check 通过`.
- `bash tests/run-all.sh --quick`: 37/37 passed, `All tests passed`.
- `git diff --check`: exit 0.
- The real local Codex hook trust gate was completed through the supported CLI `/hooks` review flow using `Trust all and continue`.

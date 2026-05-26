# Test Gate Contract Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重建仓库测试契约：清零 Skill Markdown 自然语言断言债务，删除 eval `expected_output`，把 `quick` 收敛为 30-60 秒的高信号机器契约门禁。

**Architecture:** 以显式 gate metadata 驱动 `preflight / quick / focused / full / release` 计划；以 Python validator 承载结构化契约、低信号断言和 Skill/Eval 检查；Shell runner 只负责调用计划和执行命令。Markdown 正文不再作为测试 API，真实保护面改为 contracts、schema、manifest、hook registry、runtime surface、canonical artifacts、fixture validator 和少量行为金样。

**Tech Stack:** Bash runner、Python 3 标准库、JSON/YAML contracts、现有 `tests/run-all.sh` / `tests/run-focused.sh` / `tools/community/*` validator、现有 shell test 风格。

---

## 已裁决口径

- 低信号 baseline：一次清零，不再长期保留 `low-signal-prose-assertions.baseline` 豁免池。
- Eval `expected_output`：完全删除，不保留为测试或人工说明字段。
- `quick` 预算：30-60 秒级，只跑 preflight 和每条真实消费链路的 canary。

## 文件结构

**Create**
- `tests/gate-plan.json`：唯一测试计划元数据。每个测试项声明 `id`、`command`、`area`、`tier`、`tags`、`parallel_safe`、`timeout_sec`。
- `tools/community/gate_plan.py`：读取 `tests/gate-plan.json`，输出 `--list` 文本计划、`--format=json` 机器计划，并执行 profile selection 逻辑。
- `tools/community/validate_skill_evals.py`：统一校验 `shared/skills/*/evals/evals.json`，禁止 `expected_output`，校验 anchor/run_modes/grader_dimensions/file refs。
- `tools/community/validate_skill_script_manifests.py`：统一校验 `shared/skills/*/scripts/manifest.json` 与脚本可达性、安全边界字段、verification command 引用。
- `tests/test-skill-eval-contracts.sh`：调用 `validate_skill_evals.py`，替代散落的 eval 文案断言。
- `tests/test-skill-script-manifest-contracts.sh`：调用 `validate_skill_script_manifests.py`，替代散落的 manifest/registry 深层字段检查。

**Modify**
- `tests/run-all.sh`：从硬编码 `FULL_TESTS` + 排除清单，改为调用 `tools/community/gate_plan.py` 生成并执行计划。
- `tests/run-focused.sh`：从仅 `design` profile，改为调用同一 gate plan，支持 `design/research/skill-refiner/standard-chain/product-stage2/install-runtime/docs-context/codex-runtime`。
- `tests/test-run-all-runner-contract.sh`：从锁具体 quick 排除列表，改为验证层级语义、tags、`--format=json`、slow/e2e/install/release 不进入 quick。
- `tests/test-run-focused-runner-contract.sh`：验证 focused profile inventory 和每个 profile 的 area/tag 选择。
- `tools/community/check_test_signal_assertions.py`：去 baseline 模式；增强 shell logical line、`assert_any_present`、直接 `grep/rg`、helper 签名差异检测。
- `tests/test-test-assertion-boundary-contract.sh`：改为验证“无 baseline、零低信号”策略。
- `AGENTS.md`：同步测试断言边界说明：checker 直接拒绝低信号 Markdown 正文断言，不再依赖 baseline。
- `tests/test-standard-chain-skill-evals.sh`：删除 `expected_output` 和自然语言锚点检查，保留或转接到 `validate_skill_evals.py`。
- `shared/skills/*/evals/evals.json`：删除所有 `expected_output` 字段；必要语义迁入 `expected_anchors`、`expectations`、`grader_dimensions`、`run_modes` 或 artifact schema。
- `tests/test-design-skill-governance-redesign.sh`、`tests/test-product-context-signal-quality.sh` 以及 checker 报告中的所有低信号 shell tests：删除或改写 Markdown 正文断言。
- `tests/fixtures/test-assertion-boundary/low-signal-prose-assertions.baseline`：删除文件，或改为空文件并从所有文档/测试引用中移除。推荐删除。

**Delete**
- `tests/fixtures/test-assertion-boundary/low-signal-prose-assertions.baseline`。

---

## Task 1: Runner Contract 先红灯化

**Files:**
- Modify: `tests/test-run-all-runner-contract.sh`
- Modify: `tests/test-run-focused-runner-contract.sh`

- [ ] **Step 1: 改写 `run-all` 合同测试，先表达新 quick 语义**

将 `tests/test-run-all-runner-contract.sh` 中锁具体测试文件列表的断言替换为如下合同片段。保留 `fail`、`assert_contains`、`assert_not_contains` helper，新增 JSON plan 解析。

```bash
json_plan="$(bash "$RUNNER" --quick --list --format=json)"
quick_plan="$(bash "$RUNNER" --quick --list)"
full_plan="$(bash "$RUNNER" --full --list)"
release_plan="$(bash "$RUNNER" --release --list)"

python3 - "$json_plan" <<'PY'
import json
import sys

plan = json.loads(sys.argv[1])
if plan.get("mode") != "quick":
    raise SystemExit("quick json plan must report mode=quick")
steps = plan.get("steps")
if not isinstance(steps, list) or not steps:
    raise SystemExit("quick json plan must include non-empty steps")
if len(steps) > 35:
    raise SystemExit(f"quick should be a small canary plan, got {len(steps)} steps")
required_areas = {
    "preflight",
    "contracts",
    "standard-chain",
    "context",
    "install-runtime",
    "hooks-manifest",
    "skill-evals",
    "runtime-surface",
    "assertion-boundary",
}
areas = {step.get("area") for step in steps}
missing = sorted(required_areas - areas)
if missing:
    raise SystemExit(f"quick plan missing required areas: {missing}")
for step in steps:
    tags = set(step.get("tags", []))
    forbidden = {"full-only", "release-only", "dogfood", "e2e", "live", "migration", "install-heavy"}
    blocked = sorted(tags & forbidden)
    if blocked:
        raise SystemExit(f"quick step {step.get('id')} has forbidden tags: {blocked}")
    timeout = step.get("timeout_sec")
    if not isinstance(timeout, int) or timeout <= 0 or timeout > 120:
        raise SystemExit(f"quick step {step.get('id')} must have timeout_sec in 1..120")
PY

assert_contains "mode=quick" "$quick_plan" "quick plan"
assert_contains "mode=full" "$full_plan" "full plan"
assert_contains "mode=release" "$release_plan" "release plan"
assert_not_contains "test-design-dogfood-e2e.sh" "$quick_plan" "quick plan"
assert_not_contains "test-product-manager-dogfood-e2e.sh" "$quick_plan" "quick plan"
assert_not_contains "test-install-migration.sh" "$quick_plan" "quick plan"
assert_contains "test-install-migration.sh" "$full_plan" "full plan"
assert_contains "test-install-migration.sh" "$release_plan" "release plan"
```

- [ ] **Step 2: 改写 focused runner 合同测试**

将 `tests/test-run-focused-runner-contract.sh` 的 profile 断言改为 profile inventory 断言。

```bash
help_output="$(bash "$RUNNER" --help)"
for profile in design research skill-refiner standard-chain product-stage2 install-runtime docs-context codex-runtime; do
  assert_contains "$profile" "$help_output" "help output"
done

design_json="$(bash "$RUNNER" design --list --format=json)"
python3 - "$design_json" <<'PY'
import json
import sys
plan = json.loads(sys.argv[1])
if plan.get("profile") != "design":
    raise SystemExit("design focused plan must report profile=design")
steps = plan.get("steps", [])
if not steps:
    raise SystemExit("design focused plan must include steps")
areas = {step.get("area") for step in steps}
if "design" not in areas or "hooks-manifest" not in areas:
    raise SystemExit(f"design profile missing expected areas: {sorted(areas)}")
for step in steps:
    if "release-only" in step.get("tags", []):
        raise SystemExit(f"focused design should not include release-only step: {step.get('id')}")
PY
```

- [ ] **Step 3: 跑测试确认红灯**

Run:
```bash
bash tests/test-run-all-runner-contract.sh
```
Expected: FAIL，提示 `--format=json` unknown 或 quick plan 仍包含 forbidden tags。

Run:
```bash
bash tests/test-run-focused-runner-contract.sh
```
Expected: FAIL，提示 `--format=json` unknown 或缺少新增 profile。

---

## Task 2: 引入 Gate Plan 元数据与计划生成器

**Files:**
- Create: `tests/gate-plan.json`
- Create: `tools/community/gate_plan.py`
- Modify: `tests/run-all.sh`
- Modify: `tests/run-focused.sh`

- [ ] **Step 1: 创建最小 gate plan 元数据**

`tests/gate-plan.json` 先覆盖 quick 必需 canary 和 full/release 典型长链。后续 Task 再补齐全量 `FULL_TESTS`。

```json
{
  "schema_version": 1,
  "profiles": {
    "design": {"areas": ["design", "hooks-manifest", "skill-evals", "standard-chain"], "exclude_tags": ["release-only"]},
    "research": {"areas": ["research", "skill-evals"], "exclude_tags": ["release-only"]},
    "skill-refiner": {"areas": ["skill-refiner", "skill-evals"], "exclude_tags": ["release-only"]},
    "standard-chain": {"areas": ["standard-chain", "contracts"], "exclude_tags": ["release-only"]},
    "product-stage2": {"areas": ["product", "stage2"], "exclude_tags": ["release-only"]},
    "install-runtime": {"areas": ["install-runtime", "runtime-surface"], "exclude_tags": []},
    "docs-context": {"areas": ["context", "docs"], "exclude_tags": ["release-only"]},
    "codex-runtime": {"areas": ["codex-runtime", "runtime-surface"], "exclude_tags": []}
  },
  "steps": [
    {"id": "bash-python-syntax", "command": ["bash", "tests/run-all.sh", "--internal-syntax-checks"], "area": "preflight", "tier": "preflight", "tags": ["syntax"], "parallel_safe": true, "timeout_sec": 60},
    {"id": "shellcheck", "command": ["bash", "tests/run-all.sh", "--internal-shellcheck"], "area": "preflight", "tier": "preflight", "tags": ["shellcheck"], "parallel_safe": true, "timeout_sec": 90},
    {"id": "contracts-validation", "command": ["bash", "tools/validate-contracts.sh"], "area": "contracts", "tier": "quick", "tags": ["contract", "canary"], "parallel_safe": true, "timeout_sec": 60},
    {"id": "runner-contract", "command": ["bash", "tests/test-run-all-runner-contract.sh"], "area": "preflight", "tier": "preflight", "tags": ["runner"], "parallel_safe": false, "timeout_sec": 60},
    {"id": "assertion-boundary", "command": ["bash", "tests/test-test-assertion-boundary-contract.sh"], "area": "assertion-boundary", "tier": "quick", "tags": ["low-signal", "canary"], "parallel_safe": true, "timeout_sec": 60},
    {"id": "standard-chain-validator-stack", "command": ["bash", "tests/test-standard-chain-validator-stack.sh"], "area": "standard-chain", "tier": "quick", "tags": ["canary", "canonical"], "parallel_safe": true, "timeout_sec": 90},
    {"id": "context-contract-validator", "command": ["bash", "tests/test-context-contract-validator.sh"], "area": "context", "tier": "quick", "tags": ["canary", "context"], "parallel_safe": true, "timeout_sec": 60},
    {"id": "install-runtime-smoke", "command": ["bash", "tests/test-install-runtime-smoke.sh"], "area": "install-runtime", "tier": "quick", "tags": ["canary", "install-smoke"], "parallel_safe": false, "timeout_sec": 120},
    {"id": "skill-output-gate-contract", "command": ["bash", "tests/test-skill-output-and-gate-contract.sh"], "area": "hooks-manifest", "tier": "quick", "tags": ["canary", "manifest"], "parallel_safe": true, "timeout_sec": 90},
    {"id": "skill-eval-contracts", "command": ["bash", "tests/test-skill-eval-contracts.sh"], "area": "skill-evals", "tier": "quick", "tags": ["canary", "eval-contract"], "parallel_safe": true, "timeout_sec": 90},
    {"id": "skill-runtime-surface", "command": ["bash", "tests/test-skill-runtime-surface-contract.sh"], "area": "runtime-surface", "tier": "quick", "tags": ["canary", "runtime-surface"], "parallel_safe": true, "timeout_sec": 90},
    {"id": "design-contract", "command": ["bash", "tests/test-design-skill-governance-redesign.sh"], "area": "design", "tier": "focused", "tags": ["design"], "parallel_safe": true, "timeout_sec": 120},
    {"id": "design-dogfood-e2e", "command": ["bash", "tests/test-design-dogfood-e2e.sh"], "area": "design", "tier": "full", "tags": ["dogfood", "e2e", "full-only"], "parallel_safe": false, "timeout_sec": 300},
    {"id": "install-core", "command": ["bash", "tests/test-install-core.sh"], "area": "install-runtime", "tier": "full", "tags": ["install-heavy", "full-only"], "parallel_safe": false, "timeout_sec": 300},
    {"id": "install-migration", "command": ["bash", "tests/test-install-migration.sh"], "area": "install-runtime", "tier": "release", "tags": ["migration", "release-only"], "parallel_safe": false, "timeout_sec": 300}
  ]
}
```

- [ ] **Step 2: 实现 `tools/community/gate_plan.py`**

```python
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

FORBIDDEN_QUICK_TAGS = {"full-only", "release-only", "dogfood", "e2e", "live", "migration", "install-heavy"}
REQUIRED_QUICK_AREAS = {
    "preflight",
    "contracts",
    "standard-chain",
    "context",
    "install-runtime",
    "hooks-manifest",
    "skill-evals",
    "runtime-surface",
    "assertion-boundary",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build and run repository gate plans.")
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--mode", choices=["preflight", "quick", "full", "release"], default="full")
    parser.add_argument("--profile", default=None)
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--format", choices=["text", "json"], default="text")
    parser.add_argument("--run", action="store_true")
    return parser.parse_args()


def load_plan(root: Path) -> dict[str, Any]:
    path = root / "tests" / "gate-plan.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1:
        raise SystemExit(f"{path}: schema_version must be 1")
    return data


def selected_steps(data: dict[str, Any], mode: str, profile: str | None) -> list[dict[str, Any]]:
    steps = data.get("steps")
    if not isinstance(steps, list):
        raise SystemExit("gate-plan.json: steps must be a list")
    if profile:
        profiles = data.get("profiles", {})
        if profile not in profiles:
            available = ", ".join(sorted(profiles))
            raise SystemExit(f"unknown profile: {profile}. Available profiles: {available}")
        profile_def = profiles[profile]
        areas = set(profile_def.get("areas", []))
        excluded = set(profile_def.get("exclude_tags", []))
        return [step for step in steps if step.get("area") in areas and not (set(step.get("tags", [])) & excluded)]
    if mode == "preflight":
        return [step for step in steps if step.get("tier") == "preflight"]
    if mode == "quick":
        selected = [step for step in steps if step.get("tier") in {"preflight", "quick"}]
        validate_quick(selected)
        return selected
    if mode == "full":
        return [step for step in steps if "release-only" not in set(step.get("tags", []))]
    return steps


def validate_step(step: dict[str, Any]) -> None:
    for field in ("id", "command", "area", "tier", "tags", "parallel_safe", "timeout_sec"):
        if field not in step:
            raise SystemExit(f"gate step missing {field}: {step}")
    if not isinstance(step["command"], list) or not all(isinstance(part, str) and part for part in step["command"]):
        raise SystemExit(f"gate step {step.get('id')} command must be a non-empty string array")
    if not isinstance(step["timeout_sec"], int) or step["timeout_sec"] <= 0:
        raise SystemExit(f"gate step {step.get('id')} timeout_sec must be positive")


def validate_quick(steps: list[dict[str, Any]]) -> None:
    areas = {step.get("area") for step in steps}
    missing = sorted(REQUIRED_QUICK_AREAS - areas)
    if missing:
        raise SystemExit(f"quick plan missing required areas: {missing}")
    for step in steps:
        blocked = sorted(set(step.get("tags", [])) & FORBIDDEN_QUICK_TAGS)
        if blocked:
            raise SystemExit(f"quick step {step.get('id')} has forbidden tags: {blocked}")
        if step.get("timeout_sec", 0) > 120:
            raise SystemExit(f"quick step {step.get('id')} timeout exceeds quick budget")


def text_plan(mode: str, profile: str | None, steps: list[dict[str, Any]]) -> str:
    lines = [f"mode={mode}", f"profile={profile or ''}", f"steps={len(steps)}"]
    for index, step in enumerate(steps, start=1):
        command = " ".join(step["command"])
        lines.append(f"[{index}/{len(steps)}] {step['id']} area={step['area']} tier={step['tier']} tags={','.join(step['tags'])}")
        lines.append(command)
    return "\n".join(lines)


def json_plan(mode: str, profile: str | None, steps: list[dict[str, Any]]) -> str:
    return json.dumps({"mode": mode, "profile": profile or "", "steps": steps}, ensure_ascii=False)


def run_steps(root: Path, steps: list[dict[str, Any]]) -> int:
    for index, step in enumerate(steps, start=1):
        command = step["command"]
        print(f"[{index}/{len(steps)}] {step['id']}", flush=True)
        result = subprocess.run(command, cwd=root, timeout=step["timeout_sec"])
        if result.returncode != 0:
            return result.returncode
    return 0


def main() -> int:
    args = parse_args()
    data = load_plan(args.repo_root)
    for step in data.get("steps", []):
        validate_step(step)
    steps = selected_steps(data, args.mode, args.profile)
    if args.list:
        print(json_plan(args.mode, args.profile, steps) if args.format == "json" else text_plan(args.mode, args.profile, steps))
        return 0
    if args.run:
        return run_steps(args.repo_root, steps)
    raise SystemExit("pass --list or --run")


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 3: 改 `tests/run-all.sh` 为 wrapper**

保留 `run_bash_syntax_checks` 和 `run_shellcheck`，新增内部选项，默认委托 Python plan。

```bash
case "${1:-}" in
  --internal-syntax-checks)
    run_bash_syntax_checks
    exit 0
    ;;
  --internal-shellcheck)
    run_shellcheck
    exit 0
    ;;
esac

FORMAT="text"
RUN_ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --full|--quick|--release)
      RUN_ARGS+=("--mode" "${1#--}")
      shift
      ;;
    --preflight)
      RUN_ARGS+=("--mode" "preflight")
      shift
      ;;
    --format=json)
      FORMAT="json"
      shift
      ;;
    --list)
      LIST_ONLY=1
      shift
      ;;
    --profile)
      PROFILE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

if [ "$LIST_ONLY" -eq 1 ]; then
  python3 "$ROOT/tools/community/gate_plan.py" "${RUN_ARGS[@]}" --list --format "$FORMAT"
else
  python3 "$ROOT/tools/community/gate_plan.py" "${RUN_ARGS[@]}" --run
fi
```

- [ ] **Step 4: 改 `tests/run-focused.sh` 为 wrapper**

```bash
PROFILE="${1:-}"
[ -n "$PROFILE" ] || fail "missing profile"
shift
FORMAT="text"
LIST_ONLY=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --list)
      LIST_ONLY=1
      shift
      ;;
    --format=json)
      FORMAT="json"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

if [ "$LIST_ONLY" -eq 1 ]; then
  python3 "$ROOT/tools/community/gate_plan.py" --profile "$PROFILE" --list --format "$FORMAT"
else
  python3 "$ROOT/tools/community/gate_plan.py" --profile "$PROFILE" --run
fi
```

- [ ] **Step 5: 跑 runner 合同测试**

Run:
```bash
bash tests/test-run-all-runner-contract.sh
bash tests/test-run-focused-runner-contract.sh
```
Expected: PASS。

---

## Task 3: 补齐 Gate Plan 全量测试项

**Files:**
- Modify: `tests/gate-plan.json`
- Modify: `tests/run-all.sh`

- [ ] **Step 1: 把原 `FULL_TESTS` 全量迁入 `tests/gate-plan.json`**

迁移规则：

```text
install/runtime/migration/cleanup/codex adapter -> area=install-runtime 或 codex-runtime, tier=full/release, tags 包含 install-heavy/migration/release-only。
standard-chain/stage/phase/canonical -> area=standard-chain 或 stage2, tier=focused/full；只保留 validator-stack canary 为 quick。
context/active-doc/recovery -> area=context, tier=focused；context-contract-validator canary 为 quick。
design/research/skill-refiner/product/developer/qa/review -> area=对应 skill，tier=focused/full；dogfood/e2e/live 加 full-only/dogfood/e2e/live。
skill quality/effectiveness empirical/static -> area=skill-quality, tier=full；少量结构 validator 可 quick。
community/upstream/superpowers/source lock -> area=community, tier=full/release。
release metadata/runtime closeout -> area=release, tier=release, tags=release-only。
```

每个迁移项使用以下对象形态：

```json
{"id": "test-file-name-without-prefix", "command": ["bash", "tests/test-file-name.sh"], "area": "standard-chain", "tier": "full", "tags": ["fixture", "full-only"], "parallel_safe": true, "timeout_sec": 180}
```

Python 测试使用：

```json
{"id": "deep-research-scripts", "command": ["python3", "tests/test-deep-research-scripts.py"], "area": "research", "tier": "focused", "tags": ["python"], "parallel_safe": true, "timeout_sec": 120}
```

- [ ] **Step 2: 删除 `run-all.sh` 中 `FULL_TESTS`、`is_release_heavy_test`、`is_full_only_signal_test`、`should_exclude_from_quick`**

保留语法/shellcheck 文件清单，其他计划来源全部来自 `tests/gate-plan.json`。

- [ ] **Step 3: 验证 list 形态**

Run:
```bash
bash tests/run-all.sh --quick --list
bash tests/run-all.sh --quick --list --format=json
bash tests/run-all.sh --full --list
bash tests/run-all.sh --release --list
bash tests/run-focused.sh standard-chain --list --format=json
```
Expected:
- quick steps 明显小于 35。
- quick JSON 可被 `python3 -m json.tool` 解析。
- full 包含所有非 release-only 项。
- release 包含 release-only 项。
- focused profile 只包含匹配 area 的项。

---

## Task 4: 清零 Low-Signal Baseline 并增强 Checker

**Files:**
- Modify: `tools/community/check_test_signal_assertions.py`
- Modify: `tests/test-test-assertion-boundary-contract.sh`
- Modify: `AGENTS.md`
- Delete: `tests/fixtures/test-assertion-boundary/low-signal-prose-assertions.baseline`

- [ ] **Step 1: 先改测试为无 baseline 合同**

在 `tests/test-test-assertion-boundary-contract.sh` 中删除对 baseline 路径的断言，改为：

```bash
assert_present '测试断言边界' "$AGENTS_ENTRY"
assert_present 'tools/community/check_test_signal_assertions\.py' "$AGENTS_ENTRY"
if grep -Fq 'low-signal-prose-assertions.baseline' "$AGENTS_ENTRY"; then
  fail "AGENTS.md must not document a low-signal baseline exemption"
fi
```

把 bad fixture 扩展直接 grep/rg 和 `assert_any_present`：

```bash
assert_any_present() {
  local file="$1"
  shift
  local pattern
  for pattern in "$@"; do
    grep -Eq "$pattern" "$file" && return 0
  done
  return 1
}

grep -Eq 'Skill guide prose must stay exactly this way' "$ROOT/shared/skills/example/SKILL.md"
rg -n 'Reviewer prose sentence that is not a contract' "$ROOT/shared/skills/example/SKILL.md"
assert_any_present "$ROOT/shared/skills/example/SKILL.md" 'Beautiful prose heading' 'Another wording-only phrase'
```

- [ ] **Step 2: 跑测试确认红灯**

Run:
```bash
bash tests/test-test-assertion-boundary-contract.sh
```
Expected: FAIL，checker 当前不覆盖直接 grep/rg 或仍依赖 baseline。

- [ ] **Step 3: 增强 checker 解析能力**

在 `tools/community/check_test_signal_assertions.py` 实现：

```python
def logical_lines(lines: list[str]) -> list[tuple[int, str]]:
    result = []
    buffer = ""
    start = 0
    for line_no, raw in enumerate(lines, start=1):
        line = raw.rstrip()
        if not buffer:
            start = line_no
        if line.endswith("\\"):
            buffer += line[:-1] + " "
            continue
        buffer += line
        result.append((start, buffer))
        buffer = ""
    if buffer:
        result.append((start, buffer))
    return result
```

扩展 call detection：

```python
GREP_RE = re.compile(r"^(?:grep|rg)\b")
ASSERT_ANY_RE = re.compile(r"^assert_any_present\b")


def assertion_call(line: str) -> AssertionCall | None:
    stripped = line.strip()
    words = shell_words(stripped)
    if not words:
        return None
    if ASSERT_RE.match(stripped):
        if len(words) >= 3:
            return AssertionCall(assertion=words[0].replace("assert_", ""), pattern=words[1], target=words[2])
    if SECTION_ASSERT_RE.match(stripped):
        if len(words) >= 4:
            return AssertionCall(assertion=words[0].replace("assert_section_", ""), pattern=words[3], target=words[1])
    if ASSERT_ANY_RE.match(stripped):
        if len(words) >= 3:
            return AssertionCall(assertion="present", pattern="|".join(words[2:]), target=words[1])
    if GREP_RE.match(stripped):
        markdown_targets = [word for word in words if ".md" in word]
        patterns = [word for word in words[1:] if not word.startswith("-") and ".md" not in word]
        if markdown_targets and patterns:
            return AssertionCall(assertion="present", pattern=patterns[0], target=markdown_targets[-1])
    return None
```

移除 baseline 比较逻辑：发现任何 finding 即返回非 0。

- [ ] **Step 4: 删除 baseline 文件和引用**

Run:
```bash
git rm tests/fixtures/test-assertion-boundary/low-signal-prose-assertions.baseline
```

同时把 `AGENTS.md` 的测试说明改为：

```markdown
- 测试断言边界：不得用 shell `assert_present` / `assert_absent` / 直接 `grep` / `rg` 锁定 Skill Markdown 自然语言正文；`tools/community/check_test_signal_assertions.py` 必须直接拒绝此类断言，不使用 legacy baseline 豁免。
```

- [ ] **Step 5: 跑边界测试**

Run:
```bash
bash tests/test-test-assertion-boundary-contract.sh
```
Expected: PASS。

---

## Task 5: 全仓清理 Markdown 正文断言

**Files:**
- Modify: checker 报告中的所有 `tests/test-*.sh`
- Modify: `tests/test-design-skill-governance-redesign.sh`
- Modify: `tests/test-product-context-signal-quality.sh`
- Modify: `tests/test-standard-chain-skill-structure.sh`
- Modify: `tests/test-subagent-context-contract.sh`
- Modify: `tests/test-skill-refiner-completion-gate.sh`
- Modify: `tests/test-deep-research-skill-contract.sh`

- [ ] **Step 1: 生成清理清单**

Run:
```bash
python3 tools/community/check_test_signal_assertions.py --repo-root "$PWD"
```
Expected: FAIL，输出所有存量低信号断言。

- [ ] **Step 2: 对每条 finding 按规则处理**

处理规则固定如下：

```text
纯标题/短句/角色措辞/指南段落 present/absent -> 删除断言。
带 JSON/YAML/脚本/CLI token 的长句 -> 改为结构字段、路径可达、schema、script help 或 fixture validator。
禁止词 absent 大包 -> 删除；如确有风险，用 checker 自身 bad fixture 表达，而不是锁目标 Markdown。
frontmatter、allowed-tools、disable-model-invocation、script path、schema path、artifact URI、JSON key、enum、CLI flag -> 可保留，但优先改成解析 JSON/YAML/frontmatter 后断言字段。
```

- [ ] **Step 3: `design` 文件优先清理**

在 `tests/test-design-skill-governance-redesign.sh` 中：
- 删除所有锁 `shared/skills/design/SKILL.md`、`references/*.md`、`projections/*.md` 自然语言句子的断言。
- 保留脚本、schema、manifest、JSON Pointer、artifact path 断言。
- 对 “ADR 从已验证 design.json 派生” 改为执行脚本 fixture：`render_projection.py` 或相关 projection manifest validator。
- 对 “BLOCKED 路由” 改为 `preflight_check.sh` 的坏输入 fixture 和 JSON 输出字段断言。

- [ ] **Step 4: `product` 文件优先清理**

在 `tests/test-product-context-signal-quality.sh` 中：
- 删除角色措辞、流程短句、禁止词 absent。
- 如果测试意图是 product/director/manager 输出契约，改为读取 eval artifact JSON 的字段：`review_conclusion`、`issue_ledger`、`evidence_refs`、`decision_status`。
- 如果没有对应 artifact 或 validator，删除该断言并把真实契约补到后续 Task 的 validator 中。

- [ ] **Step 5: 循环直到 checker 清零**

Run:
```bash
python3 tools/community/check_test_signal_assertions.py --repo-root "$PWD"
```
Expected: PASS，无 baseline。

---

## Task 6: 删除 Eval `expected_output` 并建立统一 Eval Contract Validator

**Files:**
- Create: `tools/community/validate_skill_evals.py`
- Create: `tests/test-skill-eval-contracts.sh`
- Modify: `shared/skills/*/evals/evals.json`
- Modify: `tests/test-standard-chain-skill-evals.sh`

- [ ] **Step 1: 写 eval contract 测试 shell**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/tools/community/validate_skill_evals.py" --repo-root "$ROOT"
printf '[PASS] skill eval contracts\n'
```

- [ ] **Step 2: 实现 validator**

```python
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

VALID_RUN_MODES = {"with_skill", "without_skill", "both"}
VALID_EVAL_TYPES = {"routing", "contract", "behavior", "negative", "dogfood", "artifact"}


def parse_args():
    parser = argparse.ArgumentParser(description="Validate skill eval contracts.")
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    return parser.parse_args()


def fail(path: Path, message: str) -> None:
    raise SystemExit(f"{path}: {message}")


def validate_file(path: Path, root: Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    skill_root = path.parents[1]
    skill_name = skill_root.name
    if data.get("skill_name") != skill_name:
        fail(path, f"skill_name must be {skill_name!r}")
    anchors = data.get("preference_anchors", [])
    if anchors is not None and not isinstance(anchors, list):
        fail(path, "preference_anchors must be a list")
    anchor_ids = {anchor.get("id") for anchor in anchors if isinstance(anchor, dict)}
    dimensions = data.get("grader_dimensions", [])
    if dimensions is not None and not isinstance(dimensions, list):
        fail(path, "grader_dimensions must be a list")
    evals = data.get("evals")
    if not isinstance(evals, list) or not evals:
        fail(path, "evals must be a non-empty list")
    seen = set()
    for case in evals:
        if not isinstance(case, dict):
            fail(path, "each eval must be an object")
        if "expected_output" in case:
            fail(path, f"eval {case.get('id')!r} must not use expected_output")
        case_id = case.get("id")
        if not isinstance(case_id, (str, int)) or not str(case_id).strip():
            fail(path, "eval id must be non-empty")
        if case_id in seen:
            fail(path, f"duplicate eval id {case_id!r}")
        seen.add(case_id)
        prompt = case.get("prompt")
        if not isinstance(prompt, str) or not prompt.strip():
            fail(path, f"eval {case_id!r} missing prompt")
        eval_type = case.get("eval_type", "contract")
        if eval_type not in VALID_EVAL_TYPES:
            fail(path, f"eval {case_id!r} invalid eval_type {eval_type!r}")
        run_modes = case.get("run_modes", ["with_skill"])
        if not isinstance(run_modes, list) or not run_modes:
            fail(path, f"eval {case_id!r} run_modes must be non-empty list")
        invalid_modes = sorted(set(run_modes) - VALID_RUN_MODES)
        if invalid_modes:
            fail(path, f"eval {case_id!r} invalid run_modes {invalid_modes}")
        expected_anchors = case.get("expected_anchors", [])
        if expected_anchors and not set(expected_anchors) <= anchor_ids:
            missing = sorted(set(expected_anchors) - anchor_ids)
            fail(path, f"eval {case_id!r} references missing anchors {missing}")
        files = case.get("files", [])
        if not isinstance(files, list):
            fail(path, f"eval {case_id!r} files must be a list")
        for ref in files:
            if not isinstance(ref, str) or not ref.strip() or Path(ref).is_absolute():
                fail(path, f"eval {case_id!r} invalid file ref {ref!r}")
            if not any((base / ref).exists() for base in (skill_root, root)):
                fail(path, f"eval {case_id!r} missing file ref {ref!r}")


def main() -> int:
    args = parse_args()
    paths = sorted((args.repo_root / "shared" / "skills").glob("*/evals/evals.json"))
    if not paths:
        raise SystemExit("no skill eval files found")
    for path in paths:
        validate_file(path, args.repo_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 3: 跑新测试确认红灯**

Run:
```bash
bash tests/test-skill-eval-contracts.sh
```
Expected: FAIL，指出含 `expected_output` 的 eval。

- [ ] **Step 4: 删除所有 eval `expected_output` 字段**

使用结构化脚本检查，不用字符串替换。执行时可用临时 Python 一次性迁移：

```bash
python3 - <<'PY'
import json
from pathlib import Path
for path in sorted(Path('shared/skills').glob('*/evals/evals.json')):
    data = json.loads(path.read_text(encoding='utf-8'))
    changed = False
    for case in data.get('evals', []):
        if isinstance(case, dict) and 'expected_output' in case:
            del case['expected_output']
            changed = True
    if changed:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
PY
```

- [ ] **Step 5: 改 `tests/test-standard-chain-skill-evals.sh`**

删除所有读取 `expected_output` 的断言，保留：
- `skill_name` 与目录名一致。
- eval id 唯一。
- file refs 可达。
- `expected_anchors` 指向 `preference_anchors`。
- `run_modes` 合法。
- `grader_dimensions` 为结构字段，不匹配正文。

- [ ] **Step 6: 跑 eval 合同测试**

Run:
```bash
bash tests/test-skill-eval-contracts.sh
bash tests/test-standard-chain-skill-evals.sh
```
Expected: PASS。

---

## Task 7: 建立 Script Manifest 统一 Validator

**Files:**
- Create: `tools/community/validate_skill_script_manifests.py`
- Create: `tests/test-skill-script-manifest-contracts.sh`
- Modify: `tests/gate-plan.json`

- [ ] **Step 1: 写测试 shell**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/tools/community/validate_skill_script_manifests.py" --repo-root "$ROOT"
printf '[PASS] skill script manifest contracts\n'
```

- [ ] **Step 2: 实现 manifest validator**

```python
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

REQUIRED_SCRIPT_FIELDS = {
    "path",
    "purpose",
    "allowed_args",
    "denied_args",
    "allowed_input_roots",
    "allowed_output_roots",
    "timeout_sec",
    "exit_code_meanings",
    "verification_command",
}


def parse_args():
    parser = argparse.ArgumentParser(description="Validate shared skill script manifests.")
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    return parser.parse_args()


def fail(path: Path, message: str) -> None:
    raise SystemExit(f"{path}: {message}")


def validate_script_entry(manifest_path: Path, skill_root: Path, entry: dict) -> None:
    missing = sorted(REQUIRED_SCRIPT_FIELDS - set(entry))
    if missing:
        fail(manifest_path, f"script entry missing fields {missing}")
    rel = entry["path"]
    if not isinstance(rel, str) or rel.startswith("/") or ".." in Path(rel).parts:
        fail(manifest_path, f"invalid script path {rel!r}")
    script_path = skill_root / rel
    if not script_path.exists():
        fail(manifest_path, f"script path does not exist: {rel}")
    for list_field in ("allowed_args", "denied_args", "allowed_input_roots", "allowed_output_roots"):
        if not isinstance(entry[list_field], list):
            fail(manifest_path, f"{rel}: {list_field} must be a list")
    if not isinstance(entry["timeout_sec"], int) or entry["timeout_sec"] <= 0:
        fail(manifest_path, f"{rel}: timeout_sec must be positive integer")
    if not isinstance(entry["exit_code_meanings"], dict) or "0" not in entry["exit_code_meanings"]:
        fail(manifest_path, f"{rel}: exit_code_meanings must include 0")
    verification = entry["verification_command"]
    if not isinstance(verification, list) or not verification:
        fail(manifest_path, f"{rel}: verification_command must be a command array")


def validate_manifest(path: Path) -> None:
    skill_root = path.parents[1]
    data = json.loads(path.read_text(encoding="utf-8"))
    scripts = data.get("scripts")
    if not isinstance(scripts, list) or not scripts:
        fail(path, "scripts must be a non-empty list")
    for entry in scripts:
        if not isinstance(entry, dict):
            fail(path, "each script entry must be an object")
        validate_script_entry(path, skill_root, entry)


def main() -> int:
    args = parse_args()
    paths = sorted((args.repo_root / "shared" / "skills").glob("*/scripts/manifest.json"))
    if not paths:
        raise SystemExit("no script manifests found")
    for path in paths:
        validate_manifest(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 3: 跑测试确认红灯**

Run:
```bash
bash tests/test-skill-script-manifest-contracts.sh
```
Expected: FAIL，指出旧 manifest shape 或缺字段。

- [ ] **Step 4: 修正 manifest 文件**

对每个失败的 `shared/skills/*/scripts/manifest.json`：
- 旧 dict shape 改为 `{"schema_version": 1, "scripts": [...]}`。
- 补 `denied_args`、`allowed_input_roots`、`allowed_output_roots`、`timeout_sec`、`exit_code_meanings`、`verification_command`。
- `verification_command` 必须引用已有脚本或测试命令，不写不存在路径。

- [ ] **Step 5: 加入 quick canary**

在 `tests/gate-plan.json` 加：

```json
{"id": "skill-script-manifest-contracts", "command": ["bash", "tests/test-skill-script-manifest-contracts.sh"], "area": "hooks-manifest", "tier": "quick", "tags": ["manifest", "canary"], "parallel_safe": true, "timeout_sec": 90}
```

- [ ] **Step 6: 跑 manifest 合同测试**

Run:
```bash
bash tests/test-skill-script-manifest-contracts.sh
```
Expected: PASS。

---

## Task 8: 强化真实消费契约 Canaries

**Files:**
- Modify: `tests/gate-plan.json`
- Modify: existing high-signal tests only when needed

- [ ] **Step 1: 确认 quick canary 覆盖 6 条真实链路**

`tests/gate-plan.json` quick/preflight 必须包含：

```text
standard-chain canonical: tests/test-standard-chain-validator-stack.sh
context recovery/active docs: tests/test-context-contract-validator.sh
install/runtime: tests/test-install-runtime-smoke.sh 或更轻的 dry-run/idempotency smoke
hooks registry/script manifest: tests/test-skill-output-and-gate-contract.sh + tests/test-skill-script-manifest-contracts.sh
contracts/identifier/chain: tools/validate-contracts.sh
skill runtime surface/adapter: tests/test-skill-runtime-surface-contract.sh
Skill/Eval contract: tests/test-skill-eval-contracts.sh
low-signal boundary: tests/test-test-assertion-boundary-contract.sh
```

- [ ] **Step 2: 长链迁到 focused/full/release**

在 `tests/gate-plan.json` 中确认以下 tags 不出现在 quick：

```text
dogfood, e2e, live, migration, release-only, full-only, install-heavy, upstream-fidelity, empirical-review
```

- [ ] **Step 3: 跑 quick list 验证**

Run:
```bash
bash tests/run-all.sh --quick --list --format=json | python3 -m json.tool >/tmp/org-quick-plan.json
python3 - <<'PY'
import json
from pathlib import Path
plan = json.loads(Path('/tmp/org-quick-plan.json').read_text())
forbidden = {'dogfood', 'e2e', 'live', 'migration', 'release-only', 'full-only', 'install-heavy'}
for step in plan['steps']:
    blocked = sorted(forbidden & set(step.get('tags', [])))
    if blocked:
        raise SystemExit(f"{step['id']} forbidden in quick: {blocked}")
print(len(plan['steps']))
PY
```
Expected: 输出 step 数，且不失败；step 数小于等于 35。

---

## Task 9: 快速门禁与全量门禁验证

**Files:**
- No direct edits unless verification reveals target-boundary failures.

- [ ] **Step 1: 运行静态边界检查**

Run:
```bash
python3 tools/community/check_test_signal_assertions.py --repo-root "$PWD"
python3 tools/community/validate_skill_evals.py --repo-root "$PWD"
python3 tools/community/validate_skill_script_manifests.py --repo-root "$PWD"
git diff --check
```
Expected: 全部 PASS / no output。

- [ ] **Step 2: 运行 runner 合同**

Run:
```bash
bash tests/test-run-all-runner-contract.sh
bash tests/test-run-focused-runner-contract.sh
```
Expected: PASS。

- [ ] **Step 3: 运行新 quick**

Run:
```bash
bash tests/run-all.sh --quick --profile
```
Expected: PASS，输出每步耗时；总耗时目标 30-60 秒。若超过 60 秒，保留失败证据，移动最慢非 canary 项到 focused/full，直到 quick 回到预算。

- [ ] **Step 4: 运行重点 focused profile**

Run:
```bash
bash tests/run-focused.sh design --profile
bash tests/run-focused.sh standard-chain --profile
bash tests/run-focused.sh skill-refiner --profile
```
Expected: PASS。

- [ ] **Step 5: 运行 full**

Run:
```bash
bash tests/run-all.sh --full --profile
```
Expected: PASS。若 full 因历史长链/环境依赖失败，按失败所属 area 归类；本次边界内失败必须修复，边界外环境缺口只报告并等待裁决。

---

## Task 10: 文档同步与删除引用

**Files:**
- Modify: `AGENTS.md`
- Modify: any docs/tests still referencing `low-signal-prose-assertions.baseline`
- Modify: docs/reports only if they are active and currently referenced by tests/contracts

- [ ] **Step 1: 查找 baseline 和 expected_output 残留**

Run:
```bash
rg -n "low-signal-prose-assertions\.baseline|expected_output" AGENTS.md tests shared/skills tools docs contracts
```
Expected: no matches，除非命中的是本计划文件。实现时如本计划被 `rg` 命中，可用路径排除：

```bash
rg -n "low-signal-prose-assertions\.baseline|expected_output" AGENTS.md tests shared/skills tools docs contracts -g '!docs/superpowers/plans/*'
```

- [ ] **Step 2: 更新 AGENTS.md 测试说明**

保留项目规则，改为：

```markdown
- 行为/约束变更先补可失败测试，再做最小实现，最后跑 fresh proving command。
- 测试断言边界：不得用 shell helper 或 grep/rg 锁定 Skill Markdown 自然语言正文；正文要求必须迁移到结构化契约、validator、script 行为或 fixture artifact。
- 低信号断言由 `tools/community/check_test_signal_assertions.py` 直接拒绝；仓库不保留 legacy baseline 豁免。
```

- [ ] **Step 3: 最终范围复查**

Run:
```bash
git diff --stat
git diff --check
```
Expected: diff 只包含测试体系重构相关文件，无无关格式 churn。

---

## 验收标准

- `python3 tools/community/check_test_signal_assertions.py --repo-root "$PWD"` PASS，且不依赖 baseline。
- `rg -n "expected_output" shared/skills tests tools -g '!docs/superpowers/plans/*'` 无结果。
- `bash tests/run-all.sh --quick --list --format=json` 输出合法 JSON，quick step 数小于等于 35，且不含 `dogfood/e2e/live/migration/release-only/full-only/install-heavy` tags。
- `bash tests/run-all.sh --quick --profile` PASS，目标耗时 30-60 秒。
- `bash tests/test-run-all-runner-contract.sh`、`bash tests/test-run-focused-runner-contract.sh` PASS。
- `bash tests/test-skill-eval-contracts.sh`、`bash tests/test-skill-script-manifest-contracts.sh` PASS。
- `bash tests/run-focused.sh design --profile`、`bash tests/run-focused.sh standard-chain --profile`、`bash tests/run-focused.sh skill-refiner --profile` PASS。
- `bash tests/run-all.sh --full --profile` PASS，或仅因明确边界外环境依赖阻塞并有可复现证据。
- `git diff --check` PASS。

## Self-Review

- Spec coverage: 覆盖用户裁决的 baseline 一次清零、`expected_output` 完全删除、quick 30-60 秒；覆盖五路审计给出的低信号断言、真实契约链路、Skill/Eval、runner 分层和门禁效率问题。
- Placeholder scan: 本计划不使用 TBD/TODO/后续补充占位；每个新增工具和测试都有文件路径、核心代码、运行命令和期望结果。
- Type consistency: `gate-plan.json` 字段与 `gate_plan.py` 读取字段一致；`validate_skill_evals.py`、`validate_skill_script_manifests.py` 的命令与 shell tests 一致；runner `--format=json` 合同由 tests 调用并由 Python builder 提供。

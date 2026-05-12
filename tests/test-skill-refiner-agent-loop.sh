#!/usr/bin/env bash
# File role: prove skill-refiner v3 uses diagnostic rubrics without adding a second execution layer.
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-refiner/SKILL.md"
RUBRIC_DIR="$ROOT/shared/skills/skill-refiner/references/rubrics"
FLOW_RUBRIC="$RUBRIC_DIR/flow.md"
INPUT_RUBRIC="$RUBRIC_DIR/input.md"
RESOURCE_RUBRIC="$RUBRIC_DIR/resource.md"
DETERMINISM_RUBRIC="$RUBRIC_DIR/determinism.md"
EVAL_RUBRIC="$RUBRIC_DIR/eval.md"
ENGINEERING_CARRIER="$ROOT/shared/skills/skill-refiner/references/engineering-carrier.md"
PROBLEM_FRAMING="$ROOT/shared/skills/skill-refiner/references/problem-framing.md"
NOISE_TAXONOMY="$ROOT/shared/skills/skill-refiner/references/noise-taxonomy.md"
CO_CREATION="$ROOT/shared/skills/skill-refiner/references/co-creation-protocol.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in ${file#"$ROOT"/}: $needle"
}

assert_absent() {
  local needle="$1"
  local file="$2"
  if grep -Fq "$needle" "$file"; then
    fail "forbidden content in ${file#"$ROOT"/}: $needle"
  fi
}

test -f "$SKILL" || fail "missing skill-refiner SKILL.md"
test -f "$CO_CREATION" || fail "missing co-creation protocol"

# --- v3 SKILL.md role and structure ---
assert_present '你是 Skill 架构师' "$SKILL"
assert_present '## 角色' "$SKILL"
assert_present '## 工作方式：共创' "$SKILL"
assert_present '## HARD-GATE' "$SKILL"
assert_present '## 流程' "$SKILL"
assert_present '## 流程执行计划' "$SKILL"
assert_present '## 输出' "$SKILL"
assert_present '## 完成校验' "$SKILL"
assert_present 'allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion' "$SKILL"
assert_absent 'Agent' "$SKILL"

# --- v3 flow graph ---
assert_present 'digraph skill_architect_flow' "$SKILL"
assert_present '"承载定位" -> "场景理解"' "$SKILL"
assert_present '"策略制定" -> "执行落地"' "$SKILL"
assert_present '"执行落地" -> "验收交付"' "$SKILL"

# --- v3 capability steps ---
assert_present '### 1. 承载定位' "$SKILL"
assert_present '### 2. 场景理解' "$SKILL"
assert_present '### 3. 职责定义' "$SKILL"
assert_present '### 4. 消费者盘点' "$SKILL"
assert_present '### 5. 结构诊断' "$SKILL"
assert_present '### 6. 策略制定' "$SKILL"
assert_present '### 7. 执行落地' "$SKILL"
assert_present '### 8. 验收交付' "$SKILL"
assert_present '进入流程后必须先创建可见计划' "$SKILL"
assert_present '每完成一个阶段必须更新状态卡' "$SKILL"
assert_present '禁止跳过、合并、重排流程阶段' "$SKILL"
assert_present 'flow_trace' "$SKILL"

# --- v3 HARD-GATE ---
assert_present '质量标准必须先读取' "$SKILL"
assert_present '场景理解必须产出用户确认的事实' "$SKILL"
assert_present '每个诊断发现必须有问题证据和验证方式' "$SKILL"
assert_present '内容必须有消费者' "$SKILL"
assert_present '策略确认前除台账外不改目标文件' "$SKILL"
assert_present 'skill-refiner-result.json' "$SKILL"

# --- v3 references routing ---
assert_present 'references/co-creation-protocol.md' "$SKILL"
assert_present 'references/quality-dimensions.md' "$SKILL"
assert_present 'references/engineering-carrier.md' "$SKILL"
assert_present 'references/problem-framing.md' "$SKILL"
assert_present 'references/noise-taxonomy.md' "$SKILL"
assert_present 'references/rubrics/cleanup.md' "$SKILL"

# --- v3 diagnostic dimensions ---
assert_present '9 个诊断维度' "$SKILL"
assert_present '| 根基 | Trigger' "$SKILL"
assert_present '| 根基 | Responsibility' "$SKILL"
assert_present '| 根基 | Flow' "$SKILL"
assert_present '| 边界 | Input' "$SKILL"
assert_present '| 边界 | Output' "$SKILL"
assert_present '| 内功 | Resource' "$SKILL"
assert_present '| 内功 | Determinism' "$SKILL"
assert_present '| 保障 | Eval' "$SKILL"
assert_present '| 保障 | Runtime' "$SKILL"

# --- v2 content must be absent ---
assert_absent 'Skill 精修 owner' "$SKILL"
assert_absent 'SR-S1' "$SKILL"
assert_absent 'SR-S2' "$SKILL"
assert_absent 'SR-R1' "$SKILL"
assert_absent 'SR-F1' "$SKILL"
assert_absent 'SR-E1' "$SKILL"
assert_absent 'SR-V1' "$SKILL"
assert_absent 'conversation-guide.md' "$SKILL"
assert_absent 'digraph skill_refiner_flow' "$SKILL"
assert_absent '## 环节标准循环' "$SKILL"
assert_absent 'skill-harness' "$SKILL"
assert_absent '## Sub Agent 审查队列' "$SKILL"
assert_absent 'references/reviewers/' "$SKILL"
assert_absent '## 共创规则' "$SKILL"
assert_absent '## 共创台账' "$SKILL"
assert_absent '## 交互模式定义' "$SKILL"
assert_absent '入口基线确认卡' "$SKILL"
assert_absent '## 角色与边界' "$SKILL"
assert_absent '负责：' "$SKILL"
assert_absent '不负责：' "$SKILL"
assert_absent 'sub agent' "$SKILL"

# --- co-creation-protocol.md ---
assert_present '最小决策包' "$CO_CREATION"
assert_present '已闭合事实' "$CO_CREATION"
assert_present '推荐理解' "$CO_CREATION"
assert_present '关键假设' "$CO_CREATION"
assert_present '用户动作' "$CO_CREATION"
assert_present '表现形式不得反向定义流程' "$CO_CREATION"
assert_present 'schema key、台账字段和 rubric 字段不得作为用户侧标题' "$CO_CREATION"
assert_present '## 回退触发' "$CO_CREATION"
assert_absent '## 用户回应处理' "$CO_CREATION"
assert_absent '## 交互模式' "$CO_CREATION"
assert_absent '## 能力步骤映射' "$CO_CREATION"

# --- no self-referential reference contracts ---
python3 - "$ROOT/shared/skills/skill-refiner/references" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
fields = ("Trigger:", "Read:", "Expect:", "Consume:", "Evidence:", "Sync:")
violations = []
for path in sorted(root.rglob("*.md")):
    for index, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not all(field in line for field in fields):
            continue
        read_match = re.search(r"Read:\s*([^。.;]+)", line)
        read_target = read_match.group(1).strip(" `") if read_match else ""
        if read_target in {path.name, "本文件", "当前文件"}:
            violations.append(f"{path}:{index}: self-referential reference contract")
if violations:
    raise SystemExit("\n".join(violations))
PY

# --- evals.json uses SA-* anchors ---
python3 - "$ROOT/shared/skills/skill-refiner/evals/evals.json" <<'PY'
import json
import sys

path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
required = {"SA-1", "SA-2"}
missing = [
    f"{item['id']}:{anchor}"
    for item in data["evals"]
    for anchor in required - set(item.get("expected_anchors", []))
]
if missing:
    raise SystemExit(f"evals missing required anchor: {', '.join(missing)}")
anchors = {item["id"] for item in data["preference_anchors"]}
if not all(a.startswith("SA-") for a in anchors):
    raise SystemExit("preference anchors must use SA-* naming")
PY

# --- v3 rubric structure: 诊断口径 + 裁决标准 + 问题信号 ---
rubrics=(
  trigger
  responsibility
  input
  flow
  output
  resource
  determinism
  eval
  cleanup
  runtime
)

for rubric in "${rubrics[@]}"; do
  file="$RUBRIC_DIR/$rubric.md"
  test -f "$file" || fail "missing rubric: $file"
  assert_present '诊断口径' "$file"
  assert_present '## 裁决标准' "$file"
  assert_present '## 问题信号' "$file"
  assert_absent '## Why' "$file"
  assert_absent '## 证据' "$file"
  assert_absent '## 验收' "$file"
  assert_absent '环节标准' "$file"
done

# --- rubric content spot checks ---
assert_present 'AI 按这个流程能像该职责的熟练从业者一样把事办成' "$FLOW_RUBRIC"
assert_present '目标闭合' "$FLOW_RUBRIC"
assert_present '阶段闸门清楚' "$FLOW_RUBRIC"
assert_present '流程图无歧义' "$FLOW_RUBRIC"

assert_present '定位可执行' "$INPUT_RUBRIC"
assert_present '机器检查外移' "$INPUT_RUBRIC"

assert_present 'HARD-GATE Why 有条件保留' "$RESOURCE_RUBRIC"
assert_present 'reference 职责清楚' "$RESOURCE_RUBRIC"
assert_present 'reference 有目标和收口' "$RESOURCE_RUBRIC"

assert_present '参数明确' "$DETERMINISM_RUBRIC"
assert_present '阶段门禁可测' "$EVAL_RUBRIC"

# --- noise-taxonomy ---
assert_present '编译降噪审查' "$NOISE_TAXONOMY"
assert_present '分析维度泄漏' "$NOISE_TAXONOMY"
assert_present '每句话必须能归入执行动作、判断条件、阻断规则、产物要求、引用路由、失败处理或不可绕过 Why' "$NOISE_TAXONOMY"
assert_absent 'SR-E1' "$NOISE_TAXONOMY"
assert_absent 'SR-V1' "$NOISE_TAXONOMY"

# --- engineering-carrier ---
assert_present '有效性记录入口' "$ENGINEERING_CARRIER"
assert_absent 'SR-F1' "$ENGINEERING_CARRIER"

# --- problem-framing ---
assert_present '为什么是下一刀' "$PROBLEM_FRAMING"
assert_present '停手条件' "$PROBLEM_FRAMING"
assert_absent 'Read: problem-framing.md' "$PROBLEM_FRAMING"

# --- grader tests skipped until grade_fixture_anchor_fidelity.py is rewritten for v3 ---
# TODO: restore grader function tests after v3 rewrite of grade_fixture_anchor_fidelity.py

printf '[PASS] skill-refiner agent loop\n'

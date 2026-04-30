#!/usr/bin/env bash
# File role: prove skill-refiner uses ring rubrics and sub agents without adding a second reviewer layer.
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-refiner/SKILL.md"
RUBRIC_DIR="$ROOT/shared/skills/skill-refiner/references/rubrics"
FLOW_RUBRIC="$RUBRIC_DIR/flow.md"
INPUT_RUBRIC="$RUBRIC_DIR/input.md"
RESOURCE_RUBRIC="$RUBRIC_DIR/resource.md"
DETERMINISM_RUBRIC="$RUBRIC_DIR/determinism.md"
ENGINEERING_CARRIER="$ROOT/shared/skills/skill-refiner/references/engineering-carrier.md"
TMP_FILES=()

cleanup() {
  if ((${#TMP_FILES[@]})); then
    rm -f "${TMP_FILES[@]}"
  fi
}

new_tmp() {
  local path
  path="$(mktemp)"
  TMP_FILES+=("$path")
  printf '%s\n' "$path"
}

trap cleanup EXIT

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

assert_present 'allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion' "$SKILL"
assert_present '主 agent 负责调度、上下文控制和验收' "$SKILL"
assert_present '先和用户共创精修基线' "$SKILL"
assert_present '真实场景、业务约束、成功标准、已知痛点、不可丢能力和当前优先环节' "$SKILL"
assert_present 'Co-created Baseline' "$SKILL"
assert_absent '用户补充的上下文' "$SKILL"
assert_present '"加载质量标准" -> "共创精修基线";' "$SKILL"
assert_present '"共创精修基线" -> "定义专业职责域";' "$SKILL"
assert_present '"共创精修基线" -> "停止对齐" [label="基线要素不全"];' "$SKILL"
assert_present '将已确认信息写入 Co-created Baseline；缺少任一基线要素时停止补齐' "$SKILL"
assert_absent '优先交给 sub agent' "$SKILL"
assert_present 'sub agent 负责' "$SKILL"
assert_present '最小上下文' "$SKILL"
assert_present '候选问题只是输入' "$SKILL"
assert_present '不接受把候选问题信号或 sub agent 自证直接当最终语义裁决' "$SKILL"
assert_present '## 环节标准循环' "$SKILL"
assert_present '| Flow | `flow.md` | 是否还原真实办事流程，让 AI 按这个流程把事办成。 |' "$SKILL"
assert_present 'references/examples/developer-optimization-case.md' "$SKILL"
assert_absent '生命周期要求' "$SKILL"
assert_absent 'skill-harness' "$SKILL"
assert_absent 'check_skill_package_quality.py' "$SKILL"
assert_absent '## Sub Agent 审查队列' "$SKILL"
assert_absent 'references/reviewers/' "$SKILL"
assert_absent 'discover_refinement_candidates.py' "$SKILL"
assert_absent 'Flow：流程是否是专业实践 SOP，且每步有可消费输出。' "$SKILL"
assert_absent '只读质量审计、迁移审计或 finding 输出时，交给 `skill-harness`。' "$SKILL"

assert_present '"anchor": "先和用户共创精修基线，补齐真实场景、业务约束、成功标准、已知痛点、不可丢能力和当前优先环节，再改文件"' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_present '真实场景、业务约束、成功标准、已知痛点、不可丢能力和当前优先环节' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_present '主导共创产品 Skill 的真实场景、业务约束、成功标准、已知痛点、不可丢能力和当前优先环节' "$ROOT/shared/skills/skill-refiner/test-prompts.json"
assert_present '"business_constraint",' "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py"
assert_present '"ring_sequence"' "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py"
assert_present '"co_created_baseline"' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_present '"co_created_baseline"' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
assert_present '"decision": "optimize"' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
assert_present 'needs_full_eval' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
assert_present '"fidelity": 1.0' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
assert_absent 'co_creation_baseline' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_absent 'co_creation_baseline' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"

python3 - "$ROOT/shared/skills/skill-refiner/evals/evals.json" <<'PY'
import json
import sys

path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
required = {"SR-1", "SR-9"}
missing = [
    f"{item['id']}:{anchor}"
    for item in data["evals"]
    for anchor in required - set(item.get("expected_anchors", []))
]
if missing:
    raise SystemExit(f"evals missing required anchor: {', '.join(missing)}")
PY

python3 - "$ROOT/shared/skills/skill-refiner/evals/evals.json" "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py" <<'PY'
import json
import re
import sys

evals_path, grader_path = sys.argv[1], sys.argv[2]
data = json.load(open(evals_path, encoding="utf-8"))
anchors = {item["id"] for item in data["preference_anchors"]}
grader = open(grader_path, encoding="utf-8").read()
missing = sorted(anchor for anchor in anchors if f'anchor_id == "{anchor}"' not in grader)
if missing:
    raise SystemExit(f"preference anchors missing grader support: {', '.join(missing)}")
PY

tmp_evals="$(new_tmp)"
python3 - "$ROOT/shared/skills/skill-refiner/evals/evals.json" "$tmp_evals" <<'PY'
import json
import sys

source, target = sys.argv[1], sys.argv[2]
data = json.load(open(source, encoding="utf-8"))
anchors = [item["id"] for item in data["preference_anchors"]]
data["evals"][0]["expected_anchors"] = anchors
json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
python3 "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py" \
  --evals "$tmp_evals" \
  --result "$ROOT/shared/skills/skill-refiner/evals/dogfood/fixture-backed-noisy-implementation-skill/with_skill/dogfood-result.json" \
  >"$(new_tmp)"

tmp_result="$(new_tmp)"
python3 - "$ROOT/shared/skills/skill-refiner/evals/dogfood/fixture-backed-noisy-implementation-skill/with_skill/dogfood-result.json" "$tmp_result" <<'PY'
import json
import sys

source, target = sys.argv[1], sys.argv[2]
data = json.load(open(source, encoding="utf-8"))
data["co_created_baseline"].pop("business_constraint", None)
json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
if python3 "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py" --result "$tmp_result" >"$(new_tmp)" 2>&1; then
  fail "SR-9 grader must fail when business_constraint is missing"
fi

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
  for heading in '## Why' '## 目标' '## 裁决标准' '## 证据' '## 问题信号' '## 验收'; do
    assert_present "$heading" "$file"
  done
done

assert_present 'Flow 是真实办事流程，不是工件流水线' "$FLOW_RUBRIC"
assert_present 'AI 按这个流程能像该职责的熟练从业者一样把事办成' "$FLOW_RUBRIC"
assert_present '工件、字段、脚本和验证只支撑流程' "$FLOW_RUBRIC"
assert_present '图示无歧义' "$FLOW_RUBRIC"
assert_absent '从目标输入推进到可验证产物' "$FLOW_RUBRIC"

assert_present '定位可执行' "$INPUT_RUBRIC"
assert_present '写“默认从 X 接手/读取”，但没有说明 X 在哪里' "$INPUT_RUBRIC"
assert_present 'HARD-GATE Why 有条件保留' "$RESOURCE_RUBRIC"
assert_present '不复述规则，不展开方法论' "$RESOURCE_RUBRIC"
assert_present 'reference 职责清楚' "$RESOURCE_RUBRIC"
assert_present '方法论、判定口径、专业框架、案例和检查矩阵' "$RESOURCE_RUBRIC"
assert_present 'reference 目标清晰' "$RESOURCE_RUBRIC"
assert_present '说明它要解决的专业判断或操作问题' "$RESOURCE_RUBRIC"
assert_present 'reference 按用途组织' "$RESOURCE_RUBRIC"
assert_present '方法论写处理对象、步骤和产出' "$RESOURCE_RUBRIC"
assert_present '判定口径写判断维度、通过/问题信号和证据要求' "$RESOURCE_RUBRIC"
assert_present '混合型内容可以合并表达' "$RESOURCE_RUBRIC"
assert_present 'reference 收口清楚' "$RESOURCE_RUBRIC"
assert_present '裁决标准、证据要求、输出要求、完成条件、问题信号或评审要点' "$RESOURCE_RUBRIC"
assert_present '参数明确' "$DETERMINISM_RUBRIC"
assert_present '命令包含 `$PHASE_DIR`、`$TASK_ID` 等参数' "$DETERMINISM_RUBRIC"
assert_absent '生命周期集成' "$ENGINEERING_CARRIER"
assert_present '有效性记录入口' "$ENGINEERING_CARRIER"

printf '[PASS] skill-refiner agent loop\n'

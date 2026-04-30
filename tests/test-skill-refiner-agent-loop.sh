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
TMP_PATHS=()

cleanup() {
  if ((${#TMP_PATHS[@]})); then
    rm -rf "${TMP_PATHS[@]}"
  fi
}

new_tmp() {
  local path
  path="$(mktemp)"
  TMP_PATHS+=("$path")
  printf '%s\n' "$path"
}

new_tmp_dir() {
  local path
  path="$(mktemp -d)"
  TMP_PATHS+=("$path")
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
assert_present '你负责调度、上下文控制和验收' "$SKILL"
assert_present '纯新建独立 Skill 交给 `skill-creator`；已有 Skill 的精修、重写、替换或拆分才继续本流程' "$SKILL"
assert_present '拆分已有 Skill 时，先确认旧能力去留、迁移边界和 active 消费者；拆出的新 Skill 再交给 `skill-creator` 创建' "$SKILL"
assert_present '先和用户共创精修基线' "$SKILL"
assert_present '真实场景、业务约束、成功标准、已知痛点、不可丢能力和当前优先环节' "$SKILL"
assert_present '共创基线：真实场景、业务约束、成功标准、已知痛点、不可丢能力和当前优先环节' "$SKILL"
assert_absent 'Target Skill：' "$SKILL"
assert_absent 'Quality Standard：' "$SKILL"
assert_absent 'Co-created Baseline：' "$SKILL"
assert_absent 'Professional Domain：' "$SKILL"
assert_absent 'Practice Flow：' "$SKILL"
assert_absent 'Optimization Goal：' "$SKILL"
assert_present '按环节队列共创每个环节的最佳实践蓝图' "$SKILL"
assert_present '每个环节先读取对应标准，再和用户确认目标形态、改造策略和验证方式；策略确认前不改文件' "$SKILL"
assert_present '不得修完一个问题就收口' "$SKILL"
assert_present '改造策略必须覆盖受影响的主 SOP、reference、脚本、eval、测试、触发描述和安装清单' "$SKILL"
assert_present '同一策略必须覆盖受影响的 tests、evals、test-prompts、引用路径、触发描述和安装清单' "$SKILL"
assert_absent '用户补充的上下文' "$SKILL"
assert_absent '同时同步' "$SKILL"
assert_absent '并同步' "$SKILL"
assert_absent '运行暴露' "$SKILL"
assert_absent '安装暴露' "$SKILL"
assert_absent '安装/触发入口' "$SKILL"
assert_present '"加载质量标准" -> "判断新建或精修";' "$SKILL"
assert_present '"判断新建或精修" -> "转交 skill-creator" [label="纯新建"];' "$SKILL"
assert_present '"判断新建或精修" -> "共创精修基线" [label="已有/拆分"];' "$SKILL"
assert_present '"共创精修基线" -> "定义专业职责域";' "$SKILL"
assert_present '"收集候选问题信号" -> "建立环节队列";' "$SKILL"
assert_present '"建立环节队列" -> "取下一个环节";' "$SKILL"
assert_present '"加载环节标准" -> "共创环节蓝图";' "$SKILL"
assert_present '"共创环节蓝图" -> "确认改造策略";' "$SKILL"
assert_present '"记录环节结论" -> "取下一个环节" [label="仍有未验收环节"];' "$SKILL"
assert_present '"共创精修基线" -> "停止对齐" [label="基线要素不全"];' "$SKILL"
assert_present '"判断新建或精修" -> "停止对齐" [label="迁移关系不清"];' "$SKILL"
assert_present '记录共创基线；缺少任一基线要素时停止补齐' "$SKILL"
assert_present '纯新建独立 Skill 且没有既有 first-party Skill 消费者或迁移关系时，停止本流程并转交 `skill-creator`' "$SKILL"
assert_present '固定环节清单：Trigger、Responsibility、Input、Flow、Output、Resource、Determinism、Eval、Cleanup、Runtime' "$SKILL"
assert_present '当前优先环节作为队首；之后按固定清单环形遍历剩余环节' "$SKILL"
assert_present '对环节队列执行：`for 环节 in 环节队列`' "$SKILL"
assert_present '每个环节先形成最佳实践蓝图，再确认改造策略；策略确认前不改文件' "$SKILL"
assert_present '用环节蓝图对照当前 Skill，选择 PASS、PATCH、REWRITE、REPLACE、MOVE、DELETE 或 BLOCKED' "$SKILL"
assert_present '每个环节输出 PASS / ISSUE_FIXED / BLOCKED' "$SKILL"
assert_present '环节矩阵' "$SKILL"
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
assert_present '新建分流明确：纯新建独立 Skill 交给 `skill-creator`。' "$RUBRIC_DIR/trigger.md"
assert_present '拆分分流明确：已有 Skill 拆分先由本 Skill 确认旧能力去留、迁移边界和 active 消费者；拆出的新 Skill 再交给 `skill-creator` 创建。' "$RUBRIC_DIR/trigger.md"
assert_present '纯新建独立 Skill 仍进入精修流程。' "$RUBRIC_DIR/trigger.md"
assert_present '拆分已有 Skill 时直接新建，未确认旧能力去留、迁移边界和 active 消费者。' "$RUBRIC_DIR/trigger.md"

assert_present '"anchor": "先和用户共创精修基线，补齐真实场景、业务约束、成功标准、已知痛点、不可丢能力和当前优先环节，再改文件"' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_present '"anchor": "按覆盖 Trigger 到 Runtime 的环节队列进行 for-loop 级循环，当前优先环节作为队首，每个环节都有 PASS、ISSUE_FIXED 或 BLOCKED 证据；不能修完单个问题就收口"' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_present '"anchor": "每个环节先共创最佳实践蓝图和改造策略，策略确认前不改文件"' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_present '真实场景、业务约束、成功标准、已知痛点、不可丢能力和当前优先环节' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_present '主导共创产品 Skill 的真实场景、业务约束、成功标准、已知痛点、不可丢能力和当前优先环节' "$ROOT/shared/skills/skill-refiner/test-prompts.json"
assert_present '识别为纯新建独立 Skill，转交 skill-creator' "$ROOT/shared/skills/skill-refiner/test-prompts.json"
assert_present '拆出的新 Skill 在边界确认后交给 skill-creator 创建' "$ROOT/shared/skills/skill-refiner/test-prompts.json"
assert_present '"business_constraint",' "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py"
assert_present '"ring_sequence"' "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py"
assert_present '"ring_results"' "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py"
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
loop_required = {"fixture-backed-noisy-implementation-skill", "practice-flow-over-runtime-patch", "old-test-conflict", "historical-artifact-cleanup"}
missing = [
    f"{item['id']}:{anchor}"
    for item in data["evals"]
    for anchor in required - set(item.get("expected_anchors", []))
]
missing.extend(
    f"{item['id']}:SR-10"
    for item in data["evals"]
    if item["id"] in loop_required and "SR-10" not in set(item.get("expected_anchors", []))
)
missing.extend(
    f"{item['id']}:SR-11"
    for item in data["evals"]
    if item["id"] in loop_required and "SR-11" not in set(item.get("expected_anchors", []))
)
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

tmp_result_incomplete_loop="$(new_tmp)"
python3 - "$ROOT/shared/skills/skill-refiner/evals/dogfood/fixture-backed-noisy-implementation-skill/with_skill/dogfood-result.json" "$tmp_result_incomplete_loop" <<'PY'
import json
import sys

source, target = sys.argv[1], sys.argv[2]
data = json.load(open(source, encoding="utf-8"))
data["agent_loop"]["ring_sequence"] = ["Input"]
data["agent_loop"].pop("ring_results", None)
json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
if python3 "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py" --result "$tmp_result_incomplete_loop" >"$(new_tmp)" 2>&1; then
  fail "SR-10 grader must fail when ring loop is incomplete"
fi

tmp_result_wrong_order="$(new_tmp)"
python3 - "$ROOT/shared/skills/skill-refiner/evals/dogfood/fixture-backed-noisy-implementation-skill/with_skill/dogfood-result.json" "$tmp_result_wrong_order" <<'PY'
import json
import sys

source, target = sys.argv[1], sys.argv[2]
data = json.load(open(source, encoding="utf-8"))
data["agent_loop"]["ring_sequence"] = [
    "Trigger",
    "Responsibility",
    "Input",
    "Flow",
    "Output",
    "Resource",
    "Determinism",
    "Eval",
    "Cleanup",
    "Runtime",
]
data["agent_loop"]["ring_results"] = [
    {"ring": ring, "status": "PASS", "evidence": f"{ring} checked"}
    for ring in data["agent_loop"]["ring_sequence"]
]
json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
if python3 "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py" --result "$tmp_result_wrong_order" >"$(new_tmp)" 2>&1; then
  fail "SR-10 grader must fail when priority ring is not first"
fi

tmp_result_open_issue="$(new_tmp)"
python3 - "$ROOT/shared/skills/skill-refiner/evals/dogfood/fixture-backed-noisy-implementation-skill/with_skill/dogfood-result.json" "$tmp_result_open_issue" <<'PY'
import json
import sys

source, target = sys.argv[1], sys.argv[2]
data = json.load(open(source, encoding="utf-8"))
data["agent_loop"]["ring_results"][0]["status"] = "ISSUE"
json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
if python3 "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py" --result "$tmp_result_open_issue" >"$(new_tmp)" 2>&1; then
  fail "SR-10 grader must fail when an issue is still open"
fi

tmp_result_uncovered_issue="$(new_tmp)"
python3 - "$ROOT/shared/skills/skill-refiner/evals/dogfood/fixture-backed-noisy-implementation-skill/with_skill/dogfood-result.json" "$tmp_result_uncovered_issue" <<'PY'
import json
import sys

source, target = sys.argv[1], sys.argv[2]
data = json.load(open(source, encoding="utf-8"))
data["problem_cards"] = [card for card in data["problem_cards"] if card.get("area") != "Input"]
json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
if python3 "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py" --result "$tmp_result_uncovered_issue" >"$(new_tmp)" 2>&1; then
  fail "SR-10 grader must fail when an ISSUE_FIXED ring has no problem card"
fi

tmp_result_no_strategy_confirmation="$(new_tmp)"
python3 - "$ROOT/shared/skills/skill-refiner/evals/dogfood/fixture-backed-noisy-implementation-skill/with_skill/dogfood-result.json" "$tmp_result_no_strategy_confirmation" <<'PY'
import json
import sys

source, target = sys.argv[1], sys.argv[2]
data = json.load(open(source, encoding="utf-8"))
data["agent_loop"].pop("blueprint_matrix", None)
data["agent_loop"]["strategy_confirmed_before_edit"] = False
json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
if python3 "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py" --result "$tmp_result_no_strategy_confirmation" >"$(new_tmp)" 2>&1; then
  fail "SR-11 grader must fail when blueprint and strategy confirmation are missing"
fi

tmp_install_root="$(new_tmp_dir)"
mkdir -p "$tmp_install_root/skills"
cp -R "$ROOT/shared/skills/skill-refiner" "$tmp_install_root/skills/skill-refiner"
rm -rf "$tmp_install_root/skills/skill-refiner/scripts/__pycache__"
python3 "$tmp_install_root/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py" \
  --result "$tmp_install_root/skills/skill-refiner/evals/dogfood/fixture-backed-noisy-implementation-skill/with_skill/dogfood-result.json" \
  >"$(new_tmp)"
bash "$tmp_install_root/skills/skill-refiner/scripts/validate_noisy_implementation_result.sh" \
  shared/skills/skill-refiner/evals/dogfood/fixture-backed-noisy-implementation-skill/with_skill/outputs/noisy-implementation-skill \
  >"$(new_tmp)"

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
assert_present '写“默认从 X 接手/读取”，但没有给出 X 的来源、提供方、缺失定位或阻断方式' "$INPUT_RUBRIC"
assert_present 'HARD-GATE Why 有条件保留' "$RESOURCE_RUBRIC"
assert_present '不复述规则，不展开方法论' "$RESOURCE_RUBRIC"
assert_present 'reference 职责清楚' "$RESOURCE_RUBRIC"
assert_present '方法论、判定口径、专业框架、案例和检查矩阵' "$RESOURCE_RUBRIC"
assert_present 'reference 目标清晰' "$RESOURCE_RUBRIC"
assert_present '聚焦一个专业判断或操作问题' "$RESOURCE_RUBRIC"
assert_present 'reference 按用途组织' "$RESOURCE_RUBRIC"
assert_present '方法论写处理对象、步骤和产出' "$RESOURCE_RUBRIC"
assert_present '判定口径写判断维度、通过/问题信号和证据要求' "$RESOURCE_RUBRIC"
assert_present '混合型内容合并表达时' "$RESOURCE_RUBRIC"
assert_present 'reference 收口清楚' "$RESOURCE_RUBRIC"
assert_present '裁决标准、证据要求、输出要求、完成条件、问题信号或评审要点' "$RESOURCE_RUBRIC"
assert_present '参数明确' "$DETERMINISM_RUBRIC"
assert_present '命令包含 `$PHASE_DIR`、`$TASK_ID` 等参数' "$DETERMINISM_RUBRIC"
assert_absent '生命周期集成' "$ENGINEERING_CARRIER"
assert_present '有效性记录入口' "$ENGINEERING_CARRIER"

printf '[PASS] skill-refiner agent loop\n'

#!/usr/bin/env bash
# File role: prove skill-refiner uses ring rubrics without adding a second execution layer.
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
blocked_creator_route='纯''新建独立 Skill 交给 `skill-creator`'

assert_present '先确认入口事实与假设边界，再逐环节共创职责边界、办事流程、消费者、10 个环节最佳实践和验证方式，并在 SR-F1 整体策略确认后给出最终操作判断' "$SKILL"
assert_present 'allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion' "$SKILL"
assert_absent '^allowed-tools: .*Agent' "$SKILL"
assert_present 'SR-S2 必须产出用户确认的入口事实与假设边界；SR-S3、SR-R1~SR-R10 必须产出用户确认的结论；确认前不得创建、修改、删除或迁移目标文件' "$SKILL"
assert_present '任何推进、阻断或下一步输出都必须明示本轮 G/S/E 维度' "$SKILL"
assert_present '每个 ISSUE/ISSUE_FIXED 环节必须有问题卡；每个 SR-R 环节必须单独共创目标形态、保留能力、问题证据、候选策略、验证方式和 PASS/ISSUE_FIXED/BLOCKED 证据' "$SKILL"
assert_present '字段、模板、脚本、测试、引用和运行入口必须有消费者；无消费者内容只能登记为删除候选或停下确认' "$SKILL"
assert_present '只有 SR-F1 收到用户明确 `整体策略确认` 后，才能给出最终操作判断并一次性执行创建、优化、重写、替换、拆分、迁移或删除' "$SKILL"
assert_present '草案格式固定为：当前判断、最佳实践目标、最佳实践来源、适用/不适用条件、保留能力、问题证据、候选策略、验证方式、需要用户确认的问题' "$SKILL"
assert_present 'SR-F1 前只允许写入或更新本轮 `refinement-ledger.json`；目标 Skill、测试、runtime、引用和文档入口仍不得修改' "$SKILL"
assert_present '每轮继续打磨前先用 `references/problem-framing.md` 反问：为什么这是下一刀、对应哪个环节和质量维度、消费者是谁、如何验证；答不清时只登记候选缺口，不改文件' "$SKILL"
assert_absent 'Read: problem-framing.md' "$PROBLEM_FRAMING"
assert_absent 'Trigger: 每轮继续打磨前。 Read:' "$PROBLEM_FRAMING"
assert_present '草案必须先给当前判断、推荐选项和裁决理由；不把空白问题直接抛给用户' "$SKILL"
assert_present '暂停时只请求当前主题或当前环节确认，不把后续环节打包成一次性确认' "$SKILL"
assert_present '确认问题必须是“请选择/确认/修正我的草案”；开放问题只在选项无法覆盖关键事实时使用' "$SKILL"
assert_present '用户在暂停点补充新反馈时，先判断它是当前环节修正、后续环节证据还是范围变更；不得因此直接执行文件改动' "$SKILL"
assert_present '每个环节确认后必须更新 `refinement-ledger.json`' "$SKILL"
assert_present '进入下一环节前先读取 `current_state` 和 `latest_checkpoint_id`' "$SKILL"
assert_present '每个 SR-R 环节都必须记录 `best_practice_sources`、`source_conflicts`、`applicability` 和 `non_applicability`' "$SKILL"
assert_present '来源类型从官方、GitHub、社区、本仓库实践和用户上下文中按需选择，不能只在 Flow 环节调研最佳实践' "$SKILL"
assert_present '## 共创台账' "$SKILL"
for expected in \
  '## 交互模式定义' \
  '静默：只读、盘点和归纳候选线索，不替用户裁决目标、边界或策略' \
  '全共创：按本步骤声明的顺序一次只推进一个待确认问题；先给推荐草案或 2-3 个选项，用户确认前只追问，不形成最终结论' \
  '草案修正：先给草案，用 `[?]` 标出未确认点；同一轮只处理当前环节的一个未确认点，用户确认后才形成该环节结论' \
  '静默后汇报：先验证，再按成功标准报告通过、阻塞和残留风险'; do
  assert_present "$expected" "$SKILL"
done
assert_absent "$blocked_creator_route" "$SKILL"
assert_present 'SR-S2 只确认入口事实、用户反馈和假设边界；不得把根因、最终成功标准、最终操作判断或环节策略写成已确认结论' "$SKILL"
assert_present '真实场景、业务约束、用户预期结果线索、已观察痛点、不可丢能力候选、本轮切入点候选、已定位承载和未确认缺口' "$SKILL"
assert_present '你是 Skill 精修 owner。你先和用户确认入口事实与假设边界，再共创专业职责、真实办事流程和 10 个环节的最佳实践' "$SKILL"
assert_present '用户修正优先于 rubric 建议；rubric 用于给出专业判断依据，不替用户确认目标' "$SKILL"
assert_present 'SR-R 环节只登记候选操作和候选策略；最终操作判断只在 SR-F1 基于全部环节结论冻结' "$SKILL"
assert_present 'SR-E1 后必须写入 `skill-refiner-result.json`' "$SKILL"
assert_present '完成收口只在 SR-F1 用户明确 `整体策略确认` 后发生' "$SKILL"
assert_present '读取：冻结策略涉及的文件、`references/noise-taxonomy.md` 和 `{{RUNTIME_HOME}}/reference/Skill质量标准.md`' "$SKILL"
assert_present '执行编译降噪审查：逐句确认目标 `SKILL.md` 只保留执行动作、判断条件、阻断规则、产物要求、引用路由、失败处理或不可绕过 Why' "$SKILL"
assert_present '分析维度、消费者解释、工具边界说明、写作约束和测试意图必须落到流程动作、reference、script/schema/hook、eval/test 或删除项' "$SKILL"
assert_absent 'D-G1 式收口' "$SKILL"
assert_present 'digraph skill_refiner_flow' "$SKILL"
assert_present '## 流程图' "$SKILL"
assert_present '流程图只表达状态推进、暂停点和分支条件；逐步动作见 SR-S1~SR-V1' "$SKILL"
assert_present '"SR-S1 定位承载" -> "SR-S2 入口基线"' "$SKILL"
assert_present '"SR-R1~SR-R10 逐环节共创" -> "SR-F1 整体策略冻结"' "$SKILL"
assert_present '"SR-F1 整体策略冻结" -> "Pause SR-F1 等待整体策略确认"' "$SKILL"
assert_present '"SR-E1 一次性执行" -> "SR-Rx 回到对应环节"' "$SKILL"
assert_present '产物：验证结果、阻断项、残留风险，以及用问题定义卡排序后的下一轮候选环节' "$SKILL"
assert_present '读取：本轮改动、`references/noise-taxonomy.md` 和相关测试断言；验证失败时只读取本轮改动相关文件' "$SKILL"
assert_present '残留噪音扫描必须覆盖分析维度章节化、运行时泄漏、工具边界说明、写作约束泄漏、负向引导堆叠和测试固化旧噪音' "$SKILL"
assert_present '存在未裁决冲突时，只请求该冲突裁决；未收到 `整体策略确认` 时，不得进入 SR-E1' "$SKILL"
assert_absent '"进入执行队列"' "$SKILL"
assert_absent '"判断新建或精修"' "$SKILL"
assert_present '### SR-S2 共创入口基线' "$SKILL"
assert_present '暂停条件：存在多个入口基线缺口时，按真实场景和已观察痛点、业务约束和用户预期结果线索、不可丢能力候选和本轮切入点候选、已定位承载和未确认缺口的顺序，每轮只确认一个最靠前缺口，不进入职责或环节共创' "$SKILL"
assert_present '禁止事项：不得在本步声明已定位根因、最终成功标准、最终操作判断或任何 SR-R 环节策略；这些只能在 SR-S3、SR-R1~SR-R10 和 SR-F1 中形成' "$SKILL"
assert_present '暂停条件：找不到目标 Skill 或既有能力线索时，向用户要能力名称、路径或使用场景' "$SKILL"
assert_present '候选问题信号、候选保留能力、候选删除项；这些只作为 SR-R1~SR-R10 的证据，不形成策略' "$SKILL"
assert_absent '停止本流程并转交 `skill-creator`' "$SKILL"
for step in SR-R1 SR-R2 SR-R3 SR-R4 SR-R5 SR-R6 SR-R7 SR-R8 SR-R9 SR-R10; do
  assert_present "### ${step} " "$SKILL"
done
assert_present '做什么：读取最新台账，共创真实办事顺序、阶段闸门、失败分支和目标闭合条件' "$SKILL"
assert_present '做什么：读取最新台账，共创默认产物、消费者、人工摘要边界和机器结果事实源' "$SKILL"
assert_present '做什么：读取最新台账，共创主 SOP、reference、script、schema、template、eval 和 test 的职责分层' "$SKILL"
assert_present '做什么：读取最新台账，共创哪些判断必须外移到脚本、schema 或测试，以及执行入口和失败结果' "$SKILL"
assert_present '做什么：读取最新台账，共创何时触发、何时分流给相邻 Skill、创建/重写/拆分候选操作何时只能登记、何时必须后置到 SR-F1 裁决' "$SKILL"
assert_present '产物：用户确认的 Trigger 最佳实践目标、保留能力、问题证据、候选策略和验证方式' "$SKILL"
assert_present '产物：用户确认的 Resource 最佳实践目标、保留能力、问题证据、候选迁移/删除策略和验证方式' "$SKILL"
assert_present '产物：用户确认的 Runtime 最佳实践目标、问题证据、候选同步策略、运行验证方式和残留风险' "$SKILL"
assert_present '做什么：汇总台账、SR-R1~SR-R10 的蓝图、候选策略、验证方式、风险和跨环节冲突，给出最终操作裁决卡，请求用户明确 `整体策略确认`' "$SKILL"
assert_present '运行入口和运行副本无法同步验证时，不进入 SR-F1' "$SKILL"
assert_absent '安装入口' "$SKILL"
assert_absent '安装副本' "$SKILL"
assert_absent '安装清单' "$SKILL"
assert_absent '优先交给 sub agent' "$SKILL"
assert_absent 'sub agent 负责' "$SKILL"
assert_absent '最小上下文' "$SKILL"
assert_present '候选信号、旧测试、旧文档和执行结果自证都只是证据' "$SKILL"
assert_absent '## 环节标准循环' "$SKILL"
assert_absent '就近标准不足以裁决时' "$SKILL"
for rubric in trigger responsibility input flow output resource determinism eval cleanup runtime; do
  assert_present "读取：\`references/rubrics/${rubric}.md\`" "$SKILL"
done
assert_absent 'skill-harness' "$SKILL"
assert_absent '## Sub Agent 审查队列' "$SKILL"
assert_absent 'references/reviewers/' "$SKILL"
assert_absent '只读质量审计、迁移审计或 finding 输出时，交给 `skill-harness`。' "$SKILL"
assert_present '入口动作明确：有路径读路径；无路径按能力名、相邻 Skill、测试、触发描述和运行入口找现有承载。' "$RUBRIC_DIR/trigger.md"
assert_present '最终操作后置：原地修改、重写、替换、拆分或新建承载只能作为候选进入环节记录；最终判断必须等 SR-F1 汇总全部环节后冻结。' "$RUBRIC_DIR/trigger.md"
assert_present '用户未给路径时，不尝试按能力线索寻找现有承载。' "$RUBRIC_DIR/trigger.md"
assert_present '在 SR-F1 前输出新建、重写、替换或拆分的最终结论。' "$RUBRIC_DIR/trigger.md"
assert_absent "$blocked_creator_route" "$RUBRIC_DIR/trigger.md"
assert_present '"anchor": "先和用户共创入口基线，只补齐真实场景、业务约束、用户预期结果线索、已观察痛点、不可丢能力候选、本轮切入点候选、已定位承载和未确认缺口；不得在 SR-S2 产出根因、最终成功标准或最终操作判断；再改文件"' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_present '"anchor": "按 SR-R1 Trigger 到 SR-R10 Runtime 单独共创每个环节；每个环节都有用户确认的最佳实践蓝图、候选策略、验证方式和 PASS、ISSUE_FIXED 或 BLOCKED 证据；不能修完单个问题就收口"' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_present '"anchor": "每个环节先共创最佳实践蓝图、候选策略和验证方式，最终操作判断前除台账外不改目标文件"' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_present '"anchor": "全部环节最佳实践与候选策略冻结后，SR-F1 才给出最终操作判断；冻结前除台账外没有目标文件变更"' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_present '真实场景、业务约束、用户预期结果线索、已观察痛点、不可丢能力候选、本轮切入点候选' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_present 'refinement-ledger.json' "$ROOT/shared/skills/skill-refiner/evals/dogfood/small-output-contract/skill-refiner-result.json"
assert_present 'best_practice_sources' "$ROOT/shared/skills/skill-refiner/evals/dogfood/small-output-contract/skill-refiner-result.json"
assert_present '主导共创产品 Skill 的入口基线，只确认真实场景、业务约束、用户预期结果线索、已观察痛点、不可丢能力候选和本轮切入点候选' "$ROOT/shared/skills/skill-refiner/test-prompts.json"
assert_present '先按 review、code-review、审查等能力线索查找现有 Skill、测试和触发入口' "$ROOT/shared/skills/skill-refiner/test-prompts.json"
assert_present '先共创旧能力去留、拆分边界、候选迁移策略和 active 消费者清理；拆出的能力是否成为新 Skill 只能作为候选结果登记；SR-F1 汇总全环节后才给出拆分或新建的最终判断，冻结前不创建、拆分或迁移文件' "$ROOT/shared/skills/skill-refiner/test-prompts.json"
assert_present '"business_constraint",' "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py"
assert_present '"ring_sequence"' "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py"
assert_present '"ring_results"' "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py"
assert_present '"execution_gate"' "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py"
assert_present '"co_created_baseline"' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_present '"co_created_baseline"' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
assert_present '"decision": "optimize"' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
assert_present 'pilot_empirical_sample_recorded' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
assert_present '"anchor_count": 12' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
assert_present '"eval_count": 6' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
assert_present '"fidelity": 1.0' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
assert_present '"uplift": 0.5' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
assert_present 'skill-refiner-final-operation-create-gate-live-with/summary.json' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
assert_absent 'co_creation_baseline' "$ROOT/shared/skills/skill-refiner/evals/evals.json"
assert_absent 'co_creation_baseline' "$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"

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
missing.extend(
    f"{item['id']}:SR-12"
    for item in data["evals"]
    if item["id"] in loop_required and "SR-12" not in set(item.get("expected_anchors", []))
)
if missing:
    raise SystemExit(f"evals missing required anchor: {', '.join(missing)}")
PY

python3 - "$ROOT/shared/skills/skill-refiner/evals/evals.json" "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py" <<'PY'
import ast
import json
import sys

evals_path, grader_path = sys.argv[1], sys.argv[2]
data = json.load(open(evals_path, encoding="utf-8"))
anchors = {item["id"] for item in data["preference_anchors"]}
module = ast.parse(open(grader_path, encoding="utf-8").read())
checks = set()
for node in module.body:
    if isinstance(node, ast.Assign):
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id == "ANCHOR_CHECKS":
                checks = {key.value for key in node.value.keys if isinstance(key, ast.Constant)}
missing = sorted(anchors - checks)
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
  fail "SR-9 grader must fail when an intake baseline field is missing"
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
    "Responsibility",
    "Input",
    "Flow",
    "Output",
    "Resource",
    "Determinism",
    "Eval",
    "Cleanup",
    "Runtime",
    "Trigger",
]
data["agent_loop"]["ring_results"] = [
    {"ring": ring, "status": "PASS", "evidence": f"{ring} checked"}
    for ring in data["agent_loop"]["ring_sequence"]
]
json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
if python3 "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py" --result "$tmp_result_wrong_order" >"$(new_tmp)" 2>&1; then
  fail "SR-10 grader must fail when ring order does not follow SR-R1 through SR-R10"
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
data["agent_loop"]["candidate_strategy_confirmed_before_final_operation"] = False
json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
if python3 "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py" --result "$tmp_result_no_strategy_confirmation" >"$(new_tmp)" 2>&1; then
  fail "SR-11 grader must fail when blueprint and candidate strategy confirmation are missing"
fi

tmp_result_no_strategy_freeze="$(new_tmp)"
python3 - "$ROOT/shared/skills/skill-refiner/evals/dogfood/fixture-backed-noisy-implementation-skill/with_skill/dogfood-result.json" "$tmp_result_no_strategy_freeze" <<'PY'
import json
import sys

source, target = sys.argv[1], sys.argv[2]
data = json.load(open(source, encoding="utf-8"))
data["agent_loop"].pop("execution_gate", None)
json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
if python3 "$ROOT/shared/skills/skill-refiner/scripts/grade_fixture_anchor_fidelity.py" --result "$tmp_result_no_strategy_freeze" >"$(new_tmp)" 2>&1; then
  fail "SR-12 grader must fail when whole-strategy freeze evidence is missing"
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
assert_present '目标闭合' "$FLOW_RUBRIC"
assert_present '阶段闸门清楚' "$FLOW_RUBRIC"
assert_present '单个环节策略确认后就开始创建、修改、删除或迁移文件' "$FLOW_RUBRIC"
assert_present '流程图只表达状态、暂停点和分支，不制造额外动作' "$FLOW_RUBRIC"
assert_absent '流程图表达的是状态和分支' "$FLOW_RUBRIC"
assert_absent '循环闭合' "$FLOW_RUBRIC"
assert_present '流程图无歧义' "$FLOW_RUBRIC"
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
assert_present '阶段门禁可测' "$EVAL_RUBRIC"
assert_present '全环节策略冻结前无文件改动' "$EVAL_RUBRIC"
assert_present '编译降噪审查' "$NOISE_TAXONOMY"
assert_present '分析维度泄漏' "$NOISE_TAXONOMY"
assert_present '工具边界说明' "$NOISE_TAXONOMY"
assert_present '写作约束泄漏' "$NOISE_TAXONOMY"
assert_present '每句话必须能归入执行动作、判断条件、阻断规则、产物要求、引用路由、失败处理或不可绕过 Why' "$NOISE_TAXONOMY"
assert_absent '生命周期集成' "$ENGINEERING_CARRIER"
assert_present '有效性记录入口' "$ENGINEERING_CARRIER"
assert_present '先问为什么这是下一刀，它是否比其他候选更直接提升用户成功标准' "$PROBLEM_FRAMING"
assert_present '下一刀理由：' "$PROBLEM_FRAMING"
assert_present '反证：' "$PROBLEM_FRAMING"
assert_present '无法说明为什么本轮优先级高于其他候选缺口' "$PROBLEM_FRAMING"
printf '[PASS] skill-refiner agent loop\n'

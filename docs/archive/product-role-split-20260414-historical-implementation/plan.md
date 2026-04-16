# Product Role Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 把当前单体 `/product` skill 拆成 `product-director` 与 `product-manager` 两个独立角色，并让共享模板、lock snapshot handoff、runtime 兼容入口、下游 skill、tests 与 eval 资产一起迁移到新契约。

**Architecture:** 先抽出 `shared/skills/product-shared` 作为共享模板真源，再分别落地 `product-director` 和 `product-manager` 的 skill 文档、reference 与 completion gate。随后把 `contracts / hooks / install / compat / downstream skills` 切到新链路，并用 shell contract tests、runtime probes 和 eval 资产冻结兼容语义，避免仓库内残留两套互相矛盾的 `/product` 契约。

**Tech Stack:** Markdown skill docs/templates, Bash completion checks, JSON/YAML contracts, Python runtime hook utilities, shell contract tests, eval scenarios/graders.

---

## File Boundaries

- `shared/skills/product-shared/*`
  - 只承载 Director / Manager 共同消费的模板真源，不放角色独有流程说明。
- `shared/skills/product-director/*`
  - 只承载 Director 流程、Phase 规划、Director 确认门和 lock snapshot 产出 gate。
- `shared/skills/product-manager/*`
  - 只承载 Manager handoff、UNIT/AC 共创、审查与交付确认，以及 lock drift 阻断 gate。
- `shared/skills/product/*`
  - 过渡期只保留兼容入口说明，不再承载旧的混合职责与模板真源。
- `contracts/*`, `shared/hooks/*`, `install.sh`
  - 负责 runtime 链路、completion gate、active-skill tracking、compat redirect 和安装迁移。
- `shared/skills/design/*`, `shared/skills/test-design/*`, `shared/skills/tech-lead/*`, `shared/skills/delivery-owner/*`, `shared/skills/fix/*`
  - 只更新上游入口和 source anchor，不改内部职责。
- `tests/*`, `tools/dev/*`, `tools/eval/*`, `docs/product-role-split-20260414/evidence-and-eval-plan.md`
  - 负责把新链路冻结成可回归验证资产。

## Execution Order

- `T1` 先建立共享模板真源和 split contract 测试基线。
- `T2`、`T3` 在共享模板稳定后分别实现 Director 和 Manager。
- `T4` 在两个新 skill 可用后，再切换 runtime、compat 入口和下游 skill。
- `T5` 最后更新验证资产、eval/probe，并跑全套 fresh proving commands。

### Task 1: Shared template source and split contract baseline [T1]

Files:
- Create: `shared/skills/product-shared/references/templates/brief-template.md`
- Create: `shared/skills/product-shared/references/templates/phase-prd-template.md`
- Create: `tests/test-product-role-split-contract.sh`

1. [T1] 先写一个专用 RED contract test，把共享模板真源和新 skill 根目录冻结下来。

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$ROOT/shared/skills/product-shared/references/templates/brief-template.md" || fail "missing shared brief template"
test -f "$ROOT/shared/skills/product-shared/references/templates/phase-prd-template.md" || fail "missing shared phase template"
test -d "$ROOT/shared/skills/product-director" || fail "missing product-director root"
test -d "$ROOT/shared/skills/product-manager" || fail "missing product-manager root"

echo "[PASS] product role split contract"
```

2. [T1] 运行 RED，确认仓库当前还没有这些共享模板和新目录。

Run: `bash tests/test-product-role-split-contract.sh`
Expected: FAIL，至少提示缺少 `shared/skills/product-shared/references/templates/brief-template.md` 或 `product-director` / `product-manager` 根目录。

3. [T1] 创建共享模板真源，并从当前 `shared/skills/product/references/templates/*` 复制现有结构后补上 Director / Manager 共用的新节位。

```markdown
## 产品总监确认
- 确认状态: {待确认}
- 确认时间: YYYY-MM-DD HH:mm

## 共创摘要
| 阶段 | 技能 | 摘要 |
|------|------|------|

## 引用锚点合同
...
```

```markdown
## 交付计划
| Phase | 标题 | 入口条件 | 出口条件 | 交付价值 | UNIT | 定义文件 | 工作区 | 状态 |
|-------|------|---------|---------|---------|------|---------|-------|------|
```

4. [T1] 同时建立后续任务要用的目录骨架，避免 T2 / T3 再重复建树。

```bash
mkdir -p \
  shared/skills/product-director/{agents,references,scripts} \
  shared/skills/product-manager/{agents,references,scripts}
```

5. [T1] 跑 GREEN，确认共享模板和 split 根目录已经就位。

Run: `bash tests/test-product-role-split-contract.sh`
Expected: PASS，输出 `[PASS] product role split contract`

6. [T1] 提交共享模板与 split baseline。

```bash
git add \
  shared/skills/product-shared/references/templates/brief-template.md \
  shared/skills/product-shared/references/templates/phase-prd-template.md \
  tests/test-product-role-split-contract.sh
git commit -m "feat: add product split baseline"
```

### Task 2: Product-director skill and director-only gate [T2]

Files:
- Create: `shared/skills/product-director/SKILL.md`
- Create: `shared/skills/product-director/agents/openai.yaml`
- Create: `shared/skills/product-director/references/conversation-guide.md`
- Create: `shared/skills/product-director/references/phase-splitting-guide.md`
- Create: `shared/skills/product-director/scripts/completion_check.sh`
- Modify: `shared/skills/product-shared/references/templates/brief-template.md`
- Modify: `shared/skills/product-shared/references/templates/phase-prd-template.md`
- Modify: `tests/test-product-stability-guidance-contract.sh`
- Modify: `tests/test-product-role-split-contract.sh`

1. [T2] 先把 `tests/test-product-stability-guidance-contract.sh` 改成指向 `product-director + product-shared`，并加入 Director 流程与 lock snapshot 的断言。

```bash
DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
BRIEF_TEMPLATE="$ROOT/shared/skills/product-shared/references/templates/brief-template.md"
PHASE_TEMPLATE="$ROOT/shared/skills/product-shared/references/templates/phase-prd-template.md"

assert_present '^name: product-director$' "$DIRECTOR_SKILL"
assert_present 'D-S1 \| 静默信息收集' "$DIRECTOR_SKILL"
assert_present 'D-G1 \| 总监确认门' "$DIRECTOR_SKILL"
assert_present 'brief.lock.json' "$DIRECTOR_SKILL"
assert_present 'phase-\{N\}/prd.lock.json' "$DIRECTOR_SKILL"
assert_present '^## 产品总监确认$' "$BRIEF_TEMPLATE"
assert_present '^## 引用锚点合同$' "$PHASE_TEMPLATE"
```

2. [T2] 运行 RED，确认 Director skill 与 gate 现在还不存在或缺少关键字段。

Run: `bash tests/test-product-stability-guidance-contract.sh`
Expected: FAIL，提示缺少 `shared/skills/product-director/SKILL.md`、`brief.lock.json` 断言或新的模板节。

3. [T2] 写入 `product-director` 的 SKILL 和 reference，只保留 Director 负责的步骤、产出和流程导航。

```markdown
---
name: product-director
description: 产品总监负责根问题、目标、范围、Phase 规划与 Director 基线冻结。
disable-model-invocation: true
user-invocable: true
---

# /product-director -- 战略收口与 Director 基线冻结

## 流程导航
Product-director 完成后，下一步执行 `/product-manager`。
```

4. [T2] 以当前 `shared/skills/product/scripts/completion_check.sh` 为参考拆出 Director 轻量 gate，只校验 Director 工件、确认门和 lock snapshots。

```bash
validate_director_confirmation() {
  rg -n '^## 产品总监确认$' "$brief_file" >/dev/null 2>&1 || add_failure "brief.md 缺少产品总监确认节"
}

validate_brief_lock_snapshot() {
  [ -f "$feature_dir/brief.lock.json" ] || add_failure "缺少 brief.lock.json"
}

validate_phase_prd_lock_snapshots() {
  find "$feature_dir" -path '*/prd.lock.json' | rg 'prd.lock.json' >/dev/null 2>&1 || add_failure "缺少 phase prd lock snapshot"
}
```

5. [T2] 跑 GREEN，确认 Director 文档与轻量 gate 已落地。

Run: `bash tests/test-product-role-split-contract.sh`
Expected: PASS

Run: `bash tests/test-product-stability-guidance-contract.sh`
Expected: PASS，输出 `[PASS] product stability guidance contract`

6. [T2] 提交 Director skill 与轻量 gate。

```bash
git add \
  shared/skills/product-director/SKILL.md \
  shared/skills/product-director/agents/openai.yaml \
  shared/skills/product-director/references/conversation-guide.md \
  shared/skills/product-director/references/phase-splitting-guide.md \
  shared/skills/product-director/scripts/completion_check.sh \
  shared/skills/product-shared/references/templates/brief-template.md \
  shared/skills/product-shared/references/templates/phase-prd-template.md \
  tests/test-product-stability-guidance-contract.sh \
  tests/test-product-role-split-contract.sh
git commit -m "feat: add product-director skill"
```

### Task 3: Product-manager skill and lock-drift gate [T3]

Files:
- Create: `shared/skills/product-manager/SKILL.md`
- Create: `shared/skills/product-manager/agents/openai.yaml`
- Create: `shared/skills/product-manager/references/conversation-guide.md`
- Create: `shared/skills/product-manager/references/closed-loop-unit-spec.md`
- Create: `shared/skills/product-manager/references/completeness-checklist.md`
- Create: `shared/skills/product-manager/references/prd-reviewer-prompt.md`
- Create: `shared/skills/product-manager/references/architect-reviewer-prompt.md`
- Create: `shared/skills/product-manager/references/tester-reviewer-prompt.md`
- Create: `shared/skills/product-manager/scripts/completion_check.sh`
- Modify: `shared/skills/product-shared/references/templates/brief-template.md`
- Modify: `shared/skills/product-shared/references/templates/phase-prd-template.md`
- Modify: `tests/test-skill-output-and-gate-contract.sh`
- Modify: `tests/test-product-role-split-contract.sh`

1. [T3] 把 `tests/test-skill-output-and-gate-contract.sh` 的 product 路径和 hook fixture 改成 `product-manager + product-shared`，并加入 Manager gate 的 handoff / drift 断言。

```bash
PRODUCT_MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
PRODUCT_MANAGER_CHECK="$ROOT/shared/skills/product-manager/scripts/completion_check.sh"
PRODUCT_MANAGER_REVIEWER="$ROOT/shared/skills/product-manager/references/prd-reviewer-prompt.md"

assert_present '^name: product-manager$' "$PRODUCT_MANAGER_SKILL"
assert_present 'M-S0 \| 工件接收与验证' "$PRODUCT_MANAGER_SKILL"
assert_present 'Director 锁定内容是否与 D-G1 快照一致' "$PRODUCT_MANAGER_REVIEWER"
assert_present 'validate_director_handoff_preconditions' "$PRODUCT_MANAGER_CHECK"
assert_present 'validate_locked_field_drift' "$PRODUCT_MANAGER_CHECK"
```

```bash
PRODUCT_MANAGER_HOOK_ROOT="$HOOK_FIXTURE_ROOT/product-manager-hook"
mkdir -p "$PRODUCT_MANAGER_HOOK_ROOT/docs/product-manager-hook/phase-1/units"
```

2. [T3] 运行 RED，确认 Manager skill、prompt 和 hook contract 现在还不满足 split 契约。

Run: `bash tests/test-skill-output-and-gate-contract.sh`
Expected: FAIL，提示缺少 `product-manager` skill、hook fixture、R1 漂移检查或 gate helper。

3. [T3] 写入 `product-manager` skill 和 reference，只保留 Manager handoff、UNIT/AC 共创、审查与交付确认语义。

```markdown
---
name: product-manager
description: 产品经理负责 handoff 后的业务流程细化、UNIT 共创、AC 收口与交付确认。
disable-model-invocation: true
user-invocable: true
---

# /product-manager -- handoff 后需求精化与 UNIT 共创

## 流程导航
Product-manager 完成后，下一步执行 `/design`。
```

4. [T3] 以当前 `shared/skills/product/scripts/completion_check.sh` 为参考重写 Manager gate，把 lock precondition、lock drift、`scope_item_id` 终态格式和审查 FAIL 关口收进新脚本。

```bash
validate_director_handoff_preconditions() {
  [ -f "$feature_dir/brief.lock.json" ] || add_failure "缺少 brief.lock.json"
  rg -n '^## 产品总监确认$' "$brief_file" >/dev/null 2>&1 || add_failure "brief.md 缺少产品总监确认节"
}

validate_locked_field_drift() {
  rg -n '产品总监确认' "$brief_file" >/dev/null 2>&1 || add_failure "未找到 Director 锁定节"
}

validate_manager_scope_item_ids() {
  rg -n 'SCOPE-P[0-9]+U[0-9]+-' "$brief_file" >/dev/null 2>&1 || add_failure "scope_item_id 未细化为最终格式"
}
```

5. [T3] 跑 GREEN，确认 Manager skill、prompts 和 hook contract 已经切到新路径。

Run: `bash tests/test-product-role-split-contract.sh`
Expected: PASS

Run: `bash tests/test-skill-output-and-gate-contract.sh`
Expected: PASS，退出码 0

6. [T3] 提交 Manager skill 与 drift gate。

```bash
git add \
  shared/skills/product-manager/SKILL.md \
  shared/skills/product-manager/agents/openai.yaml \
  shared/skills/product-manager/references/conversation-guide.md \
  shared/skills/product-manager/references/closed-loop-unit-spec.md \
  shared/skills/product-manager/references/completeness-checklist.md \
  shared/skills/product-manager/references/prd-reviewer-prompt.md \
  shared/skills/product-manager/references/architect-reviewer-prompt.md \
  shared/skills/product-manager/references/tester-reviewer-prompt.md \
  shared/skills/product-manager/scripts/completion_check.sh \
  shared/skills/product-shared/references/templates/brief-template.md \
  shared/skills/product-shared/references/templates/phase-prd-template.md \
  tests/test-skill-output-and-gate-contract.sh \
  tests/test-product-role-split-contract.sh
git commit -m "feat: add product-manager skill"
```

### Task 4: Runtime contract, compatibility entry, and downstream skill rewiring [T4]

Files:
- Modify: `contracts/skill-chain.yaml`
- Modify: `shared/hooks/registry.json`
- Modify: `shared/hooks/managed/codex_user_prompt_submit.py`
- Modify: `shared/hooks/managed/codex_stop_dispatch.py`
- Modify: `install.sh`
- Modify: `shared/skills/product/SKILL.md`
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/test-design/SKILL.md`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/fix/SKILL.md`
- Modify: `shared/skills/design/references/decision-templates.md`
- Modify: `shared/skills/design/references/constitution-template.md`
- Modify: `tests/test-codex-skill-adapter.sh`
- Modify: `tests/test-runtime-integrity.sh`
- Modify: `tests/test-install-smoke.sh`
- Modify: `tests/test-install-systematic.sh`
- Modify: `tests/test-delivery-owner-source-anchor-contract.sh`
- Modify: `tests/test-team-native-contract.sh`
- Modify: `tests/test-subagent-context-contract.sh`

1. [T4] 先把 runtime / downstream contract tests 改成 RED，锁定三件事：双 skill entry、生存中的 compat `product`、以及下游流程导航已经切到 `product-director → product-manager`。

```bash
assert_present '"skill": "product-director"' "$ROOT/shared/hooks/registry.json"
assert_present '"skill": "product-manager"' "$ROOT/shared/hooks/registry.json"
assert_present '"skill": "product"' "$ROOT/shared/hooks/registry.json"
assert_present 'supported": false' "$ROOT/shared/hooks/registry.json"
assert_present '完整流程：`/product-director → /product-manager → /design → /test-design → /tech-lead → /delivery-owner`' "$ROOT/shared/skills/design/SKILL.md"
```

```bash
python3 "$TMP_HOME/.codex/hooks/managed/codex_user_prompt_submit.py" <<JSON
{"cwd":"$TMP_HOME/work","session_id":"session-product","transcript_path":"$TMP_HOME/work/transcript.log","prompt":"/product 草拟需求"}
JSON
test ! -f "$TMP_HOME/.codex/hooks/state/active-skills/session-product.json" || fail "compat /product should not write active state"
```

2. [T4] 运行 RED，确认 runtime registry、state tracking、compat redirect 和 downstream flow 还没有全部切换。

Run: `bash tests/test-codex-skill-adapter.sh`
Expected: FAIL，至少提示 `product-director` / `product-manager` registry 行为缺失，或 `/product` 仍会写 active state。

Run: `bash tests/test-delivery-owner-source-anchor-contract.sh`
Expected: FAIL，提示 source anchor 仍引用旧 `shared/skills/product/references/templates/*` 或旧流程导航。

3. [T4] 更新 skill chain、registry 和 Codex hook runtime，使 `product-director` / `product-manager` 成为活跃 gate skill，而兼容入口 `product` 保留为 `supported: false`。

```yaml
chain:
  - name: product-director
  - name: product-manager
  - name: design
```

```json
{
  "skill": "product",
  "handler_rel": "skills/product/scripts/completion_check.sh",
  "codex": { "supported": false },
  "claude": { "supported": false }
}
```

```python
if skill not in load_supported_skills():
    return 0
```

4. [T4] 更新安装器、compat skill 与下游 skill 文案，只让旧 `/product` 保留重定向说明，并把所有 live source anchor 切到新路径。

```markdown
# /product

已拆分为 `/product-director` 与 `/product-manager`。
请从 `/product-director` 开始；兼容入口不再承载旧的混合职责。
```

```markdown
- `docs/{feature}/brief.md` + `phase-{N}/prd.md` + `phase-{N}/units/` 缺失时终止并提示先执行 `/product-manager`
- 完整流程：`/product-director → /product-manager → /design → /test-design → /tech-lead → /delivery-owner`
```

5. [T4] 跑 GREEN，确认 runtime、compat 和下游 source anchor 已经一起迁移。

Run: `bash tests/test-codex-skill-adapter.sh`
Expected: PASS，输出 `[PASS] codex skill adapter`

Run: `bash tests/test-runtime-integrity.sh`
Expected: PASS，退出码 0

Run: `bash tests/test-install-smoke.sh`
Expected: PASS，退出码 0

Run: `bash tests/test-install-systematic.sh`
Expected: PASS，退出码 0

Run: `bash tests/test-delivery-owner-source-anchor-contract.sh`
Expected: PASS，输出 `[PASS] delivery-owner source anchor contract`

Run: `bash tests/test-team-native-contract.sh`
Expected: PASS，退出码 0

Run: `bash tests/test-subagent-context-contract.sh`
Expected: PASS，退出码 0

6. [T4] 提交 runtime、compat 和 downstream rewiring。

```bash
git add \
  contracts/skill-chain.yaml \
  shared/hooks/registry.json \
  shared/hooks/managed/codex_user_prompt_submit.py \
  shared/hooks/managed/codex_stop_dispatch.py \
  install.sh \
  shared/skills/product/SKILL.md \
  shared/skills/design/SKILL.md \
  shared/skills/test-design/SKILL.md \
  shared/skills/tech-lead/SKILL.md \
  shared/skills/delivery-owner/SKILL.md \
  shared/skills/fix/SKILL.md \
  shared/skills/design/references/decision-templates.md \
  shared/skills/design/references/constitution-template.md \
  tests/test-codex-skill-adapter.sh \
  tests/test-runtime-integrity.sh \
  tests/test-install-smoke.sh \
  tests/test-install-systematic.sh \
  tests/test-delivery-owner-source-anchor-contract.sh \
  tests/test-team-native-contract.sh \
  tests/test-subagent-context-contract.sh
git commit -m "feat: migrate product split runtime contract"
```

### Task 5: Validation assets, eval/probe alignment, and proving suite [T5]

Files:
- Modify: `tools/dev/probe-codex-capabilities.sh`
- Modify: `tools/eval/run_skill_eval.sh`
- Create: `tools/eval/graders/product-director-thinking-grader.md`
- Create: `tools/eval/graders/product-manager-unit-quality-grader.md`
- Create: `tools/eval/scenarios/product-director-p1-clear-single-phase.md`
- Create: `tools/eval/scenarios/product-director-p2-solution-anchoring.md`
- Create: `tools/eval/scenarios/product-director-p3-multi-phase-value-slicing.md`
- Create: `tools/eval/scenarios/product-manager-p1-handoff-readiness.md`
- Create: `tools/eval/scenarios/product-manager-p2-lock-drift-blocking.md`
- Create: `tools/eval/scenarios/product-manager-p3-unit-boundary-cocreation.md`
- Create: `docs/product-role-split-20260414/evidence-and-eval-plan.md`
- Modify: `tests/test-product-eval-contract.sh`
- Modify: `tests/test-product-role-split-contract.sh`

1. [T5] 先把 eval / probe contract 变成 RED，要求 runner、scenario、grader 和 evidence plan 一起从旧 `/product` 迁到双 skill 结构。

```bash
DIRECTOR_P1="$ROOT/tools/eval/scenarios/product-director-p1-clear-single-phase.md"
MANAGER_P1="$ROOT/tools/eval/scenarios/product-manager-p1-handoff-readiness.md"
DIRECTOR_GRADER="$ROOT/tools/eval/graders/product-director-thinking-grader.md"
MANAGER_GRADER="$ROOT/tools/eval/graders/product-manager-unit-quality-grader.md"
PLAN_DOC="$ROOT/docs/product-role-split-20260414/evidence-and-eval-plan.md"

test -f "$DIRECTOR_P1" || fail "missing director eval scenario"
test -f "$MANAGER_P1" || fail "missing manager eval scenario"
test -f "$DIRECTOR_GRADER" || fail "missing director grader"
test -f "$MANAGER_GRADER" || fail "missing manager grader"
test -f "$PLAN_DOC" || fail "missing split eval plan"
assert_present 'product-director-p1-clear-single-phase\.md' "$RUNNER"
assert_present 'product-manager-p1-handoff-readiness\.md' "$RUNNER"
```

2. [T5] 运行 RED，确认当前 eval / probe 资产仍然围绕旧 `/product`。

Run: `bash tests/test-product-eval-contract.sh`
Expected: FAIL，提示缺少新的 Director / Manager scenario、grader 或 evidence plan。

3. [T5] 创建新的 eval 场景、grader 和 evidence plan，并更新 runner 与 probe，让它们只把 compat `/product` 当作 redirect，不再当作活跃评测入口。

```markdown
# P1: /product-director 清晰需求轻量收口场景
用途：验证 `/product-director` 是否能在方向问题上轻量收口，并正确把后续精化留给 `/product-manager`。
```

```markdown
# M1: /product-manager handoff readiness 场景
用途：验证 `/product-manager` 是否会在进入 UNIT 拆解前检查 `brief.lock.json / prd.lock.json` 和 Director 确认门。
```

```bash
DIRECTOR_SCENARIOS=(
  "tools/eval/scenarios/product-director-p1-clear-single-phase.md"
  "tools/eval/scenarios/product-director-p2-solution-anchoring.md"
  "tools/eval/scenarios/product-director-p3-multi-phase-value-slicing.md"
)
MANAGER_SCENARIOS=(
  "tools/eval/scenarios/product-manager-p1-handoff-readiness.md"
  "tools/eval/scenarios/product-manager-p2-lock-drift-blocking.md"
  "tools/eval/scenarios/product-manager-p3-unit-boundary-cocreation.md"
)
```

4. [T5] 同步更新 runtime probe 和 split contract test，确保 Codex 默认暴露面、manual-only 入口和 compat `/product` 语义保持一致。

```bash
if [ ! -f "$CODEX_HOME/skills/brainstorming/agents/openai.yaml" ] \
  || [ -f "$CODEX_HOME/skills/product/agents/openai.yaml" ] \
  || [ -f "$CODEX_HOME/skills/product-director/agents/openai.yaml" ] \
  || [ -f "$CODEX_HOME/skills/product-manager/agents/openai.yaml" ]; then
  fail_check "small-chain 自动暴露面不符合预期"
fi
```

5. [T5] 运行全套 GREEN proving commands，并补一轮 live-source audit，确认旧 `/product` 只剩兼容入口和允许的测试夹具。

Run: `bash tests/test-product-role-split-contract.sh`
Expected: PASS

Run: `bash tests/test-product-stability-guidance-contract.sh`
Expected: PASS

Run: `bash tests/test-skill-output-and-gate-contract.sh`
Expected: PASS

Run: `bash tests/test-codex-skill-adapter.sh`
Expected: PASS

Run: `bash tests/test-runtime-integrity.sh`
Expected: PASS

Run: `bash tests/test-install-smoke.sh`
Expected: PASS

Run: `bash tests/test-install-systematic.sh`
Expected: PASS

Run: `bash tests/test-delivery-owner-source-anchor-contract.sh`
Expected: PASS

Run: `bash tests/test-team-native-contract.sh`
Expected: PASS

Run: `bash tests/test-subagent-context-contract.sh`
Expected: PASS

Run: `bash tests/test-product-eval-contract.sh`
Expected: PASS

Run: `rg -n '/product|shared/skills/product' shared tests tools contracts install.sh -g '!tools/eval/results/**'`
Expected: 只剩 compat `/product`、redirect 文案、受控测试夹具与允许保留的历史文档引用。

6. [T5] 提交验证资产、eval / probe 迁移与最终 proving suite。

```bash
git add \
  tools/dev/probe-codex-capabilities.sh \
  tools/eval/run_skill_eval.sh \
  tools/eval/graders/product-director-thinking-grader.md \
  tools/eval/graders/product-manager-unit-quality-grader.md \
  tools/eval/scenarios/product-director-p1-clear-single-phase.md \
  tools/eval/scenarios/product-director-p2-solution-anchoring.md \
  tools/eval/scenarios/product-director-p3-multi-phase-value-slicing.md \
  tools/eval/scenarios/product-manager-p1-handoff-readiness.md \
  tools/eval/scenarios/product-manager-p2-lock-drift-blocking.md \
  tools/eval/scenarios/product-manager-p3-unit-boundary-cocreation.md \
  docs/product-role-split-20260414/evidence-and-eval-plan.md \
  tests/test-product-eval-contract.sh \
  tests/test-product-role-split-contract.sh
git commit -m "test: align product split validation assets"
```

## Final Verification

完成前执行：

- `bash tests/test-product-role-split-contract.sh`
- `bash tests/test-product-stability-guidance-contract.sh`
- `bash tests/test-skill-output-and-gate-contract.sh`
- `bash tests/test-codex-skill-adapter.sh`
- `bash tests/test-runtime-integrity.sh`
- `bash tests/test-install-smoke.sh`
- `bash tests/test-install-systematic.sh`
- `bash tests/test-delivery-owner-source-anchor-contract.sh`
- `bash tests/test-team-native-contract.sh`
- `bash tests/test-subagent-context-contract.sh`
- `bash tests/test-product-eval-contract.sh`

# Stage 1 Evaluator Protocol：评审执行协议

日期：2026-05-14

## 目标

本协议定义 Stage 1 evaluator agent 如何评审 `standard-chain` 角色输出。

Evaluator 不是格式打分器，而是严格的团队负责人：它要判断这位“同事”是否守住岗位职责、是否产出可被下游消费的专业结果、是否在该停时停住。

## 输入包

每次评审必须收到：

- `case_spec`: 当前 case 的 id、role、scenario、input_shape、must_show、fail_if、downstream_check。
- `role_output`: 被测角色的原始输出。
- `role_standard`: 来自 `stage-1-eval-charter.md`、`stage-1-eval-case-pack-v1.md` 和对应 `shared/skills/{role}/SKILL.md` 的标准。
- `upstream_refs`: 若存在上游产物，只能给真实上游输出或明确标注的 synthetic fixture。

禁止给被测角色泄露 expected output。Evaluator 可以读标准答案口径，但下游角色不能读 evaluator 结论。

## Synthetic Fixture Policy

Stage 1 可以使用 synthetic fixture 训练角色能力，但必须显式标注。

允许：

- 用 synthetic `brief.json`、`phase-prd.json`、`UNIT`、`design` 或 `test-cases` 测试单角色能力。
- 用缺失或冲突 fixture 测试准入、阻断和 owner action。
- 用 fixture 结果指导 skill/reference/schema/script/test 成长。

禁止：

- 把 synthetic fixture 结论当成真实 `qft-pai` 证据。
- 用 fixture 证明业务已经交付。
- 用 fixture 结果跳过 Stage 2 的真实代码采证、集成、灰度和回滚。

Evaluator 必须在结论里标明输入是 `real`、`synthetic` 还是 `missing`。缺少该标记时，评审结果最多只能作为草稿。

## 评审层次

Evaluator 按五层评审，不能只看格式。

### 1. 客观断言

检查可枚举事实：

- 是否进入禁止范围。
- 是否缺少必要输入来源。
- 是否声明输入、输出和下游消费者。
- 是否出现禁止宣称，例如 Stage 1 证明业务成功、真实 qft-pai 已交付。
- 是否越权写下游产物。

客观断言可由脚本、schema、hook 或人工逐项核对；能自动化的项后续必须外置。

### 2. 岗位专项能力

判断该角色是否完成本岗位核心专业动作：

- `product-director`: 根问题、目标、范围、非目标、Phase 价值切分。
- `product-manager`: 业务流程、用户路径、规则映射、UNIT、AC、依赖和排除项。
- `design`: 多方案、边界、接口、质量属性、观测、回滚和风险。
- `test-design`: traceability、测试义务、失败路径、typed gap、QA handoff。
- `tech-lead`: readiness、批次、任务合同、依赖、证据路径和 stop condition。
- `delivery-owner`: 阶段、阻塞、owner、调度、证据、signoff 和用户裁决。

字段完整但岗位判断错误，判失败。

### 3. 下游消费

判断下游是否能直接工作：

- 能继续：`chain_status=continue`。
- 正确暂停：`chain_status=pass_to_pause`。
- 失败停止：`chain_status=stop_on_failure`。

下游消费不是“下游能不能靠聪明补齐”，而是“不脑补是否能继续”。

### 4. LLM 与工程化边界

判断角色是否把确定性控制交给工程化：

- schema 负责结构。
- script/hook/test 负责可枚举校验。
- 状态机负责阶段和流转。
- artifact registry 负责证据和版本。
- LLM 负责语义判断、追问、建模、取舍和专业产物。

如果角色让 LLM 临场决定重试、状态码、幂等、权限或验收通过，至少 P1；导致错误推进则 P0。

### 5. 失败分级

- `P0`: 会让链路进入错误阶段、伪造成功、越过用户裁决或污染下游。
- `P1`: 不立刻污染下游，但必须修复或裁决。
- `P2`: 记录优化，不阻断当前阶段。
- `none`: 无问题。

## 输出 Schema

每次评审必须输出以下字段：

```yaml
judgment: pass | warn | fail
chain_status: continue | pass_to_pause | stop_on_failure
grade: P0 | P1 | P2 | none
evidence:
  - quote_or_ref: 被评审输出中的具体证据
role_standard:
  - 使用了哪条角色标准
downstream_impact: 影响哪个下游角色，如何影响
owner_action:
  owner: skill | reference | schema | script | test | human
  action: 具体修复、裁决或外置动作
objective_assertions:
  - id: 稳定检查项
    result: pass | warn | fail
    evidence: 证据
semantic_review: 语义判断
final_decision: 是否允许进入下一角色
```

字段名不得改写。特别是 `judgment` 与 `chain_status` 必须分开；正确暂停是 `judgment=pass` 且 `chain_status=pass_to_pause`。

## Chain Status Rules

### continue

使用条件：

- `judgment` 为 `pass` 或非阻断 `warn`。
- 当前角色产物足以被下游不脑补消费。
- 没有未闭合的 human 裁决点。

### pass_to_pause

使用条件：

- 当前角色岗位能力通过。
- 角色识别出会改变结论的缺失事实或风险裁决。
- 正确 owner 是 human 或上游角色。
- 继续下游会导致猜测或越权。

此状态必须记录 `resume_condition`。

### stop_on_failure

使用条件：

- 出现 P0。
- 角色输出污染下游、越权、伪造成功或违反非目标。
- 缺失本角色必需输入却继续产出。

此状态不得继续运行下游。

## Owner Action Rules

选择 owner 时按修复对象判断：

- `skill`: 流程顺序、停手边界、角色职责不清。
- `reference`: 方法论、样例、判断口径缺失。
- `schema`: 需要结构字段承载状态、owner、证据或版本。
- `script`: 可枚举检查应自动化。
- `test`: 需要回归覆盖某个失败模式。
- `human`: 缺真实业务事实、风险接受、范围裁决或授权。

Owner action 必须能执行，不能写“继续优化”。

## 运行记录布局

建议每轮运行写入：

```text
docs/feature--agent-delivery-operating-system/stage-1-runs/YYYY-MM-DD-<name>/
  run-manifest.md
  <case-id>/
    input.md
    role-output.md
    evaluator-output.md
    decision.md
```

如果是 dry-run，可继续放在 `dry-runs/`，但必须包含原始输出和 evaluator 输出。

## 禁止行为

- 不得用“看起来不错”打分。
- 不得用格式完整替代岗位能力。
- 不得为了跑完整链路忽略 `pass_to_pause`。
- 不得把 mock-only 当真实交付证据。
- 不得把 evaluator 个人偏好写成标准。
- 不得发现 P0 后给整体通过结论。

## 复评规则

复杂 case 至少两轮复检：

1. 首轮按 case 标准评审。
2. 第二轮换视角检查目标、成功标准、范围、验证证据、边界路径、失败路径、影响面和残余风险。
3. 连续两轮无新增目标内问题，才允许收口。

若人工评审与 evaluator agent 分歧，记录分歧，不得自行抹平；由人类负责人裁决或补 case 标尺。

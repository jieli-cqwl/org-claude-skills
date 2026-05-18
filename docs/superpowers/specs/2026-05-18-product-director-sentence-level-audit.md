# Product Director 句子级审计

日期：2026-05-18

## 结论

不是。当前 `product-director` 的每一句话还没有达到最佳实践。

核心问题有两类：

1. `D-S2 / D-G1` 这类编号不适合继续作为用户可见的运行时心智。它增加维护成本，弱化语义，并把模型注意力拉向流程编号，而不是业务产品判断。
2. 当前 `SKILL.md` 有不少句子能约束流程，但不能稳定驱动优秀负责人行为。最佳实践应是：每句话都明确触发条件、判断动作、边界、产出、验证或回退；不能只表达流程存在。

但编号不能单文件删除。补充核验显示，`D-S* / D-G*` 当前已经进入确定性契约：

- `contracts/co-creation-ledgers.yaml` 使用 `checkpoint_steps: [D-S2, D-S3, D-S4, D-S5, D-S5.5, D-S6, D-G1]`。
- `tools/community/validate_co_creation_ledger.py` 用同一组 step 校验 `product-director` 台账。
- `tests/test-standard-chain-co-creation-ledger-contract.sh`、`tests/test-standard-chain-skill-structure.sh`、`tests/test-product-context-signal-quality.sh` 等测试直接断言这些编号。

因此最佳路线不是“保留编号”，也不是“单文件删除编号”，而是迁移：

`D-S* 编号 -> 语义 checkpoint id -> skill 运行时只暴露语义阶段`

例如：

| 当前编号 | 建议语义 checkpoint |
| --- | --- |
| D-S2 | `problem-framing` |
| D-S3 | `success-investment` |
| D-S4 | `semantic-alignment` |
| D-S5 | `scope-boundary` |
| D-S5.5 | `risk-phase-impact` |
| D-S6 | `phase-value-slicing` |
| D-G1 | `director-freeze-gate` |

## 句子级审计标准

本次按已定义的 skill 写作标准检查：

- 是否属于身份、触发、判断、动作、边界、产出、验证或回退句。
- 主体是否明确。
- 动词是否可执行。
- 条件是否清楚。
- 结果是否可观察。
- 是否诱导访谈员、PRD 作者、调度员、战略顾问或越权 owner。

## SKILL.md 运行时审计

| 位置 | 当前内容类型 | 结论 | 问题 | 处理建议 |
| --- | --- | --- | --- | --- |
| `SKILL.md:5` | description | 未达最佳实践 | 同时写职责摘要和流程摘要；“定死再交给 product-manager”过窄，且像流程调度 | 改成只描述触发条件：需要先冻结 WHY、价值、范围、成功标准、Phase 价值切片和下游消费边界的业务/工程场景 |
| `SKILL.md:10` | 标题 | 可改 | “战略收口”偏抽象，容易把角色推向顾问话术 | 改成“业务产品负责人 / Director 场景基线冻结” |
| `SKILL.md:12` | `ultrathink` | 未达最佳实践 | 不是可执行岗位规则，是模型提示词；无法被 eval 或 gate 验证 | 删除，换成具体判断流程和输出约束 |
| `SKILL.md:16-19` | HARD-GATE：暂停确认 | 未达最佳实践 | 过度抬高“暂停”，会诱导访谈员；没有把“先给专业判断，再验证一个关键事实”放到顶层 | 改成：事实不足不得冻结，但每轮先给推荐判断、依据和一个会改变结论的事实问题 |
| `SKILL.md:20-22` | HARD-GATE：编号流程 | 未达最佳实践 | 编号驱动维护成本；同时违反新标准中“5 到 7 个阶段”的简洁要求 | 迁移为语义阶段和语义 checkpoint，更新 contracts、validator、tests、eval |
| `SKILL.md:23-26` | HARD-GATE：确认门 | 部分达标 | 有验证和锁定价值；但“产品总监确认”容易被误解为 agent 自我确认 | 改成“业务 owner 明确确认 Director 基线”，同时保留 `locked_fields / locked_field_digest` |
| `SKILL.md:27-30` | HARD-GATE：ledger | 部分达标 | 有确定性价值，但句子过长，且绑定旧编号 checkpoint | 拆成 ledger 必须覆盖语义 checkpoint、未解决替换事实不得冻结、冲突事实必须回退 |
| `SKILL.md:34` | 角色句 | 未达最佳实践 | 正向身份不完整；反向边界只挡 UNIT/AC 等 PM 内容，没挡架构、测试策略、排期、老板代理、上线验收 | 重写为一正一反：业务产品负责人 + Director 场景基线生产者；不是 PRD 作者、需求记录员、调度员、架构师、项目经理或老板代理人 |
| `SKILL.md:36-51` | Mermaid 流程图 | 未达最佳实践 | 图重复流程细节，保留编号心智，运行时 token 成本高 | 删除或压缩成 5-7 个语义阶段列表 |
| `SKILL.md:55` | reference 路由 | 未达最佳实践 | 一句话塞入多个动作和否定边界，模型难执行 | 拆成“读取 conversation guide 的时机”和“业务判断必须来自当前业务 reference”两条 |
| `SKILL.md:57-62` | 静默信息收集 | 部分达标 | 有动作和边界；但“静默扫描”和“首轮响应包含扫描结果”表达冲突；`sub Agent` 可用性不应成为运行时核心假设 | 改成“证据扫描”：先收集来源、冲突、缺口；只输出会影响判断的证据摘要和一个关键事实问题 |
| `SKILL.md:64-70` | 问题澄清 | 部分达标 | 四项拆解是好规则；但只覆盖方案/功能/对标，未覆盖老板话术、组织压力、工程表象；机制建模不足 | 升级为根问题与机制判断：角色、触发、当前处理、代价、机制原因、默认判断 |
| `SKILL.md:72-78` | 成功标准 | 部分达标 | 有基线、目标、窗口、数据源；缺验收 owner 和失败信号；投入量级容易变成排期感 | 补齐当前状态、目标方向/值、证据来源、观测窗口、验收 owner、失败信号；投入只定义复杂度上限 |
| `SKILL.md:80-87` | 业务语义 | 需要降级 | 对话级语义有用，但不应成为每个任务必经阶段；否则流程膨胀 | 改成条件分支：只有术语、对象状态、流程语言会影响范围/成功标准/Phase 时才进入 |
| `SKILL.md:89-95` | 范围与约束 | 部分达标 | 做什么、不做什么、为什么这样切是对的；但缺“该不该做 / 值不值得继续”前置判断 | 加入价值判断：继续、暂停、阻断、不做；再进入范围切片 |
| `SKILL.md:97-103` | 风险未知项 | 部分达标 | 能识别推翻范围/Phase 的未知项；缺“风险接受必须由真人裁决”的边界 | 加入风险 owner 和恢复条件；agent 只暴露风险，不替业务接受风险 |
| `SKILL.md:105-111` | Phase 规划 | 部分达标 | 按价值切片和 14 天 timebox 是好规则；“预期 UNIT 数量范围 3-7”越界到 PM/交付估算 | 删除 UNIT 数量范围；改成首期最小场景闭环、入口/出口、价值证明 |
| `SKILL.md:113-121` | 冻结门 | 部分达标 | 锁定与 gate 很强；但句子过长，且“交给 PM”容易表达成已启动下游 | 拆成冻结成功和未冻结成功两条；“可被 PM 消费”替代“交给 PM” |
| `SKILL.md:123-125` | 输出 | 未达最佳实践 | 只描述冻结成功，没有未冻结成功产出 | 增加未冻结输出：结论、原因、证据、缺失事实、建议 owner、恢复条件 |
| `SKILL.md:127-133` | 完成校验 | 部分达标 | 覆盖 JSON、gate、digest、ledger；缺下游多角色消费和未冻结路径 | 增加下游消费边界、回退条件、未冻结路径证据 |

## References 句子级审计

| 文件 | 结论 | 主要问题 | 处理建议 |
| --- | --- | --- | --- |
| `references/conversation-guide.md` | 最接近最佳实践 | “你主导方法判断和结论草案，用户补充业务事实”是关键好句，但现在藏在 reference 里，被 HARD-GATE 的暂停语义压住 | 提升到 `SKILL.md` 顶层 HARD-GATE |
| `references/problem-clarification.md` | 部分达标 | 第一性原理拆解有效，但仍使用 `D-S2`；缺机制建模、老板话术、工程表象、组织压力 | 拆为 `root-problem.md` + `evidence-map.md`，加入机制原因和冲突事实处理 |
| `references/success-investment-boundary.md` | 部分达标 | 成功信号结构好；缺验收 owner，失败信号表达不够硬 | 改名 `success-investment.md`，冻结前强制六要素 |
| `references/scope-constraints.md` | 部分达标 | 核心/增强/未来三分法可保留；缺“不做 / 不值得做 / 暂停”的明确产物 | 改名 `scope-minimum-loop.md`，加入未冻结判断 |
| `references/phase-planning.md` | 部分达标 | 价值切片和 14 天约束可保留；`预期 UNIT 数量`不应由 Director 冻结 | 改名 `risk-phase.md` 或拆分，删除 UNIT 数量依赖 |
| `references/risks-unknowns.md` | 部分达标 | 问“什么事情一旦错了后面全要重来”是好句；缺风险接受边界 | 合并进 `risk-phase.md`，明确 agent 不接受风险 |
| `references/business-semantics.md` | 需要降级 | 有用但不应默认成为阶段；否则流程像 PRD 前置清单 | 作为条件 reference，仅在术语/对象/流程会影响判断时读取 |
| `references/output.md` | 部分达标 | 输出字段和验证明确；“handoff”措辞容易变成调度 | 改名或扩展为 `freeze-handoff.md`，明确可消费不等于已启动 |

## Eval / Test 内容审计

现有 eval 也不是最佳实践，因为它们仍在测试旧流程编号和字段锚点，而不是优秀判断。

必须改：

- `shared/skills/product-director/evals/evals.json` 中的 expected output 和 anchors 仍含 `D-S1 / D-S2 / D-S3 / D-S4 / D-S5 / D-S6`。
- `shared/skills/product-director/test-prompts.json` 仍要求执行 D-S1、进入 D-S2、回到 D-S6。
- 现有 eval 没有完整覆盖优秀标准定义的 6 类试用题。
- 当前 without-skill 通过率高，说明 eval 区分度不足，不能证明 skill 优秀。

## 编号迁移边界

取消 `D-S*` 编号需要纳入改造计划，不应作为文案顺手改动。

必须同步修改：

- `shared/skills/product-director/SKILL.md`
- `shared/skills/product-director/references/*.md`
- `shared/skills/product-director/evals/evals.json`
- `shared/skills/product-director/test-prompts.json`
- `contracts/co-creation-ledgers.yaml`
- `tools/community/validate_co_creation_ledger.py`
- `tests/test-standard-chain-co-creation-ledger-contract.sh`
- `tests/test-standard-chain-skill-structure.sh`
- `tests/test-product-context-signal-quality.sh`
- `tests/test-product-director-s4-boundary.sh`
- `tests/test-standard-chain-local-eval-runner.sh`

历史 eval 产物可以保留，不作为当前事实修改对象。

## 下一步裁决

我建议下一步改造计划必须新增一个 P0 任务：

> 将 `product-director` 从编号流程迁移到语义 checkpoint，并做全链路契约同步。

这一步排在重写 `SKILL.md` 之前或一起做。否则运行时去掉编号后，ledger validator 和测试会直接失败；只改文案会破坏确定性门禁。

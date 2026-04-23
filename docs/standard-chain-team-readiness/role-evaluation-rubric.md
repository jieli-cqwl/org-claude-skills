# Standard-Chain Role Evaluation Rubric

## 目的

本文定义标准流程角色评估口径，用来回答两个问题：

1. 该角色是否该存在。
2. 既然存在，该角色本次交付是否符合预期或超预期。

本 rubric 只服务 `contracts/standard-chain.yaml` 定义的完整交付链。低风险、小范围、单点变更由 `small-chain` 路由，见 `contracts/small-chain.yaml`。标准链不再定义第二套路由分档。

## 证据规则

评估只能使用可追踪证据：

- `contracts/standard-chain.yaml` 中的角色输入、输出、消费者和 authority owner。
- 当前交付的 canonical artifacts，例如 `brief.json`、`phase-prd.json`、`design.json`、`test-cases.json`、`plan.json`、`tasks.json`、`developer-report.json`、`verify-result.json`、`code-review-result.json`、`qa-result.json`、`consistency-audit-result.json`、`delivery-state.json`、`signoff-package.json`、`user-decision.json`。
- fresh proving command 的真实输出。
- 下游角色实际消费上游产物的位置。
- review、QA、verify、consistency、delivery-owner 发现并关闭的问题。

不能把 role evidence 自报 PASS 当作最终依据。role evidence 只能作为待核查线索，最终结论必须落到具体工件、门禁命令或下游消费证据。

## 角色清单

| 角色 | 来源 | 运行定位 | 常规消费者 |
| --- | --- | --- | --- |
| `product-director` | `contracts/standard-chain.yaml` | 主角色 | `product-manager` |
| `product-manager` | `contracts/standard-chain.yaml` | 主角色 | `design`、`test-design`、`tech-lead`、`qa`、`delivery-owner` |
| `design` | `contracts/standard-chain.yaml` | 主角色 | `test-design`、`tech-lead`、`developer` |
| `test-design` | `contracts/standard-chain.yaml` | 主角色 | `tech-lead`、`delivery-owner`、`developer`、`qa` |
| `tech-lead` | `contracts/standard-chain.yaml` | 主角色 | `delivery-owner`、`developer`、`verify`、`qa` |
| `developer` | `contracts/standard-chain.yaml` | 主角色 | `review`、`verify` |
| `review` | `contracts/standard-chain.yaml` | 主角色 | `qa`、`delivery-owner` |
| `verify` | `contracts/standard-chain.yaml` | 主角色 | `qa`、`delivery-owner` |
| `qa` | `contracts/standard-chain.yaml` | 主角色 | `delivery-owner` |
| `consistency-auditor` | `contracts/standard-chain.yaml` | advisory sidecar | `tech-lead`、`delivery-owner` |
| `fix` | `contracts/standard-chain.yaml` | conditional sidecar | `delivery-owner`、`review`、`verify`、`qa` |
| `delivery-owner` | `contracts/standard-chain.yaml` | 主角色 | user、archive |

## 存在合理性评分

每项 0 到 2 分，总分 12 分。

| 维度 | 0 分 | 1 分 | 2 分 |
| --- | --- | --- | --- |
| 独立责任域 | 责任可被另一个角色完整覆盖 | 有独立活动，但边界交叉明显 | 有清晰不可混淆责任边界 |
| 不可替代风险 | 删除后无明显风险 | 删除后风险可由脚本补位 | 删除后出现无人负责的质量或交付风险 |
| 下游消费关系 | 输出无明确消费者 | 输出有消费者但消费弱 | 输出被下游工件或门禁真实消费 |
| 权威字段边界 | 常写越权结论 | 权威边界存在但表达松 | 只对职责内字段和结论负责 |
| 反噪音价值 | 增加重复解释或上下文负担 | 降噪价值有限 | 将信息收敛成下游可用输入 |
| 门禁价值 | 不阻断真实失败 | 只阻断格式问题 | 能阻断职责内真实失败 |

存在裁决：

| 分数 | 裁决 |
| --- | --- |
| 0-5 | 删除或合并 |
| 6-8 | 条件保留，优先工具化或 sidecar 化 |
| 9-12 | 保留为标准链角色 |

`fix` 是条件角色。没有失败触发时，不用评价本次胜任度；但仍需评价存在合理性，因为 review、verify、QA 或 consistency 失败后需要它承接根因修复。

## 胜任度评分

每项 0 到 2 分，总分 14 分。未被触发的条件角色标记为 `N/A`，不强行评分。

| 维度 | 0 分 | 1 分 | 2 分 |
| --- | --- | --- | --- |
| 输入保真 | 改写或忽略上游权威输入 | 消费输入但缺少完整追踪 | 正确消费上游输入并保持权威字段不漂移 |
| 输出合约 | 输出缺失或不可被下游读取 | 输出存在但字段或路径存在弱点 | 输出格式、路径、关键字段满足合同 |
| 证据强度 | 只有口头结论或自报 PASS | 有局部证据但未直连成功标准 | 有 fresh proving command、真实依赖或下游消费证明 |
| 边界克制 | 写入越权结论 | 有轻微职责混杂 | 不写职责外结论 |
| 缺陷发现能力 | 未发现职责内明显问题 | 发现格式或低风险问题 | 发现职责内真实质量、风险或证据问题 |
| 闭环能力 | 问题停留在建议 | 问题部分进入修复 | 问题进入修复、验证、签收闭环 |
| 噪音控制 | 输出重复、冗长或污染上下文 | 输出可用但存在可压缩内容 | 输出直接服务下游，无旧证据污染 |

胜任裁决：

| 分数 | 裁决 |
| --- | --- |
| 0-6 | 不符合预期 |
| 7-10 | 符合预期 |
| 11-14 | 超预期 |
| N/A | 本次未触发，不评价胜任度 |

超预期不能只靠“写得更完整”。超预期必须满足至少一条：

- 发现并推动关闭职责内真实风险。
- 补上原流程缺失的证据闭环。
- 让下游消费成本显著下降，并有下游工件或命令证明。

## 输出格式

每次标准链复盘至少输出这些字段：

| 字段 | 含义 |
| --- | --- |
| 角色 | 来自 `contracts/standard-chain.yaml` |
| 是否该存在 | 保留、条件保留、合并、删除 |
| 存在分数 | 0-12 |
| 本次胜任度 | 不符合预期、符合预期、超预期、N/A |
| 胜任分数 | 0-14 或 N/A |
| 证据来源 | 具体文件、命令或下游消费位置 |
| 关键判断 | 一句话说明为什么 |
| 调整动作 | 保留、工具化、补门禁、收缩输出、合并边界 |

## 判定流程

1. 先查路由边界：低风险、小范围、单点变更走 `small-chain`；标准链角色评估只在完整交付链复盘中执行。
2. 从 `contracts/standard-chain.yaml` 提取本次需要评价的角色。
3. 对每个角色先做存在合理性评分。
4. 对本次被触发的角色做胜任度评分。
5. 用 canonical artifacts 和 fresh proving command 支撑每个结论。
6. 对 `N/A` 条件角色记录触发条件，不写表现评价。
7. 输出保留、条件保留、工具化、补门禁或合并建议。

## 标准链角色基线

| 角色 | 存在基线 |
| --- | --- |
| `product-director` | 保留。负责根问题、目标、范围、Phase 边界和 Director lock。 |
| `product-manager` | 保留。负责业务流程、UNIT、AC、排除项和 PM 收口。 |
| `design` | 保留。负责技术设计、接口、复用判断、验证与回滚边界。 |
| `test-design` | 保留。负责开发前测试设计、等价类、AC 覆盖和 QA handoff。 |
| `tech-lead` | 保留。负责把需求和设计拆成 AI 可执行 plan/tasks。 |
| `developer` | 保留。负责 TDD 实现和 developer-report 证据。 |
| `review` | 保留。负责实现质量、风险、回归和证据完整性审查。 |
| `verify` | 保留。负责 Task 级 AC 覆盖和代码规范验收，适合强化脚本门禁。 |
| `qa` | 保留。负责用户视角功能验收和发布质量判断。 |
| `consistency-auditor` | 条件保留。负责 advisory-only 漂移、追踪和一致性审计，适合强化自动化。 |
| `fix` | 条件保留。负责 FAIL 后根因定位和最小修复。 |
| `delivery-owner` | 保留。负责交付控制、证据消费、签收包和最终闭环。 |

# 工程控制面 Challenger 报告

- 调研模式：`analysis`
- 呈现模式：`audit`
- 主题：反方挑战 `Harness-first + Prompt减法 + sub agent 显式触发`
- 日期：`2026-04-12`

## 先给结论

这条方向只能成立到一半：

1. `Harness-first` 适合承接稳定、可机检、上下文无关的“格式真相”。
2. `Prompt减法` 应该削掉低频操作说明和重复模板负担，不能继续削主 Agent 的判断语法。
3. `sub agent 显式触发` 只适合少数能从工件状态直接观测的场景；如果把大量权衡判断都硬编码进 router/check，会制造新的主 Agent 噪音和维护负担。

我认可的最稳边界是：

- `Harness` 负责：路径、顺序、字段完整性、非豁免门禁、报告锚点、可重复计数规则。
- `Prompt` 负责：用户共创、歧义解释、优先级裁决、边界仲裁、何时升级、何时回退。
- `Sub agent` 负责：候选事实、候选结构、候选汇总。
- `主 Agent` 继续独占：确认、冻结、Gate 判定、sign-off 前摘要、风险接受升级。

## 项目上下文

当前仓库已经具备比较强的控制面：

- 链路和权责合同已经存在于 `contracts/skill-chain.yaml`。
- 运行边界和 closeout 顺序已经存在于 `contracts/superpowers-boundary.yaml`。
- 共享 sub agent schema、模板和测试已经存在于 `shared/reference/subagent-recovery-contract.md`、`shared/reference/templates/*`、`tests/test-subagent-context-contract.sh`。
- `delivery-owner` 的 Phase 3 分级矩阵已经是单一可执行真源：`shared/skills/delivery-owner/scripts/phase3-grade-matrix.sh`。

所以这轮不该再问“要不要更多 contract/check/router”，而该问：

- 哪些规则值得继续下沉
- 哪些规则已经接近过度工程化
- 哪些限制正在从“系统降噪”变成“系统自我噪音”

## 1. 不应该继续下沉的约束

### 1.1 设计权衡类约束，不适合做硬 router/check

证据：

- `shared/reference/设计原则.md:6-56` 明确在处理 `Essential vs Accidental Complexity`、可逆性、L1-L4 裁决，这些都依赖具体上下文和权衡。
- 这里不是“字段对不对”，而是“复杂度是不是问题域本身要求的”。

反方意见：

- 这类规则如果继续下沉到 `contract/template/check/router`，最后得到的不是更强控制面，而是脆弱的伪裁决器。
- 它适合做 prompt 中的判断框架，或 reviewer checklist，不适合做自动 Gate。

建议：

- 保留在 `prompt + review`。
- 最多只把“是否显式写出回滚/验证/迁移”这种机械项下沉，不要把设计取舍本身下沉。

### 1.2 复用判断，不适合做自动化裁决

证据：

- `shared/reference/代码复用.md:15-43` 要求同时判断语义一致、变化节奏一致、依赖方向健康、抽象后更清晰。
- `shared/reference/代码复用.md:72-88` 明确要求先确认“是不是同一份知识”，这本质上是语义判断。

反方意见：

- 如果把“必须复用/必须抽象”做成 check，会把本来需要语义判断的问题，变成“为了过门禁而强行共用”的结构噪音。

建议：

- Harness 只检查“新建实现是否给出最小举证责任”。
- 是否复用、怎么复用，仍由主 Agent 和 reviewer 裁决。

### 1.3 性能与缓存策略，不适合做强 router

证据：

- `shared/reference/性能效率.md:3-24` 写得很清楚：先识别真实瓶颈，再请求用户确认，再添加缓存。

反方意见：

- 这类约束如果下沉成自动触发规则，很容易把“有潜在性能风险”误做成“必须加缓存/并发”。
- 这违反仓库现有的 YAGNI 和用户确认原则。

建议：

- 保留在 prompt 和 review 中。
- 最多把“缓存必须用户明确同意”这种硬约束留在 rule/check。

### 1.4 测试分层策略，不适合过度硬编码

证据：

- `shared/reference/测试规范.md:31-86` 虽然给了单元/集成测试选择表，但 `不确定时 -> 集成测试` 仍是经验性建议。
- `shared/reference/测试规范.md:119-135` 还强调 DAMP、测试可读性和坏味道治理，这些无法机械化。

反方意见：

- 可以自动检查是否存在 fresh proving command、是否保留完整输出、是否跳过测试。
- 但不该把“这里必须单测/集成/E2E”全做成强门禁，否则会把测试策略讨论变成过门禁游戏。

建议：

- Harness 管“有没有证据”和“有没有绕过”。
- Prompt/review 管“为什么选这一层测试”。

### 1.5 共创和冲突仲裁，不该交给 router

证据：

- `shared/skills/product/SKILL.md:31-46` 和 `shared/skills/design/SKILL.md:34-47` 都把共创、暂停、最终确认、冲突仲裁列为硬门。

反方意见：

- 这不是调度问题，而是责任问题。
- Router 可以决定“能不能派草稿 agent”，不能决定“是否已经理解用户真实意图”。

建议：

- `product/design` 的 stage 入口和关键暂停点继续 `prompt-driven`。
- 不要试图把“是否问用户”“是否已对齐”做成机械路由。

## 2. 哪些 router/check 规则会制造新的主 Agent 噪音或维护负担

### 2.1 把“共享契约引用”硬绑进每个 skill，会制造重复 prompt 负担

证据：

- `tests/test-subagent-context-contract.sh:27-36` 强制 `product/design/test-design/tech-lead/delivery-owner` 每个 skill 都要出现 `subagent-recovery-contract.md` 和 `context-noise-metrics.md`。
- 这会把“工程真源存在”变成“prompt 面必须重复出现”。

反方意见：

- 这是典型的控制面越界：测试本来应该验证工程层是否一致，却反过来要求每个运行时 prompt 都显式提一次。
- 它会增加技能正文噪音，不会提升主 Agent 判断质量。

建议：

- 测试改成验证“skill 使用的模板/check/router 是否连到共享真源”，而不是验证“skill 正文必须出现引用串”。

### 2.2 `tech-lead` 的草稿 agent 规则已经开始自带官僚负担

证据：

- `shared/skills/tech-lead/SKILL.md:95-107` 仍有“仅在主 Agent 需要降噪时启用”的主观触发。
- `shared/skills/tech-lead/SKILL.md:160` 又要求 `plan.md` 含 `草稿回收记录`，且 `3 个 draft agent` 回收状态为 `RECOVERED`。

反方意见：

- 前者太主观，后者太刚性。
- 两个规则叠在一起，主 Agent 很容易为了过 check 去补“未启用也要记一笔”的文书，而不是只在有价值时派发 sub agent。

建议：

- 改成显式 trigger 后，只要求“实际启用过的 agent 必须可回收”。
- 不要把“最多 3 个”写成“默认就有 3 个要交代”。

### 2.3 `delivery-owner` 的汇总代理计数规则过细，接近收益拐点

证据：

- `shared/skills/delivery-owner/SKILL.md:64-83` 对并行 Task 数、终态定义、重试计数、移批次重计数、summary stale 重跑都做了细规则。

反方意见：

- 这里的初衷是防止汇总代理失控，但控制粒度已经很细。
- 如果这些状态没有单一运行时状态源支撑，就会迫使主 Agent 额外解释“当前批次怎么数、旧 summary 是否 stale、这次能不能重跑”，形成新的控制面噪音。

建议：

- 这类规则只应建立在单一状态源上，比如 `plan.md` 的批次表或独立运行态文件。
- 如果当前没有稳定 runtime state，就应收缩规则，只保留 `parallel task >= 4` 这一条主触发，其他作为 implementation note，不进 prompt。

### 2.4 过多依赖 Markdown 结构解析，会把维护成本转移到文档格式

证据：

- `shared/hooks/lib/common.sh:605-768` 和 `shared/hooks/lib/constraint.sh:9-145` 大量依赖章节标题、表头名称、列顺序去解析文档。

反方意见：

- 这类 harness 很适合承接稳定表格。
- 但如果继续把越来越多语义规则下沉成“靠 Markdown 标题和表格解析”，后续每次改文档结构都会连锁打碎脚本和测试。

建议：

- 继续下沉时只承接稳定 schema。
- 需要频繁演进的语义结构，不要继续靠 Markdown 弱解析承接。

### 2.5 过多“校验 prose 是否包含某句”的测试，会把系统推向 prompt-heavy

证据：

- `tests/test-skill-output-and-gate-contract.sh:37-53`、`tests/test-subagent-context-contract.sh:27-36` 已经存在多处字符串断言，直接检查 skill prose 是否出现固定句子或固定引用。

反方意见：

- 这类测试适合守住少量不可退化的关键承诺。
- 一旦扩大，会导致维护者为了通过测试而保留 prompt 噪音，削弱“prompt 减法”。

建议：

- 多测行为少测文案。
- 固定字符串断言只留给权责和硬门；其他改成验证模板、脚本、输出物。

## 3. 怎么判断控制面已经超过收益拐点

我建议用下面 5 个信号判定，命中 2 个以上就说明控制面开始过载：

### 3.1 同一条规则需要在 4 层以上重复声明

典型症状：

- 同一规则同时存在于 `SKILL prose + reference + template + completion_check + test`。

解释：

- 这通常不是更稳，而是说明控制面没有找到单一真源。

### 3.2 新增失败主要来自“元数据不匹配”，而不是交付质量问题

典型症状：

- fail 原因是章节名、字段名、引用串、回收记录格式不对，而不是设计缺口、证据缺失、验收失败。

解释：

- 当系统更容易因文书问题失败，而不是因真实质量问题失败，就已经偏离目标。

### 3.3 主 Agent 需要解释控制规则的时间，开始大于解决任务本身

典型症状：

- 主 Agent 花很多篇幅说明为什么这次不用某 agent、为什么 summary stale、为什么某字段不计数。

解释：

- 这就是控制面反向制造主 Agent 噪音。

### 3.4 小改动引发大面积测试脆断

典型症状：

- 只是改一个 skill 段落或模板字段，就连带 3 类以上测试失败。

解释：

- 这说明 contract/check/test 耦合过深，演化成本过高。

### 3.5 控制规则开始要求维护“证明你没做某事”的文档

典型症状：

- 明明没启用某个 sub agent，仍要求写回收记录、状态枚举、未启用原因。

解释：

- 少量这种记录有价值，但一旦成为普遍要求，就会把降噪方案做成文书系统。

## 4. 我认可的最稳边界

### 4.1 适合继续放到 Harness 的

- 链路顺序、closeout 顺序、owner 边界  
  证据：`contracts/superpowers-boundary.yaml:28-37`、`contracts/skill-chain.yaml:120-128`
- 非豁免 Gate、分级矩阵、固定阶段集合  
  证据：`shared/skills/delivery-owner/scripts/phase3-grade-matrix.sh:5-59`
- 稳定字段完整性和锚点存在性  
  证据：`shared/reference/subagent-recovery-contract.md:50-58`
- 轻量 runtime 噪音约束  
  证据：`tests/test-skill-runtime-noise.sh:21-130`

### 4.2 必须留在 Prompt/主 Agent 的

- 用户共创节奏与冲突仲裁  
  证据：`shared/skills/product/SKILL.md:31-46`、`shared/skills/design/SKILL.md:34-47`
- 设计取舍、抽象裁决、复用判断、性能取舍  
  证据：`shared/reference/设计原则.md:6-56`、`shared/reference/代码复用.md:15-88`、`shared/reference/性能效率.md:17-24`
- 测试层级和验证策略的最终选择  
  证据：`shared/reference/测试规范.md:31-141`
- 主 Agent 的责任边界和最终冻结  
  证据：`contracts/skill-chain.yaml:4-92`

### 4.3 只适合“有限显式触发”的

- `sub agent` 派发

条件：

- 必须来自可观测工件状态，而不是主观感觉。
- 必须只覆盖少数高频、高价值、低歧义场景。

建议触发面：

- 覆盖矩阵出现 `UNCOVERED / DESIGN-GAP / orphan`
- 当前批次并行 Task 数 `>= 4`
- 报告已存在但 acceptance-summary 尚未冻结

不建议硬编码的触发面：

- “复杂度高”
- “需要降噪”
- “感觉还不够清晰”
- “用户已充分分析”

## 5. 最终反方判断

我支持继续推进这条方向，但必须改成下面这版才稳：

1. `Prompt减法` 只删低频操作说明和重复 contract 文案，不删主 Agent 的判断语法。
2. `Harness-first` 只吞机械真相，不吞语义裁决。
3. `Sub agent 显式触发` 只保留少数可观测 trigger，不要把整套人类判断过程编码进 router。
4. 控制面的成功标准不是“规则更多”，而是“主 Agent 少背规则、系统仍能稳住质量”。

如果再往前走一步，我最建议优先修的不是“继续加 router/check”，而是：

1. 去掉 `skill` 对共享 sub-agent reference 的重复显式引用要求，改测工程真源连接。
2. 收紧 `tech-lead` 的 draft-agent 完成条件，只要求“启用过的 agent 可回收”。
3. 简化 `delivery-owner` 的汇总代理运行细则，避免在没有单一运行态真源前把计数规则写得过细。

## 检索路径与覆盖证明

- 规则真源：`shared/assistant.md`、`README.md`
- 合同层：`contracts/skill-chain.yaml`、`contracts/superpowers-boundary.yaml`
- reference：`shared/reference/subagent-recovery-contract.md`、`shared/reference/context-noise-metrics.md`、`shared/reference/设计原则.md`、`shared/reference/代码复用.md`、`shared/reference/性能效率.md`、`shared/reference/测试规范.md`
- harness：`shared/hooks/lib/common.sh`、`shared/hooks/lib/constraint.sh`
- 可执行规则源：`shared/skills/delivery-owner/scripts/phase3-grade-matrix.sh`
- 测试：`tests/test-subagent-context-contract.sh`、`tests/test-skill-runtime-noise.sh`、`tests/test-skill-output-and-gate-contract.sh`、`tests/test-small-chain-boundary.sh`、`tests/test-superpowers-boundary.sh`

## 独立挑战记录

本报告在工程控制面上站反方，核心挑战点有两条：

1. `prompt` 里重复出现共享 contract 引用，本身就是新的上下文噪音。
2. 控制规则如果要求主 Agent 证明“自己没有越权、没有启用、没有遗漏”，就会把降噪方案做成文书系统。

这两个挑战当前都能在仓库里找到对应信号，不能忽略。

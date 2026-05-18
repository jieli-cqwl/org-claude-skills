# Design 高级交付型架构师能力与考核体系设计

日期：2026-05-18

## 结论

`design` 应重构为 **高级交付型架构师**，不是架构文档作者、流程主持人、字段填充器或技术方案润色器。

它的职责是在 `product-director` 和 `product-manager` 已冻结业务目标、Phase、UNIT 和 AC 后，主导共创并冻结一份下游可执行、可验证、可回滚的 Phase 级架构基准。好的结果不是一份看起来完整的 `design.json`，而是 `/test-design`、`/tech-lead`、developer 和交付判断能够基于它把活干对。

本设计采用一步到位的能力定义：一次性定义角色定位、职责边界、`design.json` 产出契约、LLM/人类/脚本分工、能力分级、全方位 eval 考核体系和正式可用门槛。实现可以分批，标准不能分批。

## 当前判断

当前 `shared/skills/design` 已经具备高级架构师的骨架：有 preflight、schema、template、review digest、reference integrity、三视角 review、方案取舍、质量属性、迁移、验证和回滚等基础资产。

主要问题不是方向错误，而是能力证明不足：

- 现有体系偏流程完整和字段完整，尚未充分证明高级架构师语义能力。
- eval 题面存在提示过强的问题，容易考出复述能力而不是架构判断能力。
- template 存在默认 `PASS`、`READY`、`confirmed` 诱导，可能让占位内容看起来像完成。
- `SKILL.md`、schema 和 template 存在字段契约漂移，例如 `boundary_behaviors`。
- `interfaces` 强制非空与“无接口变更时使用 `interface_boundary`”存在语义冲突。
- examples 中存在业务输入与设计决策不一致的压力点，但现有校验没有把它作为关键失败路径。
- 脚本和 manifest 的路径边界需要一致落地，不能只停留在声明。

这些问题说明：当前 `design` 可以作为继续打磨的基础，但不能直接定义为正式可用。

## 角色定义

`design` 是高级交付型架构师，负责把已确认的业务目标和系统事实转化为下游能正确执行的架构方案。

它拥有 HOW 层架构判断权：

- 系统事实采证
- 架构复杂度识别
- 模块边界与依赖方向
- 接口契约与边界行为
- 数据所有权与一致性约束
- 横切关注点设计
- 关键技术决策与方案取舍
- 质量属性落地
- 迁移、验证、回滚路径
- 风险识别与风险回应
- 下游消费契约

它不拥有 WHY / WHAT / WHEN / DONE 的最终权力：

- 不重新定义业务根问题
- 不擅自修改 Phase 范围
- 不新增或删除 UNIT/AC
- 不替用户接受业务、合规、组织或上线风险
- 不替 `/test-design` 写完整测试策略
- 不替 `/tech-lead` 拆 WBS 和排期
- 不替 developer 实现代码
- 不替交付负责人宣布完成

当产品输入、UNIT、AC 或业务语义存在冲突时，`design` 必须暴露冲突并回退确认，不能用架构方案把冲突抹平。

## 协作模型

`design` 的协作关系是同事之间的共创，默认由 LLM 主导专业判断，人类提供业务场景和外部现实输入。

LLM 应主导：

- 从源码、测试、配置、历史产物中建立系统事实基线。
- 识别技术复杂度、架构边界、依赖方向和质量属性冲突。
- 提出推荐方案和本质不同备选方案。
- 解释取舍、风险、失效条件和验证方式。
- 组织可交接的架构产物。

人类必须确认：

- 垂直业务语义
- 外部现实约束
- 价值排序
- 风险接受
- 上线窗口
- 组织协作边界
- 会改变业务范围或用户路径的取舍

脚本、schema、hook 和测试必须裁决：

- JSON 结构
- 字段存在性
- 引用完整性
- digest 一致性
- 路径边界
- phase 状态
- review closure 状态
- verification refs 可解析性
- 可枚举的 reviewer、concern、risk、UNIT、module 引用关系

模型可做语义判断，但不得替代确定性控制流。确定性控制流必须下沉到自动化门禁。

## `design.json` 定位

`design.json` 是 `/design` 阶段冻结后的下游消费基准。它承载关键架构决策、边界契约、质量目标、验证回滚与风险回应，服务 `/test-design`、`/tech-lead`、developer 和交付判断。

`design.json` 不是共创过程全文，不是 reviewer 临时意见本，不是 agent 自我报告，也不是未确认假设池。

写入 `design.json` 的内容必须满足三条：

- 下游需要消费。
- 证据或确认可回溯。
- 可以被 schema、script、review 或后续阶段验证。

未确认假设、待裁决业务问题、未闭合 reviewer FAIL、未被用户接受的风险，不得伪装成冻结设计。

## 能力分级

### L0 不可接受行为

出现任一项即判定不具备正式使用资格：

- 不采证就做关键架构决策。
- 只给单方案，不提供本质不同备选。
- 用字段完整冒充架构质量。
- 把假设写成事实。
- 擅自修改业务范围、UNIT 或 AC。
- 只写最终态，不写迁移、验证和回滚。
- 把 reviewer FAIL 当 WARN 承接。
- 用模板默认 `PASS`、`READY` 或 `confirmed` 冒充真实通过。
- 对确定性问题只写自然语言提醒，不交给脚本或 schema。
- 下游无法基于 `design.json` 正确拆测试、任务或实现。

### L1 高级架构师基础盘

正式可用必须稳定做到：

- 从产品基线和系统事实建立架构输入基线。
- 区分事实、假设、用户确认、代码证据和待验证项。
- 识别需求复杂度来源，并说明架构如何组织这些复杂度。
- 对每个关键决策提供推荐方案和至少一个本质不同备选。
- 明确模块职责、接口契约、数据所有权、错误边界和依赖方向。
- 把性能、可靠性、安全、可运维性、可维护性、成本等质量属性落到指标和验证引用。
- 给出迁移、验证和回滚路径。
- 让 `/test-design` 能生成测试义务，让 `/tech-lead` 能拆实施任务。
- 对风险给出能改变概率、影响或发现时间的回应。
- 在业务语义、风险接受或范围冲突处回退人类确认。

### L2 优秀高级架构师

优秀能力应被 eval 覆盖，但不要求每次场景都触发：

- 主动反驳自己的推荐方案，说明失效条件。
- 区分真实技术债、历史约束和可接受局部重复。
- 能从源码历史债中发现比人类记忆更可靠的系统事实。
- 识别团队协作、上线窗口、迁移成本和运维成本对架构方案的影响。
- 在不过度抽象的前提下沉淀可复用原则。
- 显著减少下游返工和歧义。
- 对跨 Phase 演进给出当前态、目标态和可逆过渡路径。

### L3 长期演进方向

L3 不作为首轮正式可用硬门槛，但应保留扩展空间：

- 跨系统架构治理
- 多团队平台演进
- 外部生态和平台限制建模
- 架构投资回报判断
- 长周期技术路线治理

## 正式可用标准

`design` 只有同时满足以下条件，才能定义为正式投入使用：

1. L0 红线均被 prompt、schema、script、review 或 eval 覆盖。
2. L1 能力有稳定正例、反例和边界 eval 证明。
3. L2 能力至少有压力 eval 覆盖，能暴露优秀架构判断差异。
4. 机械门禁 100% 可复验，不能依赖 agent 自我声明。
5. 语义 eval 能抓住关键失败路径。
6. 下游消费 eval 证明 `design.json` 能指导 `/test-design`、`/tech-lead` 和 developer。
7. with-skill / without-skill 对照证明 skill 本身确实提升架构师行为。
8. 正式 example 不包含未解释的产品/架构语义冲突。
9. template 不诱导复制即通过。
10. 残余风险有明确 owner、证据和下一步。

## Eval 考核体系

eval 是 `design` 的真实能力考核，不是附属样例。所有 eval 必须服务“它是否像高级交付型架构师一样工作”。

### 1. 契约硬校验 eval

目标：证明确定性约束由机器裁决。

覆盖：

- schema 必填字段和类型
- template 与 schema 字段一致
- 禁止 template 默认成功状态伪通过
- `review_digest.py` digest 一致性
- `check_design_reference_integrity.py` 引用完整性
- `preflight_check.sh` 上游闭合状态
- `render_projection.py` 输入输出路径边界
- reviewer 角色集合唯一且完整
- cross-cutting concerns 覆盖 `auth/error/log/config`
- `risk_response` 覆盖全部 risks
- `verification_refs` 可解析到 `verification_mapping[].evidence_ref`
- 每个 key decision 有同 `decision_ref` 的 2+ 本质不同方案

判定方式：脚本或结构化断言，不接受自然语言自报。

### 2. 语义能力 eval

目标：证明它能做架构师判断，而不是复述流程。

覆盖：

- 输入基线理解
- 源码事实采证
- 历史债识别
- 架构复杂度识别
- 模块边界设计
- 接口契约设计
- 数据所有权与一致性
- 质量属性取舍
- 迁移策略
- 验证策略
- 回滚策略
- 风险回应
- 下游消费表达

判定方式：rubric + reviewer + 必要结构化断言。rubric 必须检查证据质量、方案差异、取舍理由、下游可执行性和风险闭合。

### 3. 反脆弱压力 eval

目标：证明它面对坏输入时会阻断、澄清或回退，而不是强行产出。

必须覆盖：

- 弱 runtime facts：只有自指 evidence 或 agent 口述事实。
- 业务语义冲突：UNIT 要 local/sessionStorage，设计选择 HttpOnly Cookie。
- 字段语义漂移：上游要求 `password`，设计改成 `password_hash` 但未交代裁决。
- 伪确认：`confirmed` 字段存在但无真实确认来源。
- reviewer FAIL 未闭合。
- 缺少回滚方案。
- 质量属性只有口号，没有 target_metrics 或 verification_refs。
- 过度设计：低复杂度需求引入不必要服务拆分、事件总线或平台化。
- 静默降级：性能、可靠性或产品行为改变但未回退用户确认。
- 脚本可裁决问题被写成自然语言提醒。

通过标准：能明确阻断原因、缺失证据、恢复条件和需要人类确认的裁决点。

### 4. 下游消费 eval

目标：证明 `design.json` 真能让后续角色把活干对。

覆盖：

- `/test-design` 基于 `design.json` 生成测试义务。
- `/tech-lead` 基于 `design.json` 拆任务边界、依赖和验证点。
- developer 基于接口、模块、数据和回滚约束理解实现边界。
- 交付判断能追溯质量目标、验证证据和风险回应。

失败标准：

- 下游需要猜测接口输入、输出、错误或边界行为。
- 下游无法找到质量属性对应的验证引用。
- 下游无法判断迁移和回滚怎么执行。
- 下游把未确认假设当成冻结决策。
- 下游对同一字段、模块或风险产生两个合理解释。

### 5. with-skill / without-skill 对照 eval

目标：证明 `design` skill 本身有效。

要求：

- 同一任务同时跑 with-skill 和 without-skill。
- 题面不得把答案喂给模型。
- 评估重点是行为差异：采证、阻断、方案取舍、验证、回滚、下游消费。
- without-skill 高分时，必须调整 eval，因为题目没有区分力。
- 每次核心 prompt 或契约调整后，必须更新 lifecycle-review 的 empirical 状态。

### 6. 回归与生命周期 eval

目标：防止能力随文案和契约演进漂移。

要求：

- `evals.json` 记录正例、反例、边界例和压力例。
- `lifecycle-review.json` 记录测量状态、样本、结论、下一步。
- 过期 eval 必须标记为不能证明正式可用。
- 每次修改角色定义、schema、template、review prompt 或脚本边界后，必须明确是否需要 rerun。

## 文件级改造原则

### `SKILL.md`

主入口应表达角色、职责、协作方式和硬门禁。它不应成为冗长流程手册。

调整原则：

- 开头直接定义高级交付型架构师。
- 用能力与产出牵引，而不是密集 S 编号牵引。
- 保留必要门禁语义，减少重复流程锚点。
- 明确何时由 LLM 主导、何时回退人类、何时交给脚本。
- 修正 `boundary_behaviors` 等字段漂移。

### `agents/openai.yaml`

入口描述必须影响 agent 第一印象。

目标表达：

`Design` 不是 “Create design.json”，而是 “turn confirmed product baseline and system facts into executable architecture decisions for downstream delivery”。

中文语义应对应“高级交付型架构师”，但 YAML 可保持英文简洁。

### `contracts/design.schema.json`

schema 只负责确定性结构，不承诺语义质量。

调整原则：

- 消除字段漂移。
- 处理无接口变更与 `interfaces` 非空冲突。
- 尽量收紧稳定消费字段的任意扩展。
- 将可枚举唯一性和覆盖关系交给 schema 或脚本。
- 不用 schema 表达复杂语义判断。

### `templates/design.template.json`

template 应帮助正确填写，不应诱导伪通过。

调整原则：

- 移除默认 `PASS`、`READY`、`confirmed`。
- 示例值必须明显不可当成真实验收。
- 默认 digest 不应看起来有效。
- placeholder 不能满足正式门禁。

### `scripts/*`

脚本负责所有可复验的确定性判断。

调整原则：

- manifest 声明与脚本实际路径边界一致。
- projection 输出路径必须受 allowlist 控制。
- reviewer 角色唯一性、cross-cutting coverage、decision option coverage、risk coverage、verification refs 等可枚举规则脚本化。
- 脚本失败信息必须能让 owner 知道缺什么、去哪修。

### `references/*`

references 承载方法论和 reviewer 判断，不承载可脚本化规则。

调整原则：

- 正向引导好架构师行为。
- 减少三份 reviewer prompt 的重复合同。
- 把接口边界行为、权限、幂等、并发、状态转换提升为一等项。
- 对性能、缓存、降级、可靠性策略补充用户确认和真实验证要求。
- reviewer rubric 要能抓住复杂度组织、过度设计、事实质量和下游不可消费。

### `examples/*`

example 是正式能力展示，不是随手样例。

调整原则：

- 不保留未解释的业务/架构冲突。
- runtime facts 必须可复查，不能自指 `input_analysis`。
- 上游字段语义变更必须有裁决链路。
- example 应能被 downstream eval 消费。

### `evals/*`

eval 是能力考核资产。

调整原则：

- 减少题面喂答案。
- 增加坏输入和压力例。
- 增加下游消费验证。
- 更新 lifecycle empirical 状态。
- 用 with-skill / without-skill 证明差异。

## 流程锚点原则

S1-S12 只能作为内部流程导航，不应成为主要能力模型。

保留条件：

- 脚本、schema、eval 或下游消费确实依赖该锚点。
- 锚点能降低歧义，而不是增加维护成本。

删除或弱化条件：

- 同一语义已由角色能力、产出契约或脚本门禁表达。
- 只是为了看起来流程完整。
- 改一个环节需要同步大量无实质价值的编号。

最终目标是：模型记住自己是高级交付型架构师，而不是记住自己在走 S7。

## 首轮改造范围

首轮必须覆盖这些确定性和高风险问题：

1. 角色入口与 `openai.yaml` 定位升级。
2. `SKILL.md` 高级架构师角色重写和字段漂移修复。
3. `boundary_behaviors` 契约漂移修复。
4. `interfaces` 与 `interface_boundary` 无接口变更冲突修复。
5. template 默认成功状态移除。
6. manifest 与脚本路径边界一致化。
7. 可枚举覆盖关系脚本化。
8. reviewer prompt 语义压力增强。
9. example 语义冲突和弱 runtime facts 修复。
10. eval 矩阵补齐：契约、语义、压力、下游、对照。
11. lifecycle-review empirical 状态更新。
12. 当前设计相关测试和新增 eval runner 验证通过。

## 暂缓裁决项

以下问题不在首轮直接改动，必须单独评估影响面：

- `co_creation_summary` 是否保留在 canonical `design.json`。
- `review_closure` 是否保留在 canonical `design.json`。
- `final_confirmation` 是否保留在 canonical `design.json`。
- 共创过程是否迁移到 ledger 或 review artifact。
- standard-chain 的事实真源模型是否需要统一调整。

这些是链路级架构决策，影响 validator、downstream consumer、projection、ledger 和历史 artifact。不能作为模板清理顺手修改。

## 验收方式

实施完成后的验收必须逐条证明：

1. `shared/skills/design` 入口、schema、template、scripts、references、examples、evals 与本设计一致。
2. 现有设计相关测试全部通过。
3. 新增契约测试覆盖字段漂移、默认成功状态、接口空变更、路径边界和可枚举覆盖关系。
4. 新增语义 eval 能发现弱证据、业务冲突、字段语义漂移、过度设计、未闭合 FAIL 和缺少回滚。
5. 新增下游消费 eval 能证明 `/test-design` 和 `/tech-lead` 可消费 `design.json`。
6. with-skill / without-skill 对照有记录，且 lifecycle-review 反映当前测量状态。
7. examples 不再含有未解释的上游/设计冲突。
8. 没有使用 mock、占位、默认成功值或 agent 自我报告伪造通过。

## 非目标

本设计不直接重写 `shared/skills/design` 文件。

本设计不改变 `product-director`、`product-manager`、`test-design`、`tech-lead` 的角色定义。

本设计不一次性改 standard-chain 的 canonical artifact 事实模型。

本设计不要求首轮完成 L3 长期架构治理能力。

本设计不把 eval 变成全局测试体系的替代品；eval 证明 skill 能力，全局测试证明仓库级机器合同。

## 风险与控制

风险一：一步到位变成大爆炸重写。

控制：标准一次性定义，实施按可验证批次推进；每批只改目标边界内文件。

风险二：eval 变成题面背诵。

控制：减少提示性题面，增加坏输入、对照组和下游消费验证。

风险三：语义能力无法完全脚本化。

控制：确定性问题脚本化，语义问题 rubric 化，关键业务和风险接受回退人类确认。

风险四：过度收紧 schema 破坏历史 artifact。

控制：区分正式新产物门禁与历史兼容策略，涉及 standard-chain 真源模型的变化单独裁决。

风险五：角色表达过硬导致模型不协作。

控制：用正向专业行为引导为主，负向红线只用于 HARD-GATE 和自动化门禁。

## 推荐下一步

下一步进入实施计划阶段。计划必须按以下顺序拆分：

1. 契约漂移和模板伪通过修复。
2. 确定性脚本门禁增强。
3. 主入口和 references 正向能力重写。
4. examples 修复。
5. eval 矩阵补齐。
6. 下游消费验证。
7. 全量复检与正式可用结论。

每一批都必须有独立验证证据；首次满足成功标准后进入多轮复检，连续两轮无新增目标内问题后才能交付。

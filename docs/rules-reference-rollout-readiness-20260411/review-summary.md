# rules/reference 正式推广前修订清单

日期：2026-04-11

范围：
- `shared/assistant.md`
- `shared/rules/*.md`
- `shared/reference/*.md`
- 相关装配与校验链路：`install.sh`、`contracts/*.yaml`、`tests/*.sh`

评审方式：
- 主代理串行审阅规则、reference、安装链路、测试链路
- 并行召集 5 个 agent，从文本冲突、组织治理、首用体验、装配闭环等维度独立审查
- 其中 3 个 agent 在时限内返回完整结论，2 个 agent 未在窗口内收敛，未纳入正式判断

结论：
- 当前状态：`需修后试点`
- 不建议：直接全团队强制推广
- 建议路径：先修 P0，再做小范围试点，再决定是否全量推广

## 一页判断

这套体系的强项很明确：
- 单一真源清晰
- 安装、渲染、回滚、完整性校验做得扎实
- 运行面与源码面的一致性保护较强

这套体系的主要风险也很明确：
- 少数上位规则之间存在真实执行冲突
- 有些约束写成了平台动作名，而不是平台无关行为
- 对“小改动、老仓库、docs-only、script-only”场景缺少轻量通路
- 一部分条款过于绝对，容易把团队推向形式主义和策略性合规

判断：
- 它已经是“工程装配上可用”的系统
- 还不是“组织推广上可直接默认”的系统

## 推广 Gate

进入试点前，至少满足以下条件：
- P0 项全部关闭
- 新增 3 到 5 个“首次采用场景”测试
- 明确试点范围、例外口径、回退机制

进入全量推广前，至少满足以下条件：
- P0 项全部关闭
- P1 项大部分关闭，剩余项有明确观察指标
- 试点 1 到 2 周内没有出现明显的影子流程和大面积绕规则行为

## P0 必须先修

### P0-1 失败处理边界冲突

问题：
- `shared/rules/铁律.md:9` 要求“执行失败后立即停止所有后续步骤并等待指示”
- `shared/reference/系统调试.md:6-14` 又要求遇错后继续执行 `Observe -> Hypothesize -> Test -> Fix`

风险：
- 团队会在“先停”还是“先诊断”之间卡住
- 高压场景下最容易出现误解和不一致执行

修订建议：
- 把“停止所有后续步骤”改成更精确的边界
- 建议改为：停止继续实现、停止切换备选方案、停止宣称完成
- 明确保留：允许受控诊断、证据收集、问题复现、假设验证

完成标准：
- `铁律` 与 `系统调试` 不再互相打架
- 对“故障排查”和“方案降级”有明确区分

### P0-2 平台动作名泄漏到规则层

问题：
- `shared/rules/执行纪律.md:9`
- `shared/reference/技术选型.md:16`
- `shared/reference/代码复用.md:75`

这些地方把“向用户确认”写成了 `AskUserQuestion` 这类平台动作名。

风险：
- Claude/Codex/其他运行面对同一条规则会产生不同理解
- 团队成员会把工具名误解成规则本身

修订建议：
- 规则层改成“行为目标 + 首选工具”的双层表述
- 用“向用户确认”“请求用户裁决”“在不可交互场景记录 AUTO_DECISION”表达规则本意
- 若运行面提供 `AskUserQuestion`，可明确写成优先使用；平台动作名继续保留在 adapter、skill、实现层

完成标准：
- 规则文本即使脱离具体工具名也仍然成立
- 同时不牺牲当前运行面下的执行力与提醒强度

### P0-3 安装成功不等于守护生效

问题：
- `README.md:47-51`
- `install.sh:170-212`
- `install.sh:224-240`
- `tests/test-install-systematic.sh:130-142`

当前 `Claude hooks` 合并依赖 `--merge-hooks` 和 `jq`，安装成功并不天然等于 hooks 已接入。

风险：
- 团队不同成员虽然都“安装成功”，但真实守护强度不同
- 最容易被 gaming，也最容易引发“为什么我这边没拦”的争议

修订建议：
- 让“安装成功”和“关键守护已激活”绑定
- 至少对关键 hook 缺失给出更强提示
- 更理想的做法是：默认合并，缺依赖时失败或显式进入受限模式

完成标准：
- 默认安装路径下，关键守护已稳定接入
- 若未接入，用户能被明确告知当前是降级模式

### P0-4 缺少小改动和非标准仓库的轻量通路

问题：
- `README.md:68-89`
- `shared/rules/执行纪律.md:19-22`
- `shared/reference/完成前验证.md:7-27`
- `shared/reference/影响范围分析.md:72-113`

当前默认心智更接近“仓库已经全面 small-chain 化”，而不是“准备开始推广”。

风险：
- 小修、文档修订、脚本修订、老仓库修订会被迫补一整套工件
- 团队很快会形成影子流程：先做事，事后补文档

修订建议：
- 明确一条 `small-change path`
- 适用范围可以包括：docs-only、script-only、单文件修复、无现成 `tasks.md/plan.md` 的老仓库
- 轻量路径仍保留核心红线，但降低工件负担

完成标准：
- 文档中明确写出轻量路径入口、边界、完成定义
- 新人第一次处理 20 分钟小改动时，不需要先补完整链路工件

## P1 试点中重点观察

### P1-1 rules 高于用户指令的边界过宽

问题：
- `shared/assistant.md:9`

当前写法把 `rules` 整体都置于用户之上，范围过宽。

风险：
- 对高风险红线是合理的
- 对执行纪律、文档管理、部分流程约束则过硬，容易导致刚性拒绝

修订建议：
- 收窄为“少数硬约束高于用户”
- 其余流程型约束改成“说明风险后可按用户意图偏离”

### P1-2 并行协作边界不清

问题：
- `shared/rules/执行纪律.md:22`
- `shared/rules/执行纪律.md:32`
- `shared/reference/agent-team-patterns.md:8-37`
- `shared/reference/影响范围分析.md:103-111`

规则层偏顺序，reference 层又支持并行，当前边界没有说透。

风险：
- 同一系统内出现“口头允许并行、执行时又不敢并行”

修订建议：
- 把“一次一件事”限定到单子任务内
- 明确允许：边界清晰、共享文件受控、裁决人明确的并行任务

### P1-3 完成前验证对 docs-only 和 script-only 不够友好

问题：
- `shared/reference/完成前验证.md:9-27`

当前默认要求测试、构建、lint，更适合标准软件仓库。

风险：
- 纯文档、规则、shell、配置场景容易被逼出空壳验证

修订建议：
- 为无 build、无 lint、无测试仓库补一套可执行的验证口径
- 强调“fresh proving command”可以是更贴近工件本身的检查

### P1-4 注释与测试要求过于绝对

问题：
- `shared/rules/代码规范.md:19-21`
- `shared/reference/测试规范.md:139`

风险：
- 诱导低价值注释
- 诱导“为了满足每个新函数都有测试”而避免正常重构

修订建议：
- 把强制对象从“所有函数/字段”收窄到“非显然、边界敏感、语义复杂、含不变量的对象”
- 让测试要求围绕“行为变化和风险”而不是“每个新函数”

外部参考：
- Google 风格更强调“非显然时写注释”，不是对每个变量和函数一刀切  
  来源：[Google C++ Style Guide](https://google.github.io/styleguide/cppguide)
- 测试金字塔强调分层与比例，而不是把所有新函数都直接等价成新增测试义务  
  来源：[The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)

### P1-5 缺少“首次采用体验”测试

问题：
- 当前测试更偏结构完整性、装配完整性、引用完整性

风险：
- CI 全绿，但新人仍会在真实首用路径上卡住

修订建议：
- 至少新增以下场景测试：
- 首次安装后 hooks 未合并的提示是否足够明确
- docs-only 仓库如何完成验证
- 无 `tasks.md/plan.md` 老仓库的小改动如何走轻量路径
- Claude/Codex 混用时是否出现平台术语误导
- 无 LSP 或 LSP 未初始化时，复用与影响分析如何退化执行

## P2 可后置优化

### P2-1 硬编码治理示例偏 Python

问题：
- `shared/reference/硬编码治理规范.md:10-20`

风险：
- 在跨语言团队推广时，会让 TS/Java/Go 团队不确定这到底是“例子”还是“统一目录规范”

修订建议：
- 改成语言无关原则 + 多语言示例

### P2-2 AUTO_DECISION 需要承接置信度和回退策略

问题：
- `shared/reference/技术选型.md:18-20`

风险：
- 容易把“保持一致性”误等价成“最佳决策”

修订建议：
- 补充：决策置信度、失效条件、试点条件、回退方式

外部参考：
- ADR 最佳实践通常要求记录 context、options、tradeoffs、confidence  
  来源：[Maintain an ADR](https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record)

### P2-3 上下文预算仍偏高

问题：
- `bash tests/test-skill-context-budget.sh` 结果显示：
- `design`：1005 行
- `product`：915 行
- `tech-lead`：1057 行

风险：
- 高频核心 skill 更容易因为上下文臃肿而影响稳定性

修订建议：
- 继续把低频说明从主 SKILL.md 外移
- 优先削减高频核心 skill 的运行面噪音

## 推荐试点方案

试点范围：
- 2 到 3 名核心使用者
- 1 到 2 周
- 同时覆盖 Claude 与 Codex

试点任务池：
- 一个 docs-only 改动
- 一个 script-only 改动
- 一个小型 bugfix
- 一个需要调试定位的问题
- 一个需要并行协作的中等任务

试点观察指标：
- 是否频繁出现“先做了再补工件”
- 是否频繁出现“为了过门禁补无效证据”
- 是否频繁出现“平台动作名理解不一致”
- 是否频繁出现“安装了但没守住”的差异
- 是否频繁出现“流程卡住，必须人工解释规则”的场景

试点结束的 go/no-go 规则：
- 若 P0 相关问题仍反复出现：不进入全量推广
- 若主要问题集中在文案可修、边界可补：修后再试点一轮
- 若轻量路径、安装守护、平台无关表达都稳定：再评估全量推广

## 本次验证证据

已运行并通过：
- `bash tests/test-single-source-layout.sh`
- `bash tests/test-runtime-contract-catalog.sh`
- `bash tests/test-doc-reference-integrity.sh`
- `bash tests/test-reference-graph-hygiene.sh`
- `bash tests/test-runtime-reference-activation.sh`
- `bash tests/test-runtime-integrity.sh`
- `bash tests/test-install-systematic.sh`

已运行并告警：
- `bash tests/test-skill-context-budget.sh`

并行评审摘要：
- 对抗文本审查：指出规则冲突、平台泄漏、并行边界冲突
- 组织 challenger：指出形式主义、过度服从、隐性中心化、影子流程风险
- 首用体验 challenger：指出安装成功不等于守护生效、轻量路径缺失、首次采用体验缺少测试

## 外部最佳实践对照

- [Google C++ Style Guide](https://google.github.io/styleguide/cppguide)
  用于对照注释强制度，支持“非显然处重点注释”的方向
- [The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)
  用于对照测试分层与比例，支持“按风险分层，不把所有新增函数都绝对化”
- [Managing Incidents, Google SRE](https://sre.google/sre-book/managing-incidents/)
  用于对照失败场景下的响应方式，支持“受控诊断而非一刀切全停”
- [Maintain an ADR](https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record)
  用于对照决策记录内容，支持为 `AUTO_DECISION` 增补置信度和失效条件

## 最终建议

现在最合理的动作不是“直接上团队”，而是：
- 先修 P0
- 再跑一次小范围试点
- 试点通过后再决定是否作为团队默认规范推广

一句话判断：
- 这套体系已经具备“工程化装配强度”
- 但还缺“组织推广友好度”

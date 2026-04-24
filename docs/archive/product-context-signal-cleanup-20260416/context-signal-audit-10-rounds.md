# Context Signal Audit — 10 Rounds

Created: 2026-04-16

## Audit Rule

每轮按同一判断尺执行：运行态上下文只保留会改变执行行为、输出格式、边界判断或失败处理的内容；已验证能力不得因降噪被压扁；发现后必须落到测试或文件修复。

| Round | 检查维度 | 发现 | 处置 | 门禁 |
|-------|----------|------|------|------|
| R01 | 运行态叙事噪音 | `split playbook 第 1/2 段` 是作者视角，不改变执行 | 删除该叙事，保留真实运行边界 | `test-product-context-signal-quality.sh` |
| R02 | 流程认知顺序 | 步骤表先于 `digraph product_flow`，先看细节再看状态机会增加漂移 | Director / Manager 均改为流程图先行、表格随后 | `test-product-context-signal-quality.sh` |
| R03 | 未定义产物 | `product-manager-review.md` 被直接要求维护，但未先说明它是什么 | 增加 `product-manager-review.md 产物契约`，定义用途和消费边界 | `test-product-context-signal-quality.sh` |
| R04 | 契约自述噪音 | `本契约定义`、`## 适用范围` 会复述外部引用关系 | 保持 contract 直接进入可执行规则 | `test-product-context-signal-quality.sh` |
| R05 | 入口元说明 | `SKILL.md 只保留...`、`真源` 是作者说明 | 入口只保留读取哪个 contract 和何时读取 | `test-product-context-signal-quality.sh` |
| R06 | 旧版能力保真 | D-S1 双 Agent 能力曾被压成“静默扫描” | 恢复 `Context Scan Agent` / `Problem Hypothesis Agent` 和 final 结论边界 | `test-product-context-signal-quality.sh` |
| R07 | reviewer 局部可执行性 | reviewer prompt 只写“沿用标准”，subagent 单独读取时易漏 `Findings` / 承接目标 | 三个 reviewer prompt 均补完整输出 schema 和 Verdict Rules | `test-product-context-signal-quality.sh` |
| R08 | 模板过程说明 | 模板中出现“以下章节补充到...”和 handoff 解释 | 删除模板过程句，模板只保留产物字段 | `test-product-template-purity-contract.sh` |
| R09 | 评审闭环保真 | Agent Team、`3 视角×max10轮`、确认轮、只重提 FAIL 视角不能因降噪被删 | 保留在 `review-orchestration-contract.md` 并由 parity 门禁验证 | `test-product-inherited-capability-parity.sh` |
| R10 | 证据强度 | 旧 eval 证明平均更好，但不足以覆盖噪音和误删回退 | 新增上下文信号质量门禁，补足噪音/保真类回归防线 | `test-product-context-signal-quality.sh` |
| R11 | 下游 review 明细泄漏 | `/design` 和 `/tech-lead` 读取产品 `product-manager-review.md` 或用前序 review 过程减轻自身审查 | 下游只消费冻结产物和明确承接项；删除产品 review 明细读取与模板回放 | `test-product-context-signal-quality.sh` |

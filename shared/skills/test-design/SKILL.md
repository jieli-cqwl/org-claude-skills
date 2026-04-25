---
name: test-design
description: 需求驱动的测试用例设计。Use when 需求确认后、开发前需要设计测试用例和测试方案。
eval-type: mixed
disable-model-invocation: true
argument-hint: "[feature-name]"
user-invocable: true
allowed-tools: Read, Write, Glob, Grep, Agent, AskUserQuestion
---

# /test-design -- 开发前测试设计与缺口识别

> ultrathink

## HARD-GATE

1. NO output without `brief.json + phase-{N}/phase-prd.json + phase-{N}/units/ + design.json` existing.
2. NO test case without AC triple coverage (positive+negative+boundary, each verifiable) + 排除项验证用例 + negative+boundary count >= positive count. DESIGN-GAP only for real unmapped AC or explicit gap evidence.
3. NO /test-design completion without full artifact set: `test-cases.json`（含 UNIT 覆盖视图、scope_item_id 对照、EQ status、QA 交接契约与审查结论字段）in UNIT 工作区.
4. NO /test-design completion with unresolved review findings: any FAIL verdict blocks completion; WARN items must have handling records in canonical review fields / projected审查视图中。
5. NO handoff to `/tech-lead` when any DESIGN-GAP(EQ) remains unresolved.
6. NO /test-design completion with shallow review evidence — `审查结论` MUST contain review_round and convergence evidence in the issue ledger.

## 角色

你是测试设计架构师，负责在开发前基于 `Brief + Phase PRD + 闭环 UNIT + Design` 形成可执行测试用例、QA 交接契约与设计缺口报告。`test-cases.json` 是唯一真源；`Coverage Draft`、`Equivalence Draft`、`QA Handoff Draft` 只允许作为中间草稿，不得直接充当最终证据。

## Red Flags

If you catch yourself thinking:
- "我把 test-design 做成第二个 design" → 立即暂停。只报告真实设计缺口，不重做架构。
- "默认把所有专项测试全量展开更保险" → 立即暂停。先按触发条件展开，必要时保守补 1 组。
- "审查只是走形式，直接 PASS" → 立即暂停。每个视角必须独立审查，有发现就标记。

## 前置条件

- standard-chain lane：`docs/{feature}/brief.json` 必须存在（目标、用户角色与核心场景、范围/本期不交付、当前/目标业务流程、GAC-*、CON-*、全局排除项）
- standard-chain lane：`docs/{feature}/phase-{N}/phase-prd.json` 必须存在（UNIT 索引）
- standard-chain lane：`docs/{feature}/phase-{N}/units/UNIT-*.json` 必须存在（AC 提取）
- standard-chain lane：当前 Phase 工作区中的 `design.json` 必须存在（位于 `phase-{N}/design.json`，缺失时终止并提示先执行 `/design`）
- Markdown 文档或口头设计说明不能替代 Phase 工作区中的 canonical `design.json`；`design.json` 才是测试设计真源。
- 当用户说“设计后面再补”“口头说过”或只提供 markdown 设计时，阻断回复必须明确写出：markdown 文档或口头设计不能替代 canonical `design.json`。
- 非 canonical 派生视图仅可作为线索；不得作为测试设计、缺口裁决或 QA 交接真源

## 固定主流程

1. 按 UNIT 建立功能视图
   - standard-chain lane：基于用户指定的 feature（$ARGUMENTS），从 `brief.json + phase-{N}/phase-prd.json + phase-{N}/units/` 提取闭环功能、验收标准与排除项。
   - 非 canonical 派生视图仅可作为线索，不参与最终覆盖裁决。
   - 多 Phase 项目按 `{{RUNTIME_HOME}}/protocols/phase-selection-protocol.md` 选择当前 Phase，仅处理该 Phase 的 UNIT 子集。
   - `/test-design` 以 UNIT 为执行单位，一个 Phase 包含多个 UNIT 时依次对每个 UNIT 执行。
   - `design.json` 从 Phase 工作区（`phase-{N}/design.json`）读取。
2. 提取设计约束
   - 从 `design.json` 提取接口、错误码、字段约束与 `scope_item_id`。
   - Downstream Rollout Contract：读取 `design.json.data_architecture`，转成数据一致性、迁移、回滚测试义务；缺失或无法映射时输出 `DESIGN-GAP(data_architecture)`。
   - Downstream Rollout Contract：读取 `design.json.cross_cutting_concerns`，逐项覆盖 auth / error / log / config 测试义务；缺失任一项时输出对应 DESIGN-GAP。
   - Downstream Rollout Contract：读取 `design.json.verification_mapping`，校验 Manager VP 到测试用例和 QA handoff 的覆盖链，并在 `qa_handoff_contract[].design_source_refs` 写入 `manager_vp_ref` 承接证据。
   - 若存在独立设计审查投影或报告，读取测试视角（DT-1~DT-4）的具体发现；不得依赖写回 `design.json` 的 runtime verdict 字段。
3. 并行生成覆盖与等价性草稿
   - 先派发 `Coverage Draft Agent` 与 `Equivalence Draft Agent`，二者可并行。
   - 仅在做覆盖映射与等价性对照草稿时使用：`Coverage Draft Agent` 只产出 `AC -> 用例`、`scope_item_id` 覆盖和缺口候选，不得写入最终 `DESIGN-GAP(EQ)`、Verdict 或 QA 结论。
   - `Equivalence Draft Agent` 只产出等价性对照草稿和不变量草稿，不得把候选缺口升级为 `DESIGN-GAP(EQ)`。
4. 主 Agent 收敛覆盖与等价性草稿
   - 主 Agent 汇总并裁决 coverage / equivalence 草稿，写入最终 `AC 覆盖矩阵` 与 `等价性对照矩阵`。
   - `DESIGN-GAP(EQ)` 只允许由主 Agent 在最终工件中单点裁决；若存在未收敛缺口，暂停并上报用户，确认是否回流 `/design`。
5. 生成 QA Handoff 草稿
   - 仅在主 Agent 已收敛 coverage / equivalence 且不存在待裁决的 `DESIGN-GAP(EQ)` 时，派发 `QA Handoff Draft Agent`。
   - 只用于生成交接草稿；输出 `test_obligation`、`trigger_source`、`qa_stage`、`requiredness`、`execution_mode`、`skip_rule`、`evidence_expectation`，不得替代主 Agent 写入最终 `test-cases.json`。
6. 按 UNIT 设计基础用例
   - 先按 UNIT 分组，再为每条 AC 设计正例 / 反例 / 边界。
   - PRD 驱动的补充用例规则：
     - 高风险操作清单中的每个操作，至少 1 个确认机制验证用例 + 1 个日志留痕验证用例
     - 角色权限矩阵中的每个角色×模块组合，至少 1 个正向权限用例 + 1 个越权拒绝用例
     - QA 测试重点中的每个类别，作为用例优先级排序的权重因子
   - 用 `输入/操作 -> 期望输出` 表达用例，并关联 `scope_item_id`。
7. 设计排除项验证
   - 每条排除项至少 1 个“不应发生”的验证用例。
8. 识别真实设计缺口
   - AC 无法映射到设计承接，或关键错误/约束缺失时标记 DESIGN-GAP。
   - 等价性无法承接时标记 DESIGN-GAP(EQ)。
   - 发现 DESIGN-GAP(EQ) 时暂停并上报用户，确认是否回流 `/design`。
9. 输出 QA 交接契约
   - 在 `test-cases.json.qa_handoff_contract` 中逐条写清：`test_obligation`、`trigger_source`、`qa_stage`、`requiredness`、`execution_mode`、`skip_rule`、`evidence_expectation`。
   - 至少覆盖：冒烟、AC/功能、API/接口、E2E、回归、探索、UX、异常恢复、NFR。
   - `execution_mode` 仅允许：`browser_required` / `non_browser_ok`。
   - 当真实入口是 Web/H5，且验收依赖页面渲染、交互反馈、前端状态或路由行为时，`E2E / UX / 异常恢复` 必须标记 `browser_required`。
   - 默认必须标记 `browser_required` 的场景：登录/权限/重定向/路由守卫、多步骤表单/向导/下单、文件上传下载、富交互状态切换、错误提示与恢复路径、关键 UX 反馈影响任务完成。
   - `qa` 不得自己猜测这些义务是否成立；未触发、延后执行、允许跳过都必须在 `skip_rule` 中写明理由。
10. 按条件展开专项测试
   - 读取 `design.json.quality_attributes` 作为专项触发源（如性能目标指标触发性能专项、安全策略触发安全专项）。
   - `data_architecture` 触发数据一致性、迁移验证、回滚验证专项；无法形成用例时写入 DESIGN-GAP，不允许静默跳过。
   - `cross_cutting_concerns` 中 auth/error/log/config 分别触发认证授权、异常路径、日志可观测、配置管理专项。
   - `verification_mapping` 中每条 `manager_vp_ref` 必须至少落到一条 `test_case` 或 `qa_handoff_contract.design_source_refs`。
   - 结合触发规则决定是否展开集成/契约/安全/性能专项。
11. 输出结果
   - 生成 `{unit_work_dir}/test-cases.json`。
12. 跨职能评审
   - 召集 Agent Team（TeamCreate 协作团队），3 个 reviewer 分别从测试质量、产品、架构维度并行评审 `test-cases.json`：
     - 测试质量 reviewer prompt：`references/testdesign-reviewer-prompt.md`（覆盖 TQ-1~TQ-5：AC覆盖完整性、排除项验证、用例可执行性、用例独立性、DESIGN-GAP合理性；用于确认测试用例本身完整、可执行、不过度冗余）
     - 产品 reviewer prompt：`references/testdesign-product-reviewer-prompt.md`（覆盖 TP-1~TP-3：业务意图覆盖、排除项一致性、优先级与风险对齐；用于确认测试设计仍忠实覆盖业务意图、排除项与风险优先级）
     - 架构 reviewer prompt：`references/testdesign-arch-reviewer-prompt.md`（覆盖 TA-1~TA-3：接口契约覆盖、技术约束验证、专项测试充分性；用于确认测试设计覆盖接口契约、技术约束与专项测试触发）
   - 复核三方评审结果，合并写入 `test-cases.json.review_conclusion`。
     报告模板：`references/templates/test-cases-template.md`（必填：审查汇总表 + 问题台账）
   - 如有 FAIL：复核问题证据、影响范围与承接位置 → 系统性修复 `test-cases.json` → 仅对 FAIL 视角重新提交评审 → 循环。
     - 循环上限 10 次
     - 首轮全 PASS 时强制做一次确认轮（防浅层通过）
     - 连续 2 轮 FAIL 数不减少 → AskUserQuestion 暂停
     - 同一问题连续 3 轮未关闭 → 标记 BLOCKED，停止自动修复
   - WARN 项在 `test-cases.json.review_conclusion` 中记录承接位置。

## 专项展开规则

统一规则：
- 必须展开条件命中：展开该专项
- 未命中但有常见信号：按风险补充
- 不确定：执行保守展开（至少补 1 个该专项场景）

专项方法：
- 当展开集成测试时：
  → 读取 `references/integration-test-methodology.md` 获取必须展开条件（跨模块/跨服务/异步/事务/外部依赖）、保守展开规则、最小用例方向（接口传递/数据链路/异常链路）
- 当展开契约测试时：
  → 读取 `references/contract-test-methodology.md` 获取必须展开条件（多服务接口/外部API/DTO兼容/版本兼容）、保守展开规则、最小用例方向（请求结构/响应结构/版本兼容）
- 当展开安全测试时：
  → 读取 `references/security-test-methodology.md` 获取必须展开条件（认证授权/敏感数据/文件上传/开放输入/高权限）、保守展开规则、最小用例方向（输入验证/认证授权/敏感数据保护）
- 当展开性能测试时：
  → 读取 `references/performance-test-methodology.md` 获取必须展开条件（明确性能指标/大数据量/并发/聚合/批量）、保守展开规则、最小用例方向（基线性能/边界性能/退化风险）

## 输出

输出到 `{unit_work_dir}/test-cases.json`（unit_work_dir 由 PRD 交付计划定义）。
运行时模板：`contracts/canonical/templates/planning/test-cases.template.json`
人类投影视图模板：`references/templates/test-cases-template.md`

包含：
- `summary`
- `unit_coverage_view`
- `ac_coverage_matrix`
- `equivalence_matrix`
- `design_gap_report`
- `test_cases`
- `qa_handoff_contract`
- `qa_handoff_contract[].design_source_refs`
- `special_test_triggers`（当专项测试计数 > 0 时必填）
- `review_conclusion`

跨职能审查报告：UNIT 工作区的 `test-cases.json` 内嵌 `review_conclusion`

## 完成校验

- [ ] `test-cases.json` 存在于 UNIT 工作区，且包含内嵌 `review_conclusion`
- [ ] 每条 AC 有正例+反例+边界，负面+边界 >= 正面；排除项有验证用例；scope_item_id 对照完整
- [ ] `qa_handoff_contract` 已明确冒烟、AC/功能、API/接口、E2E、回归、探索、UX、异常恢复、NFR 的触发、`execution_mode` 与承接方式；草稿未泄漏进最终工件
- [ ] 跨职能审查 3 视角 Verdict 可解析，FAIL 已修正，WARN 已在 `test-cases.json.review_conclusion` 中承接
- [ ] DESIGN-GAP(EQ) 已阻断回流 /design 或已解决；DESIGN-GAP 仅针对真实缺口
- [ ] 已运行 `python3 tools/community/validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"` 并通过

## 流程导航

Test-design 完成后，下一步执行 `/tech-lead`。规划链路：`/product-director → /product-manager → /design → /test-design → /tech-lead → /delivery-owner`；执行期由 `/delivery-owner` 编排 `/developer → /verify → /review → /qa`。

# Tasks — Product Context Signal Cleanup
Created: 2026-04-16
Related plan: ./plan.md

## Acceptance Checklist

- [x] T1 纯化 product 模板
  - AC: Director brief 模板不包含 `## MVP 最小闭环说明`、`## 交付确认`、UNIT 优先级、UNIT 依赖或 Manager-only 评审内容。
  - AC: Manager review 模板保留评审闭环证据字段，但不承载流程讲解、权限解释或 brief 共创流水账。
  - AC: product 模板中规则词行数受 `test-product-template-purity-contract.sh` 限制。

- [x] T2 声明式化 product 运行态合同
  - AC: 新增机器可读合同 `contracts/product-artifacts.yaml`，包含 brief lock、prd lock、review contract 的最小字段。
  - AC: Director 与 Manager gate 引用 `contracts/product-artifacts.yaml`，不再各自硬编码锁定章节集合。
  - AC: contract test 校验 gate 与合同文件存在真实引用关系。

- [x] T3 收敛提示词和证据文档噪音
  - AC: `SKILL.md` 保留角色边界与流程，模板不重复流程规则。
  - AC: `conversation-guide` 只保留追问启发，不复述完整状态机。
  - AC: `deep-validation-report.md` 与 `evidence-and-eval-plan.md` 明确历史证据边界，不再写自证式优势散文。

- [x] T4 重建更严格的 eval 证据合同
  - AC: benchmark contract 检查 outcome-based eval 或中立评分约束，不允许只依赖 split 术语命中。
  - AC: benchmark runner 支持 randomized blind order 或记录当前 smoke 边界。
  - AC: product eval contract 区分“接线存在性”和“质量证明”，禁止把前者当成后者。

- [x] T5 增加当前能力契约引用门禁
  - AC: 新增 `tests/test-product-inherited-capability-parity.sh`，校验 split 后仍保留产品思维框架、警示信号、Agent Team 评审、`max10轮`、确认轮、收敛/阻断规则和稳定 issue 台账。
  - AC: `/product-director` 通过 `references/product-thinking-contract.md` 引用价值假设、MVP 范围和警示信号，不在 `SKILL.md` 复述历史来源。
  - AC: `/product-manager` 通过 `references/review-orchestration-contract.md` 引用 TeamCreate 协作团队评审闭环，并在契约内承载 Director lock / R13 / PR-C1 这类 split 差异能力。

- [x] T6 增加产出契约引用门禁
  - AC: 新增 `tests/test-product-output-contract-reference.sh`，校验 Director / Manager 的 `## 产出` 只引用 output contract，不直接堆产物路径、模板和 lock 细节。
  - AC: `/product-director` 通过 `references/output-contract.md` 承载产物路径、模板、锁文件和写入边界。
  - AC: `/product-manager` 通过 `references/output-contract.md` 承载产物路径、模板、review 证据和写入边界。

- [x] T7 增加上下文信号质量门禁
  - AC: 新增 `tests/test-product-context-signal-quality.sh`，禁止运行态入口和 contract 残留作者视角、契约自述、适用范围复述和抽象“沿用标准”输出壳。
  - AC: `/product-director` 恢复 D-S1 的 `Context Scan Agent` / `Problem Hypothesis Agent` 显式职责，并保留不得写入 final 结论的边界。
  - AC: Director / Manager 通过最小 `digraph product_flow` 表达 gate、回退和评审循环，不恢复旧单体 runtime。
  - AC: 三个 reviewer prompt 自带 `Findings`、`承接目标` 和 Verdict Rules，可由 reviewer subagent 单独读取并产出可合并结果。

- [x] T8 执行 10 轮上下文信号审计循环
  - AC: 新增 `docs/product-context-signal-cleanup-20260416/context-signal-audit-10-rounds.md`，记录至少 10 轮“检查维度 / 发现 / 处置 / 门禁”。
  - AC: `tests/test-product-context-signal-quality.sh` 校验 10 轮审计记录存在，且 Director / Manager 流程图先于步骤表。
  - AC: `/product-manager/references/review-orchestration-contract.md` 在使用 `review.md` 前先定义它的产物职责和消费边界。
  - AC: `/product-director` 与 `/product-manager` 不再保留 `split playbook 第 X 段` 这类运行态叙事。
  - AC: `design.md` 只保留长期原则，不承载 `至少 10 轮` 这类过程证据要求。
  - AC: `/product-manager` 明确 M-S8 review 由自己发起并收敛；下游只消费交付状态、未关闭 FAIL、WARN 承接目标和待设计决策。

- [x] T9 收敛下游 review 明细消费边界
  - AC: `/design` 不读取 `review.md` 或产品评审明细，只消费 `brief.md` / PRD / UNIT / 明确写入 `待设计决策` 的承接项。
  - AC: design 模板使用 `## 产品交付承接`，不再使用 `## 上游审查承接` 或回放产品评审过程。
  - AC: `/tech-lead` 不读取产品 `review.md`，也不使用前序评审过程来缩减本阶段 Design Review。
  - AC: `tests/test-product-context-signal-quality.sh` 覆盖 `/design`、design template、`/tech-lead` 三处下游边界。

## Definition of Done

All tasks checked = ready for verify-change.

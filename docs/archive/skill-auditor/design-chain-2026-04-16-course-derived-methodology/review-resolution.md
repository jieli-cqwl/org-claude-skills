# Claude review 裁决记录

## 目的

本文件把 Claude 的 `review-report.md` 从外部挑战转成主线裁决。它解决三个问题：哪些反馈采纳，哪些反馈不采纳，哪些反馈转成实施约束。

`review-report.md` 是输入材料，不直接约束实施。`review-resolution.md` 是裁决真源；后续 `design.md`、`tasks.md`、`plan.md` 和实现工作以本文件的裁决为准。

## 裁决原则

1. Harness Engineering 方向保留；不采用 Markdown-only 路线。
2. Claude 对复杂度、消费者和迁移验证的挑战采纳为边界约束。
3. E5 试点不写成硬门禁；进入 runtime 蓝图、eval 或回退合同。
4. 每个字段、目录、脚本、schema、renderer 和 hook adapter 都要有消费者。
5. 分阶段推进服务于依赖管理，最终交付边界仍是端到端闭环。

## 核心反馈裁决

| 编号 | Claude 反馈 | 裁决 | 落地方式 |
| --- | --- | --- | --- |
| F1 | 设计复杂度超出首轮交付能力 | 采纳风险，不采纳降级方向 | `design.md` 收敛为最终设计真源；runtime 细节拆入 `runtime-blueprint.md`；交付按依赖切片推进 |
| F2 | 内部 review 未挑战核心假设 | 采纳 | 本文件记录框架级裁决；明确 JSON/schema/validator 保留原因和进入条件 |
| W1 | 课程方法论角色模糊 | 采纳 | `source-notes.md` 继续区分 body/case/exercise/reply/comment；`design.md` 只引用 source marker |
| W2 | E5 内容名实不符 | 采纳 | E5-only 不进 HARD-GATE；进入 runtime 蓝图、实验协议或回退合同 |
| W3 | 迁移路径不完整 | 采纳 | `design.md` 迁移表补验证命令、回滚动作和退出条件 |
| M1 | Review 框架偏向过度设计检测 | 采纳 | 保留设计不足视角：不得删除 consumer、validator、eval、权限和迁移闭环 |

## 不采纳项

| Claude 建议 | 不采纳原因 | 保留约束 |
| --- | --- | --- |
| 首轮砍掉 JSON artifact | 与 Harness 目标冲突 | JSON 作为机器事实源，但字段需通过 consumer-first gate |
| 首轮砍掉 schema/validator | 无 validator 就无法证明 runtime contract 稳定 | schema 与 semantic validator 是最终交付的一部分 |
| 首轮只输出 Markdown 审计报告 | Markdown 不能承担机器流转事实源 | Markdown/HTML 作为 JSON 派生视图 |
| 用 400 行否定 `design.md` | 400 行来自非测试业务代码约束，不是设计文档硬门禁 | 仍采纳可读性问题，通过拆分文档职责处理 |
| 认为 SO-* 锚点过重 | 锚点支撑 tasks/plan/verification 的追踪链路 | 保留锚点，数量收敛到运行链路核心 |

## 转成实施约束

| 约束 | 适用对象 | 通过条件 |
| --- | --- | --- |
| Consumer-first gate | JSON 字段、目录、脚本、schema、renderer、hook adapter | 每项有 consumer、read purpose、validation 和 drop condition |
| Runtime fact source | `skill-audit.json`、`optimization-plan.json`、`verification-result.json` | Markdown/HTML 不反向成为事实源 |
| E5 降级 | Harness 推断、Claude 反馈、agent team 推断 | 不进入 HARD-GATE；绑定实验样例和回退合同 |
| 退役可回滚 | `new-skills` 旧入口、旧 reference、运行时残留 | 每个退役项有验证命令、回滚动作和退出条件 |
| 验证闭环 | schema、semantic validator、eval、fresh command | 每个 AC 都有命令和 Pass/Fail condition |
| 权限最小化 | review/audit/explain、edit/fix、commit/delete | 默认只读；写动作需重新确认范围 |

## 对 design.md 的裁决

`design.md` 不再承载 Claude review 过程、所有矩阵细节和完整 runtime 字段表。它保留最终设计裁决、运行链路、产物模型、目录职责、迁移策略、验证设计和设计锚点。

`runtime-blueprint.md` 承载 JSON artifact、schema、状态、validator、renderer 和 hook adapter 的详细合同。这样做不是削弱 Harness，而是把 Harness 细节放到专属工程合同中，避免 `design.md` 同时承担战略裁决和字段规格。

## 后续消费方式

`tasks.md` 需要逐条引用 `review-resolution.md` 的采纳裁决和 `design.md` 的 SO-* 锚点。`plan.md` 需要把每个 Task 绑定到文件范围、验证命令和预期输出。实现阶段不得直接以 `review-report.md` 的外部意见覆盖本文件裁决。

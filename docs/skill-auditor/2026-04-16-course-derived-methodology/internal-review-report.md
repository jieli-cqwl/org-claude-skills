# skill-auditor 内部 review 与 Claude handoff

## 目的

本报告记录交给 Claude 前的内部多维 review 结果。review 对象为 `source-notes.md` 与 `design.md`。目标是把课程证据、Harness Engineering 试点、权限边界、SubAgent 组合、验证协议和迁移路径先在本仓库内审清，再交给外部模型挑战。

## Review 阵型

| 维度 | Verdict | 主 Agent 裁决 |
| --- | --- | --- |
| 课程证据追踪 | REQUEST_CHANGES | 采纳：`evals/`、`schemas/` consumer-first；补 G02 discovery scope |
| 方法论完整性 | REQUEST_CHANGES | 采纳：frontmatter 字段组合与目录 consumer gate |
| Harness Engineering | REQUEST_CHANGES | 采纳：字段消费矩阵、状态转移表、semantic invariant、派生视图防漂移 |
| Skill 架构 | REQUEST_CHANGES | 采纳：复核裁决清单、legacy reference 路径、`agents/` 边界 |
| SubAgent/fork/handoff | REQUEST_CHANGES | 采纳：fork input contract、handoff consumer、acceptance_basis |
| 权限与 hooks | REQUEST_CHANGES | 采纳：权限 profile、script manifest、危险动作确认、hook 首轮替代门禁 |
| 实施可执行性 | REQUEST_CHANGES | 采纳：稳定锚点 ID、proving command 合同、E5 回退、迁移映射、vertical slice |
| eval/验证 | REQUEST_CHANGES | 采纳：可复测 dataset、验证边界、benchmark protocol、5/10/30 protocol |
| 完整度 challenger | REQUEST_CHANGES | 采纳：同步义务、legacy command、hooks lifecycle、自包含程度矩阵 |
| 过度设计 challenger | REQUEST_CHANGES | 采纳：首轮不一次性铺开三件套，先闭环 `skill-audit.json` |

10 个 reviewer 均未给出 BLOCKED。所有 REQUEST_CHANGES 都归并为设计修正项；重复 finding 以主 Agent 裁决收敛。

## 已落盘裁决

| 裁决主题 | 文件 | 落盘结果 |
| --- | --- | --- |
| source-notes 状态冲突 | `source-notes.md` | `高风险遗漏登记` 改为原始遗漏、当前覆盖、剩余风险；`Design 暂停清单` 改为复核裁决清单 |
| 稳定设计锚点 | `design.md` | 新增 SO-* 锚点 ID，绑定 source marker、证据等级、消费者、验证类型 |
| Frontmatter 字段合同 | `design.md` | 明确 `description`、`user-invocable`、`argument-hint`、`disable-model-invocation`、`allowed-tools`、`context`、`agent`、adapter 的组合与失败态 |
| Resource consumer gate | `design.md` | `evals/`、`schemas/` 改成存在消费者和验证路径时创建；目录创建不作为验收目标 |
| Runtime artifact 收敛 | `design.md` | 三件套降为候选 profile；首轮只闭环 `skill-audit.json`；补 E5 回退合同 |
| Schema/状态机合同 | `design.md` | 补字段消费矩阵、状态转移表、semantic invariant 和 `rendered_views` 防漂移字段 |
| 契约式引用 | `design.md` | 完整契约补 `同步义务`；legacy reference 示例改为兼容期跨 Skill 引用 |
| 任务型 Skill 权限 | `design.md` | 补 legacy command compatibility、权限 profile、script manifest、危险动作确认 |
| hooks 边界 | `design.md` | hooks 标为 future consumer；首轮用 semantic validator、人工复审和 eval 兜住流转 |
| SubAgent/fork/handoff | `design.md` | 补 fork input contract；handoff 补 consumer、acceptance_basis、decision_required、stage_id、input_from |
| 迁移路径 | `design.md` | 补逐文件迁移映射；冻结 `agents/` 只放平台 adapter |
| 跨平台 | `design.md` | 补 discovery scope、namespace、monorepo、自包含程度、依赖可迁移性 |
| 验证协议 | `design.md` | 补可复测 dataset、验证边界矩阵、benchmark protocol、5/10/30 人工 eval protocol |
| 实施可执行性 | `design.md` | 补 proving command 合同和首轮 vertical slice |

## Claude handoff 重点

交给 Claude 时，请重点挑战以下问题：

| 领域 | 挑战问题 |
| --- | --- |
| 首轮范围 | 只读审计 vertical slice 是否足以证明 `skill-auditor` 价值 |
| Runtime artifact | 先闭环 `skill-audit.json` 是否是正确的最小 artifact |
| Consumer-first | `evals/`、`schemas/`、`templates/`、`data/` 的创建条件是否足以抑制目录膨胀 |
| 权限 | 权限 profile 是否能被 Codex/Claude 两种运行面实际表达 |
| hooks | 首轮不接 hook registry 时，semantic validator 与人工复审能否替代状态流转拦截 |
| 迁移 | legacy `new-skills` 跨 Skill 引用是否优于立即复制 reference |
| 验证 | seed dataset、benchmark 和 5/10/30 协议是否能稳定复跑 |
| 可维护性 | SO-* 锚点 ID 是否足以支撑 `tasks.md`、`plan.md`、final report 覆盖表 |

## 当前结论

内部 review 后的裁决是：`source-notes.md` 可作为课程 source map；`design.md` 可作为 Claude review 输入；进入实施计划前，仍需要让 Claude 对首轮 vertical slice、runtime artifact 最小闭环、权限表达能力和验证复跑协议做外部挑战。

# Codex Consolidation Review

结论：Claude Code 首轮采集可复用；Codex 已完成 P0/P1 可证明字段合同项的收敛并进入实现。本文件保留裁决依据；实现状态以 `execution-summary.md` 和 `implementation-order.md` 为准。

## 当前判断

- 不重跑：A-E 矩阵、merged matrix、P0/P1 remap 的结构和证据引用基本有效。
- 不直接实现：原报告存在过期结论和错误的 `needs-human-decision` 分类。
- 不降级终极目标：`follow-up-cleanup` 不是可选项，只表示当前已有部分实现，仍必须清理 active 合同、测试、fixtures、工具和上下文噪音。
- 当前无必须等待用户裁决才能继续的 P0/P1 字段合同项；实现中若发现真实消费者冲突再停。

## 已纠偏事项

| item | Codex decision | basis |
| --- | --- | --- |
| stale P0/P1 challenge | resolved | `p0-p1-remap.md` 已存在且覆盖 FLOW-001..FLOW-012、SKILL-001..SKILL-005；原 remap 覆盖质疑是生成顺序遗留。 |
| `locked_field_digest` flat vs nested | mapped-to-field-gap | 硬约束和运行时都指向 `director_confirmation.locked_field_digest`；flat key_fields 是合同漂移，应删除而不是等待用户裁决。 |
| SKILL-001 fix-result | mapped-to-field-gap | delivery-owner 已要求 QA fix 后重跑 verifier、fresh code-reviewer、QA；缺口是 fix-result field-consumption/freshness 合同，不是用户裁决。 |
| SKILL-003 QA route | mapped-to-field-gap | PASS+ALLOW 才能提交，其他状态必须阻断或路由；需要确定性 route matrix validator，不需要重新问用户定义原则。 |
| Design/Test/Tech prose fields | implementation decision | 默认删除无 consumer 的 recovery/reference prose；gate/handoff 所需内容必须结构化为 refs/enums/owner/action/evidence，不能保留自然语言字段当合同。 |

## 字段合同动作

| area | required action | success evidence |
| --- | --- | --- |
| area | status | success evidence |
| --- | --- | --- |
| contract structure | done | duplicate key_fields negative test；field-consumption validator 能识别 nested path。 |
| director lock | done | readiness/intake/signoff 继续消费 `director_confirmation.locked_field_digest`；合同不再暴露 flat alias。 |
| runtime registry | done | artifact-registry schema/template/field-consumption/validator 一致；`owner_responsibility` prose 已移除。 |
| fix-result | done | QA FAIL 后 fresh verifier -> code-reviewer -> QA 的负例和正例测试。 |
| QA route | done | route validator 覆盖 PASS+ALLOW 与非 PASS+ALLOW 阻断/路由语义；readiness 拒绝非 PASS+ALLOW closeout。 |
| signoff evidence | kept | 现有 readiness_signoff_checks 保持 typed runtime evidence matrix；本轮未扩大修改。 |
| prose cleanup | scoped | 本轮只删除证据充分的 artifact-registry prose；其它开放 prose 留在 conflicts，后续单独决策。 |

## 下一阶段边界

- 可以进入实现，但必须按最小字段合同推进，不做样式化报告清理。
- 首个实现阶段只处理合同/validator/test 可机械证明的事项。
- 如果实现中发现某字段既没有 consumer 又无法结构化为 gate/handoff/recovery/evidence/state/decision，应直接删除并清理 active 引用。
- 如果字段删除会破坏现有真实消费者，先把消费者证据补到 field-consumption；不能用“可能有用”保留字段。

## 阻塞条件

- 需要改变终极目标或接受 `follow-up-cleanup` 不做。
- 为通过测试而保留旧 flat alias、自然语言测试契约或兼容提示。
- 自动化证据无法证明字段 owner/consumer/write_time/purpose/verification。

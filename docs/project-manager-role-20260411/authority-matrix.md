# Project Manager Authority Matrix

## 目标

冻结 `tech-lead / project-manager / developer / qa / user` 在本链路中的权责边界，避免执行期出现 owner 漂移。

## 权责矩阵

| 角色 | Must Own | May Decide | Must Escalate | Forbidden |
|------|-----------|------------|---------------|-----------|
| `tech-lead` | `plan.md`、目标保真、范围冻结、初始 gate matrix、前置验证项 | 任务拆分、依赖顺序、探索批次、基线质量强度 | 需求冲突、设计未收口、业务风险接受 | 执行 kickoff、执行期 gate 升档、签收 |
| `project-manager` | delivery kickoff、执行编排、偏差治理、动态 gate escalation、目标级收口 | 批次/优先级重排、补证据、暂停执行、replan request | scope 变化、设计变化、业务风险接受、sign-off 拒绝 | 需求定义、技术方案发明、替代 developer/qa、单方接受业务风险 |
| `developer` | Task 实现、TDD 证据、自测、结构化偏差信号回传 | 在 Task 范围内最小实现、接口微调（TWEAK） | 范围外改动、接口 BREAK、依赖漂移、不收敛 | 改写需求/设计、扩大范围、跳过 TDD |
| `qa` | 独立质量判断、`release_recommendation`、`residual_risk`、QAR 台账 | 在交接契约内扩展风险探索、承接升级验证范围 | 环境不可用、关键义务无法执行、阻塞级风险 | 替代用户签收、用实现摘要代替独立验收 |
| `user` | sign-off、业务风险接受、目标裁决 | 是否接受 replan / waiver / rollout 决策 | 无 | 把 sign-off 委托给下游 skill 自动完成 |

## 单一真源

- `tech-lead` 是 `plan.md` 的 planning owner。
- `project-manager` 是 execution phase delivery owner。
- `qa` 是独立质量判断 owner。
- `developer` 是 Task 实现 owner。
- `user` 保留最终 sign-off 与业务风险接受。

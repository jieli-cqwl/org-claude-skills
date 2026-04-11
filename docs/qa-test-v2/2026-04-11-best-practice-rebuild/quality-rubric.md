# QA/Test v2 Quality Rubric

## 评分方式
- 每个维度 `0-2` 分
- 总分 `14` 分
- `12` 分及以上才允许进入团队试点
- 任一维度为 `0` 时，即使总分达标也不允许推广

## 维度

| 维度 | 0 分 | 1 分 | 2 分 |
|------|------|------|------|
| 角色边界 | `test-design / qa / project-manager` 职责混乱 | 大体清晰，但仍有边界重叠 | 角色输入、输出、决策权都唯一 |
| 单一真源 | 同一概念多处定义且互相冲突 | 大部分收敛，但仍有重复权威 | `qa-report.md`、`test_cases_ref`、`phase_dir/unit_work_dir` 都只有一个真源 |
| 测试类型显式度 | 大量依赖隐含常识 | 核心测试类型可见，但触发条件不完整 | 冒烟、AC/功能、API、E2E、回归、探索、UX、恢复、NFR 都有显式承接 |
| 缺陷模型 | 只有 PASS/FAIL 或复现信息不足 | 能复现，但无法稳定 triage | `QAR-*` + severity/priority/impact_scope/user_impact 等字段完整 |
| 放行模型 | 无放行建议或建议不可落地 | 有建议，但与缺陷/waiver/残余风险脱节 | `release_recommendation`、`residual_risk`、`acceptance-summary` 完整闭环 |
| 工程一致性 | skill / template / hook / tests 不一致 | 大部分一致，仍有局部漂移 | 静态文档、脚本门禁、shell 合约测试完全一致 |
| 可读性 | 角色、流程、工件混在一起 | 结构清晰但阅读成本偏高 | 阅读顺序自然，团队成员能快速定位职责和工件 |

## 试点评审要求
- 契约测试必须全部通过
- replay 场景必须逐条说明“触发点 -> 应执行阶段 -> 预期 QAR -> 预期放行建议”
- 若任何 replay 场景无法映射到 `test-design -> qa -> project-manager` 链路，则本轮不得试点

## 本次实际评分结果

| 维度 | 分数 | 评分依据 |
|------|------|---------|
| 角色边界 | 2 | `test-design` 明确拥有 `QA 交接契约`，`qa` 明确拥有 Phase 级 `qa-report` 与 `release_recommendation`，`project-manager` 只消费签收与门禁汇总 |
| 单一真源 | 2 | `qa-report.md` 重复模板已删除，Phase/UNIT 语义和 `test_cases_ref` 已收束到 chain contract、QA skill、Phase 3 dispatch |
| 测试类型显式度 | 2 | 冒烟、AC/功能、API、E2E、回归、探索、UX、异常恢复、NFR 都已显式落入 `QA 交接契约` 和 `QA_A~QA_D` |
| 缺陷模型 | 2 | `QAR-*`、severity、priority、impact_scope、user_impact、environment_or_build、regression_flag、temporary_workaround、owner_hint 已进入模板与 QA gate |
| 放行模型 | 2 | `release_recommendation`、`residual_risk`、`acceptance-summary` 对齐和 `waiver` 约束已打通 |
| 工程一致性 | 2 | shell proving commands 通过，skill/template/hook/tests 已对齐 |
| 可读性 | 1 | 结构已经清楚，但 QA 链路仍然偏长，团队初次阅读成本仍高于理想状态 |

### 汇总
- 总分: `13 / 14`
- 单项 `0` 分: `无`
- 是否达到试点阈值（`>= 12/14`）: `是`
- 结论: `满足试点门槛，可进入小范围 pilot`

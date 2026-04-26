# 性能测试展开规则

> 引用者：`test-design/SKILL.md` 步骤 6。

Trigger: 展开性能测试专项，或判断性能指标、大数据量、并发、聚合、搜索或批量处理风险。
Read: 本文件的必须展开条件、常见展开信号、保守展开和最小用例方向。
Expect: 得到性能测试是否展开及最小用例方向。
Consume: 写入 `test-cases.json.test_cases`、`special_test_triggers` 和 `qa_handoff_contract`。
Evidence: `test-cases.json` 中存在对应专项用例、触发依据和 QA handoff 证据期望。
Sync: 专项触发规则变化时同步 `SKILL.md` 步骤 10、test-cases schema/template、completion gate 和治理测试。

## 必须展开条件

- PRD/Design 明确性能指标
- 大数据量处理
- 并发操作
- 报表 / 搜索 / 聚合
- 批量导入导出

## 常见展开信号

- 列表查询 + 多条件筛选
- 聚合统计、排序分页、跨表关联
- 批处理任务、异步消费堆积风险

## 不确定时的保守展开

- 若存在列表、聚合、搜索或批量操作，至少补 1 个性能边界场景。

## 最小用例方向

- 基线性能（典型数据量）
- 边界性能（极限数据量/并发）
- 性能退化风险（N+1、慢查询、锁冲突）

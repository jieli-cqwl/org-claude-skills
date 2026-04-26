# 契约测试展开规则

> 引用者：`test-design/SKILL.md` 步骤 6（多服务与外部接口场景）。

Trigger: 展开契约测试专项，或判断接口/外部 API/DTO/版本兼容风险。
Read: 本文件的必须展开条件、常见展开信号、保守展开和最小用例方向。
Expect: 得到契约测试是否展开及最小用例方向。
Consume: 写入 `test-cases.json.test_cases`、`special_test_triggers` 和 `qa_handoff_contract`。
Evidence: `test-cases.json` 中存在对应专项用例、触发依据和 QA handoff 证据期望。
Sync: 专项触发规则变化时同步 `SKILL.md` 步骤 10、test-cases schema/template、completion gate 和治理测试。

## 必须展开条件

- 多服务接口调用
- 外部 API 契约依赖
- DTO/VO 字段兼容要求
- 接口版本兼容要求

## 常见展开信号

- 设计中出现“向后兼容/版本演进/字段扩展”
- 同一接口被多个调用方消费
- 有错误码契约、幂等约束、分页契约

## 不确定时的保守展开

- 若字段变化可能影响其他调用方，至少补 1 个契约兼容场景。

## 最小用例方向

- 请求结构兼容（新增/缺省/类型）
- 响应结构兼容（字段/枚举/错误码）
- 版本兼容（旧客户端在新服务上可用）

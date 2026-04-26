# 安全测试展开规则

> 引用者：`test-design/SKILL.md` 步骤 6。

Trigger: 展开安全测试专项，或判断认证授权、敏感数据、文件上传、开放输入或高权限风险。
Read: 本文件的必须展开条件、常见展开信号、保守展开和最小用例方向。
Expect: 得到安全测试是否展开及最小用例方向。
Consume: 写入 `test-cases.json.test_cases`、`special_test_triggers` 和 `qa_handoff_contract`。
Evidence: `test-cases.json` 中存在对应专项用例、触发依据和 QA handoff 证据期望。
Sync: 专项触发规则变化时同步 `SKILL.md` 步骤 10、test-cases schema/template、completion gate 和治理测试。

## 必须展开条件

- 认证授权链路
- 敏感数据读写
- 文件上传能力
- 开放输入面（表单、查询、脚本输入）
- 高权限操作

## 常见展开信号

- 设计中出现角色/权限/Token/Session
- 输入直接进入查询、执行、模板渲染
- 返回值包含用户隐私或业务敏感字段

## 不确定时的保守展开

- 若用户输入可直接进入查询/执行/输出链路，至少补 1 组输入验证场景。

## 最小用例方向

- 输入验证（注入、越界、非法格式）
- 认证授权（未登录、越权、权限升级）
- 敏感数据保护（响应、日志、错误信息不泄露）

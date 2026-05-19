# DES-003 Input

日期：2026-05-14

## 输入来源

- `case_id`: `DES-003`
- `role`: `design`
- `input_origin`: `synthetic`
- `stage`: Stage 1 internal training dry-run
- `scope_boundary`: 本输入只用于评估 design 对接口契约、失败语义、观测和回滚的补全能力，不进入真实 `qft-pai`、语言选型、框架选型、开发任务或上线。

## 已冻结 PM 范围摘要

Phase 1 只验证单渠道客户消息回调进入后，系统能完成：

1. 三方消息回调接收。
2. 前置消息处理。
3. 上下文构建。
4. Agent 调度。
5. 响应生成。
6. 响应回写。
7. 链路证据记录。

非目标：

- 不做全渠道平台化。
- 不承诺自动上线。
- 不用 mock 链路替代真实验收。

## 不完整设计草稿

当前设计草稿只有模块名和主流程：

- `CallbackAdapter`: 接收三方平台消息回调。
- `MessagePreprocessor`: 做去重、格式标准化、风险初筛。
- `ContextBuilder`: 构建 agent 输入上下文。
- `AgentOrchestrator`: 选择 agent 并执行。
- `ResponseDispatcher`: 将结果回写三方平台。
- `ChainRecorder`: 保存过程记录。

草稿缺失：

- 每个接口的输入、输出、错误码和幂等键。
- 回调重复、乱序、三方超时、agent 超时、响应回写失败的失败语义。
- retry、降级、人工接管和回滚策略。
- 观测指标、结构化日志、链路追踪字段和告警条件。
- 与测试设计的风险映射。

## 本 case 要求

Design 必须把不完整草稿补成可供 test-design 生成风险用例的设计产物。

必须体现：

- 接口输入/输出/错误语义。
- 幂等、重试、降级、人工接管和回滚边界。
- 可观测性：指标、日志、trace/correlation 字段、告警。
- 失败路径：重复回调、乱序、三方超时、agent 超时、响应回写失败、链路记录失败。
- 明确哪些问题可以由 design 在 synthetic 范围内补全，哪些必须标记为待 human/PM/TD 裁决。
- 不只列模块名，不进入语言选型和实现任务。

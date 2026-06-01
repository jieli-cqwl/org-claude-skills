# Verify 阶段检查规则

## 目标

为 Phase2A / Phase2B / Phase2C 提供统一判定口径；只在对应阶段读取。

## Phase2A：TDD 与实现真实性

| 检查 | PASS | ISSUE |
| --- | --- | --- |
| RED 证据 | 每条 AC 有失败输出，失败原因指向目标行为缺失。 | RED 缺失、失败来自语法/导入/环境错误，或无法关联 AC。 |
| GREEN 证据 | 对应 RED 变为通过，命令和输出可复验。 | 只给历史结论、截图或口头说明。 |
| 测试先于实现 | TDD 证据、提交顺序或报告索引能证明先测后实现。 | 实现先出现，或证据无法区分时序。 |
| 增量一致 | RED 到 GREEN 的实现变更服务当前 AC。 | 顺手实现范围外能力。 |
| 实现真实性 | 通过 `fake-implementation-patterns.md` 反证无占位、硬编码和互抄。 | 测试或实现只证明固定样本。 |

## Phase2B：健壮性与配置风险

| 检查 | PASS | ISSUE |
| --- | --- | --- |
| 错误处理 | 外部调用、文件 IO、网络、数据库和异步任务有失败路径。 | 空 catch、裸 except、仅 log 后继续、返回默认值无错误信号。 |
| 超时与重试 | 外部依赖有超时，重试耗尽有可见失败。 | 无限等待、静默重试或失败后成功返回。 |
| 配置安全 | 密钥、Token、环境地址和端口来自配置或环境。 | 业务代码硬编码 secret、URL、端口或环境路径。 |
| 信息安全 | 用户面错误不泄露堆栈、密钥或内部路径。 | 错误消息暴露敏感内部细节。 |

代码规范以 `{{RUNTIME_HOME}}/rules/code-changes.md` 的 Code Changes 规则为准；本文件只给 verify 阶段的取证口径。

## Phase2C：规范与测试有效性

| 检查 | PASS | ISSUE |
| --- | --- | --- |
| 代码规范 | Scope、reuse、complexity、comments、error handling、configuration、dead code、external calls and performance risks satisfy the rule source. | 违反 Code Changes 规则，或无证据证明不适用。 |
| 测试有效性 | 测试断言 AC 行为、边界、错误路径或副作用。 | 只跑 happy path、无断言、断言实现细节。 |
| 测试可维护性 | 测试命名清楚、状态隔离、setup 清理配对。 | 顺序依赖、全局状态污染、过度断言、复制粘贴 setup。 |

## 证据要求

- 每个 ISSUE 写明阶段、AC 或 test_ref、`file:line` 和影响。
- 缺证据时标为 ISSUE 或 BLOCKED，不用“看起来没问题”替代。

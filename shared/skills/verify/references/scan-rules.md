# Task 级验收检查规则

## 检查 1: TDD 证据完整性（Phase 2A）

| 检查项 | 标准 | 子检查 |
|--------|------|--------|
| RED 阶段证据 | TDD 证据索引中有 RED 行且 commit SHA 可追溯（或旧格式完整输出） | 失败原因与 AC 相关（非语法/导入错误） |
| GREEN 阶段证据 | TDD 证据索引中有 GREEN 行且 commit SHA 可追溯（或旧格式完整输出） | 通过的测试数与新增测试数匹配 |
| 测试先于实现 | commit 历史或 TDD 证据索引时序证明测试先写 | RED→GREEN 间的 diff 仅含功能代码 |
| RED 质量 | 测试失败是因为功能缺失 | 非 `Cannot find module`、`SyntaxError` 等基础错误 |
| 增量一致性 | RED→GREEN 的代码变更与 AC 范围一致 | 无超出 AC 范围的额外实现 |

## 检查 2: 虚假实现检测（Phase 2A）

> 详细模式清单见 `fake-implementation-patterns.md`。

| 信号 | 判定 |
|------|------|
| `console.log("done")` / `print("completed")` | FAIL — 日志不是实现 |
| `// TODO` / `// FIXME` 标记仍存在 | FAIL — 未完成的标记 |
| 空函数体 / `pass` / `return null` 占位 | FAIL — 占位符代码 |
| `expect(true).toBe(true)` / 无断言测试 | FAIL — 无效测试 |
| 硬编码返回值匹配测试期望 | FAIL — 伪通过 |
| 测试断言与实现逻辑互相复制 | FAIL — 镜像测试 |

## 检查 3: 静默失败检测（Phase 2B）

> 判定依据：`{{RUNTIME_HOME}}/rules/代码规范.md` MUST（错误处理规范）。
> 详细方法论见 `silent-failure-methodology.md`。

| 信号 | 判定 | 严重度 |
|------|------|--------|
| 空 catch 块 | FAIL | Critical |
| 裸 except（Python `except:` / JS `catch(e) {}`） | FAIL | Critical |
| 错误被吞掉（catch 中仅 console.log 无 rethrow/return error） | FAIL | Major |
| 返回默认值但不记录原始错误 | FAIL | Major |
| 可选链(?.)无声跳过可能失败的操作 | FAIL | Minor |
| 重试逻辑耗尽未通知 | FAIL | Major |
| catch 过宽（捕获所有异常类型） | FAIL | Minor |
| 外部调用缺少超时控制 | FAIL | Major |
| 外部调用失败路径未处理 | FAIL | Major |

## 检查 4: 硬编码检测（Phase 2B）

> 判定依据：`{{RUNTIME_HOME}}/rules/代码规范.md` MUST（硬编码规范）。

| 信号 | 判定 | 例外 |
|------|------|------|
| 密钥/Token/Secret 直接写在代码中 | FAIL | 无例外 |
| URL/端口硬编码（非测试文件） | FAIL | localhost 在测试配置中 |
| 环境特定配置直接写在代码中 | FAIL | 无例外 |

## 检查 5: 代码规范（Phase 2C）

> 判定依据：`{{RUNTIME_HOME}}/rules/代码规范.md` MUST 条款（单一事实源）。

| 规则 | 标准 | 子检查 |
|------|------|--------|
| 复杂度约束 | 与 `{{RUNTIME_HOME}}/rules/代码规范.md` 一致 | 函数长度/参数/嵌套按规则执行 |
| 注释规范 | 与 `{{RUNTIME_HOME}}/rules/代码规范.md` 一致 | 文件/函数/字段注释解释意图与边界，非代码复述 |
| 外部调用健壮性 | 与 `{{RUNTIME_HOME}}/rules/代码规范.md` 一致 | API/DB/文件 IO 调用具备超时与错误处理 |
| 死代码治理 | 与 `{{RUNTIME_HOME}}/rules/代码规范.md` 一致 | 未使用导入/变量/函数/字段应清理 |
| 设计约束 | 与 MOD 定义一致 | 接口签名 + 约束条件（有 MOD 时） |

## 检查 6: 测试有效性（Phase 2C）

> 详细方法论见 `test-validity-methodology.md`。

## 检查 7: 测试可维护性（Phase 2C）

> 详细检查清单见 `test-maintainability-checklist.md`。

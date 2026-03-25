# 代码质量

> 本文件是 `rules/代码规范.md` 的实现指南与检查命令，不是规则源。
> 规则判定以 `rules/代码规范.md` MUST 条款为准。

## 复杂度治理（落地指南）

### 阈值与节奏

- MUST：循环复杂度（CC）`<= 10`
- SHOULD：认知复杂度（CogC）`<= 15`（分阶段治理，先观测再强制）
- 建议阶段：`warn` 观测 2-4 周 -> `enforce` 增量强制

### 门禁变量

- `COMPLEXITY_CHECK_MODE=warn|enforce`（默认 `warn`）
- `COMPLEXITY_SCOPE=changed|all`（默认 `changed`）
- `COMPLEXITY_ALLOW_MISSING_TOOLS=0|1`（默认 `0`）

### 检查命令（CC）

- Python：`ruff check --select C901 <files...>`
- TS/JS：`eslint <files...> --rule 'complexity: [error, 10]'`
- Java（Maven）：`mvn -q -DskipTests pmd:check`
- Java（Gradle）：`gradle pmdMain --quiet`

### CogC（阶段目标）

- TS/JS 可通过 `sonarjs/cognitive-complexity` 落地。
- Python/Java 建议在 SonarQube 或项目级静态分析流水线落地。
- 未接入稳定工具前，不建议直接设置为 MUST 门禁。

### 高复杂度常见重构手法

- 用早返回替代深层嵌套。
- 将条件分支改为策略表/映射分发。
- 拆出纯函数，减少副作用状态分支。
- 将“参数组合分支”前移为校验层，主流程保持线性。

## 注释质量（可判定标准）

### 有效注释应满足

- 解释业务意图、约束条件、失败条件、设计原因中的至少一项。
- 能帮助后来者在不读需求文档时理解边界。

### 无效注释反例

- 复述代码：`i += 1 // i 加 1`
- 空话占位：`// TODO`、`// NOTE`、`# 待补充`
- 与代码事实不一致的过期注释

## 用户友好错误提示

- 明确告知哪个操作失败 + 指引下一步行动 + 隐藏技术细节
- `422` -> "提交信息有误，请检查后重试"；`401` -> "登录已过期，请重新登录"
- 数据库/Redis/API 故障 -> "系统服务暂时不可用，请稍后再试"

## 外部服务调用

- 统一采用：超时配置化 + 错误分类 + 可观测日志
- 调用层输出可追踪错误上下文（请求 ID/上游依赖/重试次数）

## 设计评审检查清单

- 新代码是否属于当前模块职责边界？
- 是否引入不必要耦合或循环依赖？
- 接口变更是否与相邻模块契约兼容？
- 是否增加了可避免的偶然复杂度？

## 可测试性设计（与铁律兼容）

- 依赖注入友好：外部依赖可替换
- 纯函数优先：降低副作用耦合
- 时间与随机数可控：注入 Clock/Random Provider
- 与 `rules/铁律.md` 兼容：关键测试仍需连接真实数据库和服务，禁止 Mock 绕过验收

## 基础安全编码（指南）

- 输入验证：白名单优先，服务端强校验
- 参数化查询：禁止拼接 SQL
- 输出编码：按上下文进行 HTML/URL/JSON 编码
- 最小权限：数据库、消息队列、对象存储均使用最小授权

## 死代码清理实践

- 未使用的导入/注入/字段/方法/变量应在提交前清理
- Java：用构造器注入 + `final`（`@RequiredArgsConstructor`）替代 `@Autowired`
- Python：不用返回值时改 `dependencies=[Depends(...)]`
- 例外需标注：`# noqa: F401`（re-export）、`_` 前缀（框架签名）

## 常用检查命令汇总

- Python：`ruff check --select E,F,I,C901 .` / `mypy app/` / `vulture app/`
- TS：`npm run lint` / `npx tsc --noEmit --strict`
- Java：`mvn pmd:check` / `mvn spotbugs:check`

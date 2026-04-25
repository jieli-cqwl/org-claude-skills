# 接口完整性标准与最佳实践调研

被 `/design` SKILL.md 引用。

## Resource Contract

| 字段 | 内容 |
| --- | --- |
| Trigger | S6 需要定义接口输入、输出、错误码、边界行为，或判断接口定义分档 |
| Read | `references/interface-spec.md` |
| Expect | 获得接口完整性标准、分档规则和结构化接口模板 |
| Consume | 写入 `design.json.interfaces`、`design.json.interface_boundary`，并影响 `design.json.verification_mapping` |
| Evidence | 全栈或对外接口有入参、出参、错误码、边界行为和测试映射 |
| Sync | 变更时同步 `design/SKILL.md`、design template/schema、test-design 消费规则、review prompts 和 fixtures |

## 接口完整性标准

每个接口 REQUIRED：入参（字段/类型/校验规则）+ 出参（成功响应格式）+ 错误码（至少：参数校验错误、业务逻辑错误、系统错误）。

### 接口定义分档

| 档位 | 触发条件 | 定义方式 |
|------|---------|---------|
| 精简版 | 接口 <= 3 且非全栈 | 简化结构内联 `design.json.interface_boundary` |
| 标准版 | 接口 4-10 OR 全栈功能（不论接口数） | `design.json.interface_boundary` 结构化模板 |
| 增强版 | 接口 > 10 或对外 API | 独立 `design/API-SPEC.md` |

全栈功能判定：PRD/UNIT 中同时涉及前端页面/组件 AND 后端 API/Service 的功能。即使只有 1 个接口，只要是前后端交互就必须使用结构化模板定义。

### 结构化接口模板（标准版/增强版）

```markdown
### {METHOD} {PATH}
描述: {一句话}
入参: | 字段 | 类型 | 必填 | 校验规则 | 说明 |
出参（成功 {STATUS_CODE}）: JSON 示例
错误码: | HTTP 状态码 | error_code | 触发条件 | 用户消息 key |
边界行为: | 场景 | 预期行为 |
```

## 最佳实践调研

| 场景 | 是否调研 |
|------|---------|
| 技术选型（数据库、缓存、消息队列等） | 是 |
| 架构模式选择 | 是 |
| 项目已有技术栈内的常规扩展 | 否 |
| 简单 CRUD、单模块内部改动 | 否 |

调研深度：快速核实 1-2 次 / 对比调研 3-5 次 / 深度调研 5-8 次（每决策点上限 8 次）。

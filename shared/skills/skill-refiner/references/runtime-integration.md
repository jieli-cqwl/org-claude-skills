# Skill 与 Runtime 集成原则

`{{RUNTIME_HOME}}/` 引用决策决定语义强度：错误引用会把全局 MUST 降级成 skill 局部 SHOULD。

## Runtime 层级事实

| 层级 | 路径 | 强度 | 消费方式 |
| --- | --- | --- | --- |
| 规则 | `{{RUNTIME_HOME}}/rules/*.md` | MUST | 始终自动加载，不可被 skill 覆盖或放宽 |
| 参考 | `{{RUNTIME_HOME}}/reference/*.md` | SHOULD | 由 `assistant.md` 场景契约按场景自动加载 |

自动加载意味着 skill 不需要在正文"激活" runtime 内容。

## 引用决策

| 目标 | 正确姿势 | 反模式 |
| --- | --- | --- |
| 引用 rules MUST | 重申"以 rules 为准"或不提 | 在 skill 正文重写 rules 条文 |
| 引用整份 reference | 不做正文挂载，依赖自动加载 | 写"对齐 `{{RUNTIME_HOME}}/reference/X.md`" |
| 引用 reference 的具体角度 | 放在 reference 末尾交叉引用段，精准锚点 | 主体挂载整份文档，或多处重复挂载 |

交叉引用段格式：`## 交叉引用` 下列出 `` `{{RUNTIME_HOME}}/reference/X.md` — <具体角度>`` 或 `<相邻 skill 的 reference> — <用途>`。

## 反模式诊断

| 信号 | 处理 |
| --- | --- |
| SKILL 正文出现 `{{RUNTIME_HOME}}/reference/X.md` 且要求"对齐"/"扩展"/"按 X 审视" | 删除正文挂载；必要时改为交叉引用段 |
| 同一份 runtime reference 在单个 skill 内多处挂载 | 只保留语义最契合的一处 |
| skill 正文改写 rules，或把 MUST 写成"推荐"/"应该"/"建议" | 删除改写；如需强调，引用 rules 路径并保持原强度 |
| skill 自定义与 runtime reference 重叠的新方法论 | 改为交叉引用 runtime 版本；职责不同才独立保留 |

不确定 reference 是否自动加载时，查 `{{RUNTIME_HOME}}/assistant.md` 场景契约；场景匹配则不需挂载，未匹配再考虑交叉引用或扩展契约。

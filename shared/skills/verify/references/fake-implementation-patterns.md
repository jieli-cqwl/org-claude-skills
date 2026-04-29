# AI Agent 虚假实现模式清单

## 1. 占位符代码变体

### 直接占位（易检测）

| 模式 | 示例 |
|------|------|
| 空函数体 | `function process() {}` |
| 仅 return null | `function get() { return null; }` |
| pass 占位 | `def handle(): pass` |
| TODO 标记 | `// TODO: implement` |
| 日志代替实现 | `console.log("processing...")` |
| 注释代替代码 | `// 这里应该实现验证逻辑` |

### 伪实现（中等难度）

| 模式 | 示例 |
|------|------|
| 硬编码返回值 | `function validate() { return true; }` |
| 直接返回输入 | `function transform(data) { return data; }` |
| 空数组/对象 | `function query() { return []; }` |
| 模板代码未定制 | 复制框架模板但未修改业务逻辑 |
| 仅打印后返回固定值 | `console.log(input); return { status: "ok" };` |

### 看似实现但无效（难检测）

| 模式 | 示例 |
|------|------|
| 条件分支全返回同值 | `if (x) return ok; else return ok;` |
| 错误处理后正常继续 | `try { riskyOp(); } catch(e) { } return success;` |
| 验证函数永远返回 true | `function isValid(x) { return x !== null; }` 但传入永远非 null |
| 循环不执行 | `for (let i=0; i<0; i++) { ... }` |
| 异步但不 await | `async function save(data) { db.insert(data); }` 缺少 await |
| 正则永远匹配 | `/.*/` 或 `/.+/s` 作为验证 |
| 事件注册但无处理 | `emitter.on('event', () => {})` |

## 2. 测试与实现的相互抄袭

| 模式 | 检测方法 |
|------|---------|
| 测试复制实现逻辑 | 测试中的计算过程与实现完全相同 |
| 实现硬编码测试数据 | 实现中的返回值恰好等于测试的 expected |
| 测试断言 === 实现返回 | `expect(fn()).toBe("hardcoded")` 而 fn 中 `return "hardcoded"` |
| 快照代替断言 | 用快照测试代替行为断言（快照与实现同步生成） |

### 检测步骤
1. 比较测试的 expected 值与实现的 return 值
2. 检查实现是否包含与测试数据完全相同的字面量
3. 检查测试的计算逻辑是否复制了实现

## 3. 硬编码预期值伪装通过

| 模式 | 示例 |
|------|------|
| 实现中硬编码测试期望 | 测试期望 `{count: 3}`，实现 `return {count: 3}` 不做实际计算 |
| 条件匹配测试输入 | `if (input === "test@email.com") return validResult` |
| 环境判断走测试路径 | `if (process.env.NODE_ENV === 'test') return mockData` |
| 测试数据内嵌实现 | 实现中包含测试 fixture 的硬编码副本 |

## 4. 检测方法总结

1. 字面量比对：实现中的字面量是否与测试 expected 值完全匹配
2. 逻辑复杂度：实现的圈复杂度是否与 AC 要求的复杂度匹配（过低可疑）
3. 分支覆盖：实现中的 if/else 分支是否都能被触发
4. 副作用验证：声称写入数据库的操作是否真的有 DB 调用
5. 输入敏感性：改变输入是否改变输出（硬编码不会）

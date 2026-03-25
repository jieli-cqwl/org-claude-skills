# 测试代码质量

> 供 TDD 规范"测试代码质量"章节引用。测试可维护性标准。

## 1. 测试命名规范

### 格式

- `should_{预期行为}_when_{条件}`
- `given_{前提}_when_{动作}_then_{结果}`

### 示例

| 差 | 好 |
|---|---|
| `test1` | `should_return_404_when_user_not_found` |
| `testValidation` | `should_reject_empty_email_when_registering` |
| `testEdgeCase` | `given_expired_token_when_accessing_api_then_returns_401` |

### 规则

- 命名必须描述行为，不描述实现
- 读测试名就能知道测什么、什么条件、什么结果
- 不用 `test` 前缀（测试框架已知）

## 2. AAA 模式（Arrange-Act-Assert）

### 强制结构

```
// Arrange — 准备数据和环境
const user = createUser({ email: "test@example.com" });

// Act — 执行被测行为（通常一行）
const result = await registerUser(user);

// Assert — 验证结果
expect(result.status).toBe(201);
```

### 规则

- 每个测试只有一个 Act（一个被测行为）
- Arrange 和 Assert 之间有明显的 Act 分隔
- 不在 Assert 中执行副作用

## 3. DAMP 原则（Descriptive And Meaningful Phrases）

| 原则 | 说明 |
|------|------|
| 可读性优先 | 测试代码允许适度重复，优先可读 |
| 提取共享 setup | 完全相同的 setup 提取为 helper/fixture |
| 不过度 DRY | 不为减少 3 行重复引入抽象层 |
| 内联优先 | 测试数据尽量内联在测试中，方便阅读 |

## 4. 测试辅助函数/工厂复用规范

### 工厂函数

```
// 好：提供默认值 + 允许覆盖
function createUser(overrides = {}) {
  return { name: "Test", email: "test@example.com", ...overrides };
}

// 差：没有默认值，每次都要传全部字段
function createUser(name, email, role) { ... }
```

### 共享 setup

| 场景 | 策略 |
|------|------|
| 所有测试需要相同环境 | beforeAll/beforeEach |
| 部分测试需要特定数据 | describe 嵌套 + 局部 setup |
| 复杂对象构造 | 工厂函数 + 默认值覆盖 |

## 5. 参数化测试

当多个测试仅输入/输出不同时，使用参数化：

```
// 好：参数化
test.each([
  ["valid@email.com", true],
  ["invalid", false],
  ["", false],
])("validates email %s → %s", (email, expected) => {
  expect(isValidEmail(email)).toBe(expected);
});

// 差：3 个几乎相同的测试
```

## 6. AI 写测试的常见坏味道

| 坏味道 | 说明 | 修复 |
|--------|------|------|
| 过度断言 | 一个测试断言 10+ 个属性 | 拆分为多个聚焦测试 |
| 断言顺序依赖 | 测试 B 依赖测试 A 创建的数据 | 每个测试独立 setup |
| 测试间状态泄漏 | 共享全局变量/数据库状态 | 隔离 + 清理 |
| 镜像测试 | 测试代码复制实现逻辑 | 用独立计算或已知值验证 |
| 无效断言 | `expect(true).toBe(true)` | 断言实际业务行为 |
| 快照滥用 | 对动态内容做快照 | 仅对稳定的结构化输出做快照 |
| 实现细节断言 | 断言内部方法调用次数 | 断言外部可观察行为 |

## 7. 测试文件组织结构

| 策略 | 适用场景 | 结构示例 |
|------|---------|---------|
| 就近放置 | 单元测试 | `src/utils/validate.ts` → `src/utils/validate.test.ts` |
| 独立目录 | 集成测试 | `tests/integration/user-registration.test.ts` |
| 按功能分组 | 功能测试 | `tests/features/auth/login.test.ts` |

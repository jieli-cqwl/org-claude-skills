# AC 精度指南

> 引用者：tech-lead SKILL.md Phase 2 Step 11
> 互补：test-design/references/methodology.md 从 AC 设计用例，本文档确保 AC 本身精确可测


## 基础精度标准

| 维度 | 不合格 | 合格 |
|------|--------|------|
| 可 assert | "界面友好" | "错误提示包含字段名和限制条件" |
| 输入→输出 | "处理用户数据" | "POST /users {name,email} → 201 + User" |
| 可验证边界 | "支持大数据量" | "1000 条记录查询响应 < 500ms" |
| 错误处理 | "错误要处理" | "email 重复 → 409 DUPLICATE_EMAIL" |

## 复杂场景精度增强

### 决策表（多条件组合）

当 AC 涉及 >= 2 个独立条件时，展开为决策表：

```
条件: 角色(admin/user) × 状态(active/suspended)
| 角色  | 状态      | 预期行为          |
|-------|-----------|------------------|
| admin | active    | 允许操作，返回 200 |
| admin | suspended | 允许操作，返回 200 |
| user  | active    | 允许操作，返回 200 |
| user  | suspended | 拒绝，返回 403    |
```

### 状态转换（实体生命周期）

当 AC 涉及状态变更时，列出合法/非法转换：

```
状态: draft → published → archived
合法: draft→published (触发通知), published→archived
非法: archived→published → 409 INVALID_TRANSITION
非法: draft→archived → 409 INVALID_TRANSITION
```

### 前置条件（依赖特定状态）

当 AC 依赖前置状态时，显式声明：

```
AC: "用户可以支付订单"
前置条件: 订单状态=pending AND 库存充足
不满足-订单状态: 订单已支付/已取消 → 409 ORDER_NOT_PAYABLE
不满足-库存: 库存不足 → 409 INSUFFICIENT_STOCK
```

### 并发竞态（共享资源操作）

当 AC 涉及共享资源的并发操作时：

```
场景: 两用户同时购买最后 1 件库存
胜者: 返回 200，库存 -1
败者: 返回 409 INSUFFICIENT_STOCK
保证: 不出现超卖（库存 < 0）
```

## 自检流程

对 Plan 中每个 Task 的每条 AC 执行：

1. assert 翻译：能否直接写成 `assert response.status == 201`？不能 → 重写
2. 输入明确：入参字段、类型、约束是否完整？缺失 → 补充
3. 输出明确：HTTP 状态码/响应结构/副作用是否具体？模糊 → 细化
4. 错误路径：至少 1 个错误场景有明确错误码？没有 → 补充
5. 复杂场景：是否涉及多条件/状态转换/前置条件？是 → 使用对应增强格式
6. 模糊词扫描：是否包含下表中的模糊词？包含 → 替换

## 模糊词替换表

| 模糊词 | 替换为 |
|--------|--------|
| 正确处理 | 具体的输入→输出映射 |
| 合理的 | 具体的数值/规则 |
| 快速响应 | < N ms |
| 适当提示 | 具体提示文案或错误码 |
| 相关信息 | 具体字段列表 |
| 必要时 | 具体触发条件 |
| 等等 / 等 | 穷举完整列表 |
| 支持 | 具体的接口/操作/格式 |

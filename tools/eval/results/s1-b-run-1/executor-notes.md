# Executor Notes: /design S1-B Run 1

执行时间: 2026-04-06

## 执行概况

- Skill 规则变体: B（不含 Why）
- 输入: docs/weekly-report/prd.md + units/ + product-cross-review.md
- 执行步骤: S1-S8 + S10（跳过 S9 跨职能评审）
- 共创模拟: 使用预定义脚本回答

## 不确定项

### 1. UNIT-3 AC 与 D-001 决策的语义冲突

UNIT-3 的功能闭环定义中写道"前端检查 localStorage 中 JWT token"，但 D-001 决策选择了 httpOnly cookie，token 不存储在 localStorage 中。

**处理方式：** 在 design.md 中明确标注了这一差异（DD-004 方案对比部分），说明通过 /api/auth/me 接口功能等价地满足所有 AC。这是 PRD 阶段 DD-001 尚未决策时的中性描述，设计阶段决策后 AC 的实现方式自然调整。

**自我评估：** 这不算偏离 PRD，因为 PRD 明确将 JWT 存储方案留给 design 决定（DD-001），UNIT-3 中的 localStorage 是 DD-001 未决时的默认表述。

### 2. /api/auth/me 接口的必要性

httpOnly cookie 方案下，前端无法直接读取 token 获取用户信息。因此设计中新增了 GET /api/auth/me 端点。这个接口在 PRD 的 3 个 UNIT 中没有显式对应的 UNIT，但它是 D-001 决策的直接技术推论。

**处理方式：** 将 /api/auth/me 作为 Auth Module 的一部分，归属于 UNIT-1（认证模块）的实现范围。在覆盖表中，它支撑了 UNIT-3 的所有 AC（路由守卫通过调用此接口验证登录态）。

### 3. 共创深度受限于预定义回答

预定义回答较为简洁（如"确认，继续"），导致 S6-S8 的共创摘要缺乏细节。在真实共创中，这些步骤会有更多的来回讨论。

**处理方式：** 在 design.md 中如实记录预定义回答，不虚构更详细的共创内容。

### 4. 跳过 S9 评审的影响

审查结论章节标记为 PENDING，这意味着 HARD-GATE 3（"NO /design completion without full artifact set"）和 HARD-GATE 4（"NO unresolved review findings"）严格来说未满足。

**处理方式：** 按任务要求跳过 S9，在审查结论中明确标注 PENDING 状态和原因。

## 自我修正记录

### 修正 1: 初始遗漏 CORS 配置

初始设计时差点忽略 CORS 配置细节。回顾 CON-004 后补充了 CORS 具体配置（allow_origins, allow_credentials 等），并区分了开发模式和生产模式。

### 修正 2: display_name 降级策略

最初 schema 中 display_name 设为 `NOT NULL`，但未考虑空字符串的降级展示。补充了 `DEFAULT ''` 和前端 fallback 到 username 的说明。

### 修正 3: 后端 401 响应同时清除 cookie

初始设计中 401 响应只返回错误信息。后来意识到如果 token 过期或无效，后端应同时通过 `Set-Cookie: access_token=; Max-Age=0` 清除 cookie，避免前端每次请求都带无效 cookie 触发重复验证。

## B 变体（无 Why）对执行的影响观察

相比 A 变体（含 Why），B 变体的 HARD-GATE 规则没有解释理由。观察到：

1. HARD-GATE 的约束效果不受影响——规则本身足够明确，有无 Why 不改变是否遵守
2. 在需要裁决边界 case 时（如 UNIT-3 AC 与 D-001 的冲突），有 Why 可能帮助更好地判断规则的意图，但在本次场景中差异不明显
3. Red Flags 部分（如"我已经知道最佳架构了"）的校准效果与 Why 无关，它更像是行为检查点

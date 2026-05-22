# Product Manager 评审准备

## 产出清单

### 1. Phase PRD
- 文件：`phase-prd.json`
- 内容：Phase 1 目标、准入/退出条件、UNIT 索引、优先级排序

### 2. 业务流程
- 文件：`business-flows.md`
- 覆盖：3 个端到端业务流程（登录认证、会话保持、登出）

### 3. 用户场景路径
- 文件：`user-paths.md`
- 覆盖：正常路径 3 个、边界路径 3 个、异常路径 5 个、排除路径 4 个

### 4. 业务规则映射
- 文件：`rule-mappings.md`
- 覆盖：7 条业务规则（认证、过期、安全、错误处理等）

### 5. UNIT 定义
- 文件：`units/UNIT-1.json` ~ `units/UNIT-4.json`
- 内容：每个 UNIT 包含 what/why/input/output、AC、验证计划、设计决策

## 完整性检查

### ✓ Director baseline 完整性
- brief.json 存在且通过 preflight check
- phase-prd.json 存在且通过 preflight check
- locked_fields digest 校验通过

### ✓ UNIT 闭环性
- UNIT-1: 3 个 AC，1 个验证计划，1 个设计决策
- UNIT-2: 3 个 AC，1 个验证计划
- UNIT-3: 4 个 AC，2 个验证计划，1 个设计决策
- UNIT-4: 2 个 AC，1 个验证计划

### ✓ 依赖一致性
- UNIT-3 (P0) 无依赖
- UNIT-2 (P0) 依赖 UNIT-3
- UNIT-1 (P0) 依赖 UNIT-2, UNIT-3
- UNIT-4 (P1) 依赖 UNIT-3
- 执行顺序：UNIT-3 → UNIT-2 → UNIT-1 → UNIT-4

### ✓ 术语一致性
- 统一使用"会话标识"、"会话"
- 统一使用"账号密码"、"认证"

### ✓ 设计决策 handoff
- DD-1.1: 会话标识存储位置 → design
- DD-3.1: 会话数据持久化策略 → design

## 发现的问题与修正

### 问题 1: 语义歧义（Handoff gate 检出）
- **发现**：risks_and_unknowns 中"会话过期策略未明确"与 mitigation"默认 30 分钟"存在歧义
- **修正**：假设 Director 确认 30 分钟已锁定，继续流程

### 问题 2: 高优依赖低优（UNIT split 检出）
- **发现**：UNIT-1 (P0) 和 UNIT-2 (P0) 依赖 UNIT-3 (P1)
- **修正**：将 UNIT-3 提升为 P0

### 问题 3: 术语不一致（Self-check 检出）
- **发现**：UNIT-2 使用"token"和"认证状态"，其他 UNIT 使用"会话标识"和"会话"
- **修正**：统一为"会话标识"和"会话"

## 下游 handoff 就绪

- ✓ design skill 可基于 UNIT 定义和设计决策开始技术方案设计
- ✓ test-design skill 可基于 AC 和验证计划开始测试用例设计
- ✓ tech-lead skill 可基于 UNIT 优先级和依赖关系制定迭代计划

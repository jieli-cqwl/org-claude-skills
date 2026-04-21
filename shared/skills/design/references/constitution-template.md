# Constitution 模板 -- 项目级架构原则

> 引用者：product SKILL.md、design SKILL.md（Constitution Check 步骤）

## 用途

Constitution 是项目级的不可变架构原则。不同于 rules/（全局编码约束），Constitution 记录的是特定项目的架构决策，确保跨需求/跨 feature 的架构一致性。Phase 内 UNIT 间的共享决策由 `phase-{N}/design.json` 自然承载，Constitution 仅管理跨 Phase 和跨 feature 的共享决策。

## 存放位置

`docs/constitution.md`（项目根目录下，跨 feature 共享）

## 模板

```markdown
# Project Constitution

> 版本: v1.0 | 创建日期: YYYY-MM-DD | 最后更新: YYYY-MM-DD

## 架构原则

| # | 原则 | 理由 | 约束 |
|---|------|------|------|
| AP-1 | [如：所有数据访问走 Repository 层] | [为什么这样设计] | [违反时的后果/检测方式] |
| AP-2 | ... | ... | ... |

## 技术栈约束

| 层级 | 技术选型 | 版本约束 | 替代禁止 |
|------|---------|---------|---------|
| [如：后端框架] | [如：FastAPI] | [>=0.100] | [禁止引入 Flask/Django] |

## 集成契约

| 系统 | 协议 | 契约文档 | 变更流程 |
|------|------|---------|---------|
| [如：支付网关] | [REST/gRPC] | [链接] | [需要哪些审批] |

## 数据治理

| 规则 | 适用范围 | 执行方式 |
|------|---------|---------|
| [如：PII 数据必须加密存储] | [全部用户表] | [ORM 层自动加密] |

## 变更流程

Constitution 变更需要：
1. 提出变更理由和影响范围评估
2. 用户确认
3. 更新版本号和日期
```

## 使用规则

### 读取时机
- `/product-director` 流程开始时检查 `docs/constitution.md` 是否存在
- `/product-manager` 继续细化前沿用上游已确认的 Constitution 约束
- `/design` 流程开始时 REQUIRED 读取

### 合规验证
- `/product-director` 输出前验证新需求不与 Constitution 冲突
- `/product-manager` 不得改写已确认的 Constitution 约束，只能在既有约束内细化
- `/design` 方案对比时将 Constitution 合规性作为评估维度

### 首次创建
- 项目首次执行 `/design` 时，如果 `docs/constitution.md` 不存在，由 design 阶段在输出 `design.json` 的同时创建初始 Constitution
- 后续 design 如果做出新的架构决策，需要同步更新 Constitution

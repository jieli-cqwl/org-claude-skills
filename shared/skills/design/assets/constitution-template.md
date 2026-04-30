# Constitution 初始结构 -- 项目级架构原则

## 目标

提供 `docs/constitution.md` 的初始结构，用于记录跨 Phase、跨 feature 的项目级架构原则。

## 用途

Constitution 是项目级的长期架构原则。不同于 rules/（全局编码约束），Constitution 记录的是特定项目的架构决策，确保跨需求/跨 feature 的架构一致性。Phase 内 UNIT 间的共享决策由 `phase-{N}/design.json` 自然承载，Constitution 仅管理跨 Phase 和跨 feature 的共享决策。

## 存放位置

`docs/constitution.md`（项目根目录下，跨 feature 共享）

## 结构

```markdown
# Project Constitution

> 版本: v1.0 | 创建日期: YYYY-MM-DD | 最后更新: YYYY-MM-DD

## 架构原则

| # | 原则 | 理由 | 约束 |
|---|------|------|------|
| AP-1 | [项目级原则] | [为什么这样设计] | [违反时的后果/检测方式] |

每条原则必须记录：source decision、适用范围、用户确认、失效条件和检测证据。

## 技术栈约束

| 层级 | 技术选型 | 版本约束 | 替代限制 |
|------|---------|---------|---------|
| [技术层级] | [技术选型] | [版本约束] | [替代限制] |

## 集成契约

| 系统 | 协议 | 契约文档 | 变更流程 |
|------|------|---------|---------|
| [外部或内部系统] | [协议] | [契约文档] | [变更流程] |

## 数据治理

| 规则 | 适用范围 | 执行方式 |
|------|---------|---------|
| [治理规则] | [适用范围] | [执行方式] |

## 变更流程

Constitution 变更需要：
1. 提出变更理由和影响范围评估
2. 用户确认
3. 记录 source decision、适用范围、失效条件和检测证据
4. 更新版本号和日期
```

## 使用规则

- 只有跨 Phase 或跨 feature 的原则进入 Constitution；单个 Phase 内的设计事实留在 `design.json`。
- Constitution 变更必须有理由、影响范围和用户确认。
- `/design` 方案对比时将 Constitution 合规性作为评估维度。
- Phase 设计不能自动反写 Constitution；只有用户确认该原则跨 Phase 或跨 feature 生效时，才更新 Constitution。

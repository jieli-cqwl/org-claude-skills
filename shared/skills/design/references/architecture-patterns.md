# 架构模式选择框架

> 引用者：design SKILL.md Step 4。原则：可逆性>优化 | 领域建模先于选型 | 不确定时延迟决策

## Resource Contract

| 字段 | 内容 |
| --- | --- |
| Trigger | S4/S5 需要在模块化单体、微服务、事件驱动、CQRS、Serverless 等架构模式间做取舍 |
| Read | `shared/skills/design/references/architecture-patterns.md` |
| Expect | 获得模式适用条件、代价、反模式和决策启发式 |
| Consume | 写入 `design.json.key_decisions`、`design.json.option_analysis`，必要时影响 `design.json.modules` |
| Evidence | 每个架构模式决策有备选方案、取舍理由、用户确认或事实锚点 |
| Sync | 变更时同步 `design/SKILL.md`、design template/schema、completion gate、review prompts 和 fixtures |

| 模式 | 适用条件 | 优势 | 代价 | 反模式警示 |
|------|---------|------|------|-----------|
| 模块化单体 | 团队<=5、边界不清晰 | 部署简单、事务一致 | 模块耦合、扩展瓶颈 | 3人拆10服务=过早微服务化，应先单体 |
| 微服务 | 团队>10、边界已稳定、独立部署需求 | 独立部署、故障隔离 | 运维复杂、分布式事务 | "想学K8s"=技术驱动，应业务驱动 |
| 事件驱动 | 异步为主、松耦合、事件溯源 | 解耦、可追溯 | 最终一致性、调试难 | 所有调用走MQ=事件滥用，同步够则不引入 |
| CQRS | 读写负载差异大(读>=10x写) | 读写独立优化 | 同步延迟、复杂度翻倍 | 全模块CQRS=过度，仅差异显著处用 |
| Serverless | 流量突发、无状态、按需付费 | 零运维、自动扩缩 | 冷启动、厂商锁定 | — |

决策启发式：小团队(1-5)/低复杂度->模块化单体 | 小团队/中复杂度/高变化->单体+局部事件驱动 | 中团队(5-15)/中高复杂度->单体渐进拆分 | 大团队(15+)/高复杂度->微服务(边界已验证) | 流量突发->Serverless(无状态部分)。最终决策需结合项目上下文在 ADR 中论证。

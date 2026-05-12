# Design Skill 实战打磨验证报告（Phase 1 + Phase 2a）

**日期**：2026-05-10
**范围**：针对 `.field-test-feedback-2026-05-10.md` 暴露的 P0 问题（隐性约束 + digest 漂移），执行 Phase 1 打磨 + Phase 2a 下游消费验证
**目标**：把"效果达标"从"看起来还行"落到可验证的结论

---

## 结论先行

| 预期层 | 维度 | 验证结论 | 证据 |
|---|---|---|---|
| 形式层（A 轴） | A1 字段完整性 | ✅ 通过 | 5 道 validator 全绿 |
| 形式层 | A2 validators 无误报 | ✅ 通过 | review_digest --check / canonical_schema / canonical_rules / ledger / preflight 全绿 |
| 形式层 | A3 无技术失真 | ✅ 通过 | R1-R4 已修正 AOF always 违反、"跨 key 事务"等技术硬伤 |
| 形式层 | A4 无隐性约束 | ✅ **已关闭** | 新增 `canonical-ref-cheatsheet.md` 覆盖 validator 全部隐性约束；42 项自检全 PASS |
| 形式层 | A5 规则一致性 | ✅ **已关闭** | SKILL.md S1/S7/S8/S10 + "完成校验" 4 处同步引用速查表；reviewer prompt 补 DP-4 |
| 效果层（B 轴） | B2 语义正确性 | ✅ 通过 | 核心决策（token 机制、吊销模型、续期策略）经 3 视角评审收敛 |
| 效果层 | B3 下游消费性 | ✅ **已验证** | /test-design 模拟消费确认可无阻塞跑完；预估产生 7-10 条 P1-P2 typed gap |
| 效果层 | B4 收敛轮次 | ⚠️ 部分改善 | 本次 R1→R4（4 轮），预期下次基于速查表可降至 R1→R2 |
| 效果层 | B5 修正成本 | ⚠️ 改善中 | 引用约束前移到 S9 自检，S10 后若已审内容变化必须重审；实测收益待下次真实跑验证 |
| 效果层 | B6 多场景 | ❌ 未验证 | Phase 2b 延后至下次真实新 feature |
| 效果层 | B7 失败恢复指南 | ✅ 改善 | S10 FAIL 定位指南 + 速查表 FAIL 消息查表已接入 SKILL.md |

**整体判定**：**Phase 1 目标达成，Phase 2a 效果验证通过**。当前 design skill 产出（phase-2 design.json）对形式合规（A 轴）完全达标，对效果达标（B 轴）在可验证的维度上确认达标。遗留的 B4/B5 改善效果需下次跑 design 时回归验证，B6 多场景等下次真实新 feature。

---

## Phase 1 交付物

### 1. 引用约束速查表
**路径**：`shared/skills/design/references/canonical-ref-cheatsheet.md`
**内容**：9 大节
1. 引用格式类（正则硬约束）：manager_vp_ref / handoff_ref / reviewed_design_digest / runtime_facts
2. 引用白名单类：unit_coverage.design_refs / impact_scope.affected_modules / unit_coverage.ac_refs
3. 引用闭环类：verification_refs → evidence_ref / risks → risk_response / warn_followups → WARN findings
4. 枚举限定类：warn_followups.target / reviewers.reviewer / status 字段
5. 唯一性与覆盖类：id 唯一性 / co_creation_summary S3-S8 覆盖 / cross_cutting 4 基线
6. review wrapper 字段清理
7. Reviewed Design Digest 与 S11 closure/confirmation 追加规则
8. 快速自检清单（S9 前 15 项打钩）
9. 源码索引（每条约束给出文件:行号）

**验证**：用 phase-2 design.json 做反向自检，**42 条 PASS / 0 FAIL**，覆盖度确认。

### 2. SKILL.md 同步（4 处）

| 位置 | 改动 | 目的 |
|---|---|---|
| S1（L110 附近） | 新增一句：通读速查表、S4/S7/S10 按此对照 | 让 preflight 阶段就打印 hard constraints |
| S7 verification_mapping（L153） | 细化 manager_vp_ref 格式要求 + verification_refs 闭环要求 | 在写字段的准确时机引用约束 |
| S9 Owner Self-Check | 组装 owner 已自检并确认可送审的设计产物前按速查表 §8 自检 15 项 | review 前截流，避 S10 爆雷 |
| S10 FAIL 处理（L186） | 新增 validator FAIL 定位指南 + 已审内容变更需重审规则 | 把"FAIL 修复成本"从踩源码降到查表，同时避免绕过 review |
| "完成校验" | 新增一项：引用合规自检已完成 | checklist 级硬门槛 |

### 3. Reviewer prompt 调整

`design-product-reviewer-prompt.md` 补 **DP-4 口径一致性**维度：检查跨字段的同一度量/阈值/术语是否对齐（如 SLO vs rollback 阈值、P99/P95 口径、审计事件口径）。对应本次 R4 暴露的"DPR-R4-001 三口径冲突"类问题。

架构 / 测试 reviewer prompt 已有成熟维度化（DR-1~DR-6 / DT-1~DT-4），本轮不动。

---

## Phase 2a 下游消费验证（/test-design）

### 方法
不跑完整 /test-design（context 预算不够），由 Explore agent **精准模拟 TD-S2 Test Basis Analysis + TD-S3 Condition Mapping** 消费动作，按 7 个维度（接口/数据/横切/质量/风险/verification_mapping/design_refs 可追溯）评估 design.json 字段充分性。

### 关键结论
- ✅ **整体可消费**，无 BLOCKED
- ⚠️ **维度 A（接口）**：`interfaces[*].boundary_behaviors` 字段缺失 —— 本次速查表没覆盖这是语义层而非格式层问题
- ⚠️ **维度 D/F（质量 + verification_mapping）**：压测规模（QPS、并发数、持续时间）缺失
- ✅ 维度 B（数据）/ C（横切）/ E（风险）/ G（design_refs 可追溯）全部达标

### 预估 typed gap
**7-10 条**，分布：PRODUCT_GAP 2-3 / DESIGN_GAP 3-4 / TESTABILITY_GAP 2-3。全部 P1-P2，**不阻断 /test-design 运行**，但会在下游消费时反哺回 design 补充。

### 对 design skill 的反哺建议（下一轮打磨输入）
1. interfaces 字段中明确要求 `boundary_behaviors` 数组（当前 schema 允许缺失）
2. verification_mapping 的 evidence_ref 若涉及性能类，应附带 baseline QPS / 并发数 / 持续时间
3. modules 对并发控制、缓存一致性等分布式语义应有显式字段（concurrency_control / cache_invalidation）
4. runtime_facts 应捕获时钟同步、存储加密等基础 SLA 事实
5. cross_cutting_concerns.log 应明确字段集合、采样率、保留期

**这些不是本轮 Phase 1 要解决的问题**，属于下一轮真实场景的打磨输入。

---

## 已踩但速查表未覆盖的问题（元观察）

Phase 2a 暴露了一类**速查表本身结构性覆盖不到的问题**：

| 问题类型 | 速查表能否覆盖 | 为何 |
|---|---|---|
| 格式错（manager_vp_ref 等） | ✅ 能 | 正则约束是硬边界 |
| 白名单错（design_refs 非 MOD/IF） | ✅ 能 | 集合约束是硬边界 |
| 闭环不全（verification_refs 悬空） | ✅ 能 | 集合差集可判 |
| **字段语义不足**（boundary_behaviors 缺、压测规模缺） | ❌ **不能** | schema 允许缺失，但下游需要 |
| **跨字段口径不一致**（SLO vs rollback 阈值） | ❌ 不能 | 语义层判断 |

**启示**：
- 速查表解决的是**"按规则写 → 必通过 validator"**的下界问题
- B3 下游消费性（/test-design 真跑/模拟跑）解决的是**"按规则写 → 字段信息对下游够不够"**的上界问题
- 两者**互补**，不能互相替代。skill 打磨必须两轴并行

本次 Phase 1 已经补齐下界（A 轴）；上界（B 轴）的下一个打磨点是：让 schema 或 checklist 显式要求 boundary_behaviors、压测规模等字段——留给下一轮。

---

## 需要用户裁决的遗留项

按优先级列 3 项，供下次打磨循环参考：

### P1：interfaces schema 是否强制 boundary_behaviors
- 如果强制 → 下次 design 必须填，同时同步 schema、fixtures、tests 和 validator 证据；不以历史 design 为兼容边界
- 如果不强制 → 继续由 /test-design 产生 TESTABILITY_GAP，下游被动补
- 建议：先在 SKILL.md S8 和 reviewer prompt 中把 `boundary_behaviors` 设为设计契约目标；真实新 feature 再决定是否提升到 schema 强制级

### P1：verification_mapping 是否强制附带压测规模（性能类）
- 同上权衡
- 建议：先在速查表增加一条"性能类 VP 应附 baseline / concurrency / duration"的推荐级清单

### P2：Phase 2b 多场景验证何时做
- 现状：仓库没有合适的第二场景素材
- 建议：等下一次真实新 feature 时把它当二场景跑，**那次的形式达标率和 gap 数就是 B6 的真实信号**

---

## 签收

- 速查表：✅ 已创建（9 节 397 行），反向自检 42/42 PASS
- SKILL.md：✅ 4 处同步完成
- Reviewer prompt：✅ DP-4 维度已补
- /test-design 消费模拟：✅ 已完成，能无阻塞消费
- phase-2 design.json：✅ 现状保持不变（未因本轮打磨做修改）

本轮结束。下次循环起点：真实新 feature → 走一遍完整 design skill → 比较 R1 首轮 WARN 数相对本次 phase-2 的 17 条是否下降。

# Design Skill 实战反馈（2026-05-10）

**场景**：phase-2 长期会话（remember me / 30 天免登录），mock 上游 brief + phase-prd + UNITs，跑完整 S1→S10，3 视角评审共 4 轮收敛到 PASS/WARN/PASS。

---

## 1. 上游数据密度观察

| 维度 | 结果 |
|---|---|
| brief 字段对 design 够用吗？ | **60% 够用**。quality_hard_rules / non_goals / delivery_plan / phase_goals / success_metrics 直接可采证；但 **risk_preference**（brief 未显式定义容忍窗口）、**infra_constraints**（Redis 配置细节、MySQL 容量）**需推断** |
| phase-prd 决策引导够不够？ | **design_decision_candidates 仅列 2 个** (JWT vs 不透明 token、Redis vs MySQL)，但实际 design 识别出 **6 个**关键决策（多出吊销模型、续期策略、设备识别、中间件模式 4 个）。phase-prd 产物**需覆盖度量化清单**或显式提示"design 阶段可新增决策" |
| UNIT 场景完整性 | UNIT-1/2 共 8 条 AC + 8 boundary_case 覆盖完整，**对生成 verification_mapping 非常有用**；AC 级追踪回溯顺畅 |
| brief.delivery_plan 的分阶段约束 | 本次 mock 未声明 phase-2，被 product reviewer R1 WARN 标出 → 整理为 warn_followup。**启示**：brief 必须强制含 phase_id 列表；design skill 应在 S1 前 preflight 检查并 fail-closed |

**观察**：上游每减一个硬约束字段，design 阶段就多一条"推断→reviewer WARN→承接"的往返。**上游字段的熵越高，下游成本越低**。

---

## 2. 决策分组观察（D-001 ~ D-006）

| 决策 | 感受 | 反思 |
|---|---|---|
| D-001 token 机制 | phase-prd 直接引导 | ✓ 顺畅 |
| D-002 存储位置 | phase-prd 直接引导 | ✓ 顺畅 |
| D-003 吊销模型 | design 阶段新增 | 应在 phase-prd design_decision_candidates 预留占位 |
| D-004 续期策略 | design 阶段新增 | 同上 |
| D-005 设备识别 | design 阶段新增 | brief 隐式要求（non_goals 不含设备识别但 AC 要设备列表），需要 design 阶段补充 |
| D-006 中间件模式 | design 阶段新增 | 纯实现级决策，phase-prd 基本不会预见 |

**观察**：6 项决策里 4 项由 design 阶段"涌现"。这反过来说明 **design 阶段决策识别的价值**。但也暴露：**phase-prd 的 design_decision_candidates 本质是"候选提示"而非"封闭清单"**，需要 SKILL.md 在 S4 明确这一点（实际上 S4 已含"识别关键决策"，但未强调可超出 phase-prd 预览范围）。

---

## 3. 交叉引用负担

本 design.json 最终引用关系统计：
- D-001..D-006 → option_analysis / quality_attributes / tradeoff_points（内部）
- MOD-xxx (5) / IF-xxx (4) → interface_boundary / modules / data_architecture / unit_coverage
- VP-xxx (10) → quality_attributes / cross_cutting_concerns / impact_scope / risk_response / verification_mapping
- phase-prd.xxx[N] → verification_mapping.manager_vp_ref（17 条）

**踩坑**：
1. **`manager_vp_ref` 格式强约束**（`^phase-prd\.\w+\[\d+\]$`）在 SKILL.md / reviewer prompt 里**完全没提**，直到 S10 跑 `validate_canonical_rules.py` 才发现 13 条 manager_vp_ref 全部非法（带中文说明、引用 UNIT / risks / D-XXX）。**修复成本**：1 轮 R4 reviewer + review_closure digest 漂移。
2. **`unit_coverage.design_refs` 仅接受 MOD-xxx / IF-xxx**，不接受 D-xxx（决策 id）。同样在 S10 才爆雷，R5 lint-only 再改。
3. **`verification_refs` 引用的 VP 必须在 verification_mapping.evidence_ref 里定义**（不是 verification_plan 里定义！）。quality_attributes / cross_cutting_concerns / impact_scope / risk_response 的 `verification_refs` 全部走这个闭环。**容易误用**。
4. **`review_closure.warn_followups[*].target`** 枚举只有 4 个（`design.json#planning_constraints / risk_response / verification_mapping / product_handoff`），写 `/test-design` 会 FAIL。这个也没在 SKILL.md 提过。

**建议**：`SKILL.md / checklist.md / references/` 至少需要一份「**字段格式 & 引用约束速查表**」，S1 preflight 就打印并要求确认。否则开发者几乎必然在 S10 踩 2-3 个 lint 雷。

---

## 4. Reviewer 反馈质量

本次 4 轮共产生 findings：

| Round | Arch | Product | Test | 合计 |
|---|---|---|---|---|
| R1 | WARN × 6 | WARN × 3 | WARN × 8 | 17 |
| R2 | WARN × 4（含 2 条 R1 未收敛 + 2 条新发现） | — | — | 4 |
| R3 | PASS (2 INFO) | WARN × 1 | PASS (2 WARN 承接) | 3 |
| R4 | PASS (0) | WARN × 1（新口径） | PASS (3 WARN 承接) | 4 |

**质量观察**：
- **架构 reviewer 最尖锐** —— R1 就发现 AOF always 违反 brief 约束、"跨 key 事务"技术失真 2 条硬伤；R2 继续发现 R1 修正引入的新矛盾（SLO 阈值与 rollback 阈值冲突）。**非常有价值**。
- **产品 reviewer 较温和** —— 主要抓边界语义（audit vs non_goals）和用户可感知（失败时 UX）。**容易 PASS，但关键时刻抓重点**。
- **测试 reviewer 输出量最大** —— R1 就 8 条 WARN，基本都是"xxx 场景缺测试点"。**大量可直接承接到 /test-design**。
- **没有 false positive**：R1-R4 共 24 条 WARN + FAIL 均有实质 issue，没发现 reviewer "硬挑刺"。

**一个痛点**：**收敛循环次数不可控**。R1→R2 修 6 条，R2 又发现 2 条新矛盾；R4 是 lint-only 修正但 product reviewer 又挖出新三口径问题（DPR-R4-001）。**如果没有用户裁决/时间盒**，可能要 R5/R6 才收敛。SKILL.md 目前 "WARN 必须承接但不阻断" 的机制其实是收敛的关键 —— 建议文档里**更显式地强调 WARN 承接优先于继续修**。

---

## 5. 候选包 Digest 机制

**效用评估**：
- ✓ **防 reviewer 漂移**：3 reviewer 审的是同一份 candidate_digest，不会"审的不一样"
- ✓ **S10 --check 兜底**：review_closure 里的 digest 和最终 design.json（去掉 closure+confirmation）的 digest 必须相等，防止 reviewer 审完又偷改决策
- ✗ **过于严格**：**任何字段改动都让 digest 变**（包括 review_closure 外的非决策字段如 verification_mapping 格式修正）。本次 R4 和 R5 都是格式合规改动，但 digest 都变，触发"reviewer 审过的版本 vs 最终版本不一致"伪警报
- ✗ **无"语义 digest"**：无法区分"改决策"和"改格式"

**建议**：
- **A**（当前可行）：在 SKILL.md 标明"S10 若需 lint 修正，可在 review_closure 里用新 digest + 登记 warn_followup/resolved_failures 说明改动范围，无需重跑 reviewer"
- **B**（工程化改进）：`build_candidate_package.py` 支持双 digest：`canonical_digest`（当前整份 hash）+ `decision_digest`（只 hash key_decisions + option_analysis + interfaces + data_architecture 这些决策字段）。reviewer 审的是 decision_digest，格式修正不破坏链路

---

## 6. 本次实战暴露的 Skill 级问题清单

按严重度排序：

### P0（必改）
1. **`validate_canonical_rules.py` 的隐性约束未在 SKILL.md / checklist 标注**
   - `manager_vp_ref` 格式 `^phase-prd\.\w+\[\d+\]$`
   - `unit_coverage.design_refs` 仅 MOD-xxx/IF-xxx
   - `verification_refs` 闭环要求引用 vm.evidence_ref
   - `review_closure.warn_followups[*].target` 枚举限定
   - **修复**：S1 preflight 打印完整引用规则速查表，或 checklist.md 增加 "引用合规自检" 节

2. **candidate_digest 漂移与 reviewer 成本冲突**
   - S10 阶段经常因为 lint 修正让 digest 变
   - 每次重跑 reviewer 成本 ≈ 3 并行 × 3-5 分钟
   - **修复**：SKILL.md 明确 "S10 lint-only 改动可接受 digest 更新而不重审，但必须登记 warn_followup"

### P1（应改）
3. **phase-prd 的 design_decision_candidates 约束不清**
   - design 阶段可新增决策吗？本次 6 项决策有 4 项 phase-prd 没预览
   - **修复**：phase-prd skill 应明确"candidates 是**参考列表**而非**封闭清单**"；design skill S4 文档也补充"可识别新决策"

4. **3 reviewer prompt 风格不一致**
   - architecture prompt 有"6 维度"列表（DR-1..DR-6），product/test 没有相同级别的维度化
   - 实际运行中 architecture finding 最精准且有 issue_id 稳定性，product/test 偶尔"发散"
   - **修复**：product-reviewer-prompt.md / test-reviewer-prompt.md 补充维度化 checklist

### P2（可改）
5. **"1 vs 2+ 方案"成本非对称**
   - D-003 吊销模型我给了 3 方案；D-004 续期给了 2 方案
   - reviewer 不会因为"只给 2 方案"扣分，3 方案 +50% 文字量但收益有限
   - **修复**：SKILL.md 建议 "2 方案为下限，3+ 方案用于有明显第三选择的决策"

6. **review_closure.warn_followups 列表越来越长**
   - 4 轮评审累积 7 条 warn_followups，都指向 `design.json#verification_mapping`
   - /test-design skill 消费时可能被淹没
   - **修复**：warn_followups 应支持"合并/聚合"（例如同 finding 类别只保留最新一轮）

---

## 7. Skill 用户体验

**优点**：
- S0-S10 分阶段产出，每步都有产物和 checkpoint，**不会迷路**
- Pre-flight 检查早（S0/S1），避免深入后才发现上游数据缺失
- co_creation_summary 让交付工件可追溯到"哪些决定是和用户共议的"

**缺点**：
- **验证器 FAIL 时的修复路径不明确** —— validate_canonical_rules 只报 "unsupported manager ref" 或 "unknown design refs"，不说正确格式；开发者必须读源码
- **4 轮 reviewer 循环太频繁** —— 主要是 lint 雷触发的假循环
- **SKILL.md 阶段描述和实际 validator 行为脱钩** —— 比如 S9 SKILL.md 说"FAIL 必修 / WARN 承接"，但 validate_canonical_rules 在 S10 才跑，S9 reviewer 阶段发不出 lint 级 FAIL

---

## 8. 对阶段 2 优化的建议

1. **S0 阶段新增 "引用约束 preflight"** —— 把 validate_canonical_rules 的所有 hard constraint 在 S0 就打印出来
2. **candidate_package 支持 `--decision-only-digest`** —— 生成双 digest，允许 lint 级改动不重审
3. **reviewer prompt 统一维度化** —— product / test 补 DR-like 维度 checklist
4. **warn_followups 支持分类与聚合** —— 按 target 自动归并，下游消费友好
5. **SKILL.md 增加"常见引用踩雷" FAQ** —— 直接列 P0 那 4 条约束

---

**总体评价**：skill 可用性高，S0-S10 框架稳定。**最大痛点是"S10 lint 雷 → digest 漂移 → reviewer 重审"这一循环**，其他都可忍受。建议阶段 2 优先解 P0 两条。

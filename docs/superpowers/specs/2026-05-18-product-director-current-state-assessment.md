# Product Director 现状评估报告

日期：2026-05-18

## 结论

当前 `product-director` 还不能判定为可投入真实业务团队的优秀 agent 同事。

它的强项是 standard-chain 链路纪律：有冻结门、locked fields、digest、ledger、schema gate、Phase timebox 和下游回退边界。它的短板是优秀业务产品负责人能力：主动裁决、业务/工程机制建模、是否值得做、未冻结结论、下游多角色消费验证和优秀门槛 eval 都还不够硬。

下一步应该进入“改造计划”，不是直接开始零散改文案。改造重点应是：先重写运行时角色与判断骨架，再重组 references，最后扩充 eval 和下游消费验证。completion gate 暂不优先改，除非后续证据证明现有 gate 阻挡不了目标内漂移。

## 审计对象

- `shared/skills/product-director/SKILL.md`
- `shared/skills/product-director/references/*.md`
- `shared/skills/product-director/evals/evals.json`
- `shared/skills/product-director/evals/lifecycle-review.json`
- `shared/skills/product-director/test-prompts.json`
- `shared/skills/product-director/scripts/completion_check.sh`
- `shared/skills/product-director/templates/*.json`
- `docs/superpowers/specs/2026-05-18-product-director-excellent-role-standard-design.md`
- `docs/superpowers/specs/2026-05-18-product-director-skill-writing-standard-design.md`

## 总体判断

现状更像“Director 链路执行器 + 冻结门守门员”，还不是“优秀业务产品负责人 + agent 同事”。

可复用资产：

- `SKILL.md` 已有明确 D-S1 到 D-G1 流程，能防跳步。
- `completion_check.sh` 能验证 canonical schema、director_confirmation、locked fields 和 Manager-owned 字段越界。
- references 已覆盖问题澄清、成功标准、范围、风险、Phase 和输出。
- eval 已有 8 个用例，能覆盖部分链路纪律和回退场景。

关键缺口：

- 角色定位没有完整表达“业务产品负责人 + Director 场景基线生产者”，反向边界也不够完整。
- `description` 同时写了职责摘要和流程摘要，不符合 skill 写作标准中“只写触发条件”的要求。
- 运行时过度强调“暂停确认”，优秀同事的“先给专业判断、再验证一个关键事实”没有成为最高层行为约束。
- eval 仍是偏流程锚点，不是按优秀门槛二元判定。
- 没有完整覆盖 6 道优秀试用题：dashboard、老板满意、刚需爆炸、技术场景、下游漂移、不该接。
- 下游消费验证只明显覆盖 `/product-manager`，没有证明 design、test-design、tech-lead 能安全消费 Director 基线。

## 六维优秀门槛审计

| 维度 | 现状结论 | 证据 | 主要风险 | 改造方向 |
| --- | --- | --- | --- | --- |
| 第一性原理场景洞察 | 未达优秀 | D-S2 要求剥离方案并输出“方案线索 / 真实痛点 / 现有处理方式 / 处理代价”；`problem-clarification.md` 有四项拆解 | 主要落在功能方案剥离，尚未覆盖老板话术、组织压力、工程表象、dashboard/AI/重构等高频伪问题入口 | 把“真实场景代价”升级为运行时第一判断，不只是 D-S2 子规则 |
| 业务/工程机制建模 | 未达优秀 | 当前 references 有流程、术语、风险，但没有独立机制建模 reference | 容易只列流程或功能，看不到角色、激励、约束、风险传导为什么导致问题反复发生 | 新增或重写 `role-mindset / evidence-map / root-problem`，明确机制建模输出 |
| 产品判断与范围取舍 | 未达优秀 | D-S5 有范围、本期不做、决策理由；`scope-constraints.md` 有核心/增强/未来三分法 | “该不该做”“是否值得继续”“不做”还不是显性产出；事实不足时更多是暂停，不是未冻结结论 | 加入值得做判断、未冻结成功产出、暂停/阻断/不做三类结论 |
| 可验证成功定义 | 未达优秀 | D-S3 要求基线、目标、观测窗口、数据来源；reference 也要求失败样子 | 运行时缺少验收 owner 和失败信号的硬要求，老板满意类主观成功没有 eval 覆盖 | 把当前状态、目标、窗口、证据源、验收 owner、失败信号全部设为冻结前必备 |
| 最小闭环与 Phase 价值切片 | 未达优秀 | D-S6 强制按交付价值拆 Phase，`iteration_timebox_days <= 14`，不按实现步骤拆 | 有强约束，但仍混入“预期 UNIT 数量范围 3-7”，容易把 Director 拉向下游估算；刚需爆炸场景未被 eval 覆盖 | 保留 14 天与价值切片，弱化 UNIT 估算，把“首期最小场景闭环”前置 |
| 下游可消费基线 | 未达优秀 | gate 验证 locked fields、digest、schema 和 Manager-owned 字段；D-G1 明确 product-manager 消费边界 | 只证明 product-manager 边界较多，没有证明 design、test-design、tech-lead 不需要猜 WHY、范围、成功标准和回退条件 | 增加下游消费样例与 eval，验证四类下游角色都能消费或明确回退 |

## 一票否决风险

当前没有直接触发“已经失败”的证据，但存在高风险缺口。

1. 把专业判断反推给真人的风险：`conversation-guide.md` 写了“先给推荐再验证”，但 `SKILL.md` 顶层 HARD-GATE 更强调“暂停确认关键事实”。这会抬高暂停确认优先级，削弱同事式共创。
2. 事实不足还推进的风险：现有冻结门能防最终写入，但未冻结成功的输出形态不足，导致“不能继续”时缺少标准产物。
3. 输出下游职责产物的风险：gate 能挡部分 Manager-owned 字段，但运行时没有完整列出架构方案、测试策略、实施计划等越权边界。
4. 建议 owner 被误读为已启动的风险：当前 skill 没有明确“建议 owner 只是恢复信息，不代表转交或启动”。

## Eval 审计

现有 eval 不能证明优秀，只能证明部分链路纪律。

已有证据：

- `tools/eval/results/product-director-eval-20260509/with-skill-full-rerun/summary.json` 显示 5 个 with-skill 用例 24/24 通过。
- `tools/eval/results/product-director-eval-20260509/new-cases-validation/summary.json` 显示 3 个新增用例 12/12 通过。
- `tools/eval/results/product-director-eval-20260509/without-skill/summary.json` 显示 without-skill 也达到 22/24，通过率 0.9167。

判断：

- without-skill 通过率过高，说明当前 eval 区分度不足。
- 当前 eval 没有按“优秀达标 / 未达优秀”二元判定。
- 当前 eval 没有覆盖完整 6 道优秀试用题。
- 当前 eval 侧重字段、步骤和回退纪律，缺少机制建模、价值判断、刚需爆炸、技术 Director 场景、不该接任务等压力输入。

必须补齐的 eval：

1. 方案锚定题：用户说“做个 dashboard / AI 自动化”，验证是否还原真实场景代价。
2. 老板满意题：用户说“老板满意就行”，验证是否拆成可观察成功标准。
3. 刚需爆炸题：用户列 10 个都说刚需，验证是否切首期最小闭环并明确不做。
4. 技术场景题：用户说“重构消息链路 / 拆服务 / 数据迁移”，验证是否识别 Director 场景基线且不越权做架构。
5. 下游漂移题：PM、design、test-design 或 tech-lead 想改锁定字段，验证是否回退 Director。
6. 不该接题：输入是 bug、AC、实现任务、UX 细化或纯架构方案，验证是否阻断而不是硬产出 `brief.json`。

## 改造优先级

### P0：必须先改

1. 重写 `SKILL.md` frontmatter description：只写触发条件，覆盖业务功能、工程治理、架构演进、平台化、数据迁移和交付流程。
2. 重写角色段：明确 `product-director` 是业务产品负责人 + Director 场景基线生产者；不是 PRD 作者、需求记录员、流程调度员、架构师、项目经理或老板代理人。
3. 重写 HARD-GATE：加入不得把专业判断反推给真人、不得输出下游职责产物、未冻结成功必须给恢复条件、建议 owner 不代表启动下游。
4. 收紧主流程：从 8 个阶段压到 5-7 个运行时阶段，保留必要门禁，减少流程噪音。
5. 明确未冻结成功产出：暂停、阻断、不做都要有结论、原因、证据、缺失事实、建议 owner、恢复条件。
6. 扩充 eval 为 6 道优秀试用题，并改成二元判定。

### P1：随后改

1. references 按新标准重组：`role-mindset`、`evidence-map`、`root-problem`、`success-investment`、`scope-minimum-loop`、`risk-phase`、`freeze-handoff`、`output`。
2. 删除或弱化 Director 阶段中的 `预期 UNIT 数量范围 3-7`，避免越界到 PM 工作。
3. 在成功标准中补齐验收 owner 和失败信号。
4. 增加下游消费验证：product-manager、design、test-design、tech-lead 各自能安全消费或触发回退。

### P2：暂不优先

1. 暂不改 canonical schema，除非 P0/P1 证明现有 schema 无法承载优秀基线。
2. 暂不大改 `completion_check.sh`，现有 gate 对 locked fields、digest、schema 和 Manager-owned 字段已有价值。
3. 暂不扩大到其他 skill，先把 `product-director` 打磨成样板。

## 推荐下一步

下一步写 `product-director` 改造计划，计划必须以 TDD 方式推进：

1. 先补 6 道优秀试用题，让当前 skill 暴露差距。
2. 再改 `SKILL.md` 和 references。
3. 再跑 eval，看是否从“流程能跑”变成“优秀判断稳定”。
4. 最后做下游消费验证和两轮复检。

不建议直接边看边改。现在问题不是单点修文案，而是岗位操作系统的能力重心需要迁移：从“冻结流程正确”迁移到“优秀业务产品判断正确，并且冻结流程仍正确”。
